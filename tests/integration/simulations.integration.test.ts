import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.mock('../../src/infrastructure/processes/simulation-adapter.js', () => ({
  getSimulation: vi.fn(),
  getFirstSimulation: vi.fn(),
}));

import { buildTestApp } from '../helpers/buildApp.js';
import { getSimulation } from '../../src/infrastructure/processes/simulation-adapter.js';
import type { SimulationResults } from '../../src/domain/simulation.js';

const stubResults: SimulationResults = {
  cumulative: [{ fecha: '2024-01-01', value: 10 }],
  cumulative_deaths: [{ fecha: '2024-01-01', value: 1 }],
  exposed: [{ fecha: '2024-01-01', value: 2 }],
  hospitalized: [{ fecha: '2024-01-01', value: 3 }],
  immune: [{ fecha: '2024-01-01', value: 4 }],
  infectious: [{ fecha: '2024-01-01', value: 5 }],
  susceptible: [{ fecha: '2024-01-01', value: 1000 }],
  uci: [{ fecha: '2024-01-01', value: 2 }],
};

const validQuery = {
  Rt: '[1.1,1.2,1.3]',
  UCI_threshold: '100',
  V_filtered: '1000',
  lambda_I_to_H: '0.5',
};

describe('GET /api/v1/simulations', () => {
  const app = buildTestApp();

  beforeEach(() => {
    vi.mocked(getSimulation).mockReset();
  });

  it('happy path — 200 with simulation series', async () => {
    vi.mocked(getSimulation).mockResolvedValue(stubResults as unknown as string);
    const res = await request(app).get('/api/v1/simulations').query(validQuery);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toMatchObject({ cumulative: expect.any(Array) });
  });

  it('400 — invalid Rt JSON', async () => {
    const res = await request(app)
      .get('/api/v1/simulations')
      .query({ ...validQuery, Rt: 'not-json' });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('400 — UCI_threshold <= 0', async () => {
    const res = await request(app)
      .get('/api/v1/simulations')
      .query({ ...validQuery, UCI_threshold: '0' });
    expect(res.status).toBe(400);
  });

  it('400 — lambda_I_to_H > 1', async () => {
    const res = await request(app)
      .get('/api/v1/simulations')
      .query({ ...validQuery, lambda_I_to_H: '1.5' });
    expect(res.status).toBe(400);
  });

  it('500 — adapter throws', async () => {
    vi.mocked(getSimulation).mockRejectedValue(new Error('python crashed'));
    const res = await request(app).get('/api/v1/simulations').query(validQuery);
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});
