import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { buildTestApp } from '../helpers/buildApp.js';
import { SIMULATION_LIMITS } from '../../src/domain/simulation.js';

describe('GET /api/v1/simulation-defaults (CSV real del modelo R)', () => {
  it('devuelve el escenario base y los parámetros ajustados por R', async () => {
    const res = await request(buildTestApp()).get('/api/v1/simulation-defaults');
    expect(res.status).toBe(200);
    const d = res.body.data;
    expect(d.startDate).toBe('2022-12-24'); // último día del ajuste R (datos de feb-2023)
    expect(d.Rt).toEqual([1.1, 1.2, 1.3, 0.8, 0.7, 0.9]);
    expect(d.UCI_threshold).toBe(100);
    expect(d.V_filtered).toBe(1000);
    // λ I→H ajustada por R (promedio 7 días ≈ 0,3 %) → redondeada al paso del slider (0,1 %)
    expect(d.lambda_I_to_H).toBe(0.003);
    expect(d.estimatedRt).toBeGreaterThan(3);
    for (const v of Object.values(d.fractions as Record<string, number>)) {
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThanOrEqual(1);
    }
  });

  it('los valores por defecto son aceptados por la validación de /simulations', async () => {
    const d = (await request(buildTestApp()).get('/api/v1/simulation-defaults')).body.data;
    expect(d.Rt.length).toBeLessThanOrEqual(SIMULATION_LIMITS.RT_MONTHS_MAX);
    expect(d.UCI_threshold).toBeLessThanOrEqual(SIMULATION_LIMITS.UCI_MAX);
    expect(d.V_filtered).toBeLessThanOrEqual(SIMULATION_LIMITS.V_MAX);
    expect(d.lambda_I_to_H).toBeGreaterThanOrEqual(SIMULATION_LIMITS.LAMBDA_MIN);
    expect(d.lambda_I_to_H).toBeLessThanOrEqual(SIMULATION_LIMITS.LAMBDA_MAX);
  });
});
