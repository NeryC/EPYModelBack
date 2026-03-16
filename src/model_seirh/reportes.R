# =============================================================================
# reportes.R
# =============================================================================
# Funciones para generar reportes visuales de diagnóstico del modelo MCMC.
#
# Provee dos tipos de gráficos estándar para evaluar la convergencia y
# las correlaciones entre parámetros del modelo Stan:
#
#   1. Traceplot (trayectorias de cadenas):
#      Muestra la evolución de cada cadena MCMC para cada parámetro.
#      Sirve para verificar que las cadenas se mezclan bien (convergencia).
#      Una buena convergencia se ve como "ruido estacionario" superpuesto entre cadenas.
#
#   2. Pairs plot (correlaciones entre parámetros):
#      Muestra scatter plots de pares de parámetros en el espacio posterior.
#      Sirve para detectar correlaciones entre parámetros y divergencias MCMC
#      (marcadas en rojo). Las correlaciones fuertes indican problemas de
#      identificabilidad del modelo.
#
# Nota sobre el print() explícito
# ---------------------------------
# Los gráficos de lattice/trellis (como los de rstan) no se renderizan
# automáticamente dentro de loops o funciones en R. Se requiere print()
# explícito. Ver: https://cran.r-project.org/doc/FAQ/R-FAQ.html#Why-do-lattice_002ftrellis-graphics-not-work_003f
# =============================================================================

import("grDevices", "pdf", "dev.off")
import("graphics", "pairs")
import("rstan", "traceplot")


# =============================================================================
# Funciones auxiliares internas (no exportadas)
# =============================================================================

# Genera el traceplot. Si no se especifican parámetros, muestra todos.
graficar_parametros_vs_iteraciones <- function(.fitmodel, .parametros) {
  if (missing(.parametros)) {
    print(traceplot(.fitmodel))               # Todos los parámetros
  } else {
    print(traceplot(.fitmodel, pars = .parametros))  # Solo los especificados
  }
}

# Genera el pairs plot. Si no se especifican parámetros, muestra todos.
graficar_pares_entre_parametros <- function(.fitmodel, .parametros) {
  if (missing(.parametros)) {
    pairs(.fitmodel)
  } else {
    pairs(.fitmodel, pars = .parametros)
  }
}


# =============================================================================
# Funciones exportadas
# =============================================================================

# -----------------------------------------------------------------------------
# graficar_parametros_vs_iteraciones_en_pdf
# -----------------------------------------------------------------------------
# Guarda el traceplot en un archivo PDF.
#
# Útil para revisar la convergencia de las cadenas MCMC fuera de una sesión R
# interactiva (p.ej. cuando el modelo se ejecuta en un servidor sin pantalla).
#
# Parameters
# ----------
#   .filepath   : Ruta del archivo PDF de salida.
#   .fitmodel   : Objeto stanfit (salida de rstan::sampling).
#   .parametros : Vector de nombres de parámetros a graficar (opcional).
#                 Si se omite, grafica todos los parámetros del modelo.
# -----------------------------------------------------------------------------
export("graficar_parametros_vs_iteraciones_en_pdf")
graficar_parametros_vs_iteraciones_en_pdf <- function(.filepath, .fitmodel, .parametros) {
  pdf(file = .filepath)
  graficar_parametros_vs_iteraciones(.fitmodel, .parametros)
  dev.off()
}


# -----------------------------------------------------------------------------
# graficar_pares_entre_parametros_en_pdf
# -----------------------------------------------------------------------------
# Guarda el pairs plot en un archivo PDF.
#
# Permite detectar correlaciones fuertes y divergencias MCMC (puntos en rojo).
# Las divergencias indican que el sampler tuvo dificultades en ciertas regiones
# del espacio de parámetros, lo que puede sesgar las estimaciones.
#
# Parameters
# ----------
#   .filepath   : Ruta del archivo PDF de salida.
#   .fitmodel   : Objeto stanfit (salida de rstan::sampling).
#   .parametros : Vector de nombres de parámetros a graficar (opcional).
# -----------------------------------------------------------------------------
export("graficar_pares_entre_parametros_en_pdf")
graficar_pares_entre_parametros_en_pdf <- function(.filepath, .fitmodel, .parametros) {
  pdf(file = .filepath)
  graficar_pares_entre_parametros(.fitmodel, .parametros)
  dev.off()
}
