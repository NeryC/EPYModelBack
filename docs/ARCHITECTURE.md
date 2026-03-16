# 🏗️ System Architecture - EPI Model Backend

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architectural Principles](#architectural-principles)
3. [Layer Structure](#layer-structure)
4. [Data Flow](#data-flow)
5. [Dependency Rules](#dependency-rules)
6. [Design Patterns](#design-patterns)
7. [Code Conventions](#code-conventions)
8. [Implementation Guide](#implementation-guide)

---

## 🎯 Overview

This project implements **Clean Architecture** with TypeScript, following the principles of separation of concerns and dependency inversion. The architecture is organized in concentric layers where inner layers do not depend on outer layers.

### Architecture Objectives

- ✅ **Testability**: Each layer can be tested independently
- ✅ **Maintainability**: Organized and easy to understand code
- ✅ **Scalability**: Easy to add new features
- ✅ **Independence**: Decoupling from external frameworks and technologies
- ✅ **Reusability**: Reusable business logic

---

## 🎨 Architectural Principles

### 1. Clean Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│              (Controllers, Routes, DTOs)                 │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                 Application Layer                         │
│              (Use Cases, Services)                        │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                    Domain Layer                          │
│         (Entities, Interfaces, Value Objects)            │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                Infrastructure Layer                       │
│    (Repositories, External Services, Adapters)           │
└──────────────────────────────────────────────────────────┘
```

### 2. SOLID Principles

- **S**ingle Responsibility: Each class/file has a single responsibility
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Implementations can be substituted
- **I**nterface Segregation: Specific and small interfaces
- **D**ependency Inversion: Depend on abstractions, not implementations

### 3. Separation of Concerns

Each layer has clearly defined responsibilities and should not know the details of other layers.

---

## 📁 Layer Structure

### 1. **Domain Layer** (`src/domain/`)

**Responsibility**: Contains business entities, repository interfaces, and domain rules.

**Content**:
- Domain entities (Simulation, Projection)
- Repository interfaces (ISimulationRepository, IProjectionRepository)
- Value Objects (domain primitive types)
- Domain exceptions

**Rules**:
- ❌ CANNOT import from other layers
- ✅ Only contains pure business logic
- ✅ Does not depend on external frameworks
- ✅ Can contain interfaces for repositories

**Example**:
```typescript
// domain/simulation.ts
export interface Simulation {
  id: string;
  parameters: SimulationParameters;
  results: SimulationResults;
  createdAt: Date;
}

export interface ISimulationRepository {
  save(simulation: Simulation): Promise<void>;
  findById(id: string): Promise<Simulation | null>;
}
```

---

### 2. **Application Layer** (`src/application/`)

**Responsibility**: Contains use cases and orchestrates business logic.

**Content**:
- Use cases (execute-simulation.ts, get-projections.ts)
- Application DTOs (Input/Output of use cases)
- Application services (if needed to coordinate multiple use cases)

**Rules**:
- ✅ Can import from `domain`
- ❌ CANNOT import from `infrastructure` directly
- ❌ CANNOT import from `api` or `controllers`
- ✅ Depends on domain interfaces (repositories)
- ✅ Implements high-level business logic

**Example**:
```typescript
// application/simulations/execute-simulation.ts
import { SimulationInput, SimulationOutput } from '../../domain/simulation.js';
import { ISimulationRepository } from '../../domain/simulation.js';

export async function executeSimulationUseCase(
  input: SimulationInput,
  repository: ISimulationRepository
): Promise<SimulationOutput> {
  // Use case logic
  // Uses repository through interface
}
```

---

### 3. **Infrastructure Layer** (`src/infrastructure/`)

**Responsibility**: Implements adapters for external services and technical details.

**Content**:
- Repository implementations (file-repository.ts)
- External process adapters (Python, R scripts)
- External service configuration (Redis, BullMQ)
- Logging, storage, etc.

**Rules**:
- ✅ Can import from `domain` and `application`
- ✅ Implements interfaces defined in `domain`
- ❌ CANNOT import from `api` or `controllers`
- ✅ Contains all technical and integration logic

**Example**:
```typescript
// infrastructure/storage/simulation-repository.ts
import { ISimulationRepository, Simulation } from '../../domain/simulation.js';

export class FileSimulationRepository implements ISimulationRepository {
  async save(simulation: Simulation): Promise<void> {
    // File-based implementation
  }
  
  async findById(id: string): Promise<Simulation | null> {
    // File-based implementation
  }
}
```

---

### 4. **Presentation/API Layer** (`src/api/`, `src/controllers/`, `src/routes/`)

**Responsibility**: Handles HTTP requests, input validation, and data transformation.

**Content**:
- Controllers (simulationController.ts)
- Routes (simulationRoutes.ts)
- API DTOs (dto.ts)
- Middleware (validation, authentication)
- Swagger/OpenAPI docs

**Rules**:
- ✅ Can import from all layers
- ✅ Transforms API DTOs to domain entities
- ✅ Handles HTTP errors and responses
- ❌ MUST NOT contain business logic
- ✅ Validates input with Zod

**Example**:
```typescript
// controllers/simulationController.ts
import { executeSimulationUseCase } from '../application/simulations/execute-simulation.js';
import { SimulationQuerySchema } from '../api/v1/simulations/dto.js';

export class SimulationController {
  getSimulation = asyncHandler(async (req: Request, res: Response) => {
    // 1. Validate input (DTO)
    const validated = SimulationQuerySchema.parse(req.query);
    
    // 2. Transform to Application Input
    const input = mapToSimulationInput(validated);
    
    // 3. Execute use case
    const result = await executeSimulationUseCase(input, repository);
    
    // 4. Transform and respond
    res.json(mapToApiResponse(result));
  });
}
```

---

### 5. **Shared Layer** (`src/shared/`)

**Responsibility**: Shared utilities without business dependencies.

**Content**:
- Shared constants
- Generic utilities (helpers)
- Common types

**Rules**:
- ✅ Can be imported by any layer
- ❌ MUST NOT contain specific business logic
- ✅ Only generic and reusable utilities

---

### 6. **Config Layer** (`src/config/`)

**Responsibility**: Application configuration.

**Content**:
- Environment variables
- Service configuration
- Configuration validation

---

## 🔄 Data Flow

### Typical Request Flow

```
1. HTTP Request
   ↓
2. Route (routes/simulationRoutes.ts)
   ↓
3. Middleware (validation with Zod)
   ↓
4. Controller (controllers/simulationController.ts)
   ├─ Validates input DTO
   ├─ Transforms DTO → Domain Input
   ↓
5. Use Case (application/simulations/execute-simulation.ts)
   ├─ Executes business logic
   ├─ Uses repository (domain interface)
   ↓
6. Repository Implementation (infrastructure/storage/...)
   ├─ Implements domain interface
   ├─ Accesses storage/files
   ↓
7. Response
   ├─ Domain Output → API DTO
   ├─ Controller → HTTP Response
```

### Complete Example

```typescript
// 1. Route
router.get('/simulations', 
  validateQuery(SimulationQuerySchema),
  controller.getSimulation
);

// 2. Controller
getSimulation = asyncHandler(async (req, res) => {
  const query = SimulationQuerySchema.parse(req.query);
  const input: SimulationInput = {
    Rt: query.Rt,
    UCI_threshold: query.UCI_threshold,
    // ...
  };
  
  const result = await executeSimulationUseCase(input, simulationRepository);
  res.json({ success: true, data: result });
});

// 3. Use Case
export async function executeSimulationUseCase(
  input: SimulationInput,
  repository: ISimulationRepository
): Promise<SimulationOutput> {
  // Validate business rules
  // Execute simulation
  // Save result
  return result;
}

// 4. Repository (Infrastructure)
export class FileSimulationRepository implements ISimulationRepository {
  // File-based implementation
}
```

---

## 🔒 Dependency Rules

### Allowed Dependencies Matrix

| From \ To | Domain | Application | Infrastructure | API/Presentation | Shared | Config |
|-----------|--------|-------------|----------------|-------------------|--------|--------|
| **Domain**     | ✅     | ❌          | ❌             | ❌                | ✅     | ❌     |
| **Application**| ✅     | ✅          | ❌             | ❌                | ✅     | ✅     |
| **Infrastructure**| ✅  | ✅          | ✅             | ❌                | ✅     | ✅     |
| **API/Presentation**| ✅ | ✅      | ✅             | ✅                | ✅     | ✅     |
| **Shared**    | ❌     | ❌          | ❌             | ❌                | ✅     | ❌     |
| **Config**    | ❌     | ❌          | ❌             | ❌                | ✅     | ✅     |

### Key Rules

1. **Domain** is the innermost layer and does not depend on anything
2. **Application** only depends on Domain
3. **Infrastructure** implements Domain interfaces
4. **API/Presentation** can use all layers
5. **Shared** is independent and can be used by everyone

---

## 🎭 Design Patterns

### 1. Repository Pattern

**Purpose**: Abstract data access

```typescript
// Domain: Interface
export interface ISimulationRepository {
  save(simulation: Simulation): Promise<void>;
  findById(id: string): Promise<Simulation | null>;
}

// Infrastructure: Implementation
export class FileSimulationRepository implements ISimulationRepository {
  // File-based implementation
}
```

### 2. Use Case Pattern

**Purpose**: Encapsulate business logic

```typescript
// Application: Use case
export async function executeSimulationUseCase(
  input: SimulationInput,
  repository: ISimulationRepository
): Promise<SimulationOutput> {
  // Use case logic
}
```

### 3. Adapter Pattern

**Purpose**: Adapt external services

```typescript
// Infrastructure: Adapter
export class PythonSimulationAdapter {
  async executeSimulation(params: SimulationParams): Promise<string> {
    // Adapts calls to Python
  }
}
```

### 4. DTO Pattern

**Purpose**: Transfer data between layers

```typescript
// API: Input DTO
export const SimulationQuerySchema = z.object({
  Rt: z.string(),
  // ...
});

// Application: Use case Input
export interface SimulationInput {
  Rt: string;
  // ...
}
```

---

## 📝 Code Conventions

### Naming

- **Files**: kebab-case (`execute-simulation.ts`)
- **Classes**: PascalCase (`SimulationController`)
- **Functions**: camelCase (`executeSimulationUseCase`)
- **Interfaces**: PascalCase with optional `I` prefix (`ISimulationRepository`)
- **Types**: PascalCase (`SimulationInput`, `SimulationOutput`)
- **Constants**: UPPER_SNAKE_CASE (`SIMULATION_FILE_PATH`)

### File Structure

```
src/
├── domain/
│   ├── simulation.ts          # Entity and interfaces
│   └── projection.ts
├── application/
│   ├── simulations/
│   │   ├── execute-simulation.ts
│   │   └── get-first-simulation.ts
│   └── projections/
│       └── get-projections.ts
├── infrastructure/
│   ├── storage/
│   │   └── simulation-repository.ts
│   └── processes/
│       └── simulation-adapter.ts
├── api/
│   └── v1/
│       └── simulations/
│           └── dto.ts
├── controllers/
│   └── simulationController.ts
└── routes/
    └── simulationRoutes.ts
```

### Imports

- ✅ Use absolute imports when possible
- ✅ Group imports: external, internal, relative
- ✅ Sort imports alphabetically
- ✅ Use `.js` in imports (TypeScript ESM)

```typescript
// 1. External dependencies
import express from 'express';
import { z } from 'zod';

// 2. Internal - Domain
import { SimulationInput } from '../../domain/simulation.js';

// 3. Internal - Application
import { executeSimulationUseCase } from '../../application/simulations/execute-simulation.js';

// 4. Internal - Infrastructure
import { FileSimulationRepository } from '../../infrastructure/storage/simulation-repository.js';
```

---

## 🚀 Implementation Guide

### Adding a New Feature

1. **Define in Domain**:
   ```typescript
   // domain/new-feature.ts
   export interface NewFeature {
     id: string;
     // properties
   }
   
   export interface INewFeatureRepository {
     save(feature: NewFeature): Promise<void>;
   }
   ```

2. **Create Use Case in Application**:
   ```typescript
   // application/new-feature/create-feature.ts
   export async function createFeatureUseCase(
     input: NewFeatureInput,
     repository: INewFeatureRepository
   ): Promise<NewFeatureOutput> {
     // Logic
   }
   ```

3. **Implement Repository in Infrastructure**:
   ```typescript
   // infrastructure/storage/new-feature-repository.ts
   export class FileNewFeatureRepository implements INewFeatureRepository {
     // Implementation
   }
   ```

4. **Create Controller and Routes**:
   ```typescript
   // controllers/newFeatureController.ts
   export class NewFeatureController {
     create = asyncHandler(async (req, res) => {
       // Validate, transform, execute, respond
     });
   }
   ```

5. **Define DTOs**:
   ```typescript
   // api/v1/new-feature/dto.ts
   export const NewFeatureQuerySchema = z.object({
     // Validation
   });
   ```

---

## ✅ Compliance Checklist

When implementing code, verify:

- [ ] Does the layer only import from allowed layers?
- [ ] Are interfaces in Domain?
- [ ] Are use cases in Application?
- [ ] Are implementations in Infrastructure?
- [ ] Are DTOs separated by layer?
- [ ] Is there no business logic in Controllers?
- [ ] Are there no framework dependencies in Domain?
- [ ] Do names follow conventions?
- [ ] Are imports ordered?
- [ ] Is there JSDoc documentation on public functions?

---

## 📚 References

- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)
- [Use Case Pattern](https://martinfowler.com/bliki/UseCase.html)

---

**Last updated**: 2024  
**Architecture Version**: 1.0.0
