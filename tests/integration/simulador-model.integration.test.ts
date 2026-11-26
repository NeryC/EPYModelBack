/**
 * Invariantes del modelo REAL (simulador.py), no de datos simulados.
 *
 * Corre tests/model/check_invariants.py con el intérprete de environment.PYTHON_PATH.
 * Si ese Python no tiene numpy + scipy (p. ej. en el CI actual) el test se omite.
 */
import { describe, it, expect } from 'vitest';
import { spawnSync } from 'child_process';
import path from 'path';
import { environment } from '../../src/config/environment.js';

const python = environment.PYTHON_PATH;
const hasScientificPython =
  spawnSync(python, ['-c', 'import numpy, scipy'], { encoding: 'utf-8' }).status === 0;

interface Report {
  runs: { params: unknown[]; problems: string[] }[];
  monotonic: Record<string, boolean>;
}

describe.skipIf(!hasScientificPython)('simulador.py — invariantes del modelo', () => {
  let report: Report;

  it('ejecuta todos los escenarios', () => {
    const script = path.resolve('tests/model/check_invariants.py');
    const res = spawnSync(python, ['-W', 'ignore', script], { encoding: 'utf-8', maxBuffer: 50e6 });
    expect(res.status, res.stderr).toBe(0);
    report = JSON.parse(res.stdout) as Report;
    expect(report.runs.length).toBeGreaterThan(300);
  }, 120_000);

  it('ningún escenario viola invariantes (sin negativos, conserva población, monotonía de acumulados)', () => {
    const failing = report.runs.filter((r) => r.problems.length > 0);
    expect(failing.map((r) => `${JSON.stringify(r.params)}: ${r.problems.join(', ')}`)).toEqual([]);
  });

  it('responde en la dirección esperada a cada parámetro', () => {
    for (const [name, ok] of Object.entries(report.monotonic)) expect(ok, name).toBe(true);
  });
});
