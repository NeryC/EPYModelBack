# =============================================================================
# bitacora_evolucion_projection.R
# =============================================================================
# Variante de la bitácora para uso en proyecciones (projection_at_time.R).
#
# Diferencias respecto a bitacora_evolucion.R
# ---------------------------------------------
# 1. La estructura `datos_iteracion` NO incluye los campos de adapt_delta,
#    S_porciento, I_porciento, O_porciento (no necesarios para proyecciones).
# 2. No tiene `establecer_beta_opt` (simplificado).
# 3. Añade tres métodos adicionales de lectura:
#      - importar_datos_desde_penultima_linea()  : lee la anteúltima línea del CSV
#      - importar_datos_desde_linea_n(n)         : lee la línea donde ndate == n
# 4. `cargar_fitmodel_seirh` es reemplazado por `cargar_fitmodel_huf` (solo
#    estima las lambdas H/U/F, sin beta ni sigma_r).
#
# Cuándo se usa
# -------------
# Este módulo es útil cuando se necesita retroceder en el tiempo para generar
# proyecciones desde un día anterior específico, o cuando se trabaja con la
# versión de proyección que no necesita todos los campos de la bitácora principal.
#
# La inicialización automática al final del archivo (si el CSV existe → cargar
# última línea) permite a projection_at_time.R usarlo directamente sin setup manual.
# =============================================================================

import("dplyr", "%>%")
import("glue", "glue")
import("fpeek")

root_path  <- paste(getwd(), "/src/model_seirh/", sep = "")
parametros <- modules::use(glue("{root_path}parametros.R"))

# Ruta del CSV compartido (la misma bitácora que escribe bitacora_evolucion.R)
archivo_de_salida_filepath <-
  glue("{parametros$data_path}sim_SEIRHUF.csv")


# =============================================================================
# Configuración
# =============================================================================
export("ejecutar_model_init")
ejecutar_model_init <- FALSE


# =============================================================================
# Esquema de columnas (sin los campos de diagnóstico y porcentaje)
# =============================================================================
nombres_de_columnas <- c(
  "date", "ndate",
  "beta",  "beta_lo",  "beta_hi",
  "lamih", "lamih_lo", "lamih_hi",
  "lamif", "lamif_lo", "lamif_hi",
  "lamhu", "lamhu_lo", "lamhu_hi",
  "lamhf", "lamhf_lo", "lamhf_hi",
  "lamuf", "lamuf_lo", "lamuf_hi",
  "S", "E", "I", "R", "H", "U", "F",
  "dailyR", "dailyF",
  "R_sin_subRegistro", "dailyR_sin_subRegistro",
  "seed",
  "numero_reproductivo"
)

# Estado de la iteración actual (sin compartimento O ni campos de porcentaje)
datos_iteracion <- list(
  date                   = NA,
  ndate                  = NA,
  beta                   = NA,
  beta_lo                = NA,
  beta_hi                = NA,
  lamih                  = NA,
  lamih_lo               = NA,
  lamih_hi               = NA,
  lamif                  = NA,
  lamif_lo               = NA,
  lamif_hi               = NA,
  lamhu                  = NA,
  lamhu_lo               = NA,
  lamhu_hi               = NA,
  lamhf                  = NA,
  lamhf_lo               = NA,
  lamhf_hi               = NA,
  lamuf                  = NA,
  lamuf_lo               = NA,
  lamuf_hi               = NA,
  S                      = NA,
  E                      = NA,
  I                      = NA,
  R                      = NA,
  H                      = NA,
  U                      = NA,
  F                      = NA,
  dailyR                 = NA,
  dailyF                 = NA,
  R_sin_subRegistro      = NA,
  dailyR_sin_subRegistro = NA,
  seed                   = NA,
  numero_reproductivo    = NA
)


# =============================================================================
# Accessor público
# =============================================================================
export("obtener_datos")
obtener_datos <- function() datos_iteracion


# =============================================================================
# Setters
# =============================================================================

export("establecer_fecha")
establecer_fecha <- function(.fecha) {
  datos_iteracion$date <<- as.character(.fecha)
}

export("establecer_ndate")
establecer_ndate <- function(.ndate) {
  datos_iteracion$ndate <<- .ndate
}

export("establecer_beta")
establecer_beta <- function(.beta, .beta_low, .beta_high) {
  datos_iteracion$beta    <<- .beta
  datos_iteracion$beta_lo <<- .beta_low
  datos_iteracion$beta_hi <<- .beta_high
}

