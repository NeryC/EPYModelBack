# 🚀 EPI Model Backend API

<div align="center">

![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Express](https://img.shields.io/badge/Express-000000?style=for-the-badge&logo=express&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

**Backend API for epidemiological model with clean architecture and TypeScript**

[Features](#-features) • [Quick Start](#-quick-start) • [Architecture](#-architecture) • [API](#-api-documentation) • [Deployment](#-deployment)

</div>

---

## 📋 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Technologies](#-technologies)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [Available Scripts](#-available-scripts)
- [API Documentation](#-api-documentation)
- [Development](#-development)
- [Testing](#-testing)
- [Deployment](#-deployment)
- [Monitoring and Logging](#-monitoring-and-logging)
- [Troubleshooting](#-troubleshooting)
- [Contribution](#-contribution)
- [License](#-license)

---

## ✨ Features

### 🎯 Main Features

- ✅ **Complete RESTful API** for epidemiological simulations and projections
- ✅ **Clean Architecture** with separation of concerns
- ✅ **TypeScript** with strict typing for enhanced security and maintainability
- ✅ **Data Validation** with Zod for runtime and type-safe validation
- ✅ **API Documentation** with Swagger/OpenAPI
- ✅ **Metrics** with Prometheus for monitoring
- ✅ **Structured Logging** with Pino for traceability
- ✅ **Background Jobs** with BullMQ and Redis (fallback to node-cron)
- ✅ **Security** with Helmet, configurable CORS and Rate Limiting
- ✅ **Python/R Integration** for complex epidemiological models
- ✅ **Docker** ready for production

### 🏗️ Architecture

- **Clean Architecture** with well-defined layers
- **SOLID Principles** consistently applied
- **Repository Pattern** for data abstraction
- **Use Case Pattern** for business logic
- **Dependency Injection** for decoupling

---

## 🚀 Quick Start

### Prerequisites

Before starting, make sure you have installed:

- **Node.js** 18+ ([Download](https://nodejs.org/))
- **npm** or **yarn** (included with Node.js)
- **Python** 3.8+ ([Download](https://www.python.org/downloads/))
- **R** 4.0+ ([Download](https://cran.r-project.org/))
- **Redis** (optional, for background jobs) ([Download](https://redis.io/download))
- **Docker** (optional, for containers) ([Download](https://www.docker.com/get-started))

### Installation

1. **Clone the repository**

```bash
git clone <repository-url>
cd newBack
```

2. **Install dependencies**

```bash
npm install
# or
yarn install
```

3. **Configure environment variables**

```bash
cp config.example.env .env
```

Edit the `.env` file with your configurations:

```env
NODE_ENV=development
PORT=3001
LOG_LEVEL=debug
CORS_ORIGIN=http://localhost:3000
REDIS_URL=redis://localhost:6379
```

4. **Compile TypeScript**

```bash
npm run build
```

5. **Start the server**

```bash
# Development
npm run dev

# Production
npm start
```

6. **Verify it works**

Open your browser at: `http://localhost:3001/health`

You should see:

```json
{
  "status": "OK",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "environment": "development",
  "port": 3001
}
```

---

## 🏗️ Architecture

### Overview

The project follows **Clean Architecture** principles, organizing code in concentric layers where inner layers do not depend on outer layers.

```
┌─────────────────────────────────────────────────────────┐
│              Presentation Layer (API)                    │
│         Controllers, Routes, DTOs, Middleware            │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│              Application Layer                           │
│         Use Cases, Application Services                  │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                 Domain Layer                             │
│      Entities, Interfaces, Value Objects                 │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│            Infrastructure Layer                           │
│    Repositories, External Services, Adapters             │
└──────────────────────────────────────────────────────────┘
```

### Detailed Layers

#### 1. **Domain Layer** (`src/domain/`)

Contains business entities and repository interfaces. It is the innermost layer and does not depend on any other layer.

- **Entities**: `Simulation`, `Projection`
- **Interfaces**: `ISimulationRepository`, `IProjectionRepository`
- **Value Objects**: Domain primitive types

#### 2. **Application Layer** (`src/application/`)

Contains use cases that orchestrate business logic.

- **Use Cases**: `execute-simulation.ts`, `get-projections.ts`
- **Application DTOs**: Input/Output of use cases

#### 3. **Infrastructure Layer** (`src/infrastructure/`)

Implements adapters for external services and technical details.

- **Repositories**: Repository implementations
- **Adapters**: Adapters for Python/R scripts
- **Storage**: File management
- **Jobs**: BullMQ, node-cron
- **Logging**: Pino configuration

#### 4. **Presentation/API Layer** (`src/api/`, `src/controllers/`, `src/routes/`)

Handles HTTP requests, validation, and data transformation.

- **Controllers**: HTTP request handling
- **Routes**: Route definitions
- **DTOs**: Validation with Zod
- **Middleware**: Validation, authentication, logging

### Data Flow

```
HTTP Request
    ↓
Route → Middleware (Validation)
    ↓
Controller (Transforms DTO → Domain Input)
    ↓
Use Case (Business Logic)
    ↓
Repository (Infrastructure - Implements Domain interface)
    ↓
Response (Domain Output → DTO → HTTP Response)
```

### Dependency Rules

| Layer | Can Import From |
|-------|----------------|
| **Domain** | Only `shared` |
| **Application** | `domain`, `shared`, `config` |
| **Infrastructure** | `domain`, `application`, `shared`, `config` |
| **API/Presentation** | All layers |

📖 **Complete architecture documentation**: See [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)

---

## 🛠️ Technologies

### Core

- **Node.js** 18+ - JavaScript runtime
- **TypeScript** 5.8+ - Typed JavaScript superset
- **Express.js** 4.18+ - Minimalist web framework

### Validation and Types

- **Zod** 3.23+ - Runtime and type-safe validation
- **TypeScript** - Static typing

### Logging and Monitoring

- **Pino** 9.9+ - High-performance structured logger
- **Prometheus** 15.1+ - Metrics and monitoring

### Jobs and Tasks

- **BullMQ** 5.58+ - Queue system with Redis
- **node-cron** 3.0+ - Task scheduler (fallback)

### Security

- **Helmet** 7.2+ - HTTP security headers
- **express-rate-limit** 7.5+ - Rate limiting
- **CORS** 2.8+ - Cross-origin access control

### Documentation

- **Swagger/OpenAPI** - Interactive API documentation
- **swagger-jsdoc** 6.2+ - Documentation generation from comments
- **swagger-ui-express** 5.0+ - Swagger UI

### External Integration

- **python-shell** 5.0+ - Python script execution
- **danfojs-node** 1.1+ - Data manipulation

### Development

- **ESLint** 9.34+ - Code linter
- **Prettier** 3.6+ - Code formatter
- **nodemon** 3.1+ - Hot reload in development
- **concurrently** 9.2+ - Run commands in parallel

---

## 📁 Project Structure

```
newBack/
├── src/                          # Source code
│   ├── api/                      # API Layer
│   │   ├── v1/                   # Versioned API
│   │   │   ├── simulations/      # Simulation DTOs
│   │   │   ├── projections/      # Projection DTOs
│   │   │   └── files/            # File routes
│   │   ├── docs/                 # Swagger/OpenAPI
│   │   └── metrics/              # Prometheus metrics
│   ├── application/              # Application Layer
│   │   ├── simulations/          # Simulation use cases
│   │   ├── projections/          # Projection use cases
│   │   └── main-flow.ts          # Main update flow
│   ├── domain/                   # Domain Layer
│   │   ├── simulation.ts         # Simulation entity and interfaces
│   │   └── projection.ts         # Projection entity and interfaces
│   ├── infrastructure/           # Infrastructure Layer
│   │   ├── storage/              # Storage repositories
│   │   ├── processes/            # External process adapters
│   │   ├── jobs/                 # Job system (BullMQ)
│   │   └── logging/              # Logging configuration
│   ├── controllers/              # HTTP Controllers
│   │   ├── simulationController.ts
│   │   └── projectionController.ts
│   ├── routes/                   # Route definitions
│   │   ├── simulationRoutes.ts
│   │   └── projectionRoutes.ts
│   ├── middleware/               # Express middleware
│   │   ├── validationMiddleware.ts
│   │   └── zodValidator.ts
│   ├── services/                 # Application services (legacy)
│   ├── shared/                   # Shared utilities
│   ├── types/                    # Global TypeScript types
│   ├── config/                   # Configuration
│   │   └── environment.ts        # Environment variables
│   ├── utils/                    # Utilities (legacy - migrate to shared)
│   ├── worker/                   # Worker for background jobs
│   ├── scripts/                  # Python scripts
│   ├── model_seirh/              # R/Stan models
│   └── index.ts                  # Entry point
├── dist/                          # Compiled code (generated)
├── public/                       # Public files
│   ├── data/                     # Processed data
│   ├── rawData/                  # Raw data
│   └── results/                  # Simulation results
├── storage/                      # Private storage
│   └── results/                  # Simulation results
├── docs/                         # Documentation
│   └── ARCHITECTURE.md           # Architecture documentation
├── packageScripts/               # Legacy npm scripts
├── config.example.env            # Configuration example
├── Dockerfile                    # Docker image
├── tsconfig.json                 # TypeScript configuration
├── eslint.config.js              # ESLint configuration
├── nodemon.json                  # Nodemon configuration
├── package.json                  # Dependencies and scripts
└── README.md                     # This file
```

---

## ⚙️ Configuration

### Environment Variables

Create a `.env` file based on `config.example.env`:

```env
# Environment
NODE_ENV=development                    # development | production | test
PORT=3001                              # Server port
LOG_LEVEL=debug                        # debug | info | warn | error

# CORS
CORS_ORIGIN=http://localhost:3000      # Allowed origins (comma-separated) or "*"

# Redis (Optional - for BullMQ)
REDIS_URL=redis://localhost:6379      # Redis URL for background jobs

# Executable Paths (Optional)
PYTHON_PATH=python                     # Path to Python executable
R_PATH=R                               # Path to R executable
```

### TypeScript Configuration

The project uses TypeScript with strict configuration. See `tsconfig.json` for details.

**Enabled features**:
- `strict: true` - Full strict mode
- `noImplicitAny: true` - No implicit `any` allowed
- `strictNullChecks: true` - Strict null/undefined checking
- `noUncheckedIndexedAccess: true` - Safe array/object access

### ESLint Configuration

The project uses ESLint 9+ with modern configuration. See `eslint.config.js` for details.

---

## 📜 Available Scripts

### Development

```bash
# Full development (TypeScript watch + server with hot reload)
npm run dev

# TypeScript compilation only in watch mode
npm run dev:build

# Server only with nodemon (requires previous compilation)
npm run dev:server
```

### Production

```bash
# Compile TypeScript
npm run build

# Start production server
npm start

# Start worker for background jobs
npm run start:worker
```

### Code Quality

```bash
# Linting with ESLint
npm run lint

# Format code with Prettier
npm run format
```

### Legacy Scripts (Compatibility)

```bash
# Execute main update flow
npm run start-main-flow

# Download raw data
npm run download-raw-data

# Data pre-processing
npm run pre-processing

# Execute SEIRHUF model test
npm run test_seirhuf

# Generate graphic files
npm run generate-graphic

# Generate simulation files
npm run generate-simulation

# Get simulation (Python)
npm run get-simulation
```

---

## 📚 API Documentation

### Main Endpoints

#### Health Check

```http
GET /health
```

**Response**:
```json
{
  "status": "OK",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "environment": "development",
  "port": 3001
}
```

#### Simulations

##### Get Simulation with Custom Parameters

```http
GET /api/v1/simulations?Rt=[1.1,1.2,1.3]&UCI_threshold=100&V_filtered=1000&lambda_I_to_H=0.5
```

**Query Parameters**:
- `Rt` (string, required): JSON array of numbers representing the reproductive number
- `UCI_threshold` (string, required): UCI threshold (positive number)
- `V_filtered` (string, required): Filtered value (positive number)
- `lambda_I_to_H` (string, required): Transition rate from I to H (0-1)

**Success Response**:
```json
{
  "success": true,
  "data": {
    "cumulative": [...],
    "cumulative_deaths": [...],
    "exposed": [...],
    "hospitalized": [...],
    "immune": [...],
    "infectious": [...],
    "susceptible": [...],
    "uci": [...]
  },
  "message": "Simulation completed successfully"
}
```

##### Get First Simulation (Default)

```http
GET /api/v1/get-first-simulation
```

**Response**: JSON file for download

##### Get First Simulation Data

```http
GET /api/v1/get-first-simulation-data
```

**Response**:
```json
{
  "success": true,
  "data": { /* simulation data */ },
  "message": "First simulation data retrieved successfully"
}
```

#### Projections

```http
GET /api/v1/projections
```

**Response**:
```json
{
  "success": true,
  "data": [ /* array of projections */ ],
  "message": "Projections retrieved successfully"
}
```

#### Files

```http
GET /api/v1/files
```

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "filename.json",
      "createdAt": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

### Interactive Documentation

In development mode, Swagger documentation is available at:

```
http://localhost:3001/api-docs
```

### Metrics

```http
GET /api/v1/metrics
```

Returns metrics in Prometheus format.

---

## 💻 Development

### Development Environment Setup

1. **Install dependencies**:
```bash
npm install
```

2. **Configure environment variables**:
```bash
cp config.example.env .env
# Edit .env as needed
```

3. **Start in development mode**:
```bash
npm run dev
```

The server will start at `http://localhost:3001` with hot reload enabled.

### Adding a New Endpoint Structure

To add a new endpoint, follow these steps:

1. **Define DTO in `api/v1/`**:
```typescript
// api/v1/new-feature/dto.ts
import { z } from 'zod';

export const NewFeatureQuerySchema = z.object({
  param1: z.string(),
  param2: z.number().positive(),
});
```

2. **Create Use Case in `application/`**:
```typescript
// application/new-feature/get-feature.ts
export async function getFeatureUseCase(
  input: NewFeatureInput
): Promise<NewFeatureOutput> {
  // Use case logic
}
```

3. **Create Controller**:
```typescript
// controllers/newFeatureController.ts
export class NewFeatureController {
  getFeature = asyncHandler(async (req, res) => {
    const validated = NewFeatureQuerySchema.parse(req.query);
    const result = await getFeatureUseCase(validated);
    res.json({ success: true, data: result });
  });
}
```

4. **Define Route**:
```typescript
// routes/newFeatureRoutes.ts
router.get('/new-feature', 
  validateQuery(NewFeatureQuerySchema),
  controller.getFeature
);
```

5. **Register route in `index.ts`**:
```typescript
app.use('/api/v1', newFeatureRoutes);
```

### Code Conventions

- **Naming**: 
  - Files: `kebab-case.ts`
  - Classes: `PascalCase`
  - Functions: `camelCase`
  - Constants: `UPPER_SNAKE_CASE`

- **Imports**: Sort alphabetically, group by type
- **Documentation**: JSDoc on public functions
- **Types**: Use interfaces instead of types when possible

### Hot Reload

Development mode includes:
- **TypeScript watch**: Automatically recompiles when `.ts` files change
- **Nodemon**: Restarts server when compiled files change

---

## 🧪 Testing

### Linting

```bash
npm run lint
```

### Formatting

```bash
npm run format
```

### Type Validation

```bash
npm run build
```

TypeScript will validate all types during compilation.

---

## 🚀 Deployment

### Docker

#### Build Image

```bash
docker build -t epi-model-back .
```

#### Run Container

```bash
docker run -p 3001:3001 \
  -e NODE_ENV=production \
  -e PORT=3001 \
  -e CORS_ORIGIN=https://yourdomain.com \
  epi-model-back
```

#### Docker Compose (if available)

```bash
docker-compose up -d
```

### Production

#### Production Environment Variables

```env
NODE_ENV=production
PORT=3001
LOG_LEVEL=info
CORS_ORIGIN=https://yourdomain.com
REDIS_URL=redis://your-redis:6379
```

#### Deployment Process

1. **Compile**:
```bash
npm run build
```

2. **Verify**:
```bash
npm run lint
```

3. **Start**:
```bash
npm start
```

#### Worker in Production

To process background jobs, start the worker:

```bash
npm run start:worker
```

---

## 📊 Monitoring and Logging

### Logging

The project uses **Pino** for structured logging. Logs include:

- **Request ID**: Unique identifier per request
- **Log Level**: debug, info, warn, error
- **Context**: Additional structured information
- **Timestamp**: Date and time of the event

**Log Example**:
```json
{
  "level": 30,
  "time": 1704067200000,
  "id": "req-123",
  "method": "GET",
  "path": "/api/v1/simulations",
  "status": 200,
  "msg": "request:finish"
}
```

### Metrics

Prometheus metrics are available at `/api/v1/metrics` and include:

- Number of HTTP requests
- Response time
- Errors per endpoint
- Resource usage

### Health Checks

The `/health` endpoint provides information about the system status:

```json
{
  "status": "OK",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "environment": "production",
  "port": 3001
}
```

---

## 🔧 Troubleshooting

### Common Issues

#### Error: "Cannot find module"

**Solution**: Make sure you have run `npm install` and `npm run build`.

#### Error: "Port already in use"

**Solution**: Change the port in `.env` or terminate the process using the port.

#### Error: "Python script execution failed"

**Solution**: 
- Verify that Python 3.8+ is installed
- Verify that Python dependencies are installed
- Check logs for more details

#### Error: "Redis connection failed"

**Solution**: 
- If Redis is optional, you can continue without it (will use node-cron as fallback)
- If required, verify that Redis is running and the URL is correct

### Debug Logs

To get more detailed logs, configure:

```env
LOG_LEVEL=debug
```

### Verify Dependencies

```bash
# Verify Node.js
node --version  # Should be 18+

# Verify Python
python --version  # Should be 3.8+

# Verify R
R --version  # Should be 4.0+
```

---

## 🤝 Contribution

### Contribution Process

1. **Fork** the project
2. **Create** a feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

### Code Standards

- Follow naming conventions
- Add JSDoc documentation to public functions
- Run `npm run lint` and `npm run format` before committing
- Make sure code compiles without errors (`npm run build`)

### Pull Request Checklist

- [ ] Code follows the defined architecture
- [ ] Tests pass (if they exist)
- [ ] Code is formatted (`npm run format`)
- [ ] No linting errors (`npm run lint`)
- [ ] Documentation is updated
- [ ] TypeScript types are correct

---

## 📄 License

This project is under the ISC License.

---