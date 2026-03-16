# =============================================================================
# bitacora_evolucion.R
# =============================================================================
# Módulo de bitácora (log) para el pipeline de inferencia MCMC del modelo SEIRHUF.
#
# Propósito
# ----------
# Persiste el estado del modelo en cada día de simulación en un archivo CSV
# (sim_SEIRHUF.csv). Esto permite:
#   1. Reanudar una simulación interrumpida desde el último día guardado.
#   2. Inspeccionar la evolución de los parámetros a lo largo del tiempo.
#   3. Proveer los datos iniciales para el script de proyecciones.
#
# Patrón de uso
# --------------
# La bitácora es un objeto-módulo cargado con modules::use(). Su estado interno
# (`datos_iteracion`) se actualiza mediante funciones `establecer_*` y luego
# se persiste con `escribir_linea()` al final de cada iteración del loop.
#
# Columnas del CSV de salida (sim_SEIRHUF.csv)
# ---------------------------------------------
#   date, ndate              : fecha y número de día
#   beta, beta_lo, beta_hi   : tasa de transmisión (MAP, IC 2.5%, IC 97.5%)
#   lamih, ..._lo, ..._hi    : fracción I→H y sus intervalos de credibilidad
#   lamif, ..._lo, ..._hi    : fracción I→F
#   lamhu, ..._lo, ..._hi    : fracción H→U
#   lamhf, ..._lo, ..._hi    : fracción H→F
#   lamuf, ..._lo, ..._hi    : fracción U→F
#   S, E, I, R, H, U, F, O  : compartimentos del modelo al final del día
#   dailyR, dailyF           : nuevos recuperados y fallecidos del día
#   R_sin_subRegistro        : R acumulado sin factor de subregistro
#   dailyR_sin_subRegistro   : nuevos R del día sin subregistro
#   seed                     : semilla aleatoria usada por Stan
#   numero_reproductivo      : R efectivo = beta/gamma * S/N
#   adapt_delta_SEIR         : valor de adapt_delta usado en esa iteración
#   S_porciento, I_porciento, O_porciento : fracciones de la población
#
# Inicialización automática
# -------------------------
# Al cargar el módulo:
#   - Si el CSV no existe → lo crea con cabeceras y activa ejecutar_model_init.
#   - Si el CSV existe pero está vacío (< 2 líneas) → activa ejecutar_model_init.
#   - Si el CSV tiene datos → restaura el estado desde la última línea.
#
# Nota sobre <<-
# --------------
# Las funciones `establecer_*` usan `<<-` (asignación en el ambiente padre)
# para modificar `datos_iteracion` que vive en el ambiente del módulo,
# no en el ambiente local de la función. Esto es correcto y necesario en
# el patrón de módulos de R.
# =============================================================================

import("dplyr", "%>%")
import("glue", "glue")
import("fpeek")

root_path <- paste(getwd(), "/src/model_seirh/", sep = "")
parametros <- modules::use(glue("{root_path}parametros.R"))

# Ruta del archivo CSV de bitácora
archivo_de_salida_filepath <-
  glue("{parametros$data_path}sim_SEIRHUF.csv")


# =============================================================================
# Configuración inicial del experimento
# =============================================================================
# Si la bitácora no tiene datos, el modelo init debe ejecutarse antes del loop.
# Este valor es sobreescrito en la sección de inicialización al final del módulo.
export("ejecutar_model_init")
ejecutar_model_init <- FALSE


# =============================================================================
# Esquema de columnas del CSV
# =============================================================================
# El orden es crítico: importar_datos_desde_ultima_linea() usa índices posicionales.
nombres_de_columnas <- c(
  "date", "ndate",
  "beta",  "beta_lo",  "beta_hi",
  "lamih", "lamih_lo", "lamih_hi",
  "lamif", "lamif_lo", "lamif_hi",
  "lamhu", "lamhu_lo", "lamhu_hi",
  "lamhf", "lamhf_lo", "lamhf_hi",
  "lamuf", "lamuf_lo", "lamuf_hi",
  "S", "E", "I", "R", "H", "U", "F", "O",
  "dailyR", "dailyF",
  "R_sin_subRegistro", "dailyR_sin_subRegistro",
  "seed",
  "numero_reproductivo",
  "adapt_delta_SEIR",
  "S_porciento", "I_porciento", "O_porciento"
)

