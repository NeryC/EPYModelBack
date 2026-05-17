import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../../infrastructure/processes/simulation-adapter.js', () => ({
  getSimulation: vi.fn(),
  getFirstSimulation: vi.fn(),
}));

import { executeSimulationUseCase } from './get-simulation.js';
import { getSimulation } from '../../infrastructure/processes/simulation-adapter.js';
import type { SimulationInput, SimulationResults } from '../../domain/simulation.js';

const baseInput: SimulationInput = {
  Rt: [1.1, 1.2, 1.3],
  UCI_threshold: 100,
  V_filtered: 1000,
  lambda_I_to_H: 0.5,
};

const emptySeries: SimulationResults = {
  cumulative: [],
  cumulative_deaths: [],
  exposed: [],
  hospitalized: [],
  immune: [],
  infectious: [],
  susceptible: [],
  uci: [],
};

describe('executeSimulationUseCase', () => {
  beforeEach(() => {
    vi.mocked(getSimulation).mockReset();
  });

  it('returns parsed results when adapter returns an object', async () => {
    vi.mocked(getSimulation).mockResolvedValue(emptySeries);
    const out = await executeSimulationUseCase(baseInput);
    expect(out.results).toEqual(emptySeries);
    expect(getSimulation).toHaveBeenCalledOnce();
  });

  it('parses JSON when adapter returns a string', async () => {
    vi.mocked(getSimulation).mockResolvedValue(JSON.stringify(emptySeries));
    const out = await executeSimulationUseCase(baseInput);
    expect(out.results).toEqual(emptySeries);
  });

  it('converts bare NaN tokens to null when parsing string output', async () => {
    const polluted = '{"cumulative":[{"fecha":"d","value":NaN}],"cumulative_deaths":[],"exposed":[],"hospitalized":[],"immune":[],"infectious":[],"susceptible":[],"uci":[]}';
    vi.mocked(getSimulation).mockResolvedValue(polluted);
    const out = await executeSimulationUseCase(baseInput);
    expect(out.results.cumulative[0]).toEqual({ fecha: 'd', value: null });
  });

  it('throws when string output is not valid JSON', async () => {
    vi.mocked(getSimulation).mockResolvedValue('totally not json');
    await expect(executeSimulationUseCase(baseInput)).rejects.toThrow(
      /Failed to parse simulation result/,
    );
  });

  it('serializes Rt to a JSON string before calling the adapter', async () => {
    vi.mocked(getSimulation).mockResolvedValue(emptySeries);
    await executeSimulationUseCase(baseInput);
    expect(getSimulation).toHaveBeenCalledWith(
      JSON.stringify(baseInput.Rt),
      baseInput.UCI_threshold,
      baseInput.V_filtered,
      baseInput.lambda_I_to_H,
      false,
    );
  });

  it('propagates adapter errors', async () => {
    vi.mocked(getSimulation).mockRejectedValue(new Error('python crashed'));
    await expect(executeSimulationUseCase(baseInput)).rejects.toThrow('python crashed');
  });
});
