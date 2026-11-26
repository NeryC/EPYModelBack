/**
 * Post-procesamiento de proyecciones (src/scripts/cron.py, paso "generate-graphic"):
 * los datos observados tienen que quedar en su fecha real.
 *
 * Corre tests/model/check_projections.py, que ejecuta cron.py en un directorio
 * temporal (no toca public/results). Se omite si el Python configurado no tiene pandas.
 */
import { describe, it, expect } from 'vitest';
import { spawnSync } from 'child_process';
import path from 'path';
import { environment } from '../../src/config/environment.js';

const python = environment.PYTHON_PATH;
const hasPandas = spawnSync(python, ['-c', 'import pandas'], { encoding: 'utf-8' }).status === 0;

interface FileReport {
  filas: number;
  sin_fecha: number;
  fechas_duplicadas: number;
  observados: number;
  en_fuente: number;
  valor_en_fecha_equivocada: number;
  dias_de_la_fuente_perdidos: number;
  ejemplos: string[];
}

describe.skipIf(!hasPandas)('cron.py — proyecciones regeneradas', () => {
  let report: Record<string, FileReport>;

  it('regenera las cuatro proyecciones', () => {
    const res = spawnSync(
      python,
      ['-W', 'ignore', path.resolve('tests/model/check_projections.py')],
      {
        encoding: 'utf-8',
        maxBuffer: 20e6,
      },
    );
    expect(res.status, res.stderr).toBe(0);
    report = JSON.parse(res.stdout) as Record<string, FileReport>;
    expect(Object.keys(report).sort()).toEqual(['proyF', 'proyH', 'proyR', 'proyU']);
  }, 120_000);

  it.each(['proyH', 'proyU', 'proyR', 'proyF'])(
    '%s: ninguna fila sin fecha ni duplicada; cada dato observado en su fecha real',
    (name) => {
      const r = report[name] as FileReport;
      expect(r.sin_fecha, JSON.stringify(r.ejemplos)).toBe(0);
      expect(r.fechas_duplicadas).toBe(0);
      expect(r.valor_en_fecha_equivocada, JSON.stringify(r.ejemplos)).toBe(0);
      expect(r.dias_de_la_fuente_perdidos, JSON.stringify(r.ejemplos)).toBe(0);
      expect(r.observados).toBe(r.en_fuente);
    },
  );
});
