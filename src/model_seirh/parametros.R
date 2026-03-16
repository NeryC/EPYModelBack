# =============================================================================
# parametros.R
# =============================================================================
# Módulo central de configuración del modelo epidemiológico SEIRHUF.
#
# Responsabilidades
# -----------------
# 1. Define las rutas del proyecto (data, rawData, model_seirh).
# 2. Valida que todos los archivos de entrada existen al momento de carga.
# 3. Lee y limpia todos los datasets CSV necesarios:
#      - Registro diario MSPBS (hospitalizados, UCI, importados, pruebas)
#      - Confirmados diarios (con detección de subregistro)
#      - Fallecidos diarios
#      - Vacunados diarios (con filtro de suavizado exponencial)
# 4. Calcula el factor de subregistro a partir del número de pruebas.
# 5. Define los vectores de parámetros ODE para cada modelo (init, SEIR, SEIRH).
# 6. Define las funciones ODE (odefun_seir, odefun_seirh) que se integran con deSolve.
#
# Parámetros del ODE — notación y unidades
# -----------------------------------------
#   N         : Población total de Paraguay (suma por departamentos, 2020)
#   alpha     : Tasa de progresión E→I  = 1/3 día⁻¹  (período de incubación: 3 días)
#   gamma     : Tasa de recuperación I→R = 1/7 día⁻¹  (período infeccioso: 7 días)
#   delta_hu  : Tasa H→U  = 1/7  día⁻¹  (hospitalización a UCI en 7 días)
#   delta_hf  : Tasa H→F  = 1/9  día⁻¹  (hospitalización a muerte en 9 días)
#   delta_ho  : Tasa H→R  = 1/11 día⁻¹  (hospitalización a recuperación en 11 días)
#   phi_uf    : Tasa U→F  = 1/11 día⁻¹  (UCI a muerte en 11 días)
#   phi_uo    : Tasa U→R  = 1/12 día⁻¹  (UCI a recuperación en 12 días)
#   psi       : Tasa O→S  = 1/180 día⁻¹ (pérdida de inmunidad en ~6 meses)
#   eta       : Eficacia de la vacuna  = 0.9 (90% de eficacia)
#
# Factor de subregistro
# ----------------------
# Paraguay no reportó todos los casos confirmados; se estima el número real
# usando el número de pruebas realizadas como proxy:
#   factor = Cantidad_Pruebas^(-0.914773) * exp(9.00991)
# Este factor calibrado amplifica los casos reportados para aproximar
# el número verdadero de infectados.
#
# Filtro de vacunados
# --------------------
# Los datos diarios de vacunados tienen ruido (días sin reporte, picos).
# Se aplica una media móvil exponencial con τ = 14 días para suavizarlos:
#   V_filtrado[i] = (1/14) * V[i] + (13/14) * V_filtrado[i-1]
# Booster: se suma la serie de dosis de refuerzo (filtrada) a la de esquema completo.
# =============================================================================

import("dplyr", "%>%")
import("utils", "read.csv")
import("glue", "glue")


# =============================================================================
# 1. Validadores de existencia
# =============================================================================
# Wrappers de ensurer que lanzan error si el archivo/directorio no existe.
verificar_que_archivo_existe <- ensurer::ensures_that(file.exists)
verificar_directorios        <- ensurer::ensures_that(dir.exists)


# =============================================================================
# 2. Rutas del proyecto
# =============================================================================
export("data_path")
data_path <-
  glue(paste(getwd(), "/public/data/", sep = "")) %>%
  ensurer::ensure_that(dir.exists(.) ~ glue("Directorio {.} no encontrado."))

export("raw_data_path")
raw_data_path <- paste(getwd(), "/public/rawData/", sep = "")

export("model_seirh")
model_seirh <- paste(getwd(), "/src/model_seirh/", sep = "")


# =============================================================================
# 3. Configuración del experimento
# =============================================================================
# tamano_ventana : número de días en cada ventana deslizante de inferencia.
#                  Cada iteración del loop ajusta los parámetros sobre esta ventana.
export("experimento")
experimento     <- list(tamano_ventana = 14)
tamano_ventana  <- experimento$tamano_ventana  # Alias local para uso en ODE

