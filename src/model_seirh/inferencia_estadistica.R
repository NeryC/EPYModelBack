# =============================================================================
# inferencia_estadistica.R
# =============================================================================
# Módulo de inferencia estadística bayesiana con Stan/RStan.
#
# Este módulo define los constructores de datos para los tres modelos del
# pipeline y las funciones de compilación y ejecución de la inferencia MCMC.
#
# Modelos soportados
# ------------------
#   init  : Modelo de inicialización (estima condiciones iniciales del sistema).
#   SEIR  : Modelo SEIR con vacunación e importados (fases tempranas).
#   SEIRH : Modelo SEIRHUF completo (8 compartimentos, fases con hospitalización).
#
# Patrón de uso (metaconstructores)
# ----------------------------------
# Cada "metaconstructor" es una función de orden superior (factory) que captura
# los datos epidemiológicos y los parámetros del ODE, y devuelve una función
# interna "constructor" que, dado el desplazamiento temporal (n_shift) y el
# estado inicial, produce el objeto `data` listo para pasar a rstan::sampling().
#
# Este patrón permite reusar la misma estructura en el loop deslizante de
# inferencia (test_seirhuf_normal.R) cambiando solo el índice de tiempo.
#
# Funciones exportadas
# --------------------
#   metaconstructor_datos_init   : Factory para datos del modelo init.
#   metaconstructor_datos_SEIR   : Factory para datos del modelo SEIR.
#   metaconstructor_datos_SEIRH  : Factory para datos del modelo SEIRH completo.
#   ejecutar_inferencia_estadistica : Wrapper de rstan::sampling().
#   compilar_modelo              : Wrapper de rstan::stan_model().
# =============================================================================


# =============================================================================
# metaconstructor_datos_init
# =============================================================================
# Factory para el modelo de inicialización.
# Estima las condiciones iniciales del sistema (e0, i0) a partir de los
# primeros datos de casos confirmados.
#
# Parameters (del metaconstructor)
# ---------------------------------
#   .datos_diarios   : Lista con series temporales (reportados, importados, inmunizados).
#   .t0              : Tiempo inicial de la integración ODE.
#   .t               : Vector de tiempos de evaluación.
#   .parametros_ODE  : Vector numérico de parámetros del ODE (N, alpha, gamma, …).
#   .tamano_ventana  : Número de días en la ventana deslizante.
#
# Returns (del constructor interno)
# -----------------------------------
#   Lista `datos_init` con los campos que espera el modelo Stan model_init.stan.
# =============================================================================
export("metaconstructor_datos_init")
metaconstructor_datos_init <- function(.datos_diarios, .t0, .t, .parametros_ODE, .tamano_ventana) {

  constructor_datos_init <- function(..n_shift) {

    # Extraer series epidemiológicas de la ventana temporal [n_shift+1, n_shift+winsize]
    cantidad_reportados  <- .datos_diarios$reportados
    cantidad_importados  <- .datos_diarios$importados
    cantidad_inmunizados <- .datos_diarios$inmunizados

    datos_init <- list(
      winsize         = .tamano_ventana,
      t0              = .t0,
      ts              = .t,
      odeparam        = .parametros_ODE,
      # Ventana de observaciones: desde n_shift+1 hasta n_shift+tamano_ventana
      data_daily      = cantidad_reportados [..n_shift + 1:.tamano_ventana],
      data_imported   = cantidad_importados [..n_shift + 1:.tamano_ventana],
      data_vaccinated = cantidad_inmunizados[..n_shift + 1:.tamano_ventana]
    )

    return(datos_init)
  }

  return(constructor_datos_init)
}


# =============================================================================
# metaconstructor_datos_SEIR
# =============================================================================
# Factory para el modelo SEIR con vacunación.
# Se usa durante las fases tempranas de la pandemia (antes de que la
# hospitalización sea sistemáticamente registrada).
#
# Parameters adicionales respecto al init
# ----------------------------------------
#   ..estado_inicial : Vector [S0, E0, I0, R0, O0] con las condiciones iniciales
#                      del ODE, estimadas en el paso anterior.
# =============================================================================
export("metaconstructor_datos_SEIR")
metaconstructor_datos_SEIR <- function(.datos_diarios, .t0, .t, .parametros_ODE, .tamano_ventana) {

  constructor_datos_SEIR <- function(..n_shift, ..estado_inicial) {

    cantidad_reportados  <- .datos_diarios$reportados
    cantidad_importados  <- .datos_diarios$importados
    cantidad_inmunizados <- .datos_diarios$inmunizados

    datos_SEIR <- list(
      winsize         = .tamano_ventana,
      y0              = ..estado_inicial,       # Condiciones iniciales del ODE
      t0              = .t0,
      ts              = .t,
      odeparam        = .parametros_ODE,
      data_daily      = cantidad_reportados [..n_shift + 1:.tamano_ventana],
      data_imported   = cantidad_importados [..n_shift + 1:.tamano_ventana],
      data_vaccinated = cantidad_inmunizados[..n_shift + 1:.tamano_ventana]
    )

    return(datos_SEIR)
  }

  return(constructor_datos_SEIR)
}


