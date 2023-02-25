import("dplyr", "%>%")
import("glue", "glue")
import("fpeek")

root_path <- paste(getwd(),
  "/src/model_seirh/",
  sep = ""
)

parametros <- modules::use(glue("{root_path}parametros.R"))

archivo_de_salida_filepath <-
  glue("{parametros$data_path}sim_SEIRHUF.csv") # parametros$filepaths$bitacora

export("ejecutar_model_init")
ejecutar_model_init <- FALSE

nombres_de_columnas <- c(
  "date",
  "ndate",
  "beta",
  "beta_lo",
  "beta_hi",
  "lamih",
  "lamih_lo",
  "lamih_hi",
  "lamif",
  "lamif_lo",
  "lamif_hi",
  "lamhu",
  "lamhu_lo",
  "lamhu_hi",
  "lamhf",
  "lamhf_lo",
  "lamhf_hi",
  "lamuf",
  "lamuf_lo",
  "lamuf_hi",
  "S",
  "E",
  "I",
  "R",
  "H",
  "U",
  "F",
  "dailyR",
  "dailyF",
  "R_sin_subRegistro",
  "dailyR_sin_subRegistro",
  "seed",
  "numero_reproductivo"
)

# Con valores por defecto
datos_iteracion <- list(
  date = NA,
  ndate = NA,
  beta = NA,
  beta_lo = NA,
  beta_hi = NA,
  lamih = NA,
  lamih_lo = NA,
  lamih_hi = NA,
  lamif = NA,
  lamif_lo = NA,
  lamif_hi = NA,
  lamhu = NA,
  lamhu_lo = NA,
  lamhu_hi = NA,
  lamhf = NA,
  lamhf_lo = NA,
  lamhf_hi = NA,
  lamuf = NA,
  lamuf_lo = NA,
  lamuf_hi = NA,
  S = NA,
  E = NA,
  I = NA,
  R = NA,
  H = NA,
  U = NA,
  F = NA,
  dailyR = NA,
  dailyF = NA,
  R_sin_subRegistro = NA,
  dailyR_sin_subRegistro = NA,
  seed = NA,
  numero_reproductivo = NA
)

export("obtener_datos")
obtener_datos <- function() datos_iteracion

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
  datos_iteracion$beta <<- .beta
  datos_iteracion$beta_lo <<- .beta_low
  datos_iteracion$beta_hi <<- .beta_high
}

export("establecer_lambda_ih")
establecer_lambda_ih <- function(.lambda_ih, .lambda_ih_low, .lambda_ih_high) {
  datos_iteracion$lamih <<- .lambda_ih
  datos_iteracion$lamih_lo <<- .lambda_ih_low
  datos_iteracion$lamih_hi <<- .lambda_ih_high
}

export("establecer_lambda_if")
establecer_lambda_if <- function(.lambda_if, .lambda_if_low, .lambda_if_high) {
  datos_iteracion$lamif <<- .lambda_if
  datos_iteracion$lamif_lo <<- .lambda_if_low
  datos_iteracion$lamif_hi <<- .lambda_if_high
}

export("establecer_lambda_hu")
establecer_lambda_hu <- function(.lambda_hu, .lambda_hu_low, .lambda_hu_high) {
  datos_iteracion$lamhu <<- .lambda_hu
  datos_iteracion$lamhu_lo <<- .lambda_hu_low
  datos_iteracion$lamhu_hi <<- .lambda_hu_high
}

export("establecer_lambda_hf")
establecer_lambda_hf <- function(.lambda_hf, .lambda_hf_low, .lambda_hf_high) {
  datos_iteracion$lamhf <<- .lambda_hf
  datos_iteracion$lamhf_lo <<- .lambda_hf_low
  datos_iteracion$lamhf_hi <<- .lambda_hf_high
}

export("establecer_lambda_uf")
establecer_lambda_uf <- function(.lambda_uf, .lambda_uf_low, .lambda_uf_high) {
  datos_iteracion$lamuf <<- .lambda_uf
  datos_iteracion$lamuf_lo <<- .lambda_uf_low
  datos_iteracion$lamuf_hi <<- .lambda_uf_high
}

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
  datos_iteracion$R_sin_subRegistro <<- .R_sin_subRegistro
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

export("escribir_linea")
escribir_linea <- function() {
  write(paste(datos_iteracion, collapse = ","), archivo_de_salida_filepath, append = TRUE)
}

export("eliminar_ultima_linea")
eliminar_ultima_linea <- function() {
  # system(glue("sed --in-place '$d' {archivo_de_salida_filepath}"))
  system(glue("sed -i '' -e '$ d' {archivo_de_salida_filepath}"))
}