# Directorio de salida de gráficos de diagnóstico (pairs/trace plots)
export(".dir_plot")
.dir_plot <-
  glue("{model_seirh}res{tamano_ventana}/pair_out/") %>%
  ensurer::ensure_that(dir.exists(.) ~ glue("Directorio {.} no encontrado."))


# =============================================================================
# 4. Rutas de archivos (con validación de existencia)
# =============================================================================
export("filepaths")
filepaths <- list(
  # Modelos Stan compilables
  modelo_SEIR  = glue("{model_seirh}model_seir.stan") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  modelo_SEIRH = glue("{model_seirh}model_seirh.stan") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  modelo_init  = glue("{model_seirh}model_init.stan") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),

  # Datos de entrada (generados por los scripts clean_*.R)
  datos_diarios      = glue("{data_path}REGISTRO DIARIO_Datos completos_data.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_confirmados  = glue("{data_path}confirmado_diarios_revisado.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_poblacion    = glue("{data_path}DatosPoblacionDpto.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_fallecidos   = glue("{data_path}Fallecidos_diarios_revisado.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),
  datos_inmunizados  = glue("{data_path}Inmunizado_diarios.csv") %>%
    ensurer::ensure_that(file.exists(.) ~ glue("Archivo {.} no encontrado.")),

  # Archivos de salida (pueden no existir todavía)
  datos_simulacion   = glue("{data_path}sim.csv"),
  datos_probabilidad = glue("{data_path}prob.csv")
)


# =============================================================================
# 5. Carga y alineación de datos de entrada
# =============================================================================

# --- Registro diario MSPBS (hospitalizados, UCI, pruebas, importados) ---
# Formato: separado por ";", fechas en formato DD/MM/YYYY
datos_diarios_raw <- read.csv(filepaths$datos_diarios, sep = ";")
datos_diarios_raw[is.na(datos_diarios_raw)] <- 0     # Reemplazar NA por 0
numero_datos <- nrow(datos_diarios_raw)              # Total de días disponibles

# --- Confirmados diarios (post-procesados por clean_R.R) ---
datos_confirmados_raw <- read.csv(filepaths$datos_confirmados, sep = ",")
datos_confirmados_raw[is.na(datos_confirmados_raw)] <- 0
numero_x <- nrow(datos_confirmados_raw)

# Si el registro diario tiene más días que los confirmados, rellenar con ceros.
# Esto puede ocurrir cuando los datos del MSPBS avanzan más rápido que los
# datos de confirmados (que requieren procesamiento adicional).
#
# NOTA: se construyen todas las filas nuevas de una sola vez y se une con rbind.
# El patrón anterior de rbind dentro de un for-loop es O(n²) porque cada rbind
# copia el DataFrame completo. Construir el bloque de filas primero es O(n).
if (numero_datos > numero_x) {
  indices_nuevos <- seq(numero_x + 1, numero_datos)
  filas_nuevas   <- data.frame(
    X                 = indices_nuevos,
    Fecha             = as.Date(as.numeric(as.Date("2020-03-06")) + indices_nuevos, origin = "1970-01-01"),
    Confirmado_diario = 0L
  )
  datos_confirmados_raw <- rbind(datos_confirmados_raw, filas_nuevas)
}

# --- Fallecidos diarios (post-procesados por clean_F.R) ---
datos_fallecidos_raw <- read.csv(filepaths$datos_fallecidos, sep = ",")
numero_x <- nrow(datos_fallecidos_raw)

# Rellenar con ceros si faltan días (mismo criterio que confirmados, también O(n))
if (numero_datos > numero_x) {
  indices_nuevos <- seq(numero_x + 1, numero_datos)
  filas_nuevas   <- data.frame(
    X                = indices_nuevos,
    Fecha            = as.Date(as.numeric(as.Date("2020-03-06")) + indices_nuevos, origin = "1970-01-01"),
    Fallecido_diario = 0L
  )
  datos_fallecidos_raw <- rbind(datos_fallecidos_raw, filas_nuevas)
}
fallecidos <- datos_fallecidos_raw$Fallecido_diario