# Estructura de datos de una iteración con valores por defecto (NA = sin dato)
datos_iteracion <- list(
  date                     = NA,
  ndate                    = NA,
  beta                     = NA,
  beta_lo                  = NA,
  beta_hi                  = NA,
  lamih                    = NA,
  lamih_lo                 = NA,
  lamih_hi                 = NA,
  lamif                    = NA,
  lamif_lo                 = NA,
  lamif_hi                 = NA,
  lamhu                    = NA,
  lamhu_lo                 = NA,
  lamhu_hi                 = NA,
  lamhf                    = NA,
  lamhf_lo                 = NA,
  lamhf_hi                 = NA,
  lamuf                    = NA,
  lamuf_lo                 = NA,
  lamuf_hi                 = NA,
  S                        = NA,
  E                        = NA,
  I                        = NA,
  R                        = NA,
  H                        = NA,
  U                        = NA,
  F                        = NA,
  O                        = NA,
  dailyR                   = NA,
  dailyF                   = NA,
  R_sin_subRegistro        = NA,
  dailyR_sin_subRegistro   = NA,
  seed                     = NA,
  numero_reproductivo      = NA,
  adapt_delta_SEIR         = NA,
  S_porciento              = NA,
  I_porciento              = NA,
  O_porciento              = NA
)


# =============================================================================
# Accessor público
# =============================================================================

# Devuelve la copia actual del estado de la iteración en curso.
export("obtener_datos")
obtener_datos <- function() datos_iteracion


# =============================================================================
# Setters — actualizan campos de datos_iteracion (usando <<-)
# =============================================================================

export("establecer_fecha")
establecer_fecha <- function(.fecha) {
  datos_iteracion$date <<- as.character(.fecha)
}

export("establecer_ndate")
establecer_ndate <- function(.ndate) {
  datos_iteracion$ndate <<- .ndate
}

# Tasa de transmisión con intervalos de credibilidad del 95%
export("establecer_beta")
establecer_beta <- function(.beta, .beta_low, .beta_high) {
  datos_iteracion$beta    <<- .beta
  datos_iteracion$beta_lo <<- .beta_low
  datos_iteracion$beta_hi <<- .beta_high
}

# Setter solo del valor MAP de beta (sin intervalos), usado tras modelo init
export("establecer_beta_opt")
establecer_beta_opt <- function(.beta) {
  datos_iteracion$beta <<- .beta
}

# Fracción de I que pasa a H (hospitalización directa desde infecciosos)
export("establecer_lambda_ih")
establecer_lambda_ih <- function(.lambda_ih, .lambda_ih_low, .lambda_ih_high) {
  datos_iteracion$lamih    <<- .lambda_ih
  datos_iteracion$lamih_lo <<- .lambda_ih_low
  datos_iteracion$lamih_hi <<- .lambda_ih_high
}

# Fracción de I que fallece directamente (sin pasar por H)
export("establecer_lambda_if")
establecer_lambda_if <- function(.lambda_if, .lambda_if_low, .lambda_if_high) {
  datos_iteracion$lamif    <<- .lambda_if
  datos_iteracion$lamif_lo <<- .lambda_if_low
  datos_iteracion$lamif_hi <<- .lambda_if_high
}

# Fracción de H que pasa a U (UCI desde hospitalización general)
export("establecer_lambda_hu")
establecer_lambda_hu <- function(.lambda_hu, .lambda_hu_low, .lambda_hu_high) {
  datos_iteracion$lamhu    <<- .lambda_hu
  datos_iteracion$lamhu_lo <<- .lambda_hu_low
  datos_iteracion$lamhu_hi <<- .lambda_hu_high
}

# Fracción de H que fallece en hospitalización general
export("establecer_lambda_hf")
establecer_lambda_hf <- function(.lambda_hf, .lambda_hf_low, .lambda_hf_high) {
  datos_iteracion$lamhf    <<- .lambda_hf
  datos_iteracion$lamhf_lo <<- .lambda_hf_low
  datos_iteracion$lamhf_hi <<- .lambda_hf_high
}

# Fracción de U (UCI) que fallece
export("establecer_lambda_uf")
establecer_lambda_uf <- function(.lambda_uf, .lambda_uf_low, .lambda_uf_high) {
  datos_iteracion$lamuf    <<- .lambda_uf
  datos_iteracion$lamuf_lo <<- .lambda_uf_low
  datos_iteracion$lamuf_hi <<- .lambda_uf_high
}

