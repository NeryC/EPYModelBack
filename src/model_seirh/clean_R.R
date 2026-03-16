# =============================================================================
# clean_R.R
# =============================================================================
# Genera la serie temporal diaria de casos confirmados de COVID-19 en Paraguay.
#
# Proceso
# -------
# 1. Lee los datos confirmados del archivo de referencia almacenado
#    en public/data/ (versión previa, ya procesada).
# 2. Lee los datos confirmados recién descargados desde public/rawData/
#    (archivo crudo del MSPBS vía Selenium).
# 3. Compara ambas series para detectar modificaciones retrospectivas en los datos.
#    Si existe alguna fecha donde los nuevos datos difieren de los anteriores,
#    imprime la fecha aproximada del cambio (15 días antes del primer diferencial).
# 4. Construye la serie diaria completa desde 2020-03-07 hasta la fecha máxima
#    disponible en los nuevos datos.
# 5. Guarda el resultado en public/data/confirmado_diarios_revisado.csv.
#
# Entrada
# -------
#   public/data/Descargar datos_Datos completos_data.csv    ← versión de referencia
#   public/rawData/Descargar datos_Datos completos_data.csv ← versión recién descargada
#
# Salida
# ------
#   public/data/confirmado_diarios_revisado.csv
#   Columnas: Fecha (YYYY-MM-DD), Confirmado_diario (entero)
#
# Uso
# ---
#   Rscript clean_R.R   (desde la raíz del proyecto)
#   O como parte del script preprocessing: bash preprocessing
# =============================================================================

rm(list = ls())
library(readr)

# Raíz del proyecto (directorio de trabajo actual)
setwd(getwd())
root_path <- getwd()

# Fecha de inicio de la serie (primer caso confirmado en Paraguay: 2020-03-07)
FECHA_INICIO <- as.Date("2020-03-07")
FECHA_ORIGEN <- as.Date("2020-03-06")  # Día anterior al inicio (para aritmética de índices)

# =============================================================================
# 1. Leer archivo de referencia (versión anterior, ya procesada)
# =============================================================================
# Este archivo es el que fue producido en la ejecución anterior de clean_R.R.
# Se usa para detectar si el MSPBS realizó correcciones retroactivas en los datos.
datos_referencia <- read.csv(
  paste0(root_path, "/public/data/Descargar datos_Datos completos_data.csv"),
  sep = ";"
)

# Convertir fechas de confirmación y contar casos por día
fechas_ref <- as.Date(datos_referencia$Fecha.Confirmacion, format = "%d/%m/%Y")
conteo_ref <- table(cut(fechas_ref, breaks = "day"))
max_date_ref <- as.Date(max(fechas_ref))
n_dias_ref   <- as.numeric(max_date_ref) - as.numeric(FECHA_INICIO)  # Exclusivo del último día

# Construir vector de casos diarios de referencia (índice 1 = 2020-03-07)
confirmado_ref <- rep(0, n_dias_ref)
for (i in seq(1, n_dias_ref)) {
  fecha_i <- as.character(as.Date(as.numeric(FECHA_ORIGEN) + i, origin = "1970-01-01"))
  valor   <- conteo_ref[fecha_i]
  confirmado_ref[i] <- ifelse(is.na(valor), 0, as.integer(valor))
}

# =============================================================================
# 2. Leer archivo recién descargado (raw data del MSPBS)
# =============================================================================
datos_descargados <- read.csv(
  paste0(root_path, "/public/rawData/Descargar datos_Datos completos_data.csv"),
  sep = ";"
)

# Convertir fechas y contar casos por día en los datos nuevos
fechas_descargados <- as.Date(datos_descargados$Fecha.Confirmacion, format = "%d/%m/%Y")
conteo_descargados <- table(cut(fechas_descargados, breaks = "day"))
max_date_nuevo     <- as.Date(max(fechas_descargados))
n_dias_nuevo       <- as.numeric(max_date_nuevo) - as.numeric(FECHA_INICIO) + 1  # Inclusivo

# Construir vector de casos diarios de los datos nuevos
confirmado_nuevo <- rep(0, n_dias_nuevo)
for (i in seq(1, n_dias_nuevo)) {
  fecha_i <- as.character(as.Date(as.numeric(FECHA_ORIGEN) + i, origin = "1970-01-01"))
  valor   <- conteo_descargados[fecha_i]
  confirmado_nuevo[i] <- ifelse(is.na(valor), 0, as.integer(valor))
}

# =============================================================================
# 3. Detectar modificaciones retrospectivas
# =============================================================================
# El MSPBS a veces corrige datos de fechas anteriores. Si hay diferencias
# entre la versión de referencia y la nueva, se reporta la primera fecha afectada
# (con un margen de 15 días para identificar el inicio del bloque corregido).
diferencias <- rep(0, n_dias_nuevo)
n_comparar  <- min(n_dias_ref, n_dias_nuevo)
diferencias[seq(1, n_comparar)] <- confirmado_nuevo[seq(1, n_comparar)] - confirmado_ref[seq(1, n_comparar)]

indices_modificados <- which(diferencias > 0)

if (length(indices_modificados) == 0) {
  print("No hay modificación de datos retrospectivo en DATOS COMPLETOS...")
} else {
  # Estimar la fecha donde comenzó la corrección (15 días antes del primer diferencial)
  fecha_inicio_correccion <- as.Date(
    as.numeric(FECHA_ORIGEN) + indices_modificados[1] - 15,
    origin = "1970-01-01"
  )
  print(paste("Modificacion retroactiva detectada. Fecha estimada de inicio:", fecha_inicio_correccion))
}

# =============================================================================
# 4. Construir serie diaria revisada y guardar
# =============================================================================
# La serie final usa los datos recién descargados (versión más reciente)
fechas_salida <- as.Date(
  seq(as.numeric(FECHA_INICIO), as.numeric(max_date_nuevo)),
  origin = "1970-01-01"
)

lista_salida <- list(
  Fecha             = fechas_salida,
  Confirmado_diario = confirmado_nuevo
)

write.csv(
  lista_salida,
  file = paste0(root_path, "/public/data/confirmado_diarios_revisado.csv")
)

print(paste("Serie de confirmados generada:", length(confirmado_nuevo), "dias hasta", max_date_nuevo))
