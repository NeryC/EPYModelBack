# =============================================================================
# test_seirhuf_normal.R
# =============================================================================
# Script principal del pipeline de inferencia bayesiana para el modelo SEIRHUF.
#
# Descripción general
# --------------------
# Ejecuta un loop deslizante de inferencia MCMC que avanza día a día desde
# el inicio de los datos hasta el final de la serie temporal disponible.
# En cada día:
#   1. Integra el ODE un paso hacia adelante (t → t+1) para obtener el nuevo
#      estado del sistema (S, E, I, R, H, U, F, O).
#   2. Ejecuta rstan::sampling() sobre los datos de la ventana deslizante
#      de 14 días para estimar los parámetros epidemiológicos.
#   3. Guarda los resultados en la bitácora (sim_SEIRHUF.csv).
#   4. Genera gráficos de diagnóstico MCMC (pairs plot y traceplot) en PDF.
#
# Estructura del loop por fases
# ------------------------------
#   Días < 213  : Usa el modelo SEIR (sin H/U/F). La hospitalización no estaba
#                 sistemáticamente registrada al inicio de la pandemia.
#   Día == 213  : Transición a SEIRH. Se inicializan H, U, F con datos
#                 observados alrededor del día 213.
#   Días > 213  : Usa el modelo SEIRH completo (8 compartimentos).
#
# Manejo de divergencias MCMC
# ----------------------------
# Si Stan reporta divergencias o treedepth máximo excedido, se incrementa
# adapt_delta y se re-ejecuta el sampling hasta convergencia.
# El ajuste de adapt_delta funciona en ambas direcciones:
#   - Si hay problemas (x=1): aumentar (más pasos pequeños, menos divergencias)
#   - Si no hay problemas (x=0): reducir gradualmente para mantener eficiencia
#
# Reanudación de ejecuciones interrumpidas
# -----------------------------------------
# La bitácora persiste el último día completado. Al reiniciar el script,
# el loop comienza desde bitacora$obtener_datos()$ndate + 1.
#
# Al finalizar el loop llama a projection_at_time.R para generar las
# proyecciones a 45 días.
# =============================================================================

rm(list = ls())
library(glue)
library(dplyr)
library(deSolve)
library(bayesplot)
library(gridExtra)
require(ggplot2)
library(rstan)
library(tictoc)

# Usar tantos núcleos como estén disponibles (acelera muestreo en paralelo)
nchain  <- 8
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)  # Evita recompilación si el .stan no cambió


# =============================================================================
# 1. Cargar módulos del pipeline
# =============================================================================
setwd(getwd())
root_path <- paste(getwd(), "/src/model_seirh/", sep = "")

parametros <- modules::use(glue("{root_path}parametros.R"))
bitacora   <- modules::use(glue("{root_path}bitacora_evolucion.R"))
inferencia <- modules::use(glue("{root_path}inferencia_estadistica.R"))
reportes   <- modules::use(glue("{root_path}reportes.R"))

# Archivo acumulativo de resúmenes de parámetros por iteración (prob.csv)
sim_seirhuf_path <- paste(parametros$data_path, "prob.csv", sep = "")


# =============================================================================
# 2. Funciones auxiliares
# =============================================================================

# Imprime el valor de una variable con su nombre (para diagnóstico)
reportar <- function(e) {
  print(glue("{deparse(substitute(e))} = {e}"))
}

# Ajusta adapt_delta en función del resultado de la iteración.
# x == 1 → había problemas (divergencias): aumentar adapt_delta (pasos más pequeños).
# x == 0 → sin problemas: reducir adapt_delta gradualmente para mantener eficiencia.
# Se usa una estrategia asimétrica para evitar quedar atrapado cerca de 1.
set_adapt_delta <- function(adapt_delta, x) {
  if (x == 1) {
    # Aumentar: si ya está cerca de 1, reducir el gap a la mitad en vez de sumar 0.01
    if (adapt_delta + 0.01 >= 1) {
      adapt_delta <- 1 - (1.0 - adapt_delta) / 10
    } else {
      adapt_delta <- adapt_delta + 0.01
    }
  } else {
    # Reducir: expandir el gap x10 o restar 0.01 (mínimo 0.85)
    if (adapt_delta + 0.01 >= 1) {
      adapt_delta <- 1 - (1.0 - adapt_delta) * 10
    } else {
      adapt_delta <- max(adapt_delta - 0.01, 0.85)
    }
  }
}

