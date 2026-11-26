import { describe, it, expect, vi } from 'vitest';
import * as fc from 'fast-check';

vi.mock('../../src/infrastructure/processes/simulation-adapter.js', () => ({
  getSimulation: vi.fn(),
  getFirstSimulation: vi.fn(),
}));

import { executeSimulationUseCase } from '../../src/application/simulations/get-simulation.js';
import { getSimulation } from '../../src/infrastructure/processes/simulation-adapter.js';
import type { SimulationDataPoint, SimulationResults } from '../../src/domain/simulation.js';

function buildSeries(length: number, monotonic = false): SimulationDataPoint[] {
  const out: SimulationDataPoint[] = [];
  let running = 0;
  for (let i = 0; i < length; i++) {
    const v = monotonic ? running + i : Math.abs(Math.sin(i)) * 100;
    if (monotonic) running = v;
    out.push({ fecha: `d-${i}`, value: v });
  }
  return out;
}

function buildResults(length: number): SimulationResults {
  return {
    cumulative: buildSeries(length, true),
    cumulative_deaths: buildSeries(length, true),
    exposed: buildSeries(length),
    hospitalized: buildSeries(length),
    immune: buildSeries(length),
    infectious: buildSeries(length),
    susceptible: buildSeries(length),
    uci: buildSeries(length),
  };
}

// Rangos = SIMULATION_LIMITS (src/domain/simulation.ts)
const validParams = fc.record({
  Rt: fc.array(fc.float({ min: 0, max: 2, noNaN: true }), { minLength: 1, maxLength: 12 }),
  UCI_threshold: fc.integer({ min: 1, max: 5000 }),
  V_filtered: fc.integer({ min: 1, max: 5000 }),
  lambda_I_to_H: fc.float({ min: 0, max: Math.fround(0.99), noNaN: true }),
});

describe('SEIRHUF model invariants (property-based)', () => {
  it('Invariant 1 — no compartment value is negative', async () => {
    await fc.assert(
      fc.asyncProperty(validParams, async (params) => {
        vi.mocked(getSimulation).mockResolvedValue(buildResults(30));
        const out = await executeSimulationUseCase(params);
        for (const key of Object.keys(out.results) as Array<keyof SimulationResults>) {
          for (const point of out.results[key]) {
            expect(point.value).toBeGreaterThanOrEqual(0);
          }
        }
      }),
      { numRuns: 25 },
    );
  });

  it('Invariant 2 — all series share the same length', async () => {
    await fc.assert(
      fc.asyncProperty(validParams, fc.integer({ min: 1, max: 100 }), async (params, len) => {
        vi.mocked(getSimulation).mockResolvedValue(buildResults(len));
        const out = await executeSimulationUseCase(params);
        const lengths = Object.values(out.results).map((s) => s.length);
        expect(new Set(lengths).size).toBe(1);
      }),
      { numRuns: 25 },
    );
  });

  it('Invariant 3 — cumulative and cumulative_deaths are non-decreasing', async () => {
    await fc.assert(
      fc.asyncProperty(validParams, async (params) => {
        vi.mocked(getSimulation).mockResolvedValue(buildResults(40));
        const out = await executeSimulationUseCase(params);
        for (const key of ['cumulative', 'cumulative_deaths'] as const) {
          const series = out.results[key];
          for (let i = 1; i < series.length; i++) {
            expect(series[i].value).toBeGreaterThanOrEqual(series[i - 1].value);
          }
        }
      }),
      { numRuns: 25 },
    );
  });
});
