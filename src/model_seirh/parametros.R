import("dplyr", "%>%")
import("utils", "read.csv")
import("glue", "glue")

verificar_que_archivo_existe <- ensurer::ensures_that(file.exists)
verificar_directorios <- ensurer::ensures_that(dir.exists)

export("data_path")
data_path <-
  glue(paste(
    getwd(),
    "/public/data/",
    sep = ""
  )) %>%
  ensurer::ensure_that(dir.exists(.) ~ glue("Directorio {.} no encontrado."))

export("raw_data_path")
raw_data_path <-
  paste(
    getwd(),
    "/public/rawData/",
    sep = ""
  )
export("model_seirh")
model_seirh <-
  paste(
    getwd(),
    "/src/model_seirh/",
    sep = ""
  )

export("experimento")
experimento <- list(tamano_ventana = 14)

tamano_ventana <- experimento$tamano_ventana

export(".dir_plot")
.dir_plot <-
  glue("{model_seirh}res{tamano_ventana}/pair_out/") %>%
  ensurer::ensure_that(dir.exists(.) ~ glue("Directorio {.} no encontrado."))

export("filepaths")
filepaths <- list(
  modelo_SEIR = glue("{model_seirh}model_seir.stan") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  modelo_SEIRH = glue("{model_seirh}model_seirh.stan") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  modelo_init = glue("{model_seirh}model_init.stan") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_diarios =
    glue("{data_path}REGISTRO DIARIO_Datos completos_data.csv") %>%
      ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_confirmados = glue("{data_path}confirmado_diarios_revisado.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_poblacion = glue("{data_path}DatosPoblacionDpto.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_fallecidos = glue("{data_path}Fallecidos_diarios_revisado.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_inmunizados = glue("{data_path}Inmunizado_diarios.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_simulacion = glue("{data_path}sim.csv"), # TODO No necesariamente existe
  datos_probabilidad = glue("{data_path}prob.csv")
) # TODO No necesariamente existe

datos_diarios_raw <-
  read.csv(
    filepaths$datos_diarios,
    sep = ";",
    fileEncoding = "UTF-8"
  ) # TODO Try sep=",", else sep=";"
datos_diarios_raw[is.na(datos_diarios_raw)] <- 0

numero_datos <- nrow(datos_diarios_raw)

datos_confirmados_raw <-
  read.csv(filepaths$datos_confirmados, sep = ",")
# TODO Try sep=",", else sep=";"
datos_confirmados_raw[is.na(datos_confirmados_raw)] <- 0
numero_x <- nrow(datos_confirmados_raw)

if (numero_datos > numero_x) {
  for (i in seq(numero_x + 1, numero_datos)) {
    datos_confirmados_raw <-
      rbind(
        datos_confirmados_raw,
        c(
          X = i,
          Fecha = as.Date(as.numeric(as.Date("2020-03-06")) + i,
            origin = "1970-01-01"
          ),
          Confirmado_diario = 0
        )
      )
  }
}

datos_fallecidos_raw <-
  read.csv(
    filepaths$datos_fallecidos,
    sep = ",",
    fileEncoding = "UTF-8-BOM"
  ) # TODO Try sep=",", else sep=";"
fallecidos <- datos_fallecidos_raw$Fallecido_diario
numero_x <- nrow(datos_fallecidos_raw)

if (numero_datos > numero_x) {
  for (i in seq(numero_x + 1, numero_datos)) {
    datos_fallecidos_raw <-
      rbind(
        datos_fallecidos_raw,
        c(
          X = i,
          Fecha = as.Date(as.numeric(as.Date("2020-03-06")) + i,
            origin = "1970-01-01"
          ),
          Fallecido_diario = 0
        )
      )
  }
}
fallecidos <- datos_fallecidos_raw$Fallecido_diario
datos_inmunizados_raw <-
  read.csv(filepaths$datos_inmunizados, sep = ",", fileEncoding = "UTF-8-BOM")
export("inmunizados_filtrado")
inmunizados <- datos_inmunizados_raw$Inmunizado_diario
inmunizados_filtrado <- inmunizados
for (i in seq(2, length(inmunizados))) {
  inmunizados_filtrado[i] <-
    1.0 / 14.0 * inmunizados[i] +
    (1.0 - 1.0 / 14.0) * inmunizados_filtrado[i - 1]
}

export("boosters_filtrado")
boosters <- datos_inmunizados_raw$Booster_diario
boosters_filtrado <- boosters
for (i in seq(2, length(boosters))) {
  boosters_filtrado[i] <-
    1.0 / 14.0 * boosters[i] + (1.0 - 1.0 / 14.0) * boosters_filtrado[i - 1]
}
inmunizados_filtrado <- inmunizados_filtrado + boosters_filtrado
export("confirmados_sin_subregistro")
confirmados_sin_subregistro <- datos_confirmados_raw$Confirmado_diario
confirmados_sin_subregistro[is.na(confirmados_sin_subregistro)] <- 0

export("factor_subregistro")
factor_subregistro <-
  datos_diarios_raw$Cantidad.Pruebas^(-0.914773) * exp(9.00991)
index <- which(is.infinite(factor_subregistro))
factor_subregistro[index] <- 1
for (i in index) {
  factor_subregistro[i] <-
    0.5 * (factor_subregistro[i - 1] + factor_subregistro[i + 1])
}

export("confirmados_con_subregistro")
n1 <- length(datos_confirmados_raw$Confirmado_diario)
n2 <- length(datos_diarios_raw$Cantidad.Pruebas)
nn <- n1 * (n1 < n2) + n2 * (n1 >= n2)
confirmados_con_subregistro <-
  datos_confirmados_raw$Confirmado_diario[1:nn] * factor_subregistro[1:nn]

export("reportando_con_subregistro")
reportando_con_subregistro <- TRUE
# READ ONLY! Para utilizar los confirmados con subregistro, modificar aqui.

export("cantidades_diarias")
cantidades_diarias <- list(
  reportados = if (reportando_con_subregistro) {
    confirmados_con_subregistro
  } else {
    confirmados_sin_subregistro
  },
  hospitalizados = datos_diarios_raw$Internados.Generales,
  uci = datos_diarios_raw$Internados.UTI,
  fallecidos = fallecidos,
  importados = datos_diarios_raw$Confirmados.en.albergues,
  inmunizados = inmunizados_filtrado
)

export("fecha_inicial")
fecha_inicial <- min(as.Date(datos_diarios_raw$Fecha, "%d/%m/%Y")) - 1
export("fecha_final")
fecha_final <- max(as.Date(datos_diarios_raw$Fecha, "%d/%m/%Y"))

datos_sobre_poblacion <- read.csv(filepaths$datos_poblacion)

export("fecha_inicio_evaluacion")
fecha_inicio_evaluacion <- "2020-03-06"
fecha_inicio_evaluacion <- as.Date(fecha_inicio_evaluacion)

export("id_inicio_sim")
id_inicio_sim <- as.numeric(fecha_inicio_evaluacion) - as.numeric(fecha_inicial)
r0 <- sum(confirmados_sin_subregistro[1:id_inicio_sim])
r0 <- 0

alpha <- 1.0 / 3.0
gamma <- 1.0 / 7.0
delta_hu <- 1.0 / 7.0
delta_hf <- 1.0 / 9.0
delta_ho <- 1.0 / 11.0
phi_uf <- 1.0 / 11.0
phi_uo <- 1.0 / 12.0
psi <- 1.0 / 180.0
eta <- 0.9

export("parametros_ode_init")
parametros_ode_init <- c(
  N = sum(datos_sobre_poblacion[, "X2020"]),
  alpha = alpha,
  gamma = gamma,
  psi = psi,
  eta = eta,
  r0 = r0
)


export("parametros_ode_seir")
parametros_ode_seir <- c(
  N = sum(datos_sobre_poblacion[, "X2020"]),
  alpha = alpha,
  gamma = gamma,
  psi = psi,
  eta = eta
)

export("parametros_ode_seirh")
parametros_ode_seirh <- c(
  N = sum(datos_sobre_poblacion[, "X2020"]),
  alpha = alpha,
  gamma = gamma,
  delta_hu = delta_hu,
  delta_hf = delta_hf,
  delta_ho = delta_ho,
  phi_uf = phi_uf,
  phi_uo = phi_uo,
  psi = psi,
  eta = eta
)

export("odefun_seir")
#' Simula el sistema de ecuaciones durante un delta_t
#'
#' @param t Variable temporal.
#' @param state Estado del sistema en el instante t.
#' @param parameters TODO
#' @return Estado del sistema en el instante t + delta_t.
odefun_seir <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    index <- ceiling(t)
    if (index == 0) {
      index <- 1
    }
    if (index == tamano_ventana + 1) {
      index <- tamano_ventana
    }
    importados <- get(paste("imported", index, sep = ""))
    v_filtrado <- get(paste("v_filtrado", index, sep = ""))
    dS <- -beta * S * I / N + psi * O - eta * v_filtrado - importados # nolint
    dE <- beta * S * I / N - alpha * E # nolint
    dI <- alpha * E - gamma * I # nolint
    dR <- gamma * I + importados # nolint
    dO <- gamma * I + importados - psi * O + eta * v_filtrado # nolint

    list(c(dS, dE, dI, dR, dO))
  }) # end with(as.list ...
}