# Imprime la fecha de inicio del día de simulación en curso
imprimir_dia_inicio_simulacion <- function(n_shift) {
  idate <- as.Date(as.numeric(as.Date("2020-03-06")) + n_shift, origin = "1970-01-01")
  print(glue("Simulation day: {idate} ({n_shift})."))
}

# Imprime la hora actual y el tiempo estimado de finalización del loop
imprimir_tiempo_estimado <- function(n_shift) {
  tiempo_actual        <- Sys.time()
  tiempo_estimado_fin  <- tiempo_inicio_experimento +
    (t_end + 1 - t_init) / (n_shift - t_init + 0.001) *
      (tiempo_actual - tiempo_inicio_experimento)
  print(glue("Actual time: {tiempo_actual}; Estimated ending time: {tiempo_estimado_fin}."))
}


# =============================================================================
# 3. Parámetros globales del experimento
# =============================================================================
t0          <- 0                                           # Tiempo inicial del ODE
t           <- seq(1, parametros$experimento$tamano_ventana, by = 1)  # Tiempos de evaluación
n_poblacion <- as.numeric(parametros$parametros_ode_init["N"])
adapt_delta <- 0.85                                        # Valor inicial de adapt_delta


# =============================================================================
# 4. Fase de inicialización (modelo init)
# =============================================================================
# Solo se ejecuta en la primera corrida (cuando la bitácora está vacía).
# Estima las condiciones iniciales e0 e i0 (expuestos e infecciosos el día 0),
# así como la tasa de transmisión beta inicial.

if (bitacora$ejecutar_model_init) {
  modelo_init <- inferencia$compilar_modelo(parametros$filepaths$modelo_init)

  constructor_datos_init <- inferencia$metaconstructor_datos_init(
    parametros$cantidades_diarias,
    t0,
    t,
    parametros$parametros_ode_init,
    parametros$experimento$tamano_ventana
  )

  datos_init <- constructor_datos_init(parametros$id_inicio_sim)
  chains_init <- 2 * nchain  # Más cadenas para mejor exploración del espacio inicial
  iter_init   <- 3000
  warmup_init <- 1000
  stopifnot(iter_init > warmup_init)

  # Bucle de re-intento si Stan reporta divergencias
  reruntest_init <- 1
  while (reruntest_init > 0) {
    tic("sampling init")
    fitmodel_init <- inferencia$ejecutar_inferencia_estadistica(
      modelo_init,
      datos_init,
      chains_init,
      warmup_init,
      iter_init,
      .adapt_delta = adapt_delta
    )
    toc()

    reruntest_init <- get_num_divergent(fitmodel_init) + get_num_max_treedepth(fitmodel_init)
    if (reruntest_init > 0) {
      print("Reruning sampling because:")
      reportar(get_num_divergent(fitmodel_init))
      reportar(get_num_max_treedepth(fitmodel_init))
      adapt_delta <- set_adapt_delta(adapt_delta, 1)
    }
  }

  # Extraer el punto MAP (máximo a posteriori) del modelo init
  pars_init  <- c("e0", "i0", "beta", "sigma_r", "lp__")
  extracted  <- extract(fitmodel_init)
  index      <- which.max(extracted$lp__)
  seed       <- get_seed(fitmodel_init)

  # Condiciones iniciales del sistema SEIR al día de inicio
  e   <- extracted$e0[index]
  i   <- extracted$i0[index]
  r   <- as.numeric(parametros$parametros_ode_init["r0"])
  s   <- n_poblacion - e - i - r
  i_total  <- e + i
  beta_opt <- extracted$beta[index]

  # Guardar el estado inicial en la bitácora
  bitacora$establecer_fecha(parametros$fecha_inicio)
  bitacora$establecer_ndate(parametros$id_inicio_sim)
  bitacora$cargar_fitmodel_seir(fitmodel_init, c("beta", "sigma_r", "lp__"),
                                 parametros$id_inicio_sim, sim_seirhuf_path)
  bitacora$establecer_adapt_delta_SEIR(adapt_delta)
  adapt_delta <- set_adapt_delta(adapt_delta, 0)

  bitacora$establecer_SEIRHUF(s, e, i, r, NA, NA, NA, r)
  bitacora$establecer_diarios(r, NA)
  bitacora$establecer_subregistros(r, NA)
  bitacora$establecer_numero_reproductivo(
    beta_opt / as.numeric(parametros$parametros_ode_seir["gamma"]) * s / n_poblacion
  )
  bitacora$establecer_semilla(seed)
  bitacora$establecer_porciento(s / n_poblacion, i_total / n_poblacion, r / n_poblacion)
  bitacora$escribir_linea()
}