# =============================================================================
# 6. Vacunados: filtro de suavizado exponencial (τ = 14 días)
# =============================================================================
# OWID reporta datos con huecos y picos. Se aplica un filtro exponencial para
# distribuir el impacto de la vacunación de forma continua en el tiempo.
# Fórmula: V_f[i] = (1/τ) * V[i] + (1 - 1/τ) * V_f[i-1]  con τ = 14 días
datos_inmunizados_raw <- read.csv(filepaths$datos_inmunizados, sep = ",")

export("inmunizados_filtrado")
inmunizados           <- datos_inmunizados_raw$Inmunizado_diario
inmunizados_filtrado  <- inmunizados
for (i in seq(2, length(inmunizados))) {
  inmunizados_filtrado[i] <-
    (1.0 / 14.0) * inmunizados[i] + (1.0 - 1.0 / 14.0) * inmunizados_filtrado[i - 1]
}

export("boosters_filtrado")
boosters          <- datos_inmunizados_raw$Booster_diario
boosters_filtrado <- boosters
for (i in seq(2, length(boosters))) {
  boosters_filtrado[i] <-
    (1.0 / 14.0) * boosters[i] + (1.0 - 1.0 / 14.0) * boosters_filtrado[i - 1]
}

# El vector final combina esquema completo + refuerzo (ambos reducen susceptibilidad)
inmunizados_filtrado <- inmunizados_filtrado + boosters_filtrado


# =============================================================================
# 7. Factor de subregistro y confirmados ajustados
# =============================================================================
# Confirmados sin corrección (tal como reporta el MSPBS)
export("confirmados_sin_subregistro")
confirmados_sin_subregistro <- datos_confirmados_raw$Confirmado_diario
confirmados_sin_subregistro[is.na(confirmados_sin_subregistro)] <- 0

# Factor de corrección por subregistro:
#   factor = Cantidad_Pruebas^(-0.914773) * exp(9.00991)
# Derivado de la relación empírica entre positividad y volumen de pruebas.
# Si Cantidad.Pruebas == 0 (días sin datos), el factor es Inf → se interpola.
export("factor_subregistro")
factor_subregistro <- datos_diarios_raw$Cantidad.Pruebas^(-0.914773) * exp(9.00991)
indices_inf        <- which(is.infinite(factor_subregistro))
factor_subregistro[indices_inf] <- NA  # Marcar como NA para interpolación segura
for (i in indices_inf) {
  # Interpolar con la media de los días adyacentes.
  # Guardas: si i == 1 no hay i-1; si i == longitud no hay i+1.
  # En ambos extremos se usa el único vecino disponible.
  if (i == 1) {
    factor_subregistro[i] <- factor_subregistro[i + 1]
  } else if (i == length(factor_subregistro)) {
    factor_subregistro[i] <- factor_subregistro[i - 1]
  } else {
    factor_subregistro[i] <- 0.5 * (factor_subregistro[i - 1] + factor_subregistro[i + 1])
  }
}

# Confirmados ajustados por subregistro (más cercanos al número real de infectados)
export("confirmados_con_subregistro")
n1 <- length(datos_confirmados_raw$Confirmado_diario)
n2 <- length(datos_diarios_raw$Cantidad.Pruebas)
nn <- min(n1, n2)  # Usar la longitud mínima para evitar accesos fuera de rango
confirmados_con_subregistro <-
  datos_confirmados_raw$Confirmado_diario[1:nn] * factor_subregistro[1:nn]

# Bandera que controla qué serie de reportados usa el modelo.
# Cambiar a FALSE para usar los confirmados oficiales sin corregir.
export("reportando_con_subregistro")
reportando_con_subregistro <- TRUE  # READ ONLY — modificar aquí para cambiar el comportamiento


# =============================================================================
# 8. Lista consolidada de datos diarios para el ODE
# =============================================================================
export("cantidades_diarias")
cantidades_diarias <- list(
  reportados     = if (reportando_con_subregistro) confirmados_con_subregistro else confirmados_sin_subregistro,
  hospitalizados = datos_diarios_raw$Internados.Generales,
  uci            = datos_diarios_raw$Internados.UTI,
  fallecidos     = fallecidos,
  importados     = datos_diarios_raw$Confirmados.en.albergues,  # Casos en cuarentena
  inmunizados    = inmunizados_filtrado                          # Serie suavizada
)


