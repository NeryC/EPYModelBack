# ─────────────────────────────────────────────────────────────
# Base: rocker/r-ver 4.3.3 (Ubuntu 22.04 Jammy, imagen mínima).
# RSPM provee paquetes R como binarios precompilados (amd64),
# eliminando los 30-40 min de compilación de C++/Stan.
# ─────────────────────────────────────────────────────────────
FROM rocker/r-ver:4.3.3

# ── Dependencias de sistema (única capa apt) ──────────────────
# rocker/r-ver es minimal: curl, python3, gnupg NO vienen incluidos.
# Se instala todo aquí para no repetir apt-get update en capas posteriores.
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Herramientas base
    curl ca-certificates gnupg \
    # Python
    python3 python3-pip \
    # Libs para R: rstan, tidyverse, ggplot2, etc.
    libssl-dev libcurl4-openssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 18 ────────────────────────────────────────────────
# El script setup_18.x ejecuta su propio apt-get update internamente.
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Python: paquetes científicos (wheels binarios, ~1 min) ────
RUN pip3 install --no-cache-dir pandas scipy numpy

# ── RSPM: binarios Linux para Ubuntu 22.04 Jammy ─────────────
# HTTPUserAgent es obligatorio para que RSPM sirva binarios en vez
# de redirigir a instalación desde fuente.
RUN mkdir -p /etc/R && echo '\
options(\
  repos = c(\
    RSPM = "https://packagemanager.posit.co/cran/__linux__/jammy/latest",\
    CRAN = "https://cloud.r-project.org"\
  ),\
  HTTPUserAgent = sprintf(\
    "R/%s R (%s)",\
    getRversion(),\
    paste(getRversion(), R.version$platform, R.version$arch, R.version$os)\
  )\
)' >> /etc/R/Rprofile.site

# ── Paquetes R: rstan primero (el más pesado) ─────────────────
RUN install2.r --error --skipinstalled rstan

# ── Paquetes R: resto del modelo epidemiológico ───────────────
# 'ensurer' fue archivado en CRAN; se instala desde GitHub (smbache/ensurer).
RUN install2.r --error --skipinstalled \
    tidyverse dplyr rio deSolve bayesplot \
    tictoc modules roll R.utils fpeek remotes && \
    Rscript -e "remotes::install_github('smbache/ensurer')"

WORKDIR /usr/src/app

# ── Dependencias Node.js (capa cacheada por Docker) ───────────
# Se copian primero para que esta capa no se reconstruya si solo
# cambia el código fuente (pero no package.json).
COPY package*.json ./
RUN npm install

# ── Código fuente y build TypeScript ─────────────────────────
COPY . .
RUN npm run build

EXPOSE 3001

CMD ["npm", "start"]