leer_ultima_linea <- function() {
  # ultima_linea <- system(glue("tail -n 1 {archivo_de_salida_filepath}"), intern = TRUE, show.output.on.console = FALSE)
  ultima_linea <- system(glue("tail -n 1 {archivo_de_salida_filepath}"), intern = TRUE)
  return(ultima_linea)
}


leer_penultima_linea <- function() {
  # ultima_linea <- system(glue("tail -n 1 {archivo_de_salida_filepath}"), intern = TRUE, show.output.on.console = FALSE)
  penultima_linea <- system(glue("tail -n 2 {archivo_de_salida_filepath}"), intern = TRUE)
  return(penultima_linea)
}

export("importar_datos_desde_ultima_linea")
importar_datos_desde_ultima_linea <- function() {
  ultima_linea <- leer_ultima_linea()
  datos_raw <- strsplit(ultima_linea, ",")

  # https://stackoverflow.com/a/36239701/7555119
  as.num <- function(x, na.strings = "NA") {
    stopifnot(is.character(x))
    na <- x %in% na.strings
    x[na] <- 0
    x <- as.numeric(x)
    x[na] <- NA_real_
    x
  }

  datos_raw <- datos_raw[[1]]

  fecha <- datos_raw[1]
  ndate <- as.num(datos_raw[2])

  beta <- as.num(datos_raw[3])
  beta_lo <- as.num(datos_raw[4])
  beta_hi <- as.num(datos_raw[5])

  lambda_ih <- as.num(datos_raw[6])
  lambda_ih_lo <- as.num(datos_raw[7])
  lambda_ih_hi <- as.num(datos_raw[8])

  lambda_if <- as.num(datos_raw[9])
  lambda_if_lo <- as.num(datos_raw[10])
  lambda_if_hi <- as.num(datos_raw[11])

  lambda_hu <- as.num(datos_raw[12])
  lambda_hu_lo <- as.num(datos_raw[13])
  lambda_hu_hi <- as.num(datos_raw[14])

  lambda_hf <- as.num(datos_raw[15])
  lambda_hf_lo <- as.num(datos_raw[16])
  lambda_hf_hi <- as.num(datos_raw[17])

  lambda_uf <- as.num(datos_raw[18])
  lambda_uf_lo <- as.num(datos_raw[19])
  lambda_uf_hi <- as.num(datos_raw[20])

  S <- as.num(datos_raw[21])
  E <- as.num(datos_raw[22])
  I <- as.num(datos_raw[23])
  R <- as.num(datos_raw[24])
  H <- as.num(datos_raw[25])
  U <- as.num(datos_raw[26])
  F <- as.num(datos_raw[27])

  dailyR <- as.num(datos_raw[28])
  dailyF <- as.num(datos_raw[29])

  R_sin_subRegistro <- as.num(datos_raw[30])
  dailyR_sin_subRegistro <- as.num(datos_raw[31])

  seed <- as.num(datos_raw[32])

  numero_reproductivo <- as.num(datos_raw[33])

  establecer_fecha(fecha)
  establecer_ndate(ndate)
  establecer_beta(beta, beta_lo, beta_hi)
  establecer_lambda_ih(lambda_ih, lambda_ih_lo, lambda_ih_hi)
  establecer_lambda_if(lambda_if, lambda_if_lo, lambda_if_hi)
  establecer_lambda_hu(lambda_hu, lambda_hu_lo, lambda_hu_hi)
  establecer_lambda_hf(lambda_hf, lambda_hf_lo, lambda_hf_hi)
  establecer_lambda_uf(lambda_uf, lambda_uf_lo, lambda_uf_hi)
  establecer_SEIRHUF(S, E, I, R, H, U, F)
  establecer_diarios(dailyR, dailyF)
  establecer_subregistros(R_sin_subRegistro, dailyR_sin_subRegistro)
  establecer_semilla(seed)
  establecer_numero_reproductivo(numero_reproductivo)
}

