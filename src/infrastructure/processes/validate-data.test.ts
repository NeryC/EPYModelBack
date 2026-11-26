import { describe, it, expect } from 'vitest';
import {
  parseDayMonthYear,
  validateRegistry,
  validateCases,
  validateDeaths,
  validateRawData,
} from './validate-data.js';
import path from 'path';

const NL = String.fromCharCode(10);
const csv = (header: string, rows: string[]) => [header, ...rows].join(NL) + NL;

describe('parseDayMonthYear', () => {
  it.each([
    ['7/3/2020', '2020-03-07'],
    ['07/03/2020', '2020-03-07'],
    ['31/12/2022', '2022-12-31'],
    ['13/1/2021', '2021-01-13'],
  ])('%s → %s', (input, iso) => expect(parseDayMonthYear(input)).toBe(iso));

  it.each(['2020-03-07', '31/02/2021', 'abc', '1/13/2021'])('%s → null', (input) =>
    expect(parseDayMonthYear(input)).toBeNull(),
  );
});

describe('validateRegistry', () => {
  const H = 'Fecha;Internados Generales';
  it('acepta un registro que empieza con el primer caso', () => {
    expect(validateRegistry(csv(H, ['7/3/2020;0', '8/3/2020;1', '9/3/2020;2']))).toEqual([]);
  });
  it('detecta fechas anteriores al primer caso (patrón de intercambio día/mes)', () => {
    // "04/01/2020" era en realidad el 1 de abril escrito como mes/día
    expect(validateRegistry(csv(H, ['04/01/2020;5', '7/3/2020;0']))[0]).toMatch(
      /anteriores al primer caso/,
    );
  });
  it('detecta fechas duplicadas', () => {
    expect(validateRegistry(csv(H, ['7/3/2020;0', '7/3/2020;1']))[0]).toMatch(/duplicadas/);
  });
});

describe('validateCases', () => {
  const H = 'ID;Fecha Confirmacion';
  it('acepta casos desde el primer caso', () => {
    expect(validateCases(csv(H, ['1;7/3/2020', '2;20/3/2020']))).toEqual([]);
  });
  it('detecta casos confirmados antes del primer caso', () => {
    expect(validateCases(csv(H, ['1;04/01/2020', '2;20/3/2020']))[0]).toMatch(
      /antes del primer caso/,
    );
  });
});

describe('validateDeaths', () => {
  const H = 'ID;Fecha de Divulgación;Fecha Obito';
  it('acepta óbitos coherentes con su divulgación', () => {
    expect(validateDeaths(csv(H, ['1;20/3/2020;20/3/2020', '2;5/4/2020;1/4/2020']))).toEqual([]);
  });
  it('detecta óbitos con día y mes intercambiados', () => {
    // óbito real 1-ago-2020 escrito como "08/01/2020" → leído 8-ene-2020
    const rows = Array.from({ length: 10 }, (_, i) => `${i};4/8/2020;08/01/2020`);
    const problems = validateDeaths(csv(H, rows));
    expect(problems.some((p) => /antes del primer caso/.test(p))).toBe(true);
    expect(problems.some((p) => /0–60 días antes de su divulgación/.test(p))).toBe(true);
  });
});

describe('datos versionados del repositorio', () => {
  it('public/data pasa la validación (detectaría una nueva corrupción de fechas)', () => {
    expect(validateRawData(path.resolve('public/data'))).toEqual([]);
  }, 60_000);
});
