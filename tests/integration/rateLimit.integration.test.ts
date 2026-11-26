import { describe, it, expect, vi } from 'vitest';
import request from 'supertest';

vi.mock('../../src/infrastructure/processes/simulation-adapter.js', () => ({
  getSimulation: vi.fn().mockResolvedValue(
    JSON.stringify({
      cumulative: [],
      cumulative_deaths: [],
      exposed: [],
      hospitalized: [],
      immune: [],
      infectious: [],
      susceptible: [],
      uci: [],
    }),
  ),
  getFirstSimulation: vi.fn(),
}));

import { createApp } from '../../src/app.js';
import { environment } from '../../src/config/environment.js';

const sim = '/api/v1/simulations?Rt=%5B1%5D&UCI_threshold=100&V_filtered=1000&lambda_I_to_H=0.01';

describe('rate limits', () => {
  it('los valores por defecto son altos (≥ 10000 generales, ≥ 2000 simulaciones / 15 min)', () => {
    expect(environment.RATE_LIMIT.windowMinutes).toBe(15);
    expect(environment.RATE_LIMIT.max).toBeGreaterThanOrEqual(10000);
    expect(environment.RATE_LIMIT.simulationMax).toBeGreaterThanOrEqual(2000);
  });

  it('el límite de simulaciones es propio y responde 429 con retryAfterSeconds', async () => {
    const app = createApp({ skipSwagger: true, rateLimit: { max: 100, simulationMax: 2 } });
    expect((await request(app).get(sim)).status).toBe(200);
    expect((await request(app).get(sim)).status).toBe(200);
    const blocked = await request(app).get(sim);
    expect(blocked.status).toBe(429);
    expect(blocked.body).toMatchObject({
      success: false,
      error: 'rate_limited',
      scope: 'simulation',
    });
    expect(blocked.body.retryAfterSeconds).toBeGreaterThan(0);
    expect(blocked.headers['retry-after']).toBeDefined();
    // El resto de la API sigue disponible aunque se agotaron las simulaciones
    expect((await request(app).get('/health')).status).toBe(200);
  });

  it('el límite general aplica a toda la API', async () => {
    const app = createApp({ skipSwagger: true, rateLimit: { max: 2, simulationMax: 100 } });
    await request(app).get('/health');
    await request(app).get('/health');
    const blocked = await request(app).get('/health');
    expect(blocked.status).toBe(429);
    expect(blocked.body.scope).toBe('api');
  });
});