export("importar_datos_desde_penultima_linea")
importar_datos_desde_penultima_linea <- function() {
  penultima_linea <- leer_penultima_linea()
  datos_raw <- strsplit(penultima_linea, ",")

  # https://stackoverflow.com/a/36239701/7555119
  as.num <- function(x, na.strings = "NA") {
    stopifnot(is.character(x))
    na <- x %in% na.strings
    x[na] <- 0
    x <- as.numeric(x)
    x[na] <- NA_real_
    x
  }

  datos_raw <- datos_raw[[1]]

  fecha <- datos_raw[1]
  ndate <- as.num(datos_raw[2])

  beta <- as.num(datos_raw[3])
  beta_lo <- as.num(datos_raw[4])
  beta_hi <- as.num(datos_raw[5])

  lambda_ih <- as.num(datos_raw[6])
  lambda_ih_lo <- as.num(datos_raw[7])
  lambda_ih_hi <- as.num(datos_raw[8])

  lambda_if <- as.num(datos_raw[9])
  lambda_if_lo <- as.num(datos_raw[10])
  lambda_if_hi <- as.num(datos_raw[11])

  lambda_hu <- as.num(datos_raw[12])
  lambda_hu_lo <- as.num(datos_raw[13])
  lambda_hu_hi <- as.num(datos_raw[14])

  lambda_hf <- as.num(datos_raw[15])
  lambda_hf_lo <- as.num(datos_raw[16])
  lambda_hf_hi <- as.num(datos_raw[17])

  lambda_uf <- as.num(datos_raw[18])
  lambda_uf_lo <- as.num(datos_raw[19])
  lambda_uf_hi <- as.num(datos_raw[20])

  S <- as.num(datos_raw[21])
  E <- as.num(datos_raw[22])
  I <- as.num(datos_raw[23])
  R <- as.num(datos_raw[24])
  H <- as.num(datos_raw[25])
  U <- as.num(datos_raw[26])
  F <- as.num(datos_raw[27])

  dailyR <- as.num(datos_raw[28])
  dailyF <- as.num(datos_raw[29])

  R_sin_subRegistro <- as.num(datos_raw[30])
  dailyR_sin_subRegistro <- as.num(datos_raw[31])

  seed <- as.num(datos_raw[32])

  numero_reproductivo <- as.num(datos_raw[33])

  establecer_fecha(fecha)
  establecer_ndate(ndate)
  establecer_beta(beta, beta_lo, beta_hi)
  establecer_lambda_ih(lambda_ih, lambda_ih_lo, lambda_ih_hi)
  establecer_lambda_if(lambda_if, lambda_if_lo, lambda_if_hi)
  establecer_lambda_hu(lambda_hu, lambda_hu_lo, lambda_hu_hi)
  establecer_lambda_hf(lambda_hf, lambda_hf_lo, lambda_hf_hi)
  establecer_lambda_uf(lambda_uf, lambda_uf_lo, lambda_uf_hi)
  establecer_SEIRHUF(S, E, I, R, H, U, F)
  establecer_diarios(dailyR, dailyF)
  establecer_subregistros(R_sin_subRegistro, dailyR_sin_subRegistro)
  establecer_semilla(seed)
  establecer_numero_reproductivo(numero_reproductivo)
}


leer_linea_n <- function(n) {
  data <- utils::read.csv(archivo_de_salida_filepath, sep = ",")
  linea_n <- subset(data, data$ndate %in% n)
  return(linea_n)
}

export("importar_datos_desde_linea_n")
importar_datos_desde_linea_n <- function(n) {
  linea_n <- leer_linea_n(n)
  # print(linea_n)
  datos_raw <- linea_n

  # https://stackoverflow.com/a/36239701/7555119
  as.num <- function(x, na.strings = "NA") {
    # stopifnot(is.character(x))
    na <- x %in% na.strings
    x[na] <- 0
    x <- as.numeric(x)
    x[na] <- NA_real_
    x
  }

  # datos_raw <- datos_raw[[1]]

  fecha <- datos_raw$date
  ndate <- as.num(datos_raw$ndate)

  beta <- as.num(datos_raw$beta)
  beta_lo <- as.num(datos_raw$beta_lo)
  beta_hi <- as.num(datos_raw$beta_hi)

  lambda_ih <- as.num(datos_raw$lamih)
  lambda_ih_lo <- as.num(datos_raw$lamih_lo)
  lambda_ih_hi <- as.num(datos_raw$lamih_hi)

  lambda_if <- as.num(datos_raw$lamif)
  lambda_if_lo <- as.num(datos_raw$lamif_lo)
  lambda_if_hi <- as.num(datos_raw$lamif_hi)

  lambda_hu <- as.num(datos_raw$lamhu)
  lambda_hu_lo <- as.num(datos_raw$lamhu_lo)
  lambda_hu_hi <- as.num(datos_raw$lamhu_hi)

  lambda_hf <- as.num(datos_raw$lamhf)
  lambda_hf_lo <- as.num(datos_raw$lamhf_lo)
  lambda_hf_hi <- as.num(datos_raw$lamhf_hi)

  lambda_uf <- as.num(datos_raw$lamuf)
  lambda_uf_lo <- as.num(datos_raw$lamuf_lo)
  lambda_uf_hi <- as.num(datos_raw$lamuf_hi)

  S <- as.num(datos_raw$S)
  E <- as.num(datos_raw$E)
  I <- as.num(datos_raw$I)
  R <- as.num(datos_raw$R)
  H <- as.num(datos_raw$H)
  U <- as.num(datos_raw$U)
  F <- as.num(datos_raw$F)

  dailyR <- as.num(datos_raw$dailyR)
  dailyF <- as.num(datos_raw$dailyF)

  R_sin_subRegistro <- as.num(datos_raw$R_sin_subRegistro)
  dailyR_sin_subRegistro <- as.num(datos_raw$dailyR_sin_subRegistro)

  seed <- as.num(datos_raw$seed)

  numero_reproductivo <- as.num(datos_raw$numero_reproductivo)

  establecer_fecha(fecha)
  establecer_ndate(ndate)
  establecer_beta(beta, beta_lo, beta_hi)
  establecer_lambda_ih(lambda_ih, lambda_ih_lo, lambda_ih_hi)
  establecer_lambda_if(lambda_if, lambda_if_lo, lambda_if_hi)
  establecer_lambda_hu(lambda_hu, lambda_hu_lo, lambda_hu_hi)
  establecer_lambda_hf(lambda_hf, lambda_hf_lo, lambda_hf_hi)
  establecer_lambda_uf(lambda_uf, lambda_uf_lo, lambda_uf_hi)
  establecer_SEIRHUF(S, E, I, R, H, U, F)
  establecer_diarios(dailyR, dailyF)
  establecer_subregistros(R_sin_subRegistro, dailyR_sin_subRegistro)
  establecer_semilla(seed)
  establecer_numero_reproductivo(numero_reproductivo)
}