# =============================================================================
# 9. Fechas del experimento
# =============================================================================
export("fecha_inicial")
fecha_inicial <- min(as.Date(datos_diarios_raw$Fecha, "%d/%m/%Y")) - 1  # 2020-03-06

export("fecha_final")
fecha_final <- max(as.Date(datos_diarios_raw$Fecha, "%d/%m/%Y"))

export("fecha_inicio_evaluacion")
fecha_inicio_evaluacion <- as.Date("2020-03-06")

# id_inicio_sim: índice numérico del primer día de simulación (offset desde fecha_inicial)
export("id_inicio_sim")
id_inicio_sim <- as.numeric(fecha_inicio_evaluacion) - as.numeric(fecha_inicial)


# =============================================================================
# 10. Condiciones iniciales acumuladas
# =============================================================================
# r0: recuperados acumulados al inicio de la simulación.
# Se recalcula a 0 para simplicidad (se estima via modelo init en la primera ejecución).
r0 <- 0


# =============================================================================
# 11. Parámetros ODE fijos (tasas de transición entre compartimentos)
# =============================================================================
# Tasas en unidades de día⁻¹ (períodos en días = 1/tasa)
alpha    <- 1.0 / 3.0    # E→I: período de incubación de 3 días
gamma    <- 1.0 / 7.0    # I→R: período infeccioso de 7 días
delta_hu <- 1.0 / 7.0    # H→U: hospitalizado pasa a UCI en ~7 días
delta_hf <- 1.0 / 9.0    # H→F: hospitalizado fallece en ~9 días
delta_ho <- 1.0 / 11.0   # H→R: hospitalizado se recupera en ~11 días
phi_uf   <- 1.0 / 11.0   # U→F: UCI fallece en ~11 días
phi_uo   <- 1.0 / 12.0   # U→R: UCI se recupera en ~12 días
psi      <- 1.0 / 180.0  # O→S: pérdida de inmunidad en ~6 meses
eta      <- 0.9          # Eficacia de la vacuna: 90%

# Población total de Paraguay (suma de todos los departamentos, censo 2020)
datos_sobre_poblacion <- read.csv(filepaths$datos_poblacion)

# Vector de parámetros para el modelo de inicialización (estima e0, i0)
export("parametros_ode_init")
parametros_ode_init <- c(
  N     = sum(datos_sobre_poblacion[, "X2020"]),
  alpha = alpha,
  gamma = gamma,
  psi   = psi,
  eta   = eta,
  r0    = r0
)

# Vector de parámetros para el modelo SEIR (sin compartimentos H/U/F)
export("parametros_ode_seir")
parametros_ode_seir <- c(
  N     = sum(datos_sobre_poblacion[, "X2020"]),
  alpha = alpha,
  gamma = gamma,
  psi   = psi,
  eta   = eta
)

# Vector de parámetros para el modelo SEIRH completo (8 compartimentos)
export("parametros_ode_seirh")
parametros_ode_seirh <- c(
  N        = sum(datos_sobre_poblacion[, "X2020"]),
  alpha    = alpha,
  gamma    = gamma,
  delta_hu = delta_hu,
  delta_hf = delta_hf,
  delta_ho = delta_ho,
  phi_uf   = phi_uf,
  phi_uo   = phi_uo,
  psi      = psi,
  eta      = eta
)


