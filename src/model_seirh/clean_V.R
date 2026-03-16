# =============================================================================
# clean_V.R
# =============================================================================
# Descarga y procesa la serie temporal de personas vacunadas en Paraguay.
#
# Fuente de datos
# ---------------
# Our World in Data (OWID): https://covid.ourworldindata.org/data/owid-covid-data.csv
# Columnas utilizadas:
#   - people_fully_vaccinated : acumulado de personas con esquema completo
#   - total_boosters          : acumulado de dosis de refuerzo (booster)
#
# Proceso
# -------
# 1. Descarga el CSV global de OWID directamente desde la URL.
# 2. Filtra los registros de Paraguay (location == "Paraguay").
# 3. Construye una serie diaria desde 2020-03-07 hasta la fecha máxima disponible.
#    OWID reporta datos con huecos (no todos los días tienen datos), por lo que:
#    - Si un día no tiene dato, se hereda el valor del día anterior (forward-fill).
# 4. Convierte los acumulados en incrementos diarios (diff).
# 5. Guarda el resultado en public/data/Inmunizado_diarios.csv.
#
# Salida
# ------
#   public/data/Inmunizado_diarios.csv
#   Columnas:
#     Fecha           : fecha en formato YYYY-MM-DD
#     Inmunizado_diario : nuevas personas con esquema completo por día
#     Booster_diario    : nuevas dosis de refuerzo por día
#
# Uso
# ---
#   Rscript clean_V.R   (desde la raíz del proyecto)
#   Requiere conexión a Internet para descargar desde OWID.
#   O como parte del script preprocessing: bash preprocessing
# =============================================================================

rm(list = ls())
library(readr)
library(dplyr)

setwd(getwd())
root_path <- getwd()

# URL de Our World in Data con datos globales de COVID-19 (vacunación incluida)
OWID_URL <- "https://covid.ourworldindata.org/data/owid-covid-data.csv"

# Fecha de inicio de la serie (primer caso en Paraguay)
FECHA_INICIO <- as.Date("2020-03-07")
FECHA_ORIGEN <- as.Date("2020-03-06")

# =============================================================================
# 1. Descargar datos de OWID y filtrar Paraguay
# =============================================================================
print("Descargando datos de vacunacion desde Our World in Data...")
covid_data <- read_csv(OWID_URL, show_col_types = FALSE)
data_py    <- covid_data[covid_data$location == "Paraguay", ]

# Rango de fechas disponibles para Paraguay
max_date <- as.Date(max(data_py$date))
n_dias   <- as.numeric(max_date) - as.numeric(FECHA_INICIO) + 1

print(paste("Datos de Paraguay disponibles hasta:", max_date, "—", n_dias, "dias"))

# =============================================================================
# 2. Construir series diarias (con forward-fill para fechas sin dato)
# =============================================================================
# OWID reporta datos no todos los días; para fechas sin dato se usa el valor
# del día anterior (forward-fill: si no hay dato, la persona ya estaba vacunada).
inmunizados <- rep(0, n_dias)
booster     <- rep(0, n_dias)

for (i in seq(1, n_dias)) {
  fecha_i <- as.Date(as.numeric(FECHA_ORIGEN) + i, origin = "1970-01-01")

  # Buscar si OWID reporta dato para esa fecha
  valor_vacunados <- data_py$people_fully_vaccinated[data_py$date == fecha_i]
  valor_booster   <- data_py$total_boosters[data_py$date == fecha_i]

  # Almacenar: si no hay dato (integer(0)) queda 0 para forward-fill posterior
  inmunizados[i] <- ifelse(length(valor_vacunados) > 0, valor_vacunados, NA)
  booster[i]     <- ifelse(length(valor_booster) > 0,   valor_booster,   NA)
}

# Forzar que el primer día sea 0 (no había vacunados aún)
inmunizados[1] <- 0
booster[1]     <- 0

# Forward-fill: propagar el último valor conocido hacia adelante
for (i in seq(2, n_dias)) {
  if (is.na(inmunizados[i])) {
    inmunizados[i] <- inmunizados[i - 1]
  }
  if (is.na(booster[i])) {
    booster[i] <- booster[i - 1]
  }
}

# =============================================================================
# 3. Convertir acumulados en incrementos diarios
# =============================================================================
# Los datos de OWID son acumulados; se necesitan nuevas dosis por día.
# diff(x) devuelve x[i] - x[i-1], por lo que asignamos a partir del índice 2.
inmunizados[2:n_dias] <- diff(inmunizados)  # Nuevas personas con esquema completo por día
booster[2:n_dias]     <- diff(booster)      # Nuevas dosis de refuerzo por día

# Asegurar que los incrementos no sean negativos (pueden ocurrir por correcciones en OWID)
inmunizados <- pmax(inmunizados, 0)
booster     <- pmax(booster, 0)

# =============================================================================
# 4. Guardar resultado
# =============================================================================
fechas_salida <- as.Date(
  seq(as.numeric(FECHA_INICIO), as.numeric(max_date)),
  origin = "1970-01-01"
)

lista_salida <- list(
  Fecha             = fechas_salida,
  Inmunizado_diario = inmunizados,
  Booster_diario    = booster
)

write.csv(
  lista_salida,
  file      = paste0(root_path, "/public/data/Inmunizado_diarios.csv"),
  row.names = FALSE
)

print(paste(
  "Serie de vacunacion generada:", n_dias, "dias.",
  "Total vacunados (esquema completo):", sum(inmunizados, na.rm = TRUE),
  "| Total boosters:", sum(booster, na.rm = TRUE)
))
