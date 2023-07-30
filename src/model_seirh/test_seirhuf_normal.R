rm(list = ls())
library(glue)
library(dplyr)
library(deSolve)
library(bayesplot)
library(gridExtra)
require(ggplot2)
library(rstan)
library(tictoc)

nchain <- 8
options(mc.cores = parallel::detectCores()) # Para aprovechar multiples nucleos
rstan_options(auto_write = TRUE) # Para evitar recompilacion de modelos STAN


setwd(getwd())
root_path <- paste(getwd(),
  "/src/model_seirh/",
  sep = ""
)

parametros <- modules::use(glue("{root_path}parametros.R"))
bitacora <- modules::use(glue("{root_path}bitacora_evolucion.R"))
inferencia <- modules::use(glue("{root_path}inferencia_estadistica.R"))
reportes <- modules::use(glue("{root_path}reportes.R"))
sim_seirhuf_path <- paste(parametros$data_path,
  "prob.csv",
  sep = ""
)

# TODO Generalizar a listas y estructuras mas complejas
reportar <- function(e) {
  print(glue("{deparse(substitute(e))} = {e}"))
}

set_adapt_delta <- function(adapt_delta, x) {
  if (x == 1) {
    if (adapt_delta + 0.01 >= 1) {
      adapt_delta <- 1 - (1.0 - adapt_delta) / 10
    } else {
      adapt_delta <- adapt_delta + 0.01
    }
  } else {
    if (adapt_delta + 0.01 >= 1) {
      adapt_delta <- 1 - (1.0 - adapt_delta) * 10
    } else {
      adapt_delta <- max(adapt_delta - 0.01, 0.85)
    }
  }
}

t0 <- 0
t <- seq(1, parametros$experimento$tamano_ventana, by = 1)
n_poblacion <- as.numeric(parametros$parametros_ode_init["N"])
adapt_delta <- 0.85

if (bitacora$ejecutar_model_init) {
  modelo_init <- inferencia$compilar_modelo(parametros$filepaths$modelo_init)

  constructor_datos_init <-
    inferencia$metaconstructor_datos_init(
      parametros$cantidades_diarias,
      t0,
      t,
      parametros$parametros_ode_init,
      parametros$experimento$tamano_ventana
    )

  datos_init <- constructor_datos_init(parametros$id_inicio_sim)
  chains <- 2 * nchain
  iter <- 3000
  warmup <- 1000
  stopifnot(iter > warmup)

  reruntest_init <- 1
  while (reruntest_init > 0) {
    tic("sampling init")
    fitmodel_init <-
      inferencia$ejecutar_inferencia_estadistica(
        modelo_init,
        datos_init,
        chains,
        warmup,
        iter,
        .adapt_delta = adapt_delta
      )
    toc()

    reruntest_init <-
      get_num_divergent(fitmodel_init) + get_num_max_treedepth(fitmodel_init)
    if (reruntest_init > 0) {
      print("Reruning sampling because:")
      reportar(get_num_divergent(fitmodel_init))
      reportar(get_num_max_treedepth(fitmodel_init))
      adapt_delta <- set_adapt_delta(adapt_delta, 1)
    }
  }
  pars_init <- c("e0", "i0", "beta", "sigma_r", "lp__")

  extracted <- extract(fitmodel_init)
  index <- which.max(extracted$lp__)
  fit_summary <- summary(fitmodel_init, pars = pars_init)$summary

  seed <- get_seed(fitmodel_init)

  bitacora$establecer_fecha(parametros$fecha_inicio)
  bitacora$establecer_ndate(parametros$id_inicio_sim)
  bitacora$cargar_fitmodel_seir(
    fitmodel_init, c("beta", "sigma_r", "lp__"),
    parametros$id_inicio_sim, sim_seirhuf_path
  )
  bitacora$establecer_adapt_delta_SEIR(adapt_delta)
  adapt_delta <- set_adapt_delta(adapt_delta, 0)

  r <- as.numeric(parametros$parametros_ode_init["r0"])
  e <- extracted$e0[index]
  i <- extracted$i0[index]
  s <- n_poblacion - e - i - r
  i_total <- e + i
  beta_opt <- extracted$beta[index]

  bitacora$establecer_SEIRHUF(s, e, i, r, NA, NA, NA, r)
  bitacora$establecer_diarios(r, NA)
  bitacora$establecer_subregistros(r, NA)
  bitacora$establecer_numero_reproductivo(
    beta_opt /
      as.numeric(
        parametros$parametros_ode_seir["gamma"]
      ) * s / n_poblacion
  )
  bitacora$establecer_semilla(seed)
  bitacora$establecer_porciento(
    s / n_poblacion, i_total / n_poblacion, r / n_poblacion
  )
  bitacora$escribir_linea()
}