export("establecer_lambda_ih")
establecer_lambda_ih <- function(.lambda_ih, .lambda_ih_low, .lambda_ih_high) {
  datos_iteracion$lamih    <<- .lambda_ih
  datos_iteracion$lamih_lo <<- .lambda_ih_low
  datos_iteracion$lamih_hi <<- .lambda_ih_high
}

export("establecer_lambda_if")
establecer_lambda_if <- function(.lambda_if, .lambda_if_low, .lambda_if_high) {
  datos_iteracion$lamif    <<- .lambda_if
  datos_iteracion$lamif_lo <<- .lambda_if_low
  datos_iteracion$lamif_hi <<- .lambda_if_high
}

export("establecer_lambda_hu")
establecer_lambda_hu <- function(.lambda_hu, .lambda_hu_low, .lambda_hu_high) {
  datos_iteracion$lamhu    <<- .lambda_hu
  datos_iteracion$lamhu_lo <<- .lambda_hu_low
  datos_iteracion$lamhu_hi <<- .lambda_hu_high
}

export("establecer_lambda_hf")
establecer_lambda_hf <- function(.lambda_hf, .lambda_hf_low, .lambda_hf_high) {
  datos_iteracion$lamhf    <<- .lambda_hf
  datos_iteracion$lamhf_lo <<- .lambda_hf_low
  datos_iteracion$lamhf_hi <<- .lambda_hf_high
}

export("establecer_lambda_uf")
establecer_lambda_uf <- function(.lambda_uf, .lambda_uf_low, .lambda_uf_high) {
  datos_iteracion$lamuf    <<- .lambda_uf
  datos_iteracion$lamuf_lo <<- .lambda_uf_low
  datos_iteracion$lamuf_hi <<- .lambda_uf_high
}

# Nota: sin compartimento O en esta versión (no se necesita para proyecciones)
export("establecer_SEIRHUF")
establecer_SEIRHUF <- function(.S, .E, .I, .R, .H, .U, .F) {
  datos_iteracion$S <<- .S
  datos_iteracion$E <<- .E
  datos_iteracion$I <<- .I
  datos_iteracion$R <<- .R
  datos_iteracion$H <<- .H
  datos_iteracion$U <<- .U
  datos_iteracion$F <<- .F
}

export("establecer_diarios")
establecer_diarios <- function(.daily_R, .daily_F) {
  datos_iteracion$dailyR <<- .daily_R
  datos_iteracion$dailyF <<- .daily_F
}

export("establecer_subregistros")
establecer_subregistros <- function(.R_sin_subRegistro, .dailyR_sin_subRegistro) {
  datos_iteracion$R_sin_subRegistro      <<- .R_sin_subRegistro
  datos_iteracion$dailyR_sin_subRegistro <<- .dailyR_sin_subRegistro
}

export("establecer_semilla")
establecer_semilla <- function(.seed) {
  datos_iteracion$seed <<- .seed
}

export("establecer_numero_reproductivo")
establecer_numero_reproductivo <- function(.numero_reproductivo) {
  datos_iteracion$numero_reproductivo <<- .numero_reproductivo
}


# =============================================================================
# I/O del CSV
# =============================================================================

export("escribir_linea")
escribir_linea <- function() {
  write(paste(datos_iteracion, collapse = ","), archivo_de_salida_filepath, append = TRUE)
}

export("eliminar_ultima_linea")
eliminar_ultima_linea <- function() {
  system(glue("sed -i '' -e '$ d' {archivo_de_salida_filepath}"))
}


# =============================================================================
# Lectores de líneas del CSV
# =============================================================================

# Lee la última línea usando tail (requiere herramientas Unix/macOS)
leer_ultima_linea <- function() {
  system(glue("tail -n 1 {archivo_de_salida_filepath}"), intern = TRUE)
}

# Lee las últimas 2 líneas (la segunda es la anteúltima, usada para proyecciones
# que necesitan retroceder un paso antes del último día guardado)
leer_penultima_linea <- function() {
  system(glue("tail -n 2 {archivo_de_salida_filepath}"), intern = TRUE)
}

# Lee la fila donde ndate == n (búsqueda por columna, no por posición)
leer_linea_n <- function(n) {
  data   <- utils::read.csv(archivo_de_salida_filepath, sep = ",")
  linea  <- subset(data, data$ndate %in% n)
  return(linea)
}


