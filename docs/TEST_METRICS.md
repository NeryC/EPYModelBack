# Test Metrics & Evolution Policy

## Snapshot (initial release)

The following snapshot must be re-generated periodically (suggested: at every milestone / thesis chapter freeze) and the file updated.

### Coverage targets per layer (see `vitest.config.ts`)

| Layer             | Lines | Branches | Functions | Statements |
| ----------------- | ----: | -------: | --------: | ---------: |
| `src/domain`      |   90% |      85% |       90% |        90% |
| `src/application` |   90% |      85% |       90% |        90% |
| `src/api/v1`      |   85% |      80% |       85% |        85% |
| `src/controllers` |   80% |      75% |       80% |        80% |
| `src/middleware`  |   80% |      75% |       80% |        80% |
| `src/utils`       |   90% |      85% |       90% |        90% |
| `src/shared`      |   90% |      85% |       90% |        90% |
| Global floor      |   75% |      70% |       75% |        75% |

### Mutation score targets (Stryker)

- `high`: 85%
- `low`: 75%
- `break` (CI gate): 75%

### Execution time budgets (informational; alert if exceeded > 50%)

- `npm run test:unit`: <= 30s
- `npm run test:integration`: <= 2 min
- `npm run test:mutation`: <= 15 min

## Evolution policy

1. **Adding new code** → must come with tests that keep the layer above its threshold.
2. **Removing code** → if tests become obsolete, remove them in the same commit. Stale tests are tech debt.
3. **Flaky test policy** → no `.skip`, no `xfail` in main. A flaky test is suspended only with a tracked issue and a deadline.
4. **Threshold updates** → must be discussed in the thesis text. Lowering a threshold is a regression and must be justified.
5. **Mutation report review** → at every chapter freeze, scan the HTML mutation report for surviving mutants in critical paths and add targeted tests.

## How to read the coverage HTML

After `npm run test:coverage`, open `coverage/index.html` in a browser. Drill down by directory. Red lines are uncovered.

## How to read the mutation HTML

After `npm run test:mutation`, open `reports/mutation/index.html`. Surviving mutants are shown per file with the mutated operator (e.g., `>` → `>=`).