y0_seir <-
  c(
    S = bitacora$obtener_datos()$S,
    E = bitacora$obtener_datos()$E,
    I = bitacora$obtener_datos()$I,
    R = bitacora$obtener_datos()$R,
    O = bitacora$obtener_datos()$O
  )
y0_huf <-
  c(
    H = bitacora$obtener_datos()$H,
    U = bitacora$obtener_datos()$U,
    F = bitacora$obtener_datos()$F
  )

if (sum(is.na(y0_huf)) > 0 & bitacora$obtener_datos()$ndate >= 213) { # nolint
  y0_huf <-
    c(
      H = mean(
        parametros$cantidades_diarias$hospitalizados[
          bitacora$obtener_datos()$ndate + (-3:3)
        ]
      ),
      U = mean(
        parametros$cantidades_diarias$uci[
          bitacora$obtener_datos()$ndate + (-3:3)
        ]
      ),
      F = sum(
        parametros$cantidades_diarias$fallecidos[
          1:(bitacora$obtener_datos()$ndate)
        ]
      )
    )
}

y0_seirh <- c(y0_seir[1:4], y0_huf, y0_seir[5])

pars_seir <- c("beta", "sigma_r", "lp__")

pars_seirh <- c("beta", "lamih", "lamif", "lamhu", "lamhf", "lamuf", "sigma_r", "sigma_h", "sigma_u", "sigma_f", "lp__")

tiempo_inicio_experimento <- Sys.time()
t_init <- bitacora$obtener_datos()$ndate

t_end <- as.numeric(as.Date(parametros$fecha_final)) - as.numeric(parametros$fecha_inicial) - parametros$experimento$tamano_ventana

imprimir_tiempo_estimado <- function(n_shift) {
  tiempo_actual <- Sys.time()
  tiempo_estimado_fin <- tiempo_inicio_experimento +
    (t_end + 1 - t_init) / (n_shift - t_init + 0.001) *
      (tiempo_actual - tiempo_inicio_experimento)
  print(glue("Actual time: {tiempo_actual}; Estimated ending time: {tiempo_estimado_fin}."))
}
imprimir_dia_inicio_simulacion <- function(n_shift) {
  idate <- as.Date(as.numeric(as.Date("2020-03-06")) + n_shift,
    origin = "1970-01-01"
  )
  print(glue("Simulation day: {idate} ({n_shift})."))
}

constructor_datos_SEIR <- inferencia$metaconstructor_datos_SEIR(parametros$cantidades_diarias, t0, t, parametros$parametros_ode_seir, parametros$experimento$tamano_ventana)
constructor_datos_SEIRH <- inferencia$metaconstructor_datos_SEIRH(parametros$cantidades_diarias, t0, t, parametros$parametros_ode_seirh, parametros$experimento$tamano_ventana)

modelo_SEIR <- inferencia$compilar_modelo(parametros$filepaths$modelo_SEIR)
modelo_SEIRH <- inferencia$compilar_modelo(parametros$filepaths$modelo_SEIRH)

