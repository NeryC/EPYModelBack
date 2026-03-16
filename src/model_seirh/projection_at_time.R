# =============================================================================
# projection_at_time.R
# =============================================================================
# Genera proyecciones epidemiológicas a 45 días desde el último día inferido.
#
# Contexto de ejecución
# ----------------------
# Este script se ejecuta al final de test_seirhuf_normal.R (via source()),
# cuando la variable `n_shift` ya está definida en el ambiente padre.
# `n_shift` indica el día desde el cual se proyecta hacia el futuro.
#
# Lógica general
# ---------------
# 1. Carga el estado actual del sistema (S,E,I,R,H,U,F) y los parámetros
#    estimados (beta, lambdas) desde la bitácora.
# 2. Lee el historial completo de beta de la bitácora (sim_SEIRHUF.csv)
#    para construir escenarios de beta futura.
# 3. Define 10 escenarios de evolución futura de beta:
#      m2w   : media de las últimas 2 semanas
#      m4w   : media de las últimas 4 semanas
#      q25   : percentil 25 del último año de beta
#      q75   : percentil 75 del último año de beta
#      10p_h : 10% por encima de la media de 2 semanas
#      20p_l : 20% por debajo de la media de 2 semanas
#      eq    : beta de equilibrio (R_eff = 1)
#      unc_l : incertidumbre inferior (IC 2.5% de Stan)
#      proj  : proyección puntual (beta MAP actual)
#      unc_h : incertidumbre superior (IC 97.5% de Stan)
# 4. Para cada escenario de beta, resuelve el ODE SEIRHUF a 45 días.
#    Las transiciones entre el valor actual de beta y el valor del escenario
#    se suavizan con una función logística para evitar discontinuidades.
# 5. Escribe los resultados en CSV (para el frontend) y PDF (para diagnóstico).
#
# Variables heredadas del ambiente padre (test_seirhuf_normal.R)
# ---------------------------------------------------------------
#   n_shift     : índice del día actual (tiempo de inicio de la proyección)
#   n_poblacion : población total N
#   bitacora    : módulo de bitácora con el estado actual
#   parametros  : módulo de parámetros
#
# Archivos de salida (en public/data/)
# -------------------------------------
#   Rnumber.csv  : número reproductivo proyectado (10 escenarios)
#   proyR.csv    : casos reportados proyectados (10 escenarios, ajustados por subregistro)
#   proyF.csv    : fallecidos proyectados (10 escenarios)
#   proyH.csv    : hospitalizados proyectados (10 escenarios)
#   proyU.csv    : UCI proyectados (10 escenarios)
#
# PDFs de diagnóstico (en src/model_seirh/res14/)
#   ReprodNumber.pdf : evolución del número reproductivo
#   plot_proyR.pdf   : proyección de casos reportados
#   plot_proyF.pdf   : proyección de fallecidos
#   plot_proyH.pdf   : proyección de hospitalizados
#   plot_proyU.pdf   : proyección de UCI
# =============================================================================

library("dplyr")
library("tictoc")
library("deSolve")
library("roll")

print(as.Date(as.numeric(as.Date("2020-03-06")) + n_shift, origin = "1970-01-01"))

root_path  <- paste(getwd(), "/src/model_seirh/", sep = "")
parametros <- modules::use(glue("{root_path}parametros.R"))

# Directorio de salida de PDFs
dir_file <- paste(parametros$model_seirh, "res14/", sep = "")


# =============================================================================
# 1. Cargar datos de entrada
# =============================================================================

# Registro diario MSPBS (hospitalizados, UCI, pruebas, importados)
data <- read.csv(parametros$filepaths$datos_diarios, sep = ";")
data[is.na(data)] <- 0

N <- n_poblacion  # Población total (heredada del ambiente padre)

# Confirmados diarios (sin subregistro, para graficar puntos observados)
data_reportados <- read.csv(parametros$filepaths$datos_confirmados, sep = ",")
data_conf       <- data_reportados$Confirmado_diario

# Factor de subregistro: ajusta las proyecciones de R al número de reportados reales
# (los proyectados se dividen por el factor para comparar con datos oficiales)
factor_subregistro        <- data$Cantidad.Pruebas^(-0.914773) * exp(9.00991)
indices_inf               <- which(is.infinite(factor_subregistro))
factor_subregistro[indices_inf] <- 1
for (i in indices_inf) {
  factor_subregistro[i] <- 0.5 * (factor_subregistro[i - 1] + factor_subregistro[i + 1])
}