# =============================================================================
# 5. Restaurar estado inicial del sistema desde la bitácora
# =============================================================================
# Se usa el estado del último día guardado como punto de partida del loop.

y0_seir <- c(
  S = bitacora$obtener_datos()$S,
  E = bitacora$obtener_datos()$E,
  I = bitacora$obtener_datos()$I,
  R = bitacora$obtener_datos()$R,
  O = bitacora$obtener_datos()$O
)
y0_huf <- c(
  H = bitacora$obtener_datos()$H,
  U = bitacora$obtener_datos()$U,
  F = bitacora$obtener_datos()$F
)

# Si ya estamos en la fase SEIRH (ndate >= 213) pero H/U/F son NA
# (reanudando desde bitácora anterior al cambio), inicializar desde observados
if (sum(is.na(y0_huf)) > 0 & bitacora$obtener_datos()$ndate >= 213) {  # nolint
  ndate_actual <- bitacora$obtener_datos()$ndate
  y0_huf <- c(
    H = mean(parametros$cantidades_diarias$hospitalizados[ndate_actual + (-3:3)]),
    U = mean(parametros$cantidades_diarias$uci[ndate_actual + (-3:3)]),
    F = sum(parametros$cantidades_diarias$fallecidos[1:ndate_actual])
  )
}

# Estado completo SEIRH: primero S,E,I,R luego H,U,F luego O
y0_seirh <- c(y0_seir[1:4], y0_huf, y0_seir[5])


# =============================================================================
# 6. Compilar modelos Stan y preparar constructores de datos
# =============================================================================
pars_seir  <- c("beta", "sigma_r", "lp__")
pars_seirh <- c("beta", "lamih", "lamif", "lamhu", "lamhf", "lamuf",
                "sigma_r", "sigma_h", "sigma_u", "sigma_f", "lp__")

# Los metaconstructores capturan los datos y devuelven una función que acepta
# n_shift y (opcionalmente) el estado inicial para armar el objeto `data` de Stan
constructor_datos_SEIR  <- inferencia$metaconstructor_datos_SEIR(
  parametros$cantidades_diarias, t0, t, parametros$parametros_ode_seir,  parametros$experimento$tamano_ventana)
constructor_datos_SEIRH <- inferencia$metaconstructor_datos_SEIRH(
  parametros$cantidades_diarias, t0, t, parametros$parametros_ode_seirh, parametros$experimento$tamano_ventana)

# Compilar los modelos Stan (puede tomar 1-2 minutos la primera vez)
modelo_SEIR  <- inferencia$compilar_modelo(parametros$filepaths$modelo_SEIR)
modelo_SEIRH <- inferencia$compilar_modelo(parametros$filepaths$modelo_SEIRH)

# Configuración MCMC: 8 cadenas × 3000 iteraciones, 1000 de warmup → 2000 muestras/cadena
chains_SEIR  <- 2 * nchain
chains_SEIRH <- 2 * nchain
iter_SEIR    <- 3000
iter_SEIRH   <- 3000
warmup       <- 1000


# =============================================================================
# 7. Loop principal de inferencia
# =============================================================================
# Avanza desde el último día guardado hasta el final de la serie temporal.