# =============================================================================
# Helper: conversión segura de string a numeric preservando NA
# =============================================================================
# R convierte "NA" a NA_real_ en lugar de NA cuando usa as.numeric directamente,
# pero esto solo funciona para vectores atómicos; en listas puede fallar.
# Este helper garantiza el comportamiento correcto en ambos casos.
# Ver: https://stackoverflow.com/a/36239701/7555119
.as_num <- function(x, na.strings = "NA") {
  # Para datos de tipo data.frame (leer_linea_n), convertir a character primero
  if (!is.character(x)) x <- as.character(x)
  na      <- x %in% na.strings
  x[na]   <- 0
  x       <- as.numeric(x)
  x[na]   <- NA_real_
  x
}

# Núcleo de parseo: toma un vector de datos y llama a los setters
.parsear_y_establecer <- function(datos_raw, origen = "vector") {
  if (origen == "dataframe") {
    # Parseo por nombre de columna (desde leer_linea_n)
    establecer_fecha(datos_raw$date)
    establecer_ndate(.as_num(datos_raw$ndate))
    establecer_beta(.as_num(datos_raw$beta), .as_num(datos_raw$beta_lo), .as_num(datos_raw$beta_hi))
    establecer_lambda_ih(.as_num(datos_raw$lamih), .as_num(datos_raw$lamih_lo), .as_num(datos_raw$lamih_hi))
    establecer_lambda_if(.as_num(datos_raw$lamif), .as_num(datos_raw$lamif_lo), .as_num(datos_raw$lamif_hi))
    establecer_lambda_hu(.as_num(datos_raw$lamhu), .as_num(datos_raw$lamhu_lo), .as_num(datos_raw$lamhu_hi))
    establecer_lambda_hf(.as_num(datos_raw$lamhf), .as_num(datos_raw$lamhf_lo), .as_num(datos_raw$lamhf_hi))
    establecer_lambda_uf(.as_num(datos_raw$lamuf), .as_num(datos_raw$lamuf_lo), .as_num(datos_raw$lamuf_hi))
    establecer_SEIRHUF(
      .as_num(datos_raw$S), .as_num(datos_raw$E), .as_num(datos_raw$I),
      .as_num(datos_raw$R), .as_num(datos_raw$H), .as_num(datos_raw$U),
      .as_num(datos_raw$F)
    )
    establecer_diarios(.as_num(datos_raw$dailyR), .as_num(datos_raw$dailyF))
    establecer_subregistros(.as_num(datos_raw$R_sin_subRegistro), .as_num(datos_raw$dailyR_sin_subRegistro))
    establecer_semilla(.as_num(datos_raw$seed))
    establecer_numero_reproductivo(.as_num(datos_raw$numero_reproductivo))
  } else {
    # Parseo por índice posicional (desde leer_ultima/penultima_linea)
    establecer_fecha(datos_raw[1])
    establecer_ndate(.as_num(datos_raw[2]))
    establecer_beta(.as_num(datos_raw[3]), .as_num(datos_raw[4]), .as_num(datos_raw[5]))
    establecer_lambda_ih(.as_num(datos_raw[6]),  .as_num(datos_raw[7]),  .as_num(datos_raw[8]))
    establecer_lambda_if(.as_num(datos_raw[9]),  .as_num(datos_raw[10]), .as_num(datos_raw[11]))
    establecer_lambda_hu(.as_num(datos_raw[12]), .as_num(datos_raw[13]), .as_num(datos_raw[14]))
    establecer_lambda_hf(.as_num(datos_raw[15]), .as_num(datos_raw[16]), .as_num(datos_raw[17]))
    establecer_lambda_uf(.as_num(datos_raw[18]), .as_num(datos_raw[19]), .as_num(datos_raw[20]))
    establecer_SEIRHUF(
      .as_num(datos_raw[21]), .as_num(datos_raw[22]), .as_num(datos_raw[23]),
      .as_num(datos_raw[24]), .as_num(datos_raw[25]), .as_num(datos_raw[26]),
      .as_num(datos_raw[27])
    )
    establecer_diarios(.as_num(datos_raw[28]), .as_num(datos_raw[29]))
    establecer_subregistros(.as_num(datos_raw[30]), .as_num(datos_raw[31]))
    establecer_semilla(.as_num(datos_raw[32]))
    establecer_numero_reproductivo(.as_num(datos_raw[33]))
  }
}


# =============================================================================
# Funciones públicas de importación
# =============================================================================