# Series de datos observados para superposición en gráficos
data_hosp     <- data$Internados.Generales
data_uci      <- data$Internados.UTI
data_fallecido <- read.csv(parametros$filepaths$datos_fallecidos, sep = ",")
data_dead     <- data_fallecido$Fallecido_diario
data_import   <- data$Confirmados.en.albergues
data_cumdead  <- cumsum(data_dead)
data_cumconf  <- cumsum(data_conf)

# Media móvil de 14 días de confirmados (para referencia visual)
av_data_conf <- roll_mean(data_conf, width = 14)


# =============================================================================
# 2. Estado actual del sistema y parámetros estimados
# =============================================================================
# Leer el estado del último día de la bitácora como condición inicial de la proyección
s <- as.numeric(bitacora$obtener_datos()["S"])
e <- as.numeric(bitacora$obtener_datos()["E"])
i <- as.numeric(bitacora$obtener_datos()["I"])
r <- as.numeric(bitacora$obtener_datos()["R"])
h <- as.numeric(bitacora$obtener_datos()["H"])
u <- as.numeric(bitacora$obtener_datos()["U"])
f <- as.numeric(bitacora$obtener_datos()["F"])

# Condiciones iniciales del ODE (sin compartimento O que no se proyecta con exactitud)
y0 <- c(S = s, E = e, I = i, R = r, H = h, U = u, F = f)

# Parámetros del ODE (tasas fijas de transición)
winsize  <- 14
t_ode    <- seq(1, winsize, by = 1)
t0       <- 0
odeparam <- c(
  N       = N,
  alpha   = 1.0 / 3.0,   # E→I: período de incubación 3 días
  gamma   = 1.0 / 7.0,   # I→R: período infeccioso 7 días
  deltahu = 1.0 / 7.0,   # H→U: 7 días
  deltahf = 1.0 / 9.0,   # H→F: 9 días
  deltaho = 1.0 / 11.0,  # H→R: 11 días
  phiuf   = 1.0 / 11.0,  # U→F: 11 días
  phiuo   = 1.0 / 12.0   # U→R: 12 días
)

# Parámetros de proyección
n_days    <- 7    # Ancho de la ventana de transición logística (días)
width     <- 7    # Parámetro de escala de la curva logística
proy_days <- 45   # Horizonte de proyección en días
time      <- seq(0, proy_days)  # Vector de tiempos para la proyección

# Parámetros MAP del último día inferido
beta_opt  <- as.numeric(bitacora$obtener_datos()["beta"])
lamih_opt <- as.numeric(bitacora$obtener_datos()["lamih"])
lamif_opt <- as.numeric(bitacora$obtener_datos()["lamif"])
lamhu_opt <- as.numeric(bitacora$obtener_datos()["lamhu"])
lamhf_opt <- as.numeric(bitacora$obtener_datos()["lamhf"])
lamuf_opt <- as.numeric(bitacora$obtener_datos()["lamuf"])

t_cont <- as.numeric(bitacora$obtener_datos()["ndate"])
print(paste("Realizando proyeccion del dia", t_cont, "->", bitacora$obtener_datos()["date"]))


# =============================================================================
# 3. ODE de equilibrio (para calcular beta_eq)
# =============================================================================
# En el equilibrio (R_eff = 1): beta_eq * S/N = gamma
# → beta_eq = gamma * N / S
# Se usa para el escenario de "equilibrio" donde la pandemia se estabiliza.
odefun_beta_eq <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    beta_int <- N / S * gamma  # nolint: β que da R_eff = 1
    dS <- -beta_int * S * I / N  # nolint
    dE <-  beta_int * S * I / N - alpha * E  # nolint
    dI <-  alpha * E - gamma * I  # nolint
    dR <-  gamma * I  # nolint
    list(c(dS, dE, dI, dR))
  })
}

# Resolver ODE de equilibrio para obtener la evolución de S bajo beta_eq
# (necesaria para calcular el número reproductivo proyectado)
odefun_parms_eq <- c(odeparam, winsize = proy_days)
out_eq <- ode(y = y0[1:4], times = time, func = odefun_beta_eq, parms = odefun_parms_eq)


