import { describe, it, expect } from 'vitest';
import {
  SimulationParamsSchema,
  SimulationQuerySchema,
  validateSimulationParams,
  validateSimulationQuery,
} from './dto.js';

describe('SimulationParamsSchema — happy path', () => {
  it('parses a valid set of parameters', () => {
    const input = {
      Rt: '[1.1, 1.2, 1.3]',
      UCI_threshold: 100,
      V_filtered: 1000,
      lambda_I_to_H: 0.5,
    };
    const result = SimulationParamsSchema.parse(input);
    expect(result.Rt).toBe('[1.1, 1.2, 1.3]');
    expect(result.UCI_threshold).toBe(100);
    expect(result.V_filtered).toBe(1000);
    expect(result.lambda_I_to_H).toBe(0.5);
  });

  it('coerces string numbers to numbers', () => {
    const input = {
      Rt: '[1.0]',
      UCI_threshold: '50',
      V_filtered: '500',
      lambda_I_to_H: '0.25',
    };
    const result = SimulationParamsSchema.parse(input);
    expect(typeof result.UCI_threshold).toBe('number');
    expect(result.UCI_threshold).toBe(50);
  });
});

describe('SimulationParamsSchema — Rt (Boundary Value Analysis)', () => {
  it('accepts a JSON array of numbers', () => {
    expect(() =>
      SimulationParamsSchema.parse({
        Rt: '[1.0, 1.1, 1.2]',
        UCI_threshold: 100,
        V_filtered: 1000,
        lambda_I_to_H: 0.5,
      }),
    ).not.toThrow();
  });

  it('rejects Rt that is not valid JSON', () => {
    expect(() =>
      SimulationParamsSchema.parse({
        Rt: 'not-json',
        UCI_threshold: 100,
        V_filtered: 1000,
        lambda_I_to_H: 0.5,
      }),
    ).toThrow();
  });

  it('rejects Rt that is a JSON object (not array)', () => {
    expect(() =>
      SimulationParamsSchema.parse({
        Rt: '{"a": 1}',
        UCI_threshold: 100,
        V_filtered: 1000,
        lambda_I_to_H: 0.5,
      }),
    ).toThrow();
  });

  it('rejects Rt with non-numeric elements', () => {
    expect(() =>
      SimulationParamsSchema.parse({
        Rt: '[1, "two", 3]',
        UCI_threshold: 100,
        V_filtered: 1000,
        lambda_I_to_H: 0.5,
      }),
    ).toThrow();
  });

  const rtBase = { UCI_threshold: 100, V_filtered: 1000, lambda_I_to_H: 0.5 };
  it('rejects an empty Rt array (0 meses)', () => {
    expect(() => SimulationParamsSchema.parse({ ...rtBase, Rt: '[]' })).toThrow(/between 1 and 12/);
  });
  it('accepts 1 month (lower bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...rtBase, Rt: '[1]' })).not.toThrow();
  });
  it('accepts 12 months (upper bound)', () => {
    expect(() =>
      SimulationParamsSchema.parse({ ...rtBase, Rt: JSON.stringify(Array(12).fill(1)) }),
    ).not.toThrow();
  });
  it('rejects 13 months (just above upper bound)', () => {
    expect(() =>
      SimulationParamsSchema.parse({ ...rtBase, Rt: JSON.stringify(Array(13).fill(1)) }),
    ).toThrow(/between 1 and 12/);
  });
  it('accepts Rt values 0 and 2 (value bounds)', () => {
    expect(() => SimulationParamsSchema.parse({ ...rtBase, Rt: '[0, 2]' })).not.toThrow();
  });
  it('rejects a negative Rt value', () => {
    expect(() => SimulationParamsSchema.parse({ ...rtBase, Rt: '[1, -0.1]' })).toThrow(
      /between 0 and 2/,
    );
  });
  it('rejects an Rt value above 2', () => {
    expect(() => SimulationParamsSchema.parse({ ...rtBase, Rt: '[2.01]' })).toThrow(
      /between 0 and 2/,
    );
  });
  it('rejects null inside the Rt array', () => {
    expect(() => SimulationParamsSchema.parse({ ...rtBase, Rt: '[1, null]' })).toThrow();
  });
});

describe('SimulationParamsSchema — UCI_threshold (BVA)', () => {
  const base = { Rt: '[1.0]', V_filtered: 1000, lambda_I_to_H: 0.5 };

  it('rejects 0 (just below lower bound — positive only)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, UCI_threshold: 0 })).toThrow();
  });
  it('rejects negative values', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, UCI_threshold: -1 })).toThrow();
  });
  it('accepts 1 (just inside lower bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, UCI_threshold: 1 })).not.toThrow();
  });
  it('accepts 5000 (upper bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, UCI_threshold: 5000 })).not.toThrow();
  });
  it('rejects 5001 (just above upper bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, UCI_threshold: 5001 })).toThrow();
  });
});

