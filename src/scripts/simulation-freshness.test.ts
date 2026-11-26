/**
 * Guard: el `public/results/simulation.json` versionado debe haber sido
 * generado por la versión ACTUAL de `simulador.py`.
 *
 * `simulador.py` (con firstSimulation=true) escribe junto al JSON un
 * `simulation.meta.json` con el SHA-256 de su propio código fuente. Si alguien
 * modifica el modelo y no regenera la simulación inicial, este test falla.
 * Así se evita servir resultados de un modelo viejo (ver incidente: el JSON
 * de 2025-06-30 seguía en uso tras corregir el modelo en 2026-03).
 *
 * No necesita Python: solo compara hashes, por lo que corre en CI.
 * Para regenerar: `npm run generate-simulation` (requiere Python con numpy+scipy).
 */
import { describe, it, expect } from 'vitest';
import { createHash } from 'crypto';
import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '..', '..');
const SCRIPT = path.join(ROOT, 'src', 'scripts', 'simulador.py');
const META = path.join(ROOT, 'public', 'results', 'simulation.meta.json');
const RESULT = path.join(ROOT, 'public', 'results', 'simulation.json');

/** Mismo algoritmo que `_script_sha256()` en simulador.py (CRLF → LF). */
function scriptSha256(file: string): string {
  const normalized = readFileSync(file).toString('utf-8').replace(/\r\n/g, '\n');
  return createHash('sha256').update(normalized, 'utf-8').digest('hex');
}

interface SimulationMeta {
  script_sha256: string;
}

describe('simulación inicial versionada', () => {
  it('fue generada por la versión actual de simulador.py', () => {
    const meta = JSON.parse(readFileSync(META, 'utf-8')) as SimulationMeta;
    expect(
      meta.script_sha256,
      'simulador.py cambió pero public/results/simulation.json no se regeneró. ' +
        'Ejecuta `npm run generate-simulation`.',
    ).toBe(scriptSha256(SCRIPT));
  });

  it('tiene cifras epidemiológicamente plausibles con los parámetros por defecto', () => {
    const result = JSON.parse(readFileSync(RESULT, 'utf-8')) as Record<
      string,
      { day: number; value: number }[]
    >;
    const N = 7_252_672;
    const max = (k: string): number => Math.max(...(result[k] ?? []).map((p) => p.value));

    // Ningún compartimento de prevalencia puede superar la población.
    for (const k of ['susceptible', 'exposed', 'infectious', 'hospitalized', 'uci', 'immune']) {
      expect(max(k), k).toBeLessThanOrEqual(N);
    }
    // Paraguay registró ~20 000 fallecidos en toda la pandemia; en 180 días
    // una simulación por defecto no puede acercarse al 1 % de la población.
    expect(max('cumulative_deaths')).toBeLessThan(0.01 * N);
  });
});
