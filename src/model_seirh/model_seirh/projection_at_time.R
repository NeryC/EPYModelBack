library("dplyr")
library("tictoc")
library("deSolve")
library("roll")

# bitacora <- modules::use("./bitacora_evolucion_projection.R")
# bitacora$importar_datos_desde_penultima_linea()
print(as.Date(as.numeric(as.Date("2020-03-06")) + n_shift, origin = "1970-01-01"))
# bitacora$importar_datos_desde_linea_n(n_shift)


data <- read.csv("../data/REGISTRO DIARIO_Datos completos_data.csv", sep = ";", fileEncoding = "UTF-8-BOM")
data[is.na(data)] <- 0
N <- n_poblacion
data_reportados <- read.csv("../data/confirmado_diarios_revisado.csv", sep = ",")
data_conf <- data_reportados$Confirmado_diario

factor_subregistro <- data$Cantidad.Pruebas^(-0.914773) * exp(9.00991)
index <- which(is.infinite(factor_subregistro))
factor_subregistro[index] <- 1
for (i in index) {
  factor_subregistro[i] <- 0.5 * (factor_subregistro[i - 1] + factor_subregistro[i + 1])
}
data_conf_sub <- data$Confirmados.Total * factor_subregistro
av_data_conf <- roll_mean(data_conf, width = 14)
# plot(data_conf)
# lines(av_data_conf)

data_hosp <- data$Internados.Generales
data_uci <- data$Internados.UTI
data_fallecido <- read.csv("../data/Fallecidos_diarios_revisado.csv", sep = ",")
data_dead <- data_fallecido$Fallecido_diario
data_import <- data$Confirmados.en.albergues
date_init <- min(as.Date(data$Fecha, "%d/%m/%Y")) - 1
date_max <- max(as.Date(data$Fecha, "%d/%m/%Y"))
data_cumdead <- cumsum(data_dead)
data_cumconf <- cumsum(data_conf)

dirFile <- "res14/"

s <- as.numeric(bitacora$obtener_datos()["S"])
e <- as.numeric(bitacora$obtener_datos()["E"])
i <- as.numeric(bitacora$obtener_datos()["I"])
r <- as.numeric(bitacora$obtener_datos()["R"])
h <- as.numeric(bitacora$obtener_datos()["H"])
u <- as.numeric(bitacora$obtener_datos()["U"])
f <- as.numeric(bitacora$obtener_datos()["F"])

y0 <- c(S = s, E = e, I = i, R = r, H = h, U = u, F = f)

# print(bitacora$obtener_datos())

# define parameters
winsize <- 14
t <- seq(1, winsize, by = 1)
t0 <- 0
odeparam <- c(
  N = N, alpha = 1.0 / 3.0, gamma = 1.0 / 7.0,
  deltahu = 1.0 / 7.0, deltahf = 1.0 / 9.0, deltaho = 1.0 / 11.0,
  phiuf = 1.0 / 11.0, phiuo = 1.0 / 12.0
)

n_days <- 7
width <- 7
proy_days <- 45
time <- seq(0, proy_days)

beta_opt <- as.numeric(bitacora$obtener_datos()["beta"])
lamih_opt <- as.numeric(bitacora$obtener_datos()["lamih"])
lamif_opt <- as.numeric(bitacora$obtener_datos()["lamif"])
lamhu_opt <- as.numeric(bitacora$obtener_datos()["lamhu"])
lamhf_opt <- as.numeric(bitacora$obtener_datos()["lamhf"])
lamuf_opt <- as.numeric(bitacora$obtener_datos()["lamuf"])

odefun_beta_eq <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    beta_int <- N / S * gamma
    dS <- -beta_int * S * I / N
    dE <- beta_int * S * I / N - alpha * E
    dI <- alpha * E - gamma * I
    dR <- gamma * I
    list(c(dS, dE, dI, dR))
  }) # end with(as.list ...
}

odefun_parms <- c(odeparam, winsize = proy_days)
out_eq <- ode(
  y = y0[1:4], times = seq(0, proy_days), func = odefun_beta_eq,
  parms = odefun_parms
)


