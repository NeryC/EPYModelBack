# install_packages.R
# Instalación de paquetes R para el modelo SEIRHUF.
#
# En Docker: este script NO se ejecuta — los paquetes se instalan
# en el Dockerfile usando rocker/stan (rstan precompilado) + install2.r.
#
# Uso manual (fuera de Docker, primera vez en una máquina nueva):
#   Rscript src/model_seirh/install_packages.R
#
# Usa el mirror de Posit Package Manager para paquetes binarios
# (sin compilación de C++, mucho más rápido que CRAN estándar).

RSPM <- "https://packagemanager.posit.co/cran/__linux__/jammy/latest"

paquetes <- c(
    "tidyverse",
    "dplyr",
    "rio",
    "rstan",
    "deSolve",
    "bayesplot",
    "tictoc",
    "modules",
    "roll",
    "ensurer",
    "R.utils",
    "fpeek"
)

# Instalar solo los que no están presentes
faltantes <- paquetes[!paquetes %in% rownames(installed.packages())]

if (length(faltantes) == 0) {
    message("Todos los paquetes ya están instalados.")
} else {
    message("Instalando: ", paste(faltantes, collapse = ", "))
    install.packages(faltantes, repos = RSPM)
}
