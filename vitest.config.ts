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
          include: [
            'src/**/*.test.ts',
            'src/**/*.spec.ts',
            'tests/property/**/*.test.ts',
          ],
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
        'src/domain/**/*.ts': { lines: 90, branches: 85, functions: 90, statements: 90 },
        'src/application/**/*.ts': { lines: 90, branches: 85, functions: 90, statements: 90 },
        'src/api/v1/**/*.ts': { lines: 85, branches: 80, functions: 85, statements: 85 },
        'src/controllers/**/*.ts': { lines: 80, branches: 75, functions: 80, statements: 80 },
        'src/middleware/**/*.ts': { lines: 80, branches: 75, functions: 80, statements: 80 },
        'src/utils/**/*.ts': { lines: 90, branches: 85, functions: 90, statements: 90 },
        'src/shared/**/*.ts': { lines: 90, branches: 85, functions: 90, statements: 90 },
        lines: 75,
        branches: 70,
        functions: 75,
        statements: 75,
      },
    },
  },
});