# Actualiza todos los compartimentos del modelo simultáneamente
# .O representa los recuperados activos (con inmunidad vigente)
export("establecer_SEIRHUF")
establecer_SEIRHUF <- function(.S, .E, .I, .R, .H, .U, .F, .O) {
  datos_iteracion$S <<- .S
  datos_iteracion$E <<- .E
  datos_iteracion$I <<- .I
  datos_iteracion$R <<- .R
  datos_iteracion$H <<- .H
  datos_iteracion$U <<- .U
  datos_iteracion$F <<- .F
  datos_iteracion$O <<- .O
}

# Registra los flujos diarios (diferencias entre pasos de integración)
export("establecer_diarios")
establecer_diarios <- function(.daily_R, .daily_F) {
  datos_iteracion$dailyR <<- .daily_R
  datos_iteracion$dailyF <<- .daily_F
}

# Almacena los totales sin corrección de subregistro (para comparación)
export("establecer_subregistros")
establecer_subregistros <- function(.R_sin_subRegistro, .dailyR_sin_subRegistro) {
  datos_iteracion$R_sin_subRegistro       <<- .R_sin_subRegistro
  datos_iteracion$dailyR_sin_subRegistro  <<- .dailyR_sin_subRegistro
}

# Semilla usada por Stan (para reproducibilidad de esa iteración)
export("establecer_semilla")
establecer_semilla <- function(.seed) {
  datos_iteracion$seed <<- .seed
}

# Número reproductivo efectivo: R_eff = beta/gamma * S/N
export("establecer_numero_reproductivo")
establecer_numero_reproductivo <- function(.numero_reproductivo) {
  datos_iteracion$numero_reproductivo <<- .numero_reproductivo
}

# Valor de adapt_delta que usó Stan en esta iteración (para diagnóstico)
export("establecer_adapt_delta_SEIR")
establecer_adapt_delta_SEIR <- function(.adapt_delta_SEIR) {
  datos_iteracion$adapt_delta_SEIR <<- .adapt_delta_SEIR
}

# Fracciones de la población para monitoreo: S%, I% (incluye E+I+H+U), O%
export("establecer_porciento")
establecer_porciento <- function(.S_porciento, .I_porciento, .O_porciento) {
  datos_iteracion$S_porciento <<- .S_porciento
  datos_iteracion$I_porciento <<- .I_porciento
  datos_iteracion$O_porciento <<- .O_porciento
}


# =============================================================================
# I/O del archivo CSV
# =============================================================================

# Serializa la fila actual como CSV y la agrega al final del archivo.
# Debe llamarse al final de cada iteración del loop principal.
export("escribir_linea")
escribir_linea <- function() {
  write(paste(datos_iteracion, collapse = ","), archivo_de_salida_filepath, append = TRUE)
}

# Elimina la última línea del CSV (útil si la iteración falló parcialmente
# y se necesita revertir antes de reintentar).
# Nota: usa `sed -i '' -e '$ d'` que funciona en macOS/Linux.
# En Windows se necesitaría una alternativa diferente.
export("eliminar_ultima_linea")
eliminar_ultima_linea <- function() {
  system(glue("sed -i '' -e '$ d' {archivo_de_salida_filepath}"))
}

# Lee la última línea del CSV usando una conexión de archivo R (cross-platform).
# Se prefiere este método sobre `tail` que requiere herramientas Unix.
leer_ultima_linea <- function() {
  conn        <- file(archivo_de_salida_filepath, open = "r")
  lineas      <- readLines(conn)
  ultima_linea <- lineas[length(lineas)]
  close(conn)
  return(ultima_linea)
}