# =============================================================================
# metaconstructor_datos_SEIRH
# =============================================================================
# Factory para el modelo SEIRH completo (8 compartimentos: S, E, I, R, H, U, F, O).
# Se usa cuando los datos de hospitalización y UCI están disponibles.
# Ajusta simultáneamente: reportados diarios, hospitalizados, UCI y fallecidos.
#
# Parameters adicionales respecto al SEIR
# ----------------------------------------
#   Los mismos, más las series de hospitalizados, UCI y fallecidos.
# =============================================================================
export("metaconstructor_datos_SEIRH")
metaconstructor_datos_SEIRH <- function(.datos_diarios, .t0, .t, .parametros_ODE, .tamano_ventana) {

  constructor_datos_SEIRH <- function(..n_shift, ..estado_inicial) {

    cantidad_reportados     <- .datos_diarios$reportados
    cantidad_hospitalizados <- .datos_diarios$hospitalizados
    cantidad_uci            <- .datos_diarios$uci
    cantidad_fallecidos     <- .datos_diarios$fallecidos
    cantidad_importados     <- .datos_diarios$importados
    cantidad_inmunizados    <- .datos_diarios$inmunizados

    datos_SEIRH <- list(
      winsize         = .tamano_ventana,
      y0              = ..estado_inicial,       # Condiciones iniciales del ODE
      t0              = .t0,
      ts              = .t,
      odeparam        = .parametros_ODE,
      # Datos de observación para ajuste multi-variable:
      data_daily      = cantidad_reportados     [..n_shift + 1:.tamano_ventana],  # × peso 3 en el modelo
      data_hosp       = cantidad_hospitalizados [..n_shift + 1:.tamano_ventana],
      data_uci        = cantidad_uci            [..n_shift + 1:.tamano_ventana],
      data_dead       = cantidad_fallecidos     [..n_shift + 1:.tamano_ventana],
      data_imported   = cantidad_importados     [..n_shift + 1:.tamano_ventana],
      data_vaccinated = cantidad_inmunizados    [..n_shift + 1:.tamano_ventana]
    )

    return(datos_SEIRH)
  }

  return(constructor_datos_SEIRH)
}


# =============================================================================
# ejecutar_inferencia_estadistica
# =============================================================================
# Wrapper de rstan::sampling() para ejecutar la inferencia MCMC.
#
# Configuración MCMC recomendada
# --------------------------------
#   chains     : 4 (para diagnóstico de convergencia via R-hat)
#   warmup     : 500 (fase de calentamiento/adaptación del paso)
#   iteraciones: 1500 (total por cadena; 1000 muestras post-warmup)
#   adapt_delta: 0.94 (mayor = menos divergencias, más lento)
#   max_treedepth: 15 (evita truncamiento del árbol en HMC)
#
# Parameters
# ----------
#   .modelo      : Objeto Stan compilado (salida de compilar_modelo()).
#   .datos       : Lista con los datos en el formato esperado por el modelo .stan.
#   .chains      : Número de cadenas MCMC.
#   .warmup      : Iteraciones de calentamiento por cadena.
#   .iteraciones : Iteraciones totales por cadena (incluye warmup).
#   .refresh     : Frecuencia de impresión de progreso (0 = silencioso).
#   .adapt_delta : Parámetro de adaptación del paso (0-1, default 0.94).
#   .seed        : Semilla para reproducibilidad (NA = aleatorio).
#
# Returns
# -------
#   Objeto stanfit con las muestras posteriores.
# =============================================================================
export("ejecutar_inferencia_estadistica")
ejecutar_inferencia_estadistica <- function(
    .modelo,
    .datos,
    .chains,
    .warmup,
    .iteraciones,
    .refresh     = 100,
    .adapt_delta = 0.94,
    .seed        = NA
) {
  fitmodel <- rstan::sampling(
    .modelo,
    data    = .datos,
    chains  = .chains,
    warmup  = .warmup,
    iter    = .iteraciones,
    seed    = .seed,
    refresh = .refresh,
    control = list(
      adapt_delta   = .adapt_delta,
      max_treedepth = 15  # Evita truncamiento del árbol NUTS en parámetros correlacionados
    ),
    verbose = FALSE
  )

  return(fitmodel)
}


# =============================================================================
# compilar_modelo
# =============================================================================
# Compila un archivo .stan en un objeto Stan reutilizable.
#
# La compilación convierte el código Stan a C++ y lo compila con g++.
# Solo necesita hacerse una vez por sesión R (o cuando el .stan cambia).
# El aviso "g++ not found" puede ignorarse si la compilación termina bien.
#
# Parameters
# ----------
#   .modelo_filepath : Ruta absoluta al archivo .stan.
#
# Returns
# -------
#   Objeto Stan compilado (clase stanmodel).
# =============================================================================
export("compilar_modelo")
compilar_modelo <- function(.modelo_filepath) {
  # Compilar el modelo Stan (puede tardar 1-2 minutos en la primera compilación)
  modelo <- rstan::stan_model(.modelo_filepath)  # Ignorar aviso: "g++ not found"
  return(modelo)
}
