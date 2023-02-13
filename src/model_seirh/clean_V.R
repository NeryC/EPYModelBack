rm(list = ls())
library(readr)
library(dplyr)
setwd(dirname(getwd()))
root_path <- dirname(getwd())
webfile <- "https://covid.ourworldindata.org/data/owid-covid-data.csv"
covid_data <- read_csv(webfile, show_col_types = FALSE)
data_py <- covid_data[covid_data$location == "Paraguay", ]

max_date <- as.Date(max(data_py$date))
min_date <- as.Date("2020-03-07")
ndate_ <- as.numeric(max_date) - as.numeric(min_date) + 1
inmunizados <- rep(0, ndate_)
booster <- rep(0, ndate_)

for (i in seq(1, ndate_)) {
  inmunizados[i] <-
    data_py$people_fully_vaccinated[
      as.Date(
        as.numeric(
          as.Date("2020-03-06")
        )
        + i,
        origin = "1970-01-01"
      ) == data_py$date
    ]
  booster[i] <-
    data_py$total_boosters[
      as.Date(
        as.numeric(
          as.Date("2020-03-06")
        )
        + i,
        origin = "1970-01-01"
      ) == data_py$date
    ]
}
inmunizados[1] <- 0
booster[1] <- 0
for (i in seq(2, ndate_)) {
  if (is.na(inmunizados[i])) {
    inmunizados[i] <- inmunizados[i - 1]
  }
  if (is.na(booster[i])) {
    booster[i] <- booster[i - 1]
  }
}

inmunizados[2:ndate_] <- diff(inmunizados)
booster[2:ndate_] <- diff(booster)

list_1 <-
  list(
    Fecha = as.Date(
      seq(
        as.numeric(min_date),
        as.numeric(max_date)
      ),
      origin = "1970-01-01"
    ),
    Inmunizado_diario = inmunizados,
    Booster_diario = booster
  )

write.csv(
  file = paste(root_path, "/public/data/Inmunizado_diarios.csv", sep = ""),
  list_1, row.names = FALSE
)