# Restaura el estado desde la última línea del CSV.
export("importar_datos_desde_ultima_linea")
importar_datos_desde_ultima_linea <- function() {
  ultima_linea <- leer_ultima_linea()
  datos_raw    <- strsplit(ultima_linea, ",")[[1]]
  .parsear_y_establecer(datos_raw, origen = "vector")
}

# Restaura el estado desde la anteúltima línea.
# Útil para retroceder al día anterior al último guardado.
export("importar_datos_desde_penultima_linea")
importar_datos_desde_penultima_linea <- function() {
  lineas      <- leer_penultima_linea()
  datos_raw   <- strsplit(lineas, ",")[[1]]  # tail -n 2 devuelve 2 líneas; usar la primera
  .parsear_y_establecer(datos_raw, origen = "vector")
}

# Restaura el estado desde la fila donde ndate == n.
# Permite proyectar desde cualquier día histórico específico.
export("importar_datos_desde_linea_n")
importar_datos_desde_linea_n <- function(n) {
  datos_raw <- leer_linea_n(n)
  .parsear_y_establecer(datos_raw, origen = "dataframe")
}


# =============================================================================
# Carga de resultados desde stanfit — Modelo HUF (solo lambdas H/U/F)
# =============================================================================
# Esta variante se usa cuando beta ya está fijado y solo se estiman las lambdas
# que controlan la distribución de casos entre H, U y F.
export("cargar_fitmodel_huf")
cargar_fitmodel_huf <- function(.fitmodel, .pars, .n, .probfile) {
  extracted   <- rstan::extract(.fitmodel)
  index       <- which.max(extracted$lp__)
  fit_summary <- rstan::summary(.fitmodel, pars = .pars)$summary

  lamih_opt <- extracted$lamih[index]
  lamif_opt <- extracted$lamif[index]
  lamhu_opt <- extracted$lamhu[index]
  lamhf_opt <- extracted$lamhf[index]
  lamuf_opt <- extracted$lamuf[index]

  establecer_lambda_ih(lamih_opt, fit_summary["lamih", "2.5%"], fit_summary["lamih", "97.5%"])
  establecer_lambda_if(lamif_opt, fit_summary["lamif", "2.5%"], fit_summary["lamif", "97.5%"])
  establecer_lambda_hu(lamhu_opt, fit_summary["lamhu", "2.5%"], fit_summary["lamhu", "97.5%"])
  establecer_lambda_hf(lamhf_opt, fit_summary["lamhf", "2.5%"], fit_summary["lamhf", "97.5%"])
  establecer_lambda_uf(lamuf_opt, fit_summary["lamuf", "2.5%"], fit_summary["lamuf", "97.5%"])

  fit_summary <- cbind(
    "opt" = c(
      lamih   = lamih_opt,
      lamif   = lamif_opt,
      lamhu   = lamhu_opt,
      lamhf   = lamhf_opt,
      lamuf   = lamuf_opt,
      sigma_h = extracted$sigma_h[index],
      sigma_u = extracted$sigma_u[index],
      sigma_f = extracted$sigma_f[index],
      lp__h   = extracted$lp__[index]
    ),
    fit_summary
  )

  rownames(fit_summary) <- paste(rownames(fit_summary), .n, sep = "")

  utils::write.table(fit_summary,
    file      = .probfile,
    sep       = ",",
    col.names = FALSE,
    append    = TRUE
  )
}

# Carga resultados del modelo SEIR (solo beta)
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
    file      = .probfile,
    sep       = ",",
    col.names = FALSE,
    append    = TRUE
  )
}


# =============================================================================
# Inicialización automática del módulo
# =============================================================================
if (!file.exists(archivo_de_salida_filepath)) {
  print(glue("Creando un archivo de bitacora en {archivo_de_salida_filepath}."))
  file.create(archivo_de_salida_filepath)
  header <- purrr::map(nombres_de_columnas, function(.) glue("\"{.}\""))
  header <- paste(header, collapse = ",")
  write(header, archivo_de_salida_filepath)
  ejecutar_model_init <- TRUE
} else {
  print(glue("Encontrado un archivo de bitacora en {archivo_de_salida_filepath}."))
  cantidad_de_lineas <- peek_count_lines(archivo_de_salida_filepath)
  if (cantidad_de_lineas < 2) {
    print(glue("Bitacora sin datos."))
    ejecutar_model_init <- TRUE
  } else {
    importar_datos_desde_ultima_linea()
    print(glue("Inicializado con datos de la ultima linea."))
  }
}