describe('SimulationParamsSchema — V_filtered (BVA)', () => {
  const base = { Rt: '[1.0]', UCI_threshold: 100, lambda_I_to_H: 0.5 };

  it('rejects 0', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, V_filtered: 0 })).toThrow();
  });
  it('accepts 1', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, V_filtered: 1 })).not.toThrow();
  });
  it('accepts 5000 (upper bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, V_filtered: 5000 })).not.toThrow();
  });
  it('rejects 5001 (just above upper bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, V_filtered: 5001 })).toThrow();
  });
});

describe('Camas UCI y vacunados por día deben ser enteros', () => {
  const base = { Rt: '[1.0]', UCI_threshold: 100, V_filtered: 1000, lambda_I_to_H: 0.5 };
  const query = { Rt: '[1.0]', UCI_threshold: '100', V_filtered: '1000', lambda_I_to_H: '0.5' };

  it.each(['UCI_threshold', 'V_filtered'])('%s = 12.5 se rechaza (params y query)', (campo) => {
    expect(() => SimulationParamsSchema.parse({ ...base, [campo]: 12.5 })).toThrow(/whole number/);
    expect(() => SimulationQuerySchema.parse({ ...query, [campo]: '12.5' })).toThrow(
      /whole number/,
    );
  });
  it('12.0 escrito con decimales se acepta (es entero)', () => {
    expect(() => SimulationQuerySchema.parse({ ...query, UCI_threshold: '12.0' })).not.toThrow();
  });
  it('lambda_I_to_H sigue admitiendo decimales', () => {
    expect(() => SimulationQuerySchema.parse({ ...query, lambda_I_to_H: '0.003' })).not.toThrow();
  });
});

describe('SimulationParamsSchema — lambda_I_to_H (BVA)', () => {
  const base = { Rt: '[1.0]', UCI_threshold: 100, V_filtered: 1000 };

  it('accepts 0 (lower bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, lambda_I_to_H: 0 })).not.toThrow();
  });
  it('rejects negative values just below lower bound', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, lambda_I_to_H: -0.001 })).toThrow();
  });
  it('accepts 0.99 (upper bound)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, lambda_I_to_H: 0.99 })).not.toThrow();
  });
  it('rejects values just above upper bound', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, lambda_I_to_H: 0.9901 })).toThrow();
  });
  it('rejects 1 (con λ=1 la fracción I→O sería negativa)', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, lambda_I_to_H: 1 })).toThrow();
  });
  it('accepts the midpoint 0.5', () => {
    expect(() => SimulationParamsSchema.parse({ ...base, lambda_I_to_H: 0.5 })).not.toThrow();
  });
});

describe('SimulationQuerySchema (query string variant)', () => {
  it('accepts well-formed string numeric values', () => {
    const result = SimulationQuerySchema.parse({
      Rt: '[1.1]',
      UCI_threshold: '100',
      V_filtered: '1000',
      lambda_I_to_H: '0.5',
    });
    expect(result.UCI_threshold).toBe('100');
  });

  it.each([
    ['UCI_threshold', '5001'],
    ['V_filtered', '5001'],
    ['lambda_I_to_H', '0.995'],
    ['UCI_threshold', '0'],
    ['V_filtered', '0'],
  ])('rejects out-of-range %s=%s in the query string', (field, value) => {
    const query = {
      Rt: '[1.1]',
      UCI_threshold: '100',
      V_filtered: '1000',
      lambda_I_to_H: '0.5',
      [field]: value,
    };
    expect(() => SimulationQuerySchema.parse(query)).toThrow(/must be between/);
  });

  it('rejects an Rt query with 13 months', () => {
    expect(() =>
      SimulationQuerySchema.parse({
        Rt: JSON.stringify(Array(13).fill(1)),
        UCI_threshold: '100',
        V_filtered: '1000',
        lambda_I_to_H: '0.5',
      }),
    ).toThrow(/between 1 and 12/);
  });

  it('rejects non-numeric query strings', () => {
    expect(() =>
      SimulationQuerySchema.parse({
        Rt: '[1.1]',
        UCI_threshold: 'abc',
        V_filtered: '1000',
        lambda_I_to_H: '0.5',
      }),
    ).toThrow();
  });
});

describe('validateSimulationParams / validateSimulationQuery helpers', () => {
  it('validateSimulationParams returns the parsed object on success', () => {
    const result = validateSimulationParams({
      Rt: '[1.0]',
      UCI_threshold: 100,
      V_filtered: 1000,
      lambda_I_to_H: 0.5,
    });
    expect(result).toMatchObject({ UCI_threshold: 100, V_filtered: 1000 });
  });

  it('validateSimulationQuery throws on invalid input', () => {
    expect(() =>
      validateSimulationQuery({
        Rt: 'bad',
        UCI_threshold: 'x',
        V_filtered: 'y',
        lambda_I_to_H: 'z',
      }),
    ).toThrow();
  });
});