#################################

#################################

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

export("cargar_fitmodel_huf")
cargar_fitmodel_huf <- function(.fitmodel, .pars, .n, .probfile) {
  extracted <- rstan::extract(.fitmodel)
  index <- which.max(extracted$lp__)
  fit_summary <- rstan::summary(.fitmodel, pars = .pars)$summary

  lamih_opt <- extracted$lamih[index]
  lamif_opt <- extracted$lamif[index]
  lamhu_opt <- extracted$lamhu[index]
  lamhf_opt <- extracted$lamhf[index]
  lamuf_opt <- extracted$lamuf[index]

  establecer_lambda_ih(
    lamih_opt,
    fit_summary["lamih", "2.5%"],
    fit_summary["lamih", "97.5%"]
  )
  establecer_lambda_if(
    lamif_opt,
    fit_summary["lamif", "2.5%"],
    fit_summary["lamif", "97.5%"]
  )
  establecer_lambda_hu(
    lamhu_opt,
    fit_summary["lamhu", "2.5%"],
    fit_summary["lamhu", "97.5%"]
  )
  establecer_lambda_hf(
    lamhf_opt,
    fit_summary["lamhf", "2.5%"],
    fit_summary["lamhf", "97.5%"]
  )
  establecer_lambda_uf(
    lamuf_opt,
    fit_summary["lamuf", "2.5%"],
    fit_summary["lamuf", "97.5%"]
  )

  fit_summary <- cbind(
    "opt" = c(
      lamih = lamih_opt,
      lamif = lamif_opt,
      lamhu = lamhu_opt,
      lamhf = lamhf_opt,
      lamuf = lamuf_opt,
      sigma_h = extracted$sigma_h[index],
      sigma_u = extracted$sigma_u[index],
      sigma_f = extracted$sigma_f[index],
      lp__h = extracted$lp__[index]
    ),
    fit_summary
  )

  rownames(fit_summary) <- paste(rownames(fit_summary), .n, sep = "")

  utils::write.table(fit_summary,
    file = .probfile, sep = ",", col.names = FALSE,
    append = TRUE
  )
}

export("cargar_fitmodel_seir")
cargar_fitmodel_seir <- function(.fitmodel, .pars, .n, .probfile) {
  extracted <- rstan::extract(.fitmodel)
  index <- which.max(extracted$lp__)
  fit_summary <- rstan::summary(.fitmodel, pars = .pars)$summary
  beta_opt <- extracted$beta[index]
  # beta_opt <- fit_summary["beta","mean"]

  establecer_beta(
    beta_opt,
    fit_summary["beta", "2.5%"],
    fit_summary["beta", "97.5%"]
  )

  fit_summary <- cbind(
    "opt" = c(
      beta = beta_opt,
      sigma_r = extracted$sigma_r[index],
      lp__ = extracted$lp__[index]
    ),
    fit_summary
  )

  rownames(fit_summary) <- paste(rownames(fit_summary), .n, sep = "")

  utils::write.table(fit_summary,
    file = .probfile, sep = ",", col.names = FALSE,
    append = TRUE
  )
}