# =============================================================================
# 4. ODE de proyección SEIRH con parámetros dinámicos
# =============================================================================
# Los parámetros beta y lambdas varían día a día durante la proyección.
# Se pasan como vectores beta1, beta2, ..., betaN (uno por día), y se
# interpolan linealmente dentro de cada paso de integración para suavidad.
odefun_proy <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    index <- ceiling(t)
    if (index == 0)            index <- 1
    if (index == winsize + 1) {
      # Último intervalo: usar directamente el valor final
      beta_int  <- get(paste("beta",  winsize + 1, sep = ""))
      lamih_int <- get(paste("lamih", winsize + 1, sep = ""))
      lamif_int <- get(paste("lamif", winsize + 1, sep = ""))
      lamhu_int <- get(paste("lamhu", winsize + 1, sep = ""))
      lamhf_int <- get(paste("lamhf", winsize + 1, sep = ""))
      lamuf_int <- get(paste("lamuf", winsize + 1, sep = ""))
    } else {
      # Interpolación lineal entre el valor del día `index` y `index+1`
      frac <- t - floor(t)  # Fracción del día (0 a 1)
      beta_int  <- get(paste("beta",  index, sep = "")) + (get(paste("beta",  index + 1, sep = "")) - get(paste("beta",  index, sep = ""))) * frac
      lamih_int <- get(paste("lamih", index, sep = "")) + (get(paste("lamih", index + 1, sep = "")) - get(paste("lamih", index, sep = ""))) * frac
      lamif_int <- get(paste("lamif", index, sep = "")) + (get(paste("lamif", index + 1, sep = "")) - get(paste("lamif", index, sep = ""))) * frac
      lamhu_int <- get(paste("lamhu", index, sep = "")) + (get(paste("lamhu", index + 1, sep = "")) - get(paste("lamhu", index, sep = ""))) * frac
      lamhf_int <- get(paste("lamhf", index, sep = "")) + (get(paste("lamhf", index + 1, sep = "")) - get(paste("lamhf", index, sep = ""))) * frac
      lamuf_int <- get(paste("lamuf", index, sep = "")) + (get(paste("lamuf", index + 1, sep = "")) - get(paste("lamuf", index, sep = ""))) * frac
    }

    # Fracciones complementarias que suman a 1
    lamho <- (1 - lamhu_int - lamhf_int)  # H → recuperados
    lamuo <- (1 - lamuf_int)              # U → recuperados

    # Sistema de ecuaciones SEIRHUF (sin importados/vacunados en proyección)
    dS <- -beta_int * S * I / N  # nolint
    dE <-  beta_int * S * I / N - alpha * E  # nolint
    dI <-  alpha * E - gamma * I  # nolint
    dR <-  gamma * I  # nolint
    dH <-  lamih_int * gamma * I - lamhu_int * deltahu * H - lamhf_int * deltahf * H - lamho * deltaho * H  # nolint
    dU <-  lamhu_int * deltahu * H - lamuf_int * phiuf * U - lamuo * phiuo * U  # nolint
    dF <-  lamif_int * gamma * I + lamuf_int * phiuf * U + lamhf_int * deltahf * H  # nolint
    list(c(dS, dE, dI, dR, dH, dU, dF))
  })
}


# =============================================================================
# 5. Historial de parámetros y construcción de escenarios de beta
# =============================================================================
# Leer toda la bitácora para obtener el historial de beta estimado día a día
sim <- read.csv(paste(parametros$data_path, "sim_SEIRHUF.csv", sep = ""))

beta_history  <- sim$beta [1:t_cont]
lamih_history <- sim$lamih[1:t_cont]
lamif_history <- sim$lamif[1:t_cont]
lamhu_history <- sim$lamhu[1:t_cont]
lamhf_history <- sim$lamhf[1:t_cont]
lamuf_history <- sim$lamuf[1:t_cont]
length_hist   <- length(beta_history)

# Factor de subregistro para los próximos 60 días
# (14 días observados + 47 días replicando el último valor conocido)
factor <- c(
  factor_subregistro[length_hist:(length_hist + 13)],
  rep(factor_subregistro[length_hist + 13], 47)
)

