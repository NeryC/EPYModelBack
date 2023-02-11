rm(list = ls())
library(readr)

setwd("C:/Users/albert/Documents/Projects/epimodel/model_seirh")

datos_raw <- read.csv("./data/Descargar datos_Datos completos_data.csv", fileEncoding = "UTF-8-BOM", sep = ";") # TODO Try sep=",", else sep=";"
fecha_confirmacion <- as.Date(datos_raw$Fecha.Confirmacion, format = "%d/%m/%Y")
frecuencia_fecha_confirmacion <- table(cut(fecha_confirmacion, breaks = "day"))
# print(frecuencia_fecha_fallecidos)
max_date <- as.Date(max(fecha_confirmacion))
min_date <- as.Date("2020-03-07")
ndate <- as.numeric(max_date) - as.numeric(min_date)
confirmado <- rep(0, ndate)

for (i in seq(1, ndate)) {
  confirmado[i] <- frecuencia_fecha_confirmacion[as.character(as.Date(as.numeric(as.Date("2020-03-06")) + i, origin = "1970-01-01"))]
}
confirmado[is.na(confirmado)] <- 0

datos_raw_downloaded <- read.csv("./datx/Descargar datos_Datos completos_data.csv", fileEncoding = "UTF-8-BOM", sep = ";") # TODO Try sep=",", else sep=";"
fecha_confirmado_downloaded <- as.Date(datos_raw_downloaded$Fecha.Confirmacion, format = "%d/%m/%Y")
frecuencia_fecha_confirmado_downloaded <- table(cut(fecha_confirmado_downloaded, breaks = "day"))
max_date <- as.Date(max(fecha_confirmado_downloaded))
min_date <- as.Date("2020-03-07")
ndate_ <- as.numeric(max_date) - as.numeric(min_date) + 1
confirmado_downloaded <- rep(0, ndate_)

for (i in seq(1, ndate_)) {
  confirmado_downloaded[i] <- frecuencia_fecha_confirmado_downloaded[as.character(as.Date(as.numeric(as.Date("2020-03-06")) + i, origin = "1970-01-01"))]
}
confirmado_downloaded[is.na(confirmado_downloaded)] <- 0

diff_data <- rep(0, ndate_)
for (i in seq(1, ndate)) {
  diff_data[i] <- confirmado_downloaded[i] - confirmado[i]
}
index <- which(diff_data > 0)
# print(diff_data)
# print(index)
if (length(index) == 0) {
  print("No hay modificación de datos retrospectivo en DATOS COMPLETOS...")
} else {
  print(as.Date(as.numeric(as.Date("2020-03-06")) + index[1] - 15, origin = "1970-01-01"))
}


list_1 <- list(Fecha = as.Date(seq(as.numeric(min_date), as.numeric(max_date)), origin = "1970-01-01"), Confirmado_diario = confirmado_downloaded)
write.csv(file = "./data/confirmado_diarios_revisado.csv", list_1)
