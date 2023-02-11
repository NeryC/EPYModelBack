rm(list = ls())
library(readr)

setwd("C:/Users/albert/Documents/Projects/epimodel/model_seirh")

datos_fallecidos_raw <- read.csv("./data/FALLECIDOS_Datos completos_data.csv", fileEncoding = "UTF-8-BOM", sep = ";") # TODO Try sep=",", else sep=";"
fecha_fallecidos <- as.Date(datos_fallecidos_raw$Fecha.Obito, format = "%d/%m/%Y")
frecuencia_fecha_fallecidos <- table(cut(fecha_fallecidos, breaks = "day"))
# print(frecuencia_fecha_fallecidos)
max_date <- as.Date(max(fecha_fallecidos))
min_date <- as.Date("2020-03-07")
ndate <- as.numeric(max_date) - as.numeric(min_date)
fallecidos <- rep(0, ndate)

for (i in seq(1, ndate)) {
  fallecidos[i] <- frecuencia_fecha_fallecidos[as.character(as.Date(as.numeric(as.Date("2020-03-06")) + i, origin = "1970-01-01"))]
}
fallecidos[is.na(fallecidos)] <- 0

datos_fallecidos_raw_downloaded <- read.csv("./datx/FALLECIDOS_Datos completos_data.csv", fileEncoding = "UTF-8-BOM", sep = ";") # TODO Try sep=",", else sep=";"
fecha_fallecidos_downloaded <- as.Date(datos_fallecidos_raw_downloaded$Fecha.Obito, format = "%d/%m/%Y")
frecuencia_fecha_fallecidos_downloaded <- table(cut(fecha_fallecidos_downloaded, breaks = "day"))
max_date <- as.Date(max(fecha_fallecidos_downloaded))
min_date <- as.Date("2020-03-07")
ndate_ <- as.numeric(max_date) - as.numeric(min_date) + 1
fallecidos_downloaded <- rep(0, ndate_)

for (i in seq(1, ndate_)) {
  fallecidos_downloaded[i] <- frecuencia_fecha_fallecidos_downloaded[as.character(as.Date(as.numeric(as.Date("2020-03-06")) + i, origin = "1970-01-01"))]
}
fallecidos_downloaded[is.na(fallecidos_downloaded)] <- 0

diff_data <- rep(0, ndate_)
for (i in seq(1, ndate)) {
  diff_data[i] <- fallecidos_downloaded[i] - fallecidos[i]
}
index <- which(diff_data > 0)
if (length(index) == 0) {
  print("No hay modificación de datos retrospectivo en FALLECIDOS...")
} else {
  print(as.Date(as.numeric(as.Date("2020-03-06")) + index[1] - 15, origin = "1970-01-01"))
}

list_1 <- list(Fecha = as.Date(seq(as.numeric(min_date), as.numeric(max_date)), origin = "1970-01-01"), Fallecido_diario = fallecidos_downloaded)
write.csv(file = "./data/Fallecidos_diarios_revisado.csv", list_1)