odefun_proy <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    index <- ceiling(t)
    if (index == 0) {
      index <- 1
    }
    if (index == winsize + 1) {
      beta_int <- get(paste("beta", winsize + 1, sep = ""))
      lamih_int <- get(paste("lamih", winsize + 1, sep = ""))
      lamif_int <- get(paste("lamif", winsize + 1, sep = ""))
      lamhu_int <- get(paste("lamhu", winsize + 1, sep = ""))
      lamhf_int <- get(paste("lamhf", winsize + 1, sep = ""))
      lamuf_int <- get(paste("lamuf", winsize + 1, sep = ""))
    } else {
      inn <- get(paste("beta", index, sep = ""))
      inp <- get(paste("beta", index + 1, sep = ""))
      beta_int <- inn + (inp - inn) * (t - floor(t))
      inn <- get(paste("lamih", index, sep = ""))
      inp <- get(paste("lamih", index + 1, sep = ""))
      lamih_int <- inn + (inp - inn) * (t - floor(t))
      inn <- get(paste("lamif", index, sep = ""))
      inp <- get(paste("lamif", index + 1, sep = ""))
      lamif_int <- inn + (inp - inn) * (t - floor(t))
      inn <- get(paste("lamhu", index, sep = ""))
      inp <- get(paste("lamhu", index + 1, sep = ""))
      lamhu_int <- inn + (inp - inn) * (t - floor(t))
      inn <- get(paste("lamhf", index, sep = ""))
      inp <- get(paste("lamhf", index + 1, sep = ""))
      lamhf_int <- inn + (inp - inn) * (t - floor(t))
      inn <- get(paste("lamuf", index, sep = ""))
      inp <- get(paste("lamuf", index + 1, sep = ""))
      lamuf_int <- inn + (inp - inn) * (t - floor(t))
    }
    lamho <- (1 - lamhu_int - lamhf_int)
    lamuo <- (1 - lamuf_int)
    dS <- -beta_int * S * I / N
    dE <- beta_int * S * I / N - alpha * E
    dI <- alpha * E - gamma * I
    dR <- gamma * I
    dH <- lamih_int * gamma * I - lamhu_int * deltahu * H - lamhf_int * deltahf * H - lamho * deltaho * H
    dU <- lamhu_int * deltahu * H - lamuf_int * phiuf * U - lamuo * phiuo * U
    dF <- lamif_int * gamma * I + lamuf_int * phiuf * U + lamhf_int * deltahf * H
    list(c(dS, dE, dI, dR, dH, dU, dF))
  }) # end with(as.list ...
}

simSEIRHUF <- paste("res14/", "sim_SEIRHUF.csv", sep = "")
sim <- read.csv(simSEIRHUF)

ntime <- length(sim$beta)
t_cont <- as.numeric(bitacora$obtener_datos()["ndate"])
print(paste("Realizando proyeccion del dia", t_cont, "->", bitacora$obtener_datos()["date"]))
beta_history <- sim$beta[1:as.numeric(bitacora$obtener_datos()["ndate"])]
lamih_history <- sim$lamih[1:as.numeric(bitacora$obtener_datos()["ndate"])]
lamif_history <- sim$lamif[1:as.numeric(bitacora$obtener_datos()["ndate"])]
lamhu_history <- sim$lamhu[1:as.numeric(bitacora$obtener_datos()["ndate"])]
lamhf_history <- sim$lamhf[1:as.numeric(bitacora$obtener_datos()["ndate"])]
lamuf_history <- sim$lamuf[1:as.numeric(bitacora$obtener_datos()["ndate"])]
length_hist <- length(beta_history)


# lamih_1m <- mean(c(lamih_history[(length_hist-13):length_hist],rep(as.numeric(lamih_opt),winsize)))
# lamif_1m <- mean(c(lamif_history[(length_hist-13):length_hist],rep(as.numeric(lamif_opt),winsize)))
# lamhu_1m <- mean(c(lamhu_history[(length_hist-13):length_hist],rep(as.numeric(lamhu_opt),winsize)))
# lamhf_1m <- mean(c(lamhf_history[(length_hist-13):length_hist],rep(as.numeric(lamhf_opt),winsize)))
# lamuf_1m <- mean(c(lamuf_history[(length_hist-13):length_hist],rep(as.numeric(lamuf_opt),winsize)))
# lamhu_1m <- 0.2