# --- Calcular estadísticos históricos de beta ---
# Media de las últimas 2 semanas (incluyendo la ventana actual de 14 días)
beta_2w <- mean(c(beta_history[(length_hist - 13):length_hist], rep(beta_opt, winsize)))
# Media de las últimas 4 semanas
beta_4w <- mean(c(beta_history[(length_hist - 27):length_hist], rep(beta_opt, winsize)))
# Percentil 25 y 75 del último año (o desde el inicio si hay menos de 365 días)
istart    <- length_hist - min(365, length_hist - 1)
beta_temp <- beta_history[istart:length_hist]
beta_25   <- max(beta_temp[dplyr::ntile(beta_temp, 4) == 1])  # Q1
beta_75   <- min(beta_temp[dplyr::ntile(beta_temp, 4) == 4])  # Q3
# Beta de equilibrio: R_eff = 1 → beta = gamma * N / S
beta_eq   <- as.numeric(odeparam["gamma"]) * N / s
# Bandas de incertidumbre (IC del modelo Stan)
beta_il   <- as.numeric(bitacora$obtener_datos()["beta_lo"])  # IC 2.5%
beta_pr   <- as.numeric(beta_opt)
beta_ih   <- as.numeric(bitacora$obtener_datos()["beta_hi"])  # IC 97.5%
# Escenarios alto/bajo respecto a la media de 2 semanas
beta_hi   <- beta_2w * 1.10  # 10% por encima
beta_lo   <- beta_2w * 0.80  # 20% por debajo

# Histograma de R histórico (diagnóstico visual)
hist(beta_temp * 7, probability = TRUE, breaks = 10, main = "R for 30 days", xlab = "R")
abline(v = beta_25 * 7, col = "red")
abline(v = beta_75 * 7, col = "red")


# =============================================================================
# 6. Funciones de transición logística para beta
# =============================================================================
# Cada escenario tiene una función de beta que transiciona suavemente desde el
# valor actual (beta_opt) hacia el valor del escenario usando una logística:
#   beta_fun(t) = (beta_opt - beta_target) / (1 + exp(6*(t-winsize)/width - n_days/2)) + beta_target
# Esto evita discontinuidades en el ODE que causarían artefactos numéricos.

beta_2w_fun <- (beta_opt - beta_2w) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_2w
beta_4w_fun <- (beta_opt - beta_4w) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_4w
beta_25_fun <- (beta_opt - beta_25) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_25
beta_75_fun <- (beta_opt - beta_75) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_75
beta_hi_fun <- (beta_opt - beta_hi) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_hi
beta_lo_fun <- (beta_opt - beta_lo) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_lo
beta_eq_fun <- (beta_opt - beta_eq) / (1 + exp(6 * (time - winsize) / width - n_days / 2)) + beta_eq
beta_ih_fun <- rep(beta_ih, proy_days + 1)  # Constante en el IC superior
beta_pr_fun <- rep(beta_pr, proy_days + 1)  # Constante en la proyección puntual
beta_il_fun <- rep(beta_il, proy_days + 1)  # Constante en el IC inferior


# =============================================================================
# 7. Funciones de transición logística para lambdas
# =============================================================================
# Las lambdas también transicionan suavemente desde el valor actual hacia el
# valor del escenario (aquí se mantienen constantes = lamX_opt, salvo en el
# escenario de beta_75 con R>1.05 donde se incrementan 10% para reflejar
# mayor presión sobre el sistema hospitalario).

lamih_1m <- lamih_opt;  lamif_1m <- lamif_opt
lamhu_1m <- lamhu_opt;  lamhf_1m <- lamhf_opt
lamuf_1m <- lamuf_opt

# Versión "presionada" (+10%) para escenarios con R_eff > 1.05
lamih_p <- lamih_opt * 1.1;  lamif_p <- lamif_opt * 1.1
lamhu_p <- lamhu_opt * 1.1;  lamhf_p <- lamhf_opt * 1.1
lamuf_p <- lamuf_opt * 1.1