chains_SEIR <- 2 * nchain
chains_SEIRH <- 2 * nchain
iter_SEIR <- 3000
iter_SEIRH <- 3000
warmup <- 1000

loopbool <- 1
if (bitacora$obtener_datos()$ndate + 1 >= t_end) {
  loopbool <- 0
}

if (loopbool == 1) {
  for (n_shift in seq(bitacora$obtener_datos()$ndate + 1, t_end)) {
    imprimir_dia_inicio_simulacion(n_shift)
    imprimir_tiempo_estimado(n_shift)

    if (n_shift < 213) {
      odefun_parms <- c( # pasar esto! en vez de fitmodel
        parametros$parametros_ode_seir,
        tamano_ventana = parametros$experimento$tamano_ventana,
        beta           = bitacora$obtener_datos()$beta,
        imported       = parametros$cantidades_diarias$importados[n_shift - 1 + 1:parametros$experimento$tamano_ventana],
        v_filtrado     = parametros$cantidades_diarias$inmunizados[n_shift - 1 + 1:parametros$experimento$tamano_ventana]
      )
      out <- ode(
        y     = y0_seir,
        times = seq(0, 1),
        func  = parametros$odefun_seir,
        parms = odefun_parms
      )
      bitacora$establecer_SEIRHUF(
        as.numeric(out[2, -1]["S"]),
        as.numeric(out[2, -1]["E"]),
        as.numeric(out[2, -1]["I"]),
        as.numeric(out[2, -1]["R"]),
        NA, NA, NA,
        as.numeric(out[2, -1]["O"])
      )
      y0_seirh <- out[2, -1]
      y0_seir <- y0_seirh[c("S", "E", "I", "R", "O")]

      bitacora$establecer_porciento(
        as.numeric(out[2, -1]["S"]) / n_poblacion,
        i_total / n_poblacion,
        as.numeric(out[2, -1]["O"]) / n_poblacion
      )

      i_total <- as.numeric(out[2, -1]["E"]) + as.numeric(out[2, -1]["I"])
      bitacora$establecer_diarios(as.numeric(out[2, "R"] - out[1, "R"]), NA)
      dailyr_sin_subregistro <-
        as.numeric(out[2, "R"] - out[1, "R"]) /
          parametros$factor_subregistro[n_shift]
      r_sin_subregistro <-
        bitacora$obtener_datos()$R_sin_subRegistro + dailyr_sin_subregistro
      bitacora$establecer_subregistros(r_sin_subregistro, dailyr_sin_subregistro)

      reruntest_seir <- 1
      while (reruntest_seir > 0) {
        tic("sampling SEIR")
        datos_seir <- constructor_datos_SEIR(n_shift, y0_seir)
        fitmodel_seir <- inferencia$ejecutar_inferencia_estadistica(
          modelo_SEIR,
          datos_seir,
          chains_SEIR,
          warmup,
          iter_SEIR,
          .adapt_delta = adapt_delta
        )
        toc()
        reruntest_seir <-
          get_num_divergent(fitmodel_seir) + get_num_max_treedepth(fitmodel_seir)
        if (reruntest_seir > 0) {
          print("Reruning sampling because:")
          reportar(get_num_divergent(fitmodel_seir))
          reportar(get_num_max_treedepth(fitmodel_seir))
          adapt_delta <- set_adapt_delta(adapt_delta, 1)
        }
      }
      seed <- get_seed(fitmodel_seir)
      reportes$graficar_pares_entre_parametros_en_pdf(
        glue("{parametros$model_seirh}res14/pair_out/pairs_seir.pdf"),
        fitmodel_seir, pars_seir
      )
      reportes$graficar_parametros_vs_iteraciones_en_pdf(
        glue("{parametros$model_seirh}res14/pair_out/trace_seir.pdf"),
        fitmodel_seir, pars_seir
      )

      bitacora$establecer_fecha(
        parametros$fecha_inicio + n_shift - parametros$id_inicio_sim
      )
      bitacora$establecer_ndate(n_shift)
      bitacora$cargar_fitmodel_seir(
        fitmodel_seir, pars_seir, n_shift, sim_seirhuf_path
      )
      bitacora$establecer_numero_reproductivo(
        bitacora$obtener_datos()$beta /
          as.numeric(parametros$parametros_ode_seir["gamma"]) *
          bitacora$obtener_datos()$S / n_poblacion
      )
      bitacora$establecer_semilla(seed)
      bitacora$establecer_adapt_delta_SEIR(adapt_delta)
      adapt_delta <- set_adapt_delta(adapt_delta, 0)
    } else {
      if (n_shift == 213) {
        odefun_parms <- c( # pasar esto! en vez de fitmodel
          parametros$parametros_ode_seir,
          tamano_ventana = parametros$experimento$tamano_ventana,
          beta = bitacora$obtener_datos()$beta,
          imported = parametros$cantidades_diarias$importados[
            n_shift - 1 + 1:parametros$experimento$tamano_ventana
          ],
          v_filtrado = parametros$cantidades_diarias$inmunizados[
            n_shift - 1 + 1:parametros$experimento$tamano_ventana
          ]
        )
        out <- ode(
          y     = y0_seir,
          times = seq(0, 1),
          func  = parametros$odefun_seir,
          parms = odefun_parms
        )
        y0_huf <-
          c(
            H = mean(parametros$cantidades_diarias$hospitalizados[213 + (-3:3)]),
            U = mean(parametros$cantidades_diarias$uci[213 + (-3:3)]),
            F = sum(parametros$cantidades_diarias$fallecidos[1:213])
          )
        bitacora$establecer_SEIRHUF(
          as.numeric(out[2, -1]["S"]),
          as.numeric(out[2, -1]["E"]),
          as.numeric(out[2, -1]["I"]),
          as.numeric(out[2, -1]["R"]),
          as.numeric(y0_huf["H"]),
          as.numeric(y0_huf["U"]),
          as.numeric(y0_huf["F"]),
          as.numeric(out[2, -1]["O"])
        )
        y0_seirh <- c(out[2, c(-1, -6)], y0_huf, out[2, 6])
        i_total <-
          as.numeric(
            y0_seirh["E"] + y0_seirh["I"] + y0_seirh["H"] + y0_seirh["U"]
          )
        y0_seir <- y0_seirh[c("S", "E", "I", "R", "O")]
        bitacora$establecer_diarios(as.numeric(out[2, "R"] - out[1, "R"]), NA)
      } else {
        odefun_parms <- c( # pasar esto! en vez de fitmodel
          parametros$parametros_ode_seirh,
          tamano_ventana = parametros$experimento$tamano_ventana,
          beta = bitacora$obtener_datos()$beta,
          lambda_ih = bitacora$obtener_datos()$lamih,
          lambda_if = bitacora$obtener_datos()$lamif,
          lambda_hu = bitacora$obtener_datos()$lamhu,
          lambda_hf = bitacora$obtener_datos()$lamhf,
          lambda_uf = bitacora$obtener_datos()$lamuf,
          imported = parametros$cantidades_diarias$importados[
            n_shift + 1:parametros$experimento$tamano_ventana
          ],
          v_filtrado = parametros$cantidades_diarias$inmunizados[
            n_shift + 1:parametros$experimento$tamano_ventana
          ]
        )
        out <- ode(
          y     = y0_seirh,
          times = seq(0, 1),
          func  = parametros$odefun_seirh,
          parms = odefun_parms
        )
        bitacora$establecer_SEIRHUF(
          as.numeric(out[2, -1]["S"]),
          as.numeric(out[2, -1]["E"]),
          as.numeric(out[2, -1]["I"]),
          as.numeric(out[2, -1]["R"]),
          as.numeric(out[2, -1]["H"]),
          as.numeric(out[2, -1]["U"]),
          as.numeric(out[2, -1]["F"]),
          as.numeric(out[2, -1]["O"])
        )
        bitacora$establecer_diarios(
          as.numeric(out[2, "R"] - out[1, "R"]),
          as.numeric(out[2, "F"] - out[1, "F"])
        )
        i_total <-
          as.numeric(
            out[2, -1]["E"] + out[2, -1]["I"] + out[2, -1]["H"] + out[2, -1]["U"]
          )
        y0_seirh <- out[2, 2:9]
        bitacora$establecer_diarios(
          as.numeric(out[2, "R"] - out[1, "R"]),
          as.numeric(out[2, "F"] - out[1, "F"])
        )
      }
      bitacora$establecer_porciento(
        as.numeric(
          out[2, -1]["S"]
        ) / n_poblacion,
        i_total / n_poblacion,
        as.numeric(out[2, -1]["O"]) / n_poblacion
      )

      dailyr_sin_subregistro <-
        as.numeric(
          out[2, "R"] - out[1, "R"]
        ) / parametros$factor_subregistro[n_shift]
      r_sin_subregistro <-
        bitacora$obtener_datos()$R_sin_subRegistro + dailyr_sin_subregistro
      bitacora$establecer_subregistros(r_sin_subregistro, dailyr_sin_subregistro)

      reruntest_seirh <- 1
      while (reruntest_seirh > 0) {
        tic("sampling SEIRH")
        datos_seirh <- constructor_datos_SEIRH(n_shift, y0_seirh)
        fitmodel_seirh <-
          inferencia$ejecutar_inferencia_estadistica(
            modelo_SEIRH,
            datos_seirh,
            chains_SEIRH,
            warmup,
            iter_SEIRH,
            .adapt_delta = adapt_delta
          )
        toc()
        reruntest_seirh <-
          get_num_divergent(fitmodel_seirh) +
          get_num_max_treedepth(fitmodel_seirh)
        if (reruntest_seirh > 0) {
          print("Reruning sampling because:")
          reportar(get_num_divergent(fitmodel_seirh))
          reportar(get_num_max_treedepth(fitmodel_seirh))
          adapt_delta <- set_adapt_delta(adapt_delta, 1)
        }
      }
      seed <- get_seed(fitmodel_seirh)
      reportes$graficar_pares_entre_parametros_en_pdf(
        glue(
          "{parametros$model_seirh}res14/pair_out/pairs_seirh.pdf"
        ),
        fitmodel_seirh, pars_seir
      )
      reportes$graficar_parametros_vs_iteraciones_en_pdf(
        glue(
          "{parametros$model_seirh}res14/pair_out/trace_seirh.pdf"
        ),
        fitmodel_seirh, pars_seir
      )
      bitacora$establecer_fecha(
        parametros$fecha_inicio + n_shift - parametros$id_inicio_sim
      )
      bitacora$establecer_ndate(n_shift)
      bitacora$cargar_fitmodel_seirh(
        fitmodel_seirh, pars_seirh, n_shift, sim_seirhuf_path
      )
      bitacora$establecer_numero_reproductivo(
        bitacora$obtener_datos()$beta /
          as.numeric(parametros$parametros_ode_seir["gamma"]) *
          bitacora$obtener_datos()$S / n_poblacion
      )
      bitacora$establecer_semilla(seed)
      bitacora$establecer_adapt_delta_SEIR(adapt_delta)
      adapt_delta <- set_adapt_delta(adapt_delta, 0)
    }

    bitacora$escribir_linea()
  }
}

print(paste("Loop finished..."))

if (loopbool == 0) {
  n_shift <- bitacora$obtener_datos()$ndate
}
source(glue("{root_path}projection_at_time.R"))

print(paste("projection finished..."))