factor <- c(factor_subregistro[length_hist:(length_hist + 13)], rep(factor_subregistro[length_hist + 13], 47))
# lamuf_1m <- 0.5

beta_2w <- mean(c(beta_history[(length_hist - 13):length_hist], rep(as.numeric(beta_opt), winsize)))
beta_4w <- mean(c(beta_history[(length_hist - 27):length_hist], rep(as.numeric(beta_opt), winsize)))
istart <- length_hist - min(365, length_hist - 1)
beta_temp <- beta_history[istart:length_hist]
beta_25 <- max(beta_temp[ntile(beta_temp, 4) == 1])
beta_75 <- min(beta_temp[ntile(beta_temp, 4) == 4])
beta_eq <- as.numeric(odeparam["gamma"]) * N / s

hist(beta_temp * 7, probability = TRUE, breaks = 10, main = "R for 30 days", xlab = "R")
abline(v = beta_25 * 7, col = "red")
abline(v = beta_75 * 7, col = "red")

beta_il <- as.numeric(bitacora$obtener_datos()["beta_lo"])
beta_pr <- as.numeric(beta_opt)
beta_ih <- as.numeric(bitacora$obtener_datos()["beta_hi"])
beta_hi <- beta_2w * 1.10
beta_lo <- beta_2w * 0.80

beta_2w_fun <- (beta_opt - beta_2w) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_2w
beta_4w_fun <- (beta_opt - beta_4w) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_4w
beta_25_fun <- (beta_opt - beta_25) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_25
beta_75_fun <- (beta_opt - beta_75) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_75
beta_hi_fun <- (beta_opt - beta_hi) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_hi
beta_lo_fun <- (beta_opt - beta_lo) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_lo
beta_eq_fun <- (beta_opt - beta_eq) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_eq
beta_ih_fun <- rep(beta_ih, proy_days + 1)
beta_pr_fun <- rep(beta_pr, proy_days + 1)
beta_il_fun <- rep(beta_il, proy_days + 1)

lamih_1m <- lamih_opt
lamif_1m <- lamif_opt
lamhu_1m <- lamhu_opt
lamhf_1m <- lamhf_opt
lamuf_1m <- lamuf_opt

lamih_p <- lamih_opt * 1.1
lamif_p <- lamif_opt * 1.1
lamhu_p <- lamhu_opt * 1.1
lamhf_p <- lamhf_opt * 1.1
lamuf_p <- lamuf_opt * 1.1