export("odefun_seirh")
#' Simula el sistema de ecuaciones durante un delta_t
#'
#' @param t Variable temporal.
#' @param state Estado del sistema en el instante t.
#' @param parameters TODO
#' @return Estado del sistema en el instante t + delta_t.
odefun_seirh <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    index <- ceiling(t)
    if (index == 0) {
      index <- 1
    }
    if (index == tamano_ventana + 1) {
      index <- tamano_ventana
    }
    importados <- get(paste("imported", index, sep = ""))
    v_filtrado <- get(paste("v_filtrado", index, sep = ""))
    lambda_ho <- (1 - lambda_hu - lambda_hf) # nolint
    lambda_uo <- (1 - lambda_uf) # nolint
    dS <- -beta * S * I / N + psi * O - eta * v_filtrado - importados # nolint
    dE <- beta * S * I / N - alpha * E # nolint
    dI <- alpha * E - gamma * I # nolint
    dR <- gamma * I + importados # nolint
    dH <- lambda_ih * gamma * I - lambda_hu * delta_hu * H - lambda_hf * delta_hf * H - lambda_ho * delta_ho * H # nolint
    dU <- lambda_hu * delta_hu * H - lambda_uf * phi_uf * U - lambda_uo * phi_uo * U # nolint
    dF <- lambda_if * gamma * I + lambda_uf * phi_uf * U + lambda_hf * delta_hf * H # nolint
    dO <- (1 - lambda_ih - lambda_if) * gamma * I + lambda_ho * delta_ho * H + lambda_uo * phi_uo * U + importados - psi * O + eta * v_filtrado # nolint

    list(c(dS, dE, dI, dR, dH, dU, dF, dO))
  }) # end with(as.list ...
}