# =============================================================================
# Deserialización de la última línea del CSV
# =============================================================================
# Parsea la última fila del CSV y restaura `datos_iteracion` con esos valores.
# Se llama automáticamente al inicializar el módulo si el CSV ya tiene datos.
#
# Usa un helper as.num() que convierte strings a numeric preservando NA
# (en lugar de producir NaN, que ocurriría con as.numeric("NA")).
# Ver: https://stackoverflow.com/a/36239701/7555119
export("importar_datos_desde_ultima_linea")
importar_datos_desde_ultima_linea <- function() {
  ultima_linea <- leer_ultima_linea()
  datos_raw    <- strsplit(ultima_linea, ",")[[1]]

  # Conversión segura: "NA" → NA_real_, resto → numeric
  as.num <- function(x, na.strings = "NA") {
    stopifnot(is.character(x))
    na   <- x %in% na.strings
    x[na] <- 0
    x    <- as.numeric(x)
    x[na] <- NA_real_
    x
  }

  # Parseo posicional según el orden de nombres_de_columnas
  fecha    <- datos_raw[1]
  ndate    <- as.num(datos_raw[2])
  beta     <- as.num(datos_raw[3]);  beta_lo   <- as.num(datos_raw[4]);   beta_hi   <- as.num(datos_raw[5])
  lam_ih   <- as.num(datos_raw[6]);  lam_ih_lo <- as.num(datos_raw[7]);   lam_ih_hi <- as.num(datos_raw[8])
  lam_if   <- as.num(datos_raw[9]);  lam_if_lo <- as.num(datos_raw[10]);  lam_if_hi <- as.num(datos_raw[11])
  lam_hu   <- as.num(datos_raw[12]); lam_hu_lo <- as.num(datos_raw[13]);  lam_hu_hi <- as.num(datos_raw[14])
  lam_hf   <- as.num(datos_raw[15]); lam_hf_lo <- as.num(datos_raw[16]);  lam_hf_hi <- as.num(datos_raw[17])
  lam_uf   <- as.num(datos_raw[18]); lam_uf_lo <- as.num(datos_raw[19]);  lam_uf_hi <- as.num(datos_raw[20])
  S        <- as.num(datos_raw[21]); E         <- as.num(datos_raw[22]);  I         <- as.num(datos_raw[23])
  R        <- as.num(datos_raw[24]); H         <- as.num(datos_raw[25]);  U         <- as.num(datos_raw[26])
  F_comp   <- as.num(datos_raw[27]); O         <- as.num(datos_raw[28])
  dailyR   <- as.num(datos_raw[29]); dailyF    <- as.num(datos_raw[30])
  R_sr     <- as.num(datos_raw[31]); dailyR_sr <- as.num(datos_raw[32])
  seed     <- as.num(datos_raw[33])

  # Restaurar el estado completo
  establecer_fecha(fecha)
  establecer_ndate(ndate)
  establecer_beta(beta, beta_lo, beta_hi)
  establecer_lambda_ih(lam_ih, lam_ih_lo, lam_ih_hi)
  establecer_lambda_if(lam_if, lam_if_lo, lam_if_hi)
  establecer_lambda_hu(lam_hu, lam_hu_lo, lam_hu_hi)
  establecer_lambda_hf(lam_hf, lam_hf_lo, lam_hf_hi)
  establecer_lambda_uf(lam_uf, lam_uf_lo, lam_uf_hi)
  establecer_SEIRHUF(S, E, I, R, H, U, F_comp, O)
  establecer_diarios(dailyR, dailyF)
  establecer_subregistros(R_sr, dailyR_sr)
  establecer_semilla(seed)
}


