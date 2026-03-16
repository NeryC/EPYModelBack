# CLAUDE.md — EPI Model Backend (newBack)

Documentación completa en `docs/`. Lee primero los docs antes de hacer cambios.

## Proyecto

API REST de modelos epidemiológicos (SEIRHUF) para simulaciones y proyecciones de COVID-19.
Ejecuta scripts Python/R y expone los resultados como endpoints JSON.

## Stack

- **Node.js 18+** + **TypeScript 5.8** (strict mode total)
- **Express.js 4** (framework HTTP)
- **Zod 3** (validación de inputs)
- **Pino 9** (logging estructurado)
- **BullMQ** + **Redis** (jobs en background, opcional)
- **python-shell** (ejecuta scripts Python)
- **swagger-ui-express** (documentación API, solo dev)
- **prom-client** (métricas Prometheus)

## Comandos

```bash
npm run dev       # TypeScript watch + Nodemon (hot reload)
npm run build     # Compilar TypeScript → dist/
npm start         # Servidor producción (requiere build)
npm run lint      # ESLint
npm run format    # Prettier
```

## Variables de entorno

Copiar `config.example.env` a `.env`:

```env
NODE_ENV=development
PORT=3001
LOG_LEVEL=debug
CORS_ORIGIN=http://localhost:3000
REDIS_URL=redis://localhost:6379   # Opcional
PYTHON_PATH=python
R_PATH=R
```

## URLs del servidor (dev)

- `GET  /health` — Health check
- `GET  /api/v1/simulations` — Simulación con parámetros
- `GET  /api/v1/get-first-simulation-data` — Simulación default
- `GET  /api/v1/projections` — Proyecciones
- `GET  /api/v1/metrics` — Métricas Prometheus
- `GET  /api-docs` — Swagger UI (solo dev)

## Estructura clave

```
src/
  index.ts              # Entry point (Express app, rutas, middleware)
  api/v1/               # DTOs Zod, Swagger, Metrics
  application/          # Use cases (lógica de negocio pura)
  domain/               # Interfaces y entidades (sin dependencias externas)
  infrastructure/       # Repositorios, adaptadores Python, jobs
  controllers/          # HTTP handlers
  routes/               # Definición de rutas Express
  middleware/           # Validación Zod, error handling
  config/environment.ts # Variables de entorno tipadas
  shared/constants.ts   # Constantes (paths, file names)
public/results/         # Archivos públicos accesibles vía HTTP
storage/results/        # Archivos privados del servidor
docs/                   # Documentación detallada
```

## Arquitectura (Clean Architecture)

```
Presentation (routes/controllers/middleware)
    ↓
Application (use cases)
    ↓
Domain (interfaces, entities) ← núcleo puro
    ↑
Infrastructure (repositorios, adaptadores)
```

**Regla de dependencias:** Domain no importa nada externo. Infrastructure implementa interfaces de Domain.

## Para agregar un endpoint

1. DTO Zod en `src/api/v1/{resource}/dto.ts`
2. Interfaces en `src/domain/{resource}.ts`
3. Repositorio en `src/infrastructure/storage/{resource}-repository.ts`
4. Use case en `src/application/{resource}/{action}.ts`
5. Controller en `src/controllers/{resource}Controller.ts`
6. Rutas en `src/routes/{resource}Routes.ts`
7. Montar rutas en `src/index.ts`

## Patrones de código

- Async/await con `asyncHandler(fn)` para captura automática de errores
- Responses: `sendSuccessResponse` / `sendErrorResponse` de `utils/errorHandler.ts`
- Logging: `logger.info({ context }, 'event_name')` — siempre estructurado
- TypeScript strict: sin `any`, null checks, tipos de retorno explícitos
- Errores custom: `new AppError(message, statusCode)`

## Integración Python/R

- Scripts Python en `src/scripts/`
- Adaptador en `src/infrastructure/processes/simulation-adapter.ts`
- Usa `python-shell` para ejecución, parámetros como JSON strings

## Docs disponibles

- `docs/ARCHITECTURE.md` — Arquitectura detallada y decisiones de diseño
- `docs/ARCHITECTURE_COMPLIANCE.md` — Cumplimiento de arquitectura limpia
