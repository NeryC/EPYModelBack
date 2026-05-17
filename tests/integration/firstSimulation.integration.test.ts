import { describe, it, expect, vi } from 'vitest';
import request from 'supertest';

vi.mock('../../src/infrastructure/storage/simulation-repository.js', () => ({
  FileSimulationRepository: vi.fn().mockImplementation(() => ({
    save: vi.fn(),
    findById: vi.fn(),
    findLatest: vi.fn(),
    getSimulationFilePath: vi.fn(),
    getSimulationData: vi.fn().mockResolvedValue({
      cumulative: [{ fecha: '2024-01-01', value: 1 }],
      cumulative_deaths: [],
      exposed: [],
      hospitalized: [],
      immune: [],
      infectious: [],
      susceptible: [],
      uci: [],
    }),
  })),
}));

import { buildTestApp } from '../helpers/buildApp.js';

describe('GET /api/v1/get-first-simulation-data', () => {
  const app = buildTestApp();

  it('returns 200 with simulation data', async () => {
    const res = await request(app).get('/api/v1/get-first-simulation-data');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveProperty('cumulative');
  });
});