lamih_fun <- (lamih_opt - lamih_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamih_1m
lamif_fun <- (lamif_opt - lamif_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamif_1m
lamhu_fun <- (lamhu_opt - lamhu_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhu_1m
lamhf_fun <- (lamhf_opt - lamhf_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhf_1m
lamuf_fun <- (lamuf_opt - lamuf_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamuf_1m

lamihp_fun <- (lamih_opt - lamih_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamih_p
lamifp_fun <- (lamif_opt - lamif_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamif_p
lamhup_fun <- (lamhu_opt - lamhu_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhu_p
lamhfp_fun <- (lamhf_opt - lamhf_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhf_p
lamufp_fun <- (lamuf_opt - lamuf_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamuf_p

# save files of Reproduction number
time <- seq(0, proy_days)
idate <- as.Date(as.numeric(as.Date("2020-03-06")) + time + t_cont,
  origin = "1970-01-01"
)
Rnumber <- cbind(
  time,
  beta_2w_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_4w_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_25_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_75_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_hi_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_lo_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_eq_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_ih_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_pr_fun * 7 * out_eq[, "S"] / odeparam["N"],
  beta_il_fun * 7 * out_eq[, "S"] / odeparam["N"]
)
# Rnumber <- cbind(time,
#                  beta_2w_fun,
#                  beta_4w_fun,
#                  beta_25_fun,
#                  beta_75_fun,
#                  beta_hi_fun,
#                  beta_lo_fun,
#                  beta_eq_fun,
#                  beta_ih_fun,
#                  beta_pr_fun,
#                  beta_il_fun)
colnames(Rnumber) <- c(
  "time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l",
  "eq", "unc_l", "proj", "unc_h"
)
filePath <- paste(dirFile, "Rnumber_", t_cont, ".csv", sep = "")
x <- data.frame(date = idate, Rnumber)
write.table(x, file = filePath, sep = ",", row.names = FALSE)

pdf(paste(dirFile, "ReprodNumber_", t_cont, ".pdf", sep = ""))
matplot(time, beta_2w_fun * 7.0,
  type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "Reproduction Number",
  ylim = c(0, 1.5)
)
# lines(time,beta_4w_fun * 7.0, col = 3, lty = 1)
lines(time, beta_25_fun * 7.0, col = 4, lty = 1)
lines(time, beta_75_fun * 7.0, col = 5, lty = 1)
lines(time, beta_hi_fun * 7.0, col = 6, lty = 1)
lines(time, beta_lo_fun * 7.0, col = 7, lty = 1)
lines(time, beta_eq_fun * 7.0, col = 8, lty = 1)
points(time, rep(beta_il, proy_days + 1) * 7.0, col = 9, lty = 1, pch = 0)
points(time, rep(beta_ih, proy_days + 1) * 7.0, col = 9, lty = 1, pch = 1)
legend("bottomleft",
  col = c(2, 4, 5, 6, 7, 8, 9, 9, 9),
  lty = c(1, 1, 1, 1, 1, 1, 1, -1, -1),
  pch = c(-1, -1, -1, -1, -1, -1, -1, 0, 1),
  legend = c(
    "mean of last month", "percentil 25",
    "percentil 75", "10% higher of mean of last month",
    "20% lower of mean of last month", "equilibrium", "projection",
    "lower uncertainty", "upper uncertainty"
  )
)
dev.off()


odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_2w_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_2w <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)
odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_4w_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_4w <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)
odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_25_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_25 <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)

odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_75_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
roi <- beta_75 * 7 * s / as.numeric(odeparam["N"])
if (roi > 1.05) {
  odefun_parms <- c(odeparam,
    winsize = proy_days, beta = beta_75_fun,
    lamih = lamihp_fun, lamif = lamifp_fun,
    lamhu = lamhup_fun, lamhf = lamhfp_fun,
    lamuf = lamufp_fun
  )
}
out_75 <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)

odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_hi_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
roi <- beta_hi * 7 * s / as.numeric(odeparam["N"])
if (roi > 1.05) {
  odefun_parms <- c(odeparam,
    winsize = proy_days, beta = beta_hi_fun,
    lamih = lamihp_fun, lamif = lamifp_fun,
    lamhu = lamhup_fun, lamhf = lamhfp_fun,
    lamuf = lamufp_fun
  )
}
out_hi <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)
odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_lo_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_lo <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)
odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_eq_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_eq <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)
odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_il_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_il <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)
odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_pr_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_pr <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)
odefun_parms <- c(odeparam,
  winsize = proy_days, beta = beta_ih_fun,
  lamih = lamih_fun, lamif = lamif_fun,
  lamhu = lamhu_fun, lamhf = lamhf_fun,
  lamuf = lamuf_fun
)
out_ih <- ode(
  y = y0, times = seq(0, proy_days), func = odefun_proy,
  parms = odefun_parms
)

# save files of projection of R
time <- seq(0, proy_days)
nproy_darys_factor <- proy_days + 1
idate <- as.Date(as.numeric(as.Date("2020-03-06")) + time + t_cont,
  origin = "1970-01-01"
)
dailyR0 <- as.numeric(bitacora$obtener_datos()["dailyR"])
proyR <- cbind(
  time, c(dailyR0 / factor[1], diff(out_2w[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_4w[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_25[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_75[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_hi[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_lo[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_eq[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_il[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_pr[, "R"]) / factor[2:nproy_darys_factor]),
  c(dailyR0 / factor[1], diff(out_ih[, "R"]) / factor[2:nproy_darys_factor])
)
colnames(proyR) <- c(
  "time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l",
  "eq", "unc_l", "proj", "unc_h"
)
filePath <- paste(dirFile, "proyR_", t_cont, ".csv", sep = "")
x <- data.frame(date = idate, proyR)
write.table(x, file = filePath, sep = ",", row.names = FALSE)

pdf(paste(dirFile, "plot_proyR_", t_cont, ".pdf", sep = ""))
matplot(proyR[, "time"], proyR[, "m2w"],
  type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of daily reported",
  ylim = c(min(proyR[, 2:11]), max(proyR[, 2:11]))
)
# lines(proyR[,"time"],proyR[,"m4w"], col = 3, lty = 1)
lines(proyR[, "time"], proyR[, "q25"], col = 4, lty = 1)
lines(proyR[, "time"], proyR[, "q75"], col = 5, lty = 1)
lines(proyR[, "time"], proyR[, "10p_h"], col = 6, lty = 1)
lines(proyR[, "time"], proyR[, "20p_l"], col = 7, lty = 1)
lines(proyR[, "time"], proyR[, "eq"], col = 8, lty = 1)
lines(proyR[, "time"], proyR[, "proj"], col = 9, lty = 1)
points(proyR[, "time"], data_reportados$Confirmado_diario[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("topleft",
  col = c(2, 4, 5, 6, 7, 8, 9),
  lty = c(1, 1, 1, 1, 1, 1, 1),
  pch = c(-1, -1, -1, -1, -1, -1, 1),
  legend = c(
    "mean of last month", "percentil 25",
    "percentil 75", "10% higher of mean of last month",
    "20% lower of mean of last month", "equilibrium", "projection"
  )
)
dev.off()

# save files of projection of F
time <- seq(0, proy_days)
idate <- as.Date(as.numeric(as.Date("2020-03-06")) + time + t_cont,
  origin = "1970-01-01"
)
dailyF0 <- as.numeric(bitacora$obtener_datos()["dailyF"])
proyF <- cbind(
  time, c(dailyF0, diff(out_2w[, "F"])),
  c(dailyF0, diff(out_4w[, "F"])),
  c(dailyF0, diff(out_25[, "F"])),
  c(dailyF0, diff(out_75[, "F"])),
  c(dailyF0, diff(out_hi[, "F"])),
  c(dailyF0, diff(out_lo[, "F"])),
  c(dailyF0, diff(out_eq[, "F"])),
  c(dailyF0, diff(out_il[, "F"])),
  c(dailyF0, diff(out_pr[, "F"])),
  c(dailyF0, diff(out_ih[, "F"]))
)
colnames(proyF) <- c(
  "time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l",
  "eq", "unc_l", "proj", "unc_h"
)
filePath <- paste(dirFile, "proyF_", t_cont, ".csv", sep = "")
x <- data.frame(date = idate, proyF)
write.table(x, file = filePath, sep = ",", row.names = FALSE)

pdf(paste(dirFile, "plot_proyF_", t_cont, ".pdf", sep = ""))
matplot(proyF[, "time"], proyF[, "m2w"],
  type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of daily death",
  ylim = c(min(proyF[, 2:11]), max(proyF[, 2:11]))
)
lines(proyF[, "time"], proyF[, "m4w"], col = 3, lty = 1)
lines(proyF[, "time"], proyF[, "q25"], col = 4, lty = 1)
lines(proyF[, "time"], proyF[, "q75"], col = 5, lty = 1)
lines(proyF[, "time"], proyF[, "10p_h"], col = 6, lty = 1)
lines(proyF[, "time"], proyF[, "20p_l"], col = 7, lty = 1)
lines(proyF[, "time"], proyF[, "eq"], col = 8, lty = 1)
lines(proyF[, "time"], proyF[, "proj"], col = 9, lty = 1)
points(proyF[, "time"], data_fallecido$Fallecido_diario[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("topleft",
  col = c(2, 3, 4, 5, 6, 7, 8, 9),
  lty = c(1, 1, 1, 1, 1, 1, 1, -1),
  pch = c(-1, -1, -1, -1, -1, -1, -1, 1),
  legend = c(
    "mean of 2 weeks", "mean of 4 weeks", "quantil 25%",
    "quantil 75%", "10% higher of mean of 2 weeks",
    "20% lower of mean of 2 weeks", "equilibrium", "projection"
  )
)
dev.off()

# save files of projection of H
time <- seq(0, proy_days)
idate <- as.Date(as.numeric(as.Date("2020-03-06")) + time + t_cont,
  origin = "1970-01-01"
)
proyH <- cbind(
  time, out_2w[, "H"], out_4w[, "H"], out_25[, "H"], out_75[, "H"],
  out_hi[, "H"], out_lo[, "H"], out_eq[, "H"], out_il[, "H"],
  out_pr[, "H"], out_ih[, "H"]
)
colnames(proyH) <- c(
  "time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l",
  "eq", "unc_l", "proj", "unc_h"
)
filePath <- paste(dirFile, "proyH_", t_cont, ".csv", sep = "")
x <- data.frame(date = idate, proyH)
write.table(x, file = filePath, sep = ",", row.names = FALSE)

pdf(paste(dirFile, "plot_proyH_", t_cont, ".pdf", sep = ""))
matplot(proyH[, "time"], proyH[, "m2w"],
  type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of hospitalization",
  ylim = c(min(proyH[, 2:11]), max(proyH[, 2:11])),
)
lines(proyH[, "time"], proyH[, "m4w"], col = 3, lty = 1)
lines(proyH[, "time"], proyH[, "q25"], col = 4, lty = 1)
lines(proyH[, "time"], proyH[, "q75"], col = 5, lty = 1)
lines(proyH[, "time"], proyH[, "10p_h"], col = 6, lty = 1)
lines(proyH[, "time"], proyH[, "20p_l"], col = 7, lty = 1)
lines(proyH[, "time"], proyH[, "eq"], col = 8, lty = 1)
lines(proyH[, "time"], proyH[, "proj"], col = 9, lty = 1)
points(proyH[, "time"], data$Internados.Generales[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("topleft",
  col = c(2, 3, 4, 5, 6, 7, 8, 9),
  lty = c(1, 1, 1, 1, 1, 1, 1, -1),
  pch = c(-1, -1, -1, -1, -1, -1, -1, 1),
  legend = c(
    "mean of 2 weeks", "mean of 4 weeks", "quantil 25%",
    "quantil 75%", "10% higher of mean of 2 weeks",
    "20% lower of mean of 2 weeks", "equilibrium", "projection"
  )
)
dev.off()

# save files of projection of U
proyU <- cbind(
  time, out_2w[, "U"], out_4w[, "U"], out_25[, "U"], out_75[, "U"],
  out_hi[, "U"], out_lo[, "U"], out_eq[, "U"], out_il[, "U"],
  out_pr[, "U"], out_ih[, "U"]
)
colnames(proyU) <- c(
  "time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l",
  "eq", "unc_l", "proj", "unc_h"
)
filePath <- paste(dirFile, "proyU_", t_cont, ".csv", sep = "")
x <- data.frame(date = idate, proyU)
write.table(x, file = filePath, sep = ",", row.names = FALSE)

pdf(paste(dirFile, "plot_proyU_", t_cont, ".pdf", sep = ""))
matplot(proyU[, "time"], proyU[, "m2w"],
  type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of UCI",
  ylim = c(min(proyU[, 2:11]), max(proyU[, 2:11])),
)
# lines(proyU[,"time"],proyU[,"m4w"], col = 3, lty = 1)
lines(proyU[, "time"], proyU[, "q25"], col = 4, lty = 1)
lines(proyU[, "time"], proyU[, "q75"], col = 5, lty = 1)
lines(proyU[, "time"], proyU[, "10p_h"], col = 6, lty = 1)
lines(proyU[, "time"], proyU[, "20p_l"], col = 7, lty = 1)
lines(proyU[, "time"], proyU[, "eq"], col = 8, lty = 1)
lines(proyU[, "time"], proyU[, "proj"], col = 9, lty = 1)
points(proyU[, "time"], data$Internados.UTI[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("bottomleft",
  col = c(2, 4, 5, 6, 7, 8, 9),
  lty = c(1, 1, 1, 1, 1, 1, -1),
  pch = c(-1, -1, -1, -1, -1, -1, 1),
  legend = c(
    "mean of last month", "percentil 25",
    "percentil 75", "10% higher of mean of last month",
    "20% lower of mean of last month", "equilibrium", "projection"
  )
)
dev.off()

print(paste("Finished successfully..."))
