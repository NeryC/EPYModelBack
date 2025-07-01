# Arquitectura del Backend

## Estructura de Carpetas

```
src/
├── routes/           # Definición de rutas (solo endpoints)
├── controllers/      # Lógica de manejo de requests/responses
├── services/         # Lógica de negocio
├── models/           # Modelos de datos
├── utils/            # Utilidades compartidas
├── middleware/       # Middlewares personalizados
├── types/            # Definiciones de tipos TypeScript
└── config/           # Configuraciones
```

## Patrón de Arquitectura

Seguimos el patrón **Layered Architecture** (Arquitectura en Capas) para separar
responsabilidades:

### 1. Routes (Capa de Rutas)

- **Responsabilidad**: Solo definir endpoints y middlewares
- **No debe contener**: Lógica de negocio, validaciones complejas
- **Ejemplo**:

```typescript
router.get(
  "/projections",
  validateProjectionFormat,
  projectionController.getProjections
);
```

### 2. Controllers (Capa de Controladores)

- **Responsabilidad**: Manejar requests/responses, validaciones básicas
- **No debe contener**: Lógica de negocio compleja
- **Ejemplo**:

```typescript
getProjections = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const format = (req.query.format as "json" | "csv") || "json";
    const projections = await this.projectionService.getAllProjections(format);
    res.json({ success: true, projections });
  }
);
```

### 3. Services (Capa de Servicios)

- **Responsabilidad**: Lógica de negocio, acceso a datos
- **No debe contener**: Lógica de HTTP, headers, status codes
- **Ejemplo**:

```typescript
async getAllProjections(format: FormatType): Promise<Record<ProjectionType, any>> {
  const projectionTypes: ProjectionType[] = ["R", "H", "U", "F"];
  const readPromises = projectionTypes.map((type) =>
    this.readProjectionFile(type, format).then((content) => ({ type, content }))
  );
  return await Promise.all(readPromises);
}
```

### 4. Middleware (Capa de Middleware)

- **Responsabilidad**: Validaciones, autenticación, logging
- **Reutilizable**: Aplicable a múltiples rutas
- **Ejemplo**:

```typescript
export const validateProjectionFormat = validateParams([
  {
    field: "format",
    type: "string",
    enum: ["json", "csv"],
  },
]);
```

## Ventajas de esta Arquitectura

### ✅ Separación de Responsabilidades

- Cada capa tiene una responsabilidad específica
- Fácil de mantener y testear
- Código más legible y organizado

### ✅ Reutilización

- Los servicios pueden ser usados por múltiples controladores
- Los middlewares pueden aplicarse a diferentes rutas
- Lógica de negocio centralizada

### ✅ Testabilidad

- Cada capa puede ser testeada independientemente
- Fácil mock de dependencias
- Tests más específicos y rápidos

### ✅ Escalabilidad

- Fácil agregar nuevas funcionalidades
- Cambios en una capa no afectan otras
- Patrón consistente en todo el proyecto

### ✅ Mantenibilidad

- Código más limpio y organizado
- Fácil debugging
- Menor acoplamiento entre componentes

## Ejemplos de Uso

### Antes (Código Original)

```typescript
// routes/projectionRoutes.ts - Mezclaba responsabilidades
router.get(
  "/projections",
  asyncHandler(async (req, res) => {
    const format = req.query.format || "json";
    if (!["json", "csv"].includes(format)) {
      throw new AppError("Invalid format", 400);
    }
    // Lógica de negocio mezclada con manejo de HTTP
    const projections = await readProjectionFiles(format);
    res.json({ projections });
  })
);
```

### Después (Código Refactorizado)

```typescript
// routes/projectionRoutes.ts - Solo rutas
router.get("/projections", validateProjectionFormat, projectionController.getProjections);

// controllers/projectionController.ts - Manejo de HTTP
getProjections = asyncHandler(async (req, res) => {
  const format = (req.query.format as "json" | "csv") || "json";
  const projections = await this.projectionService.getAllProjections(format);
  res.json({ success: true, projections });
});

// services/projectionService.ts - Lógica de negocio
async getAllProjections(format: FormatType): Promise<Record<ProjectionType, any>> {
  // Lógica de negocio pura
}
```

### Ejemplo de Simulación Refactorizada

```typescript
// routes/simulationRoutes.ts - Solo rutas
router.get(
  "/get-simulation",
  validateSimulationParams,
  simulationController.getSimulation
);

// controllers/simulationController.ts - Manejo de HTTP
getSimulation = asyncHandler(async (req, res) => {
  const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = req.query;

  // Validación y ejecución delegada al servicio
  this.simulationService.validateSimulationParams({
    Rt: Rt as string,
    UCI_threshold: UCI_threshold as string,
    V_filtered: V_filtered as string,
    lambda_I_to_H: lambda_I_to_H as string,
  });

  const result = await this.simulationService.executeSimulation({
    Rt: Rt as string,
    UCI_threshold: UCI_threshold as string,
    V_filtered: V_filtered as string,
    lambda_I_to_H: lambda_I_to_H as string,
  });

  res.json({ success: true, data: result });
});

// services/simulationService.ts - Lógica de negocio
async executeSimulation(params: SimulationParams): Promise<any> {
  // Lógica de negocio pura para ejecutar simulaciones
}
```

## Convenciones de Naming

- **Controllers**: `*Controller.ts` (ej: `ProjectionController`,
  `SimulationController`)
- **Services**: `*Service.ts` (ej: `ProjectionService`, `SimulationService`)
- **Routes**: `*Routes.ts` (ej: `projectionRoutes.ts`, `simulationRoutes.ts`)
- **Middleware**: `*Middleware.ts` (ej: `validationMiddleware.ts`)

## Próximos Pasos

1. **Implementar más middlewares**: Autenticación, rate limiting, logging
2. **Agregar tests unitarios**: Para cada capa independientemente
3. **Documentación de API**: Swagger/OpenAPI
4. **Error handling centralizado**: Middleware de manejo de errores
5. **Logging estructurado**: Para mejor debugging y monitoreo
