# =============================================================================
# clean_F.R
# =============================================================================
# Genera la serie temporal diaria de fallecidos por COVID-19 en Paraguay.
#
# Proceso
# -------
# 1. Lee los datos de fallecidos del archivo de referencia almacenado
#    en public/data/ (versión previa, ya procesada).
# 2. Lee los datos de fallecidos recién descargados desde public/rawData/
#    (archivo crudo del MSPBS vía Selenium).
# 3. Compara ambas series para detectar modificaciones retrospectivas en los datos.
#    Si existe alguna fecha donde los nuevos datos difieren de los anteriores,
#    imprime la fecha aproximada del cambio.
# 4. Construye la serie diaria completa desde 2020-03-07 hasta la fecha máxima
#    disponible en los nuevos datos, usando la fecha de óbito (Fecha.Obito).
# 5. Guarda el resultado en public/data/Fallecidos_diarios_revisado.csv.
#
# Entrada
# -------
#   public/data/FALLECIDOS_Datos completos_data.csv    ← versión de referencia
#   public/rawData/FALLECIDOS_Datos completos_data.csv ← versión recién descargada
#
# Salida
# ------
#   public/data/Fallecidos_diarios_revisado.csv
#   Columnas: Fecha (YYYY-MM-DD), Fallecido_diario (entero)
#
# Uso
# ---
#   Rscript clean_F.R   (desde la raíz del proyecto)
#   O como parte del script preprocessing: bash preprocessing
# =============================================================================

rm(list = ls())
library(readr)

setwd(getwd())
root_path <- getwd()

# Fecha de inicio de la serie y fecha origen para aritmética de índices
FECHA_INICIO <- as.Date("2020-03-07")
FECHA_ORIGEN <- as.Date("2020-03-06")

# =============================================================================
# 1. Leer archivo de referencia (versión anterior)
# =============================================================================
datos_referencia <- read.csv(
  paste0(root_path, "/public/data/FALLECIDOS_Datos completos_data.csv"),
  sep = ";"
)

# Contar fallecidos por día de óbito en los datos de referencia
fechas_ref    <- as.Date(datos_referencia$Fecha.Obito, format = "%d/%m/%Y")
conteo_ref    <- table(cut(fechas_ref, breaks = "day"))
max_date_ref  <- as.Date(max(fechas_ref))
n_dias_ref    <- as.numeric(max_date_ref) - as.numeric(FECHA_INICIO)  # Exclusivo

# Construir vector de fallecidos diarios de referencia
fallecidos_ref <- rep(0, n_dias_ref)
for (i in seq(1, n_dias_ref)) {
  fecha_i <- as.character(as.Date(as.numeric(FECHA_ORIGEN) + i, origin = "1970-01-01"))
  valor   <- conteo_ref[fecha_i]
  fallecidos_ref[i] <- ifelse(is.na(valor), 0, as.integer(valor))
}

# =============================================================================
# 2. Leer archivo recién descargado (raw data del MSPBS)
# =============================================================================
datos_descargados <- read.csv(
  paste0(root_path, "/public/rawData/FALLECIDOS_Datos completos_data.csv"),
  sep = ";"
)

# Contar fallecidos por día de óbito en los datos nuevos
fechas_descargados <- as.Date(datos_descargados$Fecha.Obito, format = "%d/%m/%Y")
conteo_descargados <- table(cut(fechas_descargados, breaks = "day"))
max_date_nuevo     <- as.Date(max(fechas_descargados))
n_dias_nuevo       <- as.numeric(max_date_nuevo) - as.numeric(FECHA_INICIO) + 1  # Inclusivo

# Construir vector de fallecidos diarios de los datos nuevos
fallecidos_nuevo <- rep(0, n_dias_nuevo)
for (i in seq(1, n_dias_nuevo)) {
  fecha_i <- as.character(as.Date(as.numeric(FECHA_ORIGEN) + i, origin = "1970-01-01"))
  valor   <- conteo_descargados[fecha_i]
  fallecidos_nuevo[i] <- ifelse(is.na(valor), 0, as.integer(valor))
}

# =============================================================================
# 3. Detectar modificaciones retrospectivas
# =============================================================================
# El MSPBS puede corregir datos de fallecidos de fechas anteriores.
# Detectamos si el dato nuevo difiere del dato de referencia para algún día.
diferencias <- rep(0, n_dias_nuevo)
n_comparar  <- min(n_dias_ref, n_dias_nuevo)
diferencias[seq(1, n_comparar)] <- fallecidos_nuevo[seq(1, n_comparar)] - fallecidos_ref[seq(1, n_comparar)]

indices_modificados <- which(diferencias > 0)

if (length(indices_modificados) == 0) {
  print("No hay modificación de datos retrospectivo en FALLECIDOS...")
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
fechas_salida <- as.Date(
  seq(as.numeric(FECHA_INICIO), as.numeric(max_date_nuevo)),
  origin = "1970-01-01"
)

lista_salida <- list(
  Fecha            = fechas_salida,
  Fallecido_diario = fallecidos_nuevo
)

write.csv(
  lista_salida,
  file = paste0(root_path, "/public/data/Fallecidos_diarios_revisado.csv")
)

print(paste("Serie de fallecidos generada:", length(fallecidos_nuevo), "dias hasta", max_date_nuevo))
