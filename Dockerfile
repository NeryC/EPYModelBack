# ─────────────────────────────────────────────────────────────
# Base: rocker/stan ya trae R 4.x + rstan + Stan precompilados.
# Elimina los 30-40 min de compilación de C++/Stan.
# ─────────────────────────────────────────────────────────────
FROM rocker/stan:4.3

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
