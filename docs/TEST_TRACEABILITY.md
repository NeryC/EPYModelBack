# Requirements ↔ Tests Traceability Matrix

> Conforms to ISO/IEC/IEEE 29119-3:2021 §6.3.

Each requirement is derived from `CLAUDE.md` (project description), `docs/ARCHITECTURE.md`, or the design spec, and mapped to >=1 test.

| Req ID  | Requirement                                                                             | Covered by                                                                                |
| ------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| REQ-001 | `GET /health` returns 200 with status field                                             | `tests/integration/health.integration.test.ts`                                            |
| REQ-002 | `GET /api/v1/simulations` validates query params and returns simulation series          | `tests/integration/simulations.integration.test.ts`                                       |
| REQ-003 | `Rt` must be a JSON array of numbers                                                    | `src/api/v1/simulations/dto.test.ts`                                                      |
| REQ-004 | `UCI_threshold` ∈ (0, 10000]                                                            | `src/api/v1/simulations/dto.test.ts` (BVA)                                                |
| REQ-005 | `V_filtered` ∈ (0, 1_000_000]                                                           | `src/api/v1/simulations/dto.test.ts` (BVA)                                                |
| REQ-006 | `lambda_I_to_H` ∈ [0, 1]                                                                | `src/api/v1/simulations/dto.test.ts` (BVA)                                                |
| REQ-007 | `GET /api/v1/projections` accepts `format=json\|csv` and defaults to `json`             | `src/api/v1/projections/dto.test.ts`, `tests/integration/projections.integration.test.ts` |
| REQ-008 | `GET /api/v1/get-first-simulation-data` returns JSON with full SEIRHUF series           | `tests/integration/firstSimulation.integration.test.ts`                                   |
| REQ-009 | `GET /api/v1/metrics` returns Prometheus text format                                    | `tests/integration/metrics.integration.test.ts`                                           |
| REQ-010 | Use case `executeSimulationUseCase` orchestrates the adapter and parses results         | `src/application/simulations/get-simulation.test.ts`                                      |
| REQ-011 | Use case `executeGetProjectionsUseCase` orchestrates the repository                     | `src/application/projections/get-projections.test.ts`                                     |
| REQ-012 | SEIRHUF compartments are non-negative for valid parameters                              | `tests/property/seirhuf.property.test.ts` Invariant 1                                     |
| REQ-013 | All SEIRHUF series share the same length                                                | `tests/property/seirhuf.property.test.ts` Invariant 2                                     |
| REQ-014 | Cumulative series are non-decreasing                                                    | `tests/property/seirhuf.property.test.ts` Invariant 3                                     |
| REQ-015 | Worker can enqueue + process a BullMQ job against Redis                                 | `tests/integration/bullmq.integration.test.ts`                                            |
| REQ-016 | HTTP responses conform to `ApiResponseSchema` / `SimulationResponseSchema`              | `tests/integration/contract.test.ts`                                                      |
| REQ-017 | `AppError` carries statusCode + isOperational; `asyncHandler` forwards errors to `next` | `src/utils/errorHandler.test.ts`                                                          |
| REQ-018 | Errors surface with consistent JSON shape `{ success: false, error }`                   | `tests/integration/simulations.integration.test.ts` (500 path), error handler in `app.ts` |
| REQ-019 | Every request carries an `X-Request-Id` header                                          | `tests/integration/health.integration.test.ts`                                            |
| REQ-020 | Mutation testing reports a score >= 75% on business layers                              | `npm run test:mutation` + Stryker report                                                  |
