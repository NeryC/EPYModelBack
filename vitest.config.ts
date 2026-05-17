import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    pool: 'forks',
    projects: [
      {
        test: {
          name: 'unit',
          environment: 'node',
          include: ['src/**/*.test.ts', 'src/**/*.spec.ts', 'tests/property/**/*.test.ts'],
          exclude: ['tests/integration/**', 'node_modules/**', 'dist/**'],
        },
      },
      {
        test: {
          name: 'integration',
          environment: 'node',
          include: ['tests/integration/**/*.test.ts'],
          testTimeout: 60_000, // testcontainers may need time to start
          hookTimeout: 60_000,
        },
      },
    ],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      include: ['src/**/*.ts'],
      exclude: [
        'src/**/*.test.ts',
        'src/**/*.spec.ts',
        'src/types/**',
        'src/config/**',
        'src/scripts/**',
        'src/index.ts',
      ],
      thresholds: {
        // INITIAL (this release) — calibrated to current measured coverage with a growth headroom.
        // TARGET (thesis chapter freeze) — documented in docs/TEST_METRICS.md.
        // Risk-based per-layer thresholds: more rigorous on layers where tests already exist
        // and where the architectural risk is highest (business logic, validators, error utils).
        // NOTE: thresholds for `functions` on the DTO files reflect that only the
        // validation helpers actually called in tests are counted as covered;
        // the per-line/per-branch coverage of those DTOs is much higher (>85%).
        'src/api/v1/simulations/dto.ts': { lines: 95, branches: 90, functions: 70, statements: 95 },
        'src/api/v1/projections/dto.ts': { lines: 85, branches: 80, functions: 30, statements: 85 },
        'src/application/projections/**/*.ts': {
          lines: 95,
          branches: 90,
          functions: 90,
          statements: 95,
        },
        'src/application/simulations/**/*.ts': {
          lines: 70,
          branches: 80,
          functions: 70,
          statements: 70,
        },
        // simulationController.ts: only the GET /simulations and /first-simulation-data
        // paths are unit-tested; the upload / job-status paths are exercised in
        // integration tests but not yet reflected here. Threshold matches measured reality.
        'src/controllers/simulationController.ts': {
          lines: 60,
          branches: 75,
          functions: 90,
          statements: 60,
        },
        'src/middleware/zodValidator.ts': {
          lines: 95,
          branches: 90,
          functions: 90,
          statements: 95,
        },
        'src/utils/errorHandler.ts': { lines: 75, branches: 80, functions: 80, statements: 75 },
        // logger.ts has a single `if (env.NODE_ENV === 'production')` branch
        // not taken in tests — that registers as 0% branches in v8. Acceptable
        // for now; will rise to 70% once a production-env test is added.
        'src/utils/logger.ts': { lines: 85, branches: 0, functions: 80, statements: 85 },
        // Global floor: realistic for the current measured coverage (39% lines).
        // Will be raised as the suite grows. See docs/TEST_METRICS.md for the growth plan.
        lines: 35,
        branches: 65,
        functions: 35,
        statements: 35,
      },
    },
  },
});
