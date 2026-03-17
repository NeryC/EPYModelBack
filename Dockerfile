# ─────────────────────────────────────────────────────────────
# Base: rocker/r-ver 4.3.3 + RSPM (paquetes binarios para Ubuntu 22.04).
# RSPM provee rstan y dependencias como binarios precompilados,
# eliminando los 30-40 min de compilación de C++/Stan.
# ─────────────────────────────────────────────────────────────
FROM rocker/r-ver:4.3.3

# Apuntar a RSPM (binarios Linux) antes de instalar cualquier paquete R
RUN mkdir -p /etc/R && \
    echo 'options(repos = c(RSPM = "https://packagemanager.posit.co/cran/__linux__/jammy/latest", CRAN = "https://cloud.r-project.org"))' \
    >> /etc/R/Rprofile.site

# Dependencias del sistema necesarias para rstan y paquetes tidyverse
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev libcurl4-openssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Instalar rstan desde binario (sin compilar C++)
RUN install2.r --error --skipinstalled rstan

WORKDIR /usr/src/app

# ── Node.js 18 ────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# ── Python + paquetes científicos (wheels binarios, ~1 min) ───
RUN apt-get install -y python3 python3-pip && \
    pip3 install --no-cache-dir pandas scipy numpy

# ── Paquetes R restantes via RSPM (binarios, sin compilar) ────
# install2.r viene incluido en todas las imágenes rocker.
# --skipinstalled evita reinstalar lo que ya trae rocker/stan.
RUN install2.r --error --skipinstalled \
    tidyverse dplyr rio deSolve bayesplot tictoc modules roll ensurer R.utils fpeek

# ── Dependencias Node.js ──────────────────────────────────────
# Se copian primero para aprovechar el caché de Docker:
# si package.json no cambia, esta capa no se reconstruye.
COPY package*.json ./
RUN npm install

# ── Código fuente y build TypeScript ─────────────────────────
COPY . .
RUN npm run build

EXPOSE 3001

CMD ["npm", "start"]
