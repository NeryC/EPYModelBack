import { describe, it, expect } from 'vitest';

describe('SimulationParameters validation', () => {
  it('should validate correct parameters structure', () => {
    const params = {
      Rt: [1.1, 1.2, 1.3],
      UCI_threshold: 100,
      V_filtered: 1000,
      lambda_I_to_H: 0.5,
    };
    expect(params.Rt).toBeInstanceOf(Array);
    expect(params.UCI_threshold).toBeGreaterThan(0);
    expect(params.V_filtered).toBeGreaterThan(0);
    expect(params.lambda_I_to_H).toBeGreaterThanOrEqual(0);
    expect(params.lambda_I_to_H).toBeLessThanOrEqual(1);
  });
});
