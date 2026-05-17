import { describe, it, expect, vi } from 'vitest';
import request from 'supertest';

vi.mock('../../src/infrastructure/processes/simulation-adapter.js', () => ({
  getSimulation: vi.fn().mockResolvedValue({
    cumulative: [{ fecha: '2024-01-01', value: 1 }],
    cumulative_deaths: [{ fecha: '2024-01-01', value: 0 }],
    exposed: [{ fecha: '2024-01-01', value: 0 }],
    hospitalized: [{ fecha: '2024-01-01', value: 0 }],
    immune: [{ fecha: '2024-01-01', value: 0 }],
    infectious: [{ fecha: '2024-01-01', value: 1 }],
    susceptible: [{ fecha: '2024-01-01', value: 1000 }],
    uci: [{ fecha: '2024-01-01', value: 0 }],
  }),
  getFirstSimulation: vi.fn(),
}));

import { buildTestApp } from '../helpers/buildApp.js';
import {
  ApiResponseSchema,
  SimulationResponseSchema,
} from '../../src/api/v1/simulations/dto.js';

describe('HTTP response contract (Zod)', () => {
  const app = buildTestApp();

  it('GET /api/v1/simulations response satisfies ApiResponseSchema + SimulationResponseSchema', async () => {
    const res = await request(app)
      .get('/api/v1/simulations')
      .query({
        Rt: '[1.1]',
        UCI_threshold: '100',
        V_filtered: '1000',
        lambda_I_to_H: '0.5',
      });

    expect(res.status).toBe(200);
    expect(() => ApiResponseSchema.parse(res.body)).not.toThrow();
    expect(() => SimulationResponseSchema.parse(res.body.data)).not.toThrow();
  });

  it('GET /health response has the documented shape', async () => {
    const res = await request(app).get('/health');
    expect(res.body).toMatchObject({
      status: 'OK',
      timestamp: expect.any(String),
    });
  });
});