# =============================================================================
# 12. Función ODE — Modelo SEIR
# =============================================================================
# Sistema de ecuaciones diferenciales para el modelo SEIR con:
#   - Importados (casos en cuarentena que entran directamente a R)
#   - Vacunación (reduce susceptibles S con eficacia eta)
#   - Pérdida de inmunidad (O→S con tasa psi)
#
# El compartimento O ("Out") acumula los recuperados e inmunizados.
# Los parámetros dinámicos (imported_i, v_filtrado_i) se pasan como variables
# con nombre "imported1", "imported2", ..., "v_filtrado1", etc., y se recuperan
# en el instante t usando get(paste("imported", index, sep="")).
#
# Compartimentos: S (susceptibles), E (expuestos), I (infecciosos),
#                 R (recuperados acumulados), O (out: recuperados activos + vacunados)
export("odefun_seir")
odefun_seir <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    # Índice de tiempo para acceder a los parámetros dinámicos del día actual.
    # Se clampea al rango [1, tamano_ventana] para evitar accesos fuera de rango.
    index <- ceiling(t)
    if (index == 0)                   index <- 1
    if (index == tamano_ventana + 1)  index <- tamano_ventana

    # Datos dinámicos del día (importados y vacunados del índice actual)
    importados <- get(paste("imported",   index, sep = ""))
    v_filtrado <- get(paste("v_filtrado", index, sep = ""))

    # Ecuaciones diferenciales del modelo SEIR
    dS <- -beta * S * I / N + psi * O - eta * v_filtrado - importados  # nolint
    dE <-  beta * S * I / N - alpha * E                                 # nolint
    dI <-  alpha * E - gamma * I                                        # nolint
    dR <-  gamma * I + importados                                       # nolint (acumulado)
    dO <-  gamma * I + importados - psi * O + eta * v_filtrado          # nolint (recuperados activos)

    list(c(dS, dE, dI, dR, dO))
  })
}


# =============================================================================
# 13. Función ODE — Modelo SEIRH (8 compartimentos)
# =============================================================================
# Extiende el SEIR añadiendo: H (hospitalizados), U (UCI), F (fallecidos).
#
# Parámetros de distribución de casos graves (estimados por MCMC en cada ventana):
#   lambda_ih : fracción de I que pasa a H (hospitalización)
#   lambda_if : fracción de I que fallece directamente (sin hospitalización)
#   lambda_hu : fracción de H que pasa a U (UCI)
#   lambda_hf : fracción de H que fallece en hospital
#   lambda_uf : fracción de U que fallece en UCI
#
# Las fracciones complementarias:
#   lambda_ho = 1 - lambda_hu - lambda_hf  → H que se recuperan
#   lambda_uo = 1 - lambda_uf              → U que se recuperan
export("odefun_seirh")
odefun_seirh <- function(t, state, parameters) {
  with(as.list(c(state, parameters)), {
    # Índice de tiempo para datos dinámicos (clampeado al rango de la ventana)
    index <- ceiling(t)
    if (index == 0)                   index <- 1
    if (index == tamano_ventana + 1)  index <- tamano_ventana

    # Datos dinámicos del día actual
    importados <- get(paste("imported",   index, sep = ""))
    v_filtrado <- get(paste("v_filtrado", index, sep = ""))

    # Fracciones complementarias (suma a 1 por construcción)
    lambda_ho <- (1 - lambda_hu - lambda_hf)  # nolint: H → recuperados
    lambda_uo <- (1 - lambda_uf)              # nolint: U → recuperados

    # Ecuaciones del sistema SEIRHUF
    dS <- -beta * S * I / N + psi * O - eta * v_filtrado - importados                                    # nolint
    dE <-  beta * S * I / N - alpha * E                                                                   # nolint
    dI <-  alpha * E - gamma * I                                                                          # nolint
    dR <-  gamma * I + importados                                                                         # nolint (acumulado)
    dH <-  lambda_ih * gamma * I - lambda_hu * delta_hu * H - lambda_hf * delta_hf * H - lambda_ho * delta_ho * H  # nolint
    dU <-  lambda_hu * delta_hu * H - lambda_uf * phi_uf * U - lambda_uo * phi_uo * U                   # nolint
    dF <-  lambda_if * gamma * I + lambda_uf * phi_uf * U + lambda_hf * delta_hf * H                    # nolint
    dO <- (1 - lambda_ih - lambda_if) * gamma * I + lambda_ho * delta_ho * H + lambda_uo * phi_uo * U + importados - psi * O + eta * v_filtrado  # nolint

    list(c(dS, dE, dI, dR, dH, dU, dF, dO))
  })
}