# =============================================================================
# Carga de resultados desde un objeto stanfit (modelo SEIRH completo)
# =============================================================================
# Extrae el punto MAP (máximo a posteriori: argmax de lp__) y los intervalos
# de credibilidad del 95% de un objeto stanfit.
# Además escribe el resumen de parámetros al archivo de probabilidades (prob.csv).
#
# Parameters
# ----------
#   .fitmodel : Objeto stanfit (salida de rstan::sampling)
#   .pars     : Nombres de parámetros a incluir en el resumen
#   .n        : Número de iteración (se agrega como sufijo en las filas del CSV)
#   .probfile : Ruta del archivo CSV donde se acumulan los resúmenes
export("cargar_fitmodel_seirh")
cargar_fitmodel_seirh <- function(.fitmodel, .pars, .n, .probfile) {
  extracted   <- rstan::extract(.fitmodel)
  index       <- which.max(extracted$lp__)          # Índice del punto MAP
  fit_summary <- rstan::summary(.fitmodel, pars = .pars)$summary

  # Extraer valores MAP de cada parámetro
  beta_opt  <- extracted$beta[index]
  lamih_opt <- extracted$lamih[index]
  lamif_opt <- extracted$lamif[index]
  lamhu_opt <- extracted$lamhu[index]
  lamhf_opt <- extracted$lamhf[index]
  lamuf_opt <- extracted$lamuf[index]

  # Actualizar la bitácora con los valores MAP + intervalos de credibilidad 95%
  establecer_beta(      beta_opt,  fit_summary["beta",  "2.5%"], fit_summary["beta",  "97.5%"])
  establecer_lambda_ih( lamih_opt, fit_summary["lamih", "2.5%"], fit_summary["lamih", "97.5%"])
  establecer_lambda_if( lamif_opt, fit_summary["lamif", "2.5%"], fit_summary["lamif", "97.5%"])
  establecer_lambda_hu( lamhu_opt, fit_summary["lamhu", "2.5%"], fit_summary["lamhu", "97.5%"])
  establecer_lambda_hf( lamhf_opt, fit_summary["lamhf", "2.5%"], fit_summary["lamhf", "97.5%"])
  establecer_lambda_uf( lamuf_opt, fit_summary["lamuf", "2.5%"], fit_summary["lamuf", "97.5%"])

  # Agregar columna "opt" con los valores MAP al resumen (para referencia en el CSV)
  fit_summary <- cbind(
    "opt" = c(
      beta     = beta_opt,
      lamih    = lamih_opt,
      lamif    = lamif_opt,
      lamhu    = lamhu_opt,
      lamhf    = lamhf_opt,
      lamuf    = lamuf_opt,
      sigma_r  = extracted$sigma_r[index],
      sigma_h  = extracted$sigma_h[index],
      sigma_u  = extracted$sigma_u[index],
      sigma_f  = extracted$sigma_f[index],
      lp__h    = extracted$lp__[index]
    ),
    fit_summary
  )

  # Etiquetar filas con el número de iteración para trazabilidad
  rownames(fit_summary) <- paste(rownames(fit_summary), .n, sep = "")

  utils::write.table(fit_summary,
    file       = .probfile,
    sep        = ",",
    col.names  = FALSE,
    append     = TRUE
  )
}


# =============================================================================
# Carga de resultados desde un objeto stanfit (modelo SEIR)
# =============================================================================
# Versión simplificada para el modelo SEIR (solo estima beta, sin lambdas H/U/F).
export("cargar_fitmodel_seir")
cargar_fitmodel_seir <- function(.fitmodel, .pars, .n, .probfile) {
  extracted   <- rstan::extract(.fitmodel)
  index       <- which.max(extracted$lp__)
  fit_summary <- rstan::summary(.fitmodel, pars = .pars)$summary
  beta_opt    <- extracted$beta[index]

  establecer_beta(beta_opt, fit_summary["beta", "2.5%"], fit_summary["beta", "97.5%"])

  fit_summary <- cbind(
    "opt" = c(
      beta    = beta_opt,
      sigma_r = extracted$sigma_r[index],
      lp__    = extracted$lp__[index]
    ),
    fit_summary
  )

  rownames(fit_summary) <- paste(rownames(fit_summary), .n, sep = "")

  utils::write.table(fit_summary,
    file       = .probfile,
    sep        = ",",
    col.names  = FALSE,
    append     = TRUE
  )
}


# =============================================================================
# Inicialización automática del módulo
# =============================================================================
# Al cargar el módulo se determina el punto de partida de la simulación.

if (!file.exists(archivo_de_salida_filepath)) {
  # Primera ejecución: crear el CSV con cabeceras
  print(glue("Creando un archivo de bitacora en {archivo_de_salida_filepath}."))
  file.create(archivo_de_salida_filepath)
  header <- purrr::map(nombres_de_columnas, function(.) glue("\"{.}\""))
  header <- paste(header, collapse = ",")
  write(header, archivo_de_salida_filepath)
  ejecutar_model_init <- TRUE  # El modelo init debe ejecutarse primero

} else {
  print(glue("Encontrado un archivo de bitacora en {archivo_de_salida_filepath}."))
  cantidad_de_lineas <- peek_count_lines(archivo_de_salida_filepath)

  if (cantidad_de_lineas < 2) {
    # El CSV existe pero solo tiene la cabecera (sin datos)
    print(glue("Bitacora sin datos."))
    ejecutar_model_init <- TRUE
  } else {
    # Restaurar estado desde la última línea guardada y continuar
    importar_datos_desde_ultima_linea()
    print(glue("Inicializado con datos de la ultima linea."))
  }
}