tiempo_inicio_experimento <- Sys.time()
t_init <- bitacora$obtener_datos()$ndate
t_end  <- as.numeric(as.Date(parametros$fecha_final)) -
           as.numeric(parametros$fecha_inicial) -
           parametros$experimento$tamano_ventana

# Verificar si ya se completó todo el loop
loopbool <- if (t_init + 1 >= t_end) 0 else 1

if (loopbool == 1) {
  for (n_shift in seq(t_init + 1, t_end)) {
    imprimir_dia_inicio_simulacion(n_shift)
    imprimir_tiempo_estimado(n_shift)

    # -------------------------------------------------------------------------
    # Fase SEIR (días < 213): sin hospitalización
    # -------------------------------------------------------------------------
    if (n_shift < 213) {

      # Integrar el ODE SEIR un paso (t → t+1) con los parámetros del día anterior
      odefun_parms <- c(
        parametros$parametros_ode_seir,
        tamano_ventana = parametros$experimento$tamano_ventana,
        beta           = bitacora$obtener_datos()$beta,
        imported       = parametros$cantidades_diarias$importados[n_shift - 1 + 1:parametros$experimento$tamano_ventana],
        v_filtrado     = parametros$cantidades_diarias$inmunizados[n_shift - 1 + 1:parametros$experimento$tamano_ventana]
      )
      out <- ode(y = y0_seir, times = seq(0, 1), func = parametros$odefun_seir, parms = odefun_parms)

      # Actualizar estado del sistema tras el paso de integración
      bitacora$establecer_SEIRHUF(
        as.numeric(out[2, -1]["S"]), as.numeric(out[2, -1]["E"]),
        as.numeric(out[2, -1]["I"]), as.numeric(out[2, -1]["R"]),
        NA, NA, NA,
        as.numeric(out[2, -1]["O"])
      )
      y0_seirh <- out[2, -1]
      y0_seir  <- y0_seirh[c("S", "E", "I", "R", "O")]

      # Estadísticas diarias y subregistro
      i_total <- as.numeric(out[2, -1]["E"]) + as.numeric(out[2, -1]["I"])
      bitacora$establecer_diarios(as.numeric(out[2, "R"] - out[1, "R"]), NA)
      dailyr_sin_sr    <- as.numeric(out[2, "R"] - out[1, "R"]) / parametros$factor_subregistro[n_shift]
      r_sin_sr         <- bitacora$obtener_datos()$R_sin_subRegistro + dailyr_sin_sr
      bitacora$establecer_subregistros(r_sin_sr, dailyr_sin_sr)
      bitacora$establecer_porciento(
        as.numeric(out[2, -1]["S"]) / n_poblacion,
        i_total / n_poblacion,
        as.numeric(out[2, -1]["O"]) / n_poblacion
      )

      # Inferencia MCMC con modelo SEIR (re-intentar si hay divergencias)
      reruntest_seir <- 1
      while (reruntest_seir > 0) {
        tic("sampling SEIR")
        datos_seir     <- constructor_datos_SEIR(n_shift, y0_seir)
        fitmodel_seir  <- inferencia$ejecutar_inferencia_estadistica(
          modelo_SEIR, datos_seir, chains_SEIR, warmup, iter_SEIR, .adapt_delta = adapt_delta
        )
        toc()
        reruntest_seir <- get_num_divergent(fitmodel_seir) + get_num_max_treedepth(fitmodel_seir)
        if (reruntest_seir > 0) {
          print("Reruning sampling because:")
          reportar(get_num_divergent(fitmodel_seir))
          reportar(get_num_max_treedepth(fitmodel_seir))
          adapt_delta <- set_adapt_delta(adapt_delta, 1)
        }
      }

      # Guardar diagnósticos MCMC en PDF
      seed <- get_seed(fitmodel_seir)
      reportes$graficar_pares_entre_parametros_en_pdf(
        glue("{parametros$model_seirh}res14/pair_out/pairs_seir.pdf"), fitmodel_seir, pars_seir)
      reportes$graficar_parametros_vs_iteraciones_en_pdf(
        glue("{parametros$model_seirh}res14/pair_out/trace_seir.pdf"), fitmodel_seir, pars_seir)

      # Actualizar bitácora y reducir adapt_delta si todo fue bien
      bitacora$establecer_fecha(parametros$fecha_inicio + n_shift - parametros$id_inicio_sim)
      bitacora$establecer_ndate(n_shift)
      bitacora$cargar_fitmodel_seir(fitmodel_seir, pars_seir, n_shift, sim_seirhuf_path)
      bitacora$establecer_numero_reproductivo(
        bitacora$obtener_datos()$beta / as.numeric(parametros$parametros_ode_seir["gamma"]) *
          bitacora$obtener_datos()$S / n_poblacion
      )
      bitacora$establecer_semilla(seed)
      bitacora$establecer_adapt_delta_SEIR(adapt_delta)
      adapt_delta <- set_adapt_delta(adapt_delta, 0)

    # -------------------------------------------------------------------------
    # Fase de transición (día 213) y fase SEIRH (días > 213)
    # -------------------------------------------------------------------------
    } else {

      if (n_shift == 213) {
        # Transición SEIR → SEIRH: inicializar H, U, F desde datos observados.
        # Se usa la media de ±3 días alrededor del día 213 para suavizar ruido.
        odefun_parms <- c(
          parametros$parametros_ode_seir,
          tamano_ventana = parametros$experimento$tamano_ventana,
          beta      = bitacora$obtener_datos()$beta,
          imported  = parametros$cantidades_diarias$importados[n_shift - 1 + 1:parametros$experimento$tamano_ventana],
          v_filtrado = parametros$cantidades_diarias$inmunizados[n_shift - 1 + 1:parametros$experimento$tamano_ventana]
        )
        out <- ode(y = y0_seir, times = seq(0, 1), func = parametros$odefun_seir, parms = odefun_parms)

        # Inicializar H/U/F desde datos observados del registro diario
        y0_huf <- c(
          H = mean(parametros$cantidades_diarias$hospitalizados[213 + (-3:3)]),
          U = mean(parametros$cantidades_diarias$uci[213 + (-3:3)]),
          F = sum(parametros$cantidades_diarias$fallecidos[1:213])
        )

        bitacora$establecer_SEIRHUF(
          as.numeric(out[2, -1]["S"]), as.numeric(out[2, -1]["E"]),
          as.numeric(out[2, -1]["I"]), as.numeric(out[2, -1]["R"]),
          as.numeric(y0_huf["H"]), as.numeric(y0_huf["U"]),
          as.numeric(y0_huf["F"]), as.numeric(out[2, -1]["O"])
        )
        # Estado completo SEIRH: S,E,I,R (sin O del out) + H,U,F + O
        y0_seirh <- c(out[2, c(-1, -6)], y0_huf, out[2, 6])
        i_total  <- as.numeric(y0_seirh["E"] + y0_seirh["I"] + y0_seirh["H"] + y0_seirh["U"])
        y0_seir  <- y0_seirh[c("S", "E", "I", "R", "O")]
        bitacora$establecer_diarios(as.numeric(out[2, "R"] - out[1, "R"]), NA)

      } else {
        # Días > 213: integrar ODE SEIRH completo con lambdas estimadas en el paso anterior
        odefun_parms <- c(
          parametros$parametros_ode_seirh,
          tamano_ventana = parametros$experimento$tamano_ventana,
          beta       = bitacora$obtener_datos()$beta,
          lambda_ih  = bitacora$obtener_datos()$lamih,
          lambda_if  = bitacora$obtener_datos()$lamif,
          lambda_hu  = bitacora$obtener_datos()$lamhu,
          lambda_hf  = bitacora$obtener_datos()$lamhf,
          lambda_uf  = bitacora$obtener_datos()$lamuf,
          imported   = parametros$cantidades_diarias$importados[n_shift + 1:parametros$experimento$tamano_ventana],
          v_filtrado = parametros$cantidades_diarias$inmunizados[n_shift + 1:parametros$experimento$tamano_ventana]
        )
        out <- ode(y = y0_seirh, times = seq(0, 1), func = parametros$odefun_seirh, parms = odefun_parms)

        bitacora$establecer_SEIRHUF(
          as.numeric(out[2, -1]["S"]), as.numeric(out[2, -1]["E"]),
          as.numeric(out[2, -1]["I"]), as.numeric(out[2, -1]["R"]),
          as.numeric(out[2, -1]["H"]), as.numeric(out[2, -1]["U"]),
          as.numeric(out[2, -1]["F"]), as.numeric(out[2, -1]["O"])
        )
        # Se registra dos veces para asegurar que la segunda asignación (con F) prevalece
        bitacora$establecer_diarios(
          as.numeric(out[2, "R"] - out[1, "R"]),
          as.numeric(out[2, "F"] - out[1, "F"])
        )
        i_total  <- as.numeric(out[2, -1]["E"] + out[2, -1]["I"] + out[2, -1]["H"] + out[2, -1]["U"])
        y0_seirh <- out[2, 2:9]
      }

      # Estadísticas comunes a días 213 y > 213
      bitacora$establecer_porciento(
        as.numeric(out[2, -1]["S"]) / n_poblacion,
        i_total / n_poblacion,
        as.numeric(out[2, -1]["O"]) / n_poblacion
      )
      dailyr_sin_sr <- as.numeric(out[2, "R"] - out[1, "R"]) / parametros$factor_subregistro[n_shift]
      r_sin_sr      <- bitacora$obtener_datos()$R_sin_subRegistro + dailyr_sin_sr
      bitacora$establecer_subregistros(r_sin_sr, dailyr_sin_sr)

      # Inferencia MCMC con modelo SEIRH completo
      reruntest_seirh <- 1
      while (reruntest_seirh > 0) {
        tic("sampling SEIRH")
        datos_seirh    <- constructor_datos_SEIRH(n_shift, y0_seirh)
        fitmodel_seirh <- inferencia$ejecutar_inferencia_estadistica(
          modelo_SEIRH, datos_seirh, chains_SEIRH, warmup, iter_SEIRH, .adapt_delta = adapt_delta
        )
        toc()
        reruntest_seirh <- get_num_divergent(fitmodel_seirh) + get_num_max_treedepth(fitmodel_seirh)
        if (reruntest_seirh > 0) {
          print("Reruning sampling because:")
          reportar(get_num_divergent(fitmodel_seirh))
          reportar(get_num_max_treedepth(fitmodel_seirh))
          adapt_delta <- set_adapt_delta(adapt_delta, 1)
        }
      }

      seed <- get_seed(fitmodel_seirh)
      reportes$graficar_pares_entre_parametros_en_pdf(
        glue("{parametros$model_seirh}res14/pair_out/pairs_seirh.pdf"), fitmodel_seirh, pars_seir)
      reportes$graficar_parametros_vs_iteraciones_en_pdf(
        glue("{parametros$model_seirh}res14/pair_out/trace_seirh.pdf"), fitmodel_seirh, pars_seir)

      bitacora$establecer_fecha(parametros$fecha_inicio + n_shift - parametros$id_inicio_sim)
      bitacora$establecer_ndate(n_shift)
      bitacora$cargar_fitmodel_seirh(fitmodel_seirh, pars_seirh, n_shift, sim_seirhuf_path)
      bitacora$establecer_numero_reproductivo(
        bitacora$obtener_datos()$beta / as.numeric(parametros$parametros_ode_seir["gamma"]) *
          bitacora$obtener_datos()$S / n_poblacion
      )
      bitacora$establecer_semilla(seed)
      bitacora$establecer_adapt_delta_SEIR(adapt_delta)
      adapt_delta <- set_adapt_delta(adapt_delta, 0)
    }

    # Persiste la fila del día actual al CSV de bitácora
    bitacora$escribir_linea()
  }
}

print("Loop finished...")


# =============================================================================
# 8. Generar proyecciones
# =============================================================================
# Si el loop ya terminó (loopbool == 0), usar el último ndate de la bitácora.
# projection_at_time.R usa la variable `n_shift` para saber desde qué día proyectar.
if (loopbool == 0) {
  n_shift <- bitacora$obtener_datos()$ndate
}

source(glue("{root_path}projection_at_time.R"))

print("projection finished...")
