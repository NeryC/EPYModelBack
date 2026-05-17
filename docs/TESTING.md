# Backend Test Plan (newBack)

> Following IEEE 829-2008 _Standard for Software and System Test Documentation_.

## 1. Test plan identifier

`newBack-test-plan-2026-05`

## 2. Introduction

This document describes the test plan for the EPI Model backend API. It is part of the final-thesis deliverable. The full design and rationale live in `docs/superpowers/specs/2026-05-17-testing-system-design.md`.

## 3. Test items

- All TypeScript source under `src/` (Clean Architecture: Domain, Application, Infrastructure, Presentation).
- Public HTTP endpoints: `/health`, `/api/v1/simulations`, `/api/v1/projections`, `/api/v1/get-first-simulation-data`, `/api/v1/metrics`.
- Background jobs (BullMQ on Redis).

## 4. Features to be tested

- Input validation (Zod schemas).
- Use cases (Application layer) — happy paths and error paths.
- HTTP layer — request/response shape, status codes, error handling.
- SEIRHUF model invariants (property-based).
- Worker job processing (BullMQ + Redis).
- Response contract (responses match published Zod schemas).

## 5. Features not to be tested

- Python/R scripts themselves (out of scope — TypeScript test framework cannot directly assert on them; covered indirectly via integration with stubbed adapter outputs).
- Real load behavior (no SLA, see §4.3 of the design spec).
- Visual regression of Swagger UI.

## 6. Approach

Five test levels (see `docs/superpowers/specs/2026-05-17-testing-system-design.md` §4.1):

| Level                       | Tool                    |
| --------------------------- | ----------------------- |
| Unit                        | Vitest + `vi.mock`      |
| Property-based              | fast-check              |
| Integration (HTTP)          | Vitest + Supertest      |
| Integration (with services) | Vitest + Testcontainers |
| Mutation                    | Stryker (vitest-runner) |

### Test design techniques applied

- Boundary Value Analysis (ISTQB §4.2)
- Equivalence Partitioning (ISTQB §4.2)
- Property-based testing (Claessen & Hughes 2000)
- Contract testing (Fowler 2006)

## 7. Item pass / fail criteria

A test item passes when:

- Its associated tests pass.
- Coverage for its layer meets the threshold in `vitest.config.ts > coverage.thresholds`.
- For business-logic layers, mutation score >= 75%.

## 8. Suspension and resumption criteria

- Suspension: a flaky test is suspended only if a fix is filed and tracked. Skipped tests are not allowed in main.
- Resumption: when the root cause is fixed and a regression test exists.

## 9. Test deliverables

- All test files (co-located under `src/**/*.test.ts` and `tests/`).
- Coverage HTML report under `coverage/`.
- Mutation HTML report under `reports/mutation/`.
- This document, `docs/TEST_TRACEABILITY.md`, `docs/TEST_METRICS.md`.

## 10. Test environment

- Node 18.x and 20.x.
- Docker daemon required for integration tests with Testcontainers.
- No external network access required (everything mocked or containerised).

## 11. Responsibilities

- Author (thesis owner): designs, writes, and maintains the suite.
- CI: runs the suite on every PR and on every push to main.

## 12. Schedule

- Set-up phase: Phase 0–2 of the implementation plan.
- Test writing: Phase 3–8.
- Mutation testing: Phase 9.
- CI + hooks: Phase 10–11.
- Documentation freeze: Phase 12.

## 13. How to run the suite

```bash
npm install
npm run test:unit          # ~15s
npm run test:integration   # ~60-120s (requires Docker)
npm run test:coverage      # ~30s + threshold gate
npm run test:mutation      # ~5-15 min
npm run test:ci            # unit + integration + coverage gates
```

## 14. Troubleshooting

| Symptom                                                          | Likely cause                       | Fix                                                                                                                                                                                               |
| ---------------------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Testcontainers tests fail with `Cannot connect to Docker daemon` | Docker not running                 | Start Docker Desktop / `systemctl start docker`. Or run with `SKIP_TESTCONTAINERS=1` to skip them.                                                                                                |
| Coverage threshold fails on a new file                           | The layer's threshold is not met   | Add tests for the new file, or, if it is intentionally excluded, add it to `coverage.exclude` in `vitest.config.ts`.                                                                              |
| Stryker times out                                                | Test runner slow on large mutants  | Increase `timeoutMS` in `stryker.conf.json`.                                                                                                                                                      |
| `EADDRINUSE` from integration tests                              | A previous run left a server bound | Each `buildTestApp()` returns an in-memory Express instance; Supertest does **not** bind to a port. If you see this, you imported `src/index.ts` somewhere by mistake — import `src/app.ts` only. |