# Funciones de transición para lambdas en escenario base
lamih_fun <- (lamih_opt - lamih_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamih_1m
lamif_fun <- (lamif_opt - lamif_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamif_1m
lamhu_fun <- (lamhu_opt - lamhu_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhu_1m
lamhf_fun <- (lamhf_opt - lamhf_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhf_1m
lamuf_fun <- (lamuf_opt - lamuf_1m) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamuf_1m

# Funciones de transición para lambdas en escenario "presionado"
lamihp_fun <- (lamih_opt - lamih_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamih_p
lamifp_fun <- (lamif_opt - lamif_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamif_p
lamhup_fun <- (lamhu_opt - lamhu_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhu_p
lamhfp_fun <- (lamhf_opt - lamhf_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamhf_p
lamufp_fun <- (lamuf_opt - lamuf_p) / (1 + exp(6 * (time - winsize) / n_days - n_days / 2)) + lamuf_p


# =============================================================================
# 8. CSV del número reproductivo proyectado
# =============================================================================
idate  <- as.Date(as.numeric(as.Date("2020-03-06")) + time + t_cont, origin = "1970-01-01")
Rnumber <- cbind(
  time,
  beta_2w_fun * 7 * out_eq[, "S"] / odeparam["N"],   # m2w
  beta_4w_fun * 7 * out_eq[, "S"] / odeparam["N"],   # m4w
  beta_25_fun * 7 * out_eq[, "S"] / odeparam["N"],   # q25
  beta_75_fun * 7 * out_eq[, "S"] / odeparam["N"],   # q75
  beta_hi_fun * 7 * out_eq[, "S"] / odeparam["N"],   # 10p_h
  beta_lo_fun * 7 * out_eq[, "S"] / odeparam["N"],   # 20p_l
  beta_eq_fun * 7 * out_eq[, "S"] / odeparam["N"],   # eq
  beta_ih_fun * 7 * out_eq[, "S"] / odeparam["N"],   # unc_l
  beta_pr_fun * 7 * out_eq[, "S"] / odeparam["N"],   # proj
  beta_il_fun * 7 * out_eq[, "S"] / odeparam["N"]    # unc_h
)
colnames(Rnumber) <- c("time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l", "eq", "unc_l", "proj", "unc_h")
write.table(data.frame(date = idate, Rnumber),
  file = paste(parametros$data_path, "Rnumber.csv", sep = ""), sep = ",", row.names = FALSE)

# PDF del número reproductivo
pdf(paste(dir_file, "ReprodNumber.pdf", sep = ""))
matplot(time, beta_2w_fun * 7.0, type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "Reproduction Number", ylim = c(0, 1.5))
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
  legend = c("mean of last month", "percentil 25", "percentil 75",
             "10% higher of mean of last month", "20% lower of mean of last month",
             "equilibrium", "projection", "lower uncertainty", "upper uncertainty")
)
dev.off()


# =============================================================================
# 9. Resolver ODE para cada escenario
# =============================================================================
# Helper: construye el vector de parámetros para odefun_proy y resuelve el ODE
.resolver_ode <- function(beta_fun, lam_ih, lam_if, lam_hu, lam_hf, lam_uf) {
  parms <- c(odeparam, winsize = proy_days,
    beta  = beta_fun, lamih = lam_ih, lamif = lam_if,
    lamhu = lam_hu,   lamhf = lam_hf, lamuf = lam_uf)
  ode(y = y0, times = time, func = odefun_proy, parms = parms)
}

out_2w  <- .resolver_ode(beta_2w_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)
out_4w  <- .resolver_ode(beta_4w_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)
out_25  <- .resolver_ode(beta_25_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)

# Para los escenarios con R > 1.05 se usan lambdas "presionadas"
# (más hospitalización, más UCI, más fallecidos) para reflejar mayor carga sanitaria
roi_75 <- beta_75 * 7 * s / N
if (roi_75 > 1.05) {
  out_75 <- .resolver_ode(beta_75_fun, lamihp_fun, lamifp_fun, lamhup_fun, lamhfp_fun, lamufp_fun)
} else {
  out_75 <- .resolver_ode(beta_75_fun, lamih_fun,  lamif_fun,  lamhu_fun,  lamhf_fun,  lamuf_fun)
}

roi_hi <- beta_hi * 7 * s / N
if (roi_hi > 1.05) {
  out_hi <- .resolver_ode(beta_hi_fun, lamihp_fun, lamifp_fun, lamhup_fun, lamhfp_fun, lamufp_fun)
} else {
  out_hi <- .resolver_ode(beta_hi_fun, lamih_fun,  lamif_fun,  lamhu_fun,  lamhf_fun,  lamuf_fun)
}

out_lo  <- .resolver_ode(beta_lo_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)
out_eq  <- .resolver_ode(beta_eq_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)
out_il  <- .resolver_ode(beta_il_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)
out_pr  <- .resolver_ode(beta_pr_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)
out_ih  <- .resolver_ode(beta_ih_fun, lamih_fun, lamif_fun, lamhu_fun, lamhf_fun, lamuf_fun)


# =============================================================================
# 10. Exportar proyecciones de casos reportados (R)
# =============================================================================
# Los casos diarios proyectados se dividen por el factor de subregistro para
# comparar con los datos oficiales del MSPBS (que también tienen subregistro).
nproy_days_factor <- proy_days + 1
dailyR0 <- as.numeric(bitacora$obtener_datos()["dailyR"])

proyR <- cbind(
  time,
  c(dailyR0 / factor[1], diff(out_2w[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_4w[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_25[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_75[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_hi[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_lo[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_eq[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_il[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_pr[, "R"]) / factor[2:nproy_days_factor]),
  c(dailyR0 / factor[1], diff(out_ih[, "R"]) / factor[2:nproy_days_factor])
)
colnames(proyR) <- c("time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l", "eq", "unc_l", "proj", "unc_h")
write.table(data.frame(date = idate, proyR),
  file = paste(parametros$data_path, "proyR.csv", sep = ""), sep = ",", row.names = FALSE)

pdf(paste(dir_file, "plot_proyR.pdf", sep = ""))
matplot(proyR[, "time"], proyR[, "m2w"], type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of daily reported",
  ylim = c(min(proyR[, 2:11]), max(proyR[, 2:11])))
lines(proyR[, "time"], proyR[, "q25"],   col = 4, lty = 1)
lines(proyR[, "time"], proyR[, "q75"],   col = 5, lty = 1)
lines(proyR[, "time"], proyR[, "10p_h"], col = 6, lty = 1)
lines(proyR[, "time"], proyR[, "20p_l"], col = 7, lty = 1)
lines(proyR[, "time"], proyR[, "eq"],    col = 8, lty = 1)
lines(proyR[, "time"], proyR[, "proj"],  col = 9, lty = 1)
points(proyR[, "time"], data_reportados$Confirmado_diario[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("topleft",
  col = c(2, 4, 5, 6, 7, 8, 9), lty = c(1, 1, 1, 1, 1, 1, 1), pch = c(-1, -1, -1, -1, -1, -1, 1),
  legend = c("mean of last month", "percentil 25", "percentil 75",
             "10% higher of mean of last month", "20% lower of mean of last month",
             "equilibrium", "projection")
)
dev.off()


# =============================================================================
# 11. Exportar proyecciones de fallecidos (F)
# =============================================================================
dailyF0 <- as.numeric(bitacora$obtener_datos()["dailyF"])

proyF <- cbind(
  time,
  c(dailyF0, diff(out_2w[, "F"])), c(dailyF0, diff(out_4w[, "F"])),
  c(dailyF0, diff(out_25[, "F"])), c(dailyF0, diff(out_75[, "F"])),
  c(dailyF0, diff(out_hi[, "F"])), c(dailyF0, diff(out_lo[, "F"])),
  c(dailyF0, diff(out_eq[, "F"])), c(dailyF0, diff(out_il[, "F"])),
  c(dailyF0, diff(out_pr[, "F"])), c(dailyF0, diff(out_ih[, "F"]))
)
colnames(proyF) <- c("time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l", "eq", "unc_l", "proj", "unc_h")
write.table(data.frame(date = idate, proyF),
  file = paste(parametros$data_path, "proyF.csv", sep = ""), sep = ",", row.names = FALSE)

pdf(paste(dir_file, "plot_proyF.pdf", sep = ""))
matplot(proyF[, "time"], proyF[, "m2w"], type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of daily death",
  ylim = c(min(proyF[, 2:11]), max(proyF[, 2:11])))
lines(proyF[, "time"], proyF[, "m4w"],   col = 3, lty = 1)
lines(proyF[, "time"], proyF[, "q25"],   col = 4, lty = 1)
lines(proyF[, "time"], proyF[, "q75"],   col = 5, lty = 1)
lines(proyF[, "time"], proyF[, "10p_h"], col = 6, lty = 1)
lines(proyF[, "time"], proyF[, "20p_l"], col = 7, lty = 1)
lines(proyF[, "time"], proyF[, "eq"],    col = 8, lty = 1)
lines(proyF[, "time"], proyF[, "proj"],  col = 9, lty = 1)
points(proyF[, "time"], data_fallecido$Fallecido_diario[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("topleft",
  col = c(2, 3, 4, 5, 6, 7, 8, 9), lty = c(1, 1, 1, 1, 1, 1, 1, -1), pch = c(-1, -1, -1, -1, -1, -1, -1, 1),
  legend = c("mean of 2 weeks", "mean of 4 weeks", "quantil 25%", "quantil 75%",
             "10% higher of mean of 2 weeks", "20% lower of mean of 2 weeks",
             "equilibrium", "projection")
)
dev.off()


# =============================================================================
# 12. Exportar proyecciones de hospitalizados (H)
# =============================================================================
proyH <- cbind(
  time,
  out_2w[, "H"], out_4w[, "H"], out_25[, "H"], out_75[, "H"],
  out_hi[, "H"], out_lo[, "H"], out_eq[, "H"], out_il[, "H"],
  out_pr[, "H"], out_ih[, "H"]
)
colnames(proyH) <- c("time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l", "eq", "unc_l", "proj", "unc_h")
write.table(data.frame(date = idate, proyH),
  file = paste(parametros$data_path, "proyH.csv", sep = ""), sep = ",", row.names = FALSE)

pdf(paste(dir_file, "plot_proyH.pdf", sep = ""))
matplot(proyH[, "time"], proyH[, "m2w"], type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of hospitalization",
  ylim = c(min(proyH[, 2:11]), max(proyH[, 2:11])))
lines(proyH[, "time"], proyH[, "m4w"],   col = 3, lty = 1)
lines(proyH[, "time"], proyH[, "q25"],   col = 4, lty = 1)
lines(proyH[, "time"], proyH[, "q75"],   col = 5, lty = 1)
lines(proyH[, "time"], proyH[, "10p_h"], col = 6, lty = 1)
lines(proyH[, "time"], proyH[, "20p_l"], col = 7, lty = 1)
lines(proyH[, "time"], proyH[, "eq"],    col = 8, lty = 1)
lines(proyH[, "time"], proyH[, "proj"],  col = 9, lty = 1)
points(proyH[, "time"], data$Internados.Generales[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("topleft",
  col = c(2, 3, 4, 5, 6, 7, 8, 9), lty = c(1, 1, 1, 1, 1, 1, 1, -1), pch = c(-1, -1, -1, -1, -1, -1, -1, 1),
  legend = c("mean of 2 weeks", "mean of 4 weeks", "quantil 25%", "quantil 75%",
             "10% higher of mean of 2 weeks", "20% lower of mean of 2 weeks",
             "equilibrium", "projection")
)
dev.off()


# =============================================================================
# 13. Exportar proyecciones de UCI (U)
# =============================================================================
proyU <- cbind(
  time,
  out_2w[, "U"], out_4w[, "U"], out_25[, "U"], out_75[, "U"],
  out_hi[, "U"], out_lo[, "U"], out_eq[, "U"], out_il[, "U"],
  out_pr[, "U"], out_ih[, "U"]
)
colnames(proyU) <- c("time", "m2w", "m4w", "q25", "q75", "10p_h", "20p_l", "eq", "unc_l", "proj", "unc_h")
write.table(data.frame(date = idate, proyU),
  file = paste(parametros$data_path, "proyU.csv", sep = ""), sep = ",", row.names = FALSE)

pdf(paste(dir_file, "plot_proyU.pdf", sep = ""))
matplot(proyU[, "time"], proyU[, "m2w"], type = "l", col = 2, lty = 1,
  xlab = "days", ylab = "projection of UCI",
  ylim = c(min(proyU[, 2:11]), max(proyU[, 2:11])))
lines(proyU[, "time"], proyU[, "q25"],   col = 4, lty = 1)
lines(proyU[, "time"], proyU[, "q75"],   col = 5, lty = 1)
lines(proyU[, "time"], proyU[, "10p_h"], col = 6, lty = 1)
lines(proyU[, "time"], proyU[, "20p_l"], col = 7, lty = 1)
lines(proyU[, "time"], proyU[, "eq"],    col = 8, lty = 1)
lines(proyU[, "time"], proyU[, "proj"],  col = 9, lty = 1)
points(proyU[, "time"], data$Internados.UTI[t_cont:(t_cont + proy_days)], col = 9, pch = 2, lty = 1)
legend("bottomleft",
  col = c(2, 4, 5, 6, 7, 8, 9), lty = c(1, 1, 1, 1, 1, 1, -1), pch = c(-1, -1, -1, -1, -1, -1, 1),
  legend = c("mean of last month", "percentil 25", "percentil 75",
             "10% higher of mean of last month", "20% lower of mean of last month",
             "equilibrium", "projection")
)
dev.off()

print("Finished successfully...")
