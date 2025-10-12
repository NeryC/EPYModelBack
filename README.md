# 🚀 EPI Model Backend

Backend API para el modelo epidemiológico con arquitectura limpia y TypeScript.

## 🏗️ Arquitectura

El proyecto sigue principios de **Clean Architecture** con las siguientes capas:

- **Domain**: Interfaces y tipos de dominio
- **Application**: Casos de uso y lógica de negocio
- **Infrastructure**: Adaptadores y servicios externos
- **Shared**: Utilidades comunes
- **API**: Controladores y rutas

## 🚀 Inicio Rápido

### Prerrequisitos

- Node.js 18+
- npm o yarn
- Python 3.8+ (para scripts de simulación)
- R (para modelos estadísticos)

### Instalación

```bash
# Clonar el repositorio
git clone <repository-url>
cd newBack

# Instalar dependencias
npm install

# Compilar TypeScript
npm run build
```

### Desarrollo

```bash
# Modo desarrollo (compilación + servidor con hot reload)
npm run dev

# Solo compilación en watch mode
npm run dev:build

# Solo servidor con nodemon
npm run dev:server
```

### Producción

```bash
# Compilar
npm run build

# Iniciar servidor
npm start

# Iniciar worker (opcional)
npm run start:worker
```

## 📋 Scripts Disponibles

| Script                 | Descripción                                 |
| ---------------------- | ------------------------------------------- |
| `npm run dev`          | Desarrollo completo (TypeScript + servidor) |
| `npm run build`        | Compilar TypeScript                         |
| `npm start`            | Servidor de producción                      |
| `npm run start:worker` | Worker para jobs en background              |
| `npm run lint`         | Linting con ESLint                          |
| `npm run format`       | Formatear código con Prettier               |

## 🌐 Endpoints

### API v1

- **Health Check**: `GET /health`
- **Simulaciones**: `GET /api/v1/simulations`
- **Proyecciones**: `GET /api/v1/projections`
- **Archivos**: `GET /api/v1/files`

### Desarrollo

- **Swagger Docs**: `http://localhost:3001/api-docs`
- **Métricas**: `http://localhost:3001/api/v1/metrics`

## 🔧 Configuración

### Variables de Entorno

```env
NODE_ENV=development
PORT=3001
LOG_LEVEL=debug
CORS_ORIGIN=http://localhost:3000
REDIS_URL=redis://localhost:6379
```

### Puertos por Defecto

- **API**: 3001
- **Redis**: 6379 (opcional)

## 🛠️ Tecnologías

- **Backend**: Express.js + TypeScript
- **Validación**: Zod
- **Logging**: Pino
- **Jobs**: BullMQ + Redis (fallback a node-cron)
- **Seguridad**: Helmet + CORS + Rate Limiting
- **Métricas**: Prometheus
- **Documentación**: Swagger/OpenAPI
- **Linting**: ESLint + Prettier

## 📁 Estructura del Proyecto

```
src/
├── api/                 # API layer
│   ├── v1/             # API versionada
│   ├── docs/           # Swagger
│   └── metrics/        # Prometheus
├── application/        # Application layer
│   ├── simulations/    # Casos de uso simulaciones
│   └── projections/    # Casos de uso proyecciones
├── domain/             # Domain layer
├── infrastructure/     # Infrastructure layer
│   ├── jobs/          # BullMQ
│   ├── logging/       # Pino logger
│   ├── processes/     # Adaptadores Python/R
│   └── storage/       # File repository
├── shared/            # Shared utilities
├── config/            # Configuration
├── controllers/       # API controllers
├── middleware/        # Express middleware
├── routes/           # Express routes
└── types/            # TypeScript types
```

## 🔄 Jobs y Workers

El sistema incluye un worker separado para procesar jobs en background:

- **BullMQ**: Para jobs con Redis
- **node-cron**: Fallback sin Redis
- **Main Flow**: Actualización de datos automática

## 📊 Monitoreo

- **Logs estructurados**: Con request-id y contexto
- **Métricas Prometheus**: Performance y uso
- **Health checks**: Estado del sistema
- **Error handling**: Manejo centralizado de errores

## 🧪 Testing

```bash
# Linting
npm run lint

# Formatear código
npm run format
```

## 🚀 Despliegue

### Docker

```bash
# Construir imagen
docker build -t epi-model-back .

# Ejecutar contenedor
docker run -p 3001:3001 epi-model-back
```

### Variables de Producción

```env
NODE_ENV=production
PORT=3001
LOG_LEVEL=info
CORS_ORIGIN=https://yourdomain.com
REDIS_URL=redis://your-redis:6379
```

## 📝 Scripts Legacy

Para compatibilidad, se mantienen scripts legacy:

```bash
npm run download-raw-data
npm run pre-processing
npm run test_seirhuf
npm run generate-graphic
npm run generate-simulation
```

## 🤝 Contribución

1. Fork el proyecto
2. Crear feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia ISC.
