import { describe, it, expect, vi, beforeEach } from 'vitest';

// --- Mock de python-shell: simula el proceso Python sin ejecutarlo ---
const shellState: {
  stdout: string[];
  stderr: string[];
  lastArgs: unknown;
  /** normal: termina; enoent: el intérprete no existe; hang: el proceso nunca termina */
  mode: 'normal' | 'enoent' | 'hang';
  killed: boolean;
} = {
  stdout: [],
  stderr: [],
  lastArgs: undefined,
  mode: 'normal',
  killed: false,
};

vi.mock('python-shell', () => ({
  PythonShell: class {
    private handlers: Record<string, (m: unknown) => void> = {};
    constructor(_script: string, options: { args: string[] }) {
      shellState.lastArgs = options;
    }
    on(event: string, fn: (m: unknown) => void): this {
      this.handlers[event] = fn;
      return this;
    }
    kill(): void {
      shellState.killed = true;
    }
    end(cb: (err: Error | null) => void): void {
      // Como python-shell real: si el spawn falla se emite 'error' y el
      // callback de fin NUNCA se llama.
      if (shellState.mode === 'enoent') {
        this.handlers.error?.(Object.assign(new Error('spawn python ENOENT'), { code: 'ENOENT' }));
        return;
      }
      if (shellState.mode === 'hang') return;
      shellState.stdout.forEach((l) => this.handlers.message?.(l));
      shellState.stderr.forEach((l) => this.handlers.error?.(l));
      cb(null);
    }
  },
}));

// sim_SEIRHUF.csv mínimo: se lee por NOMBRE de columna (el orden no importa)
const header =
  '"date","lamih","lamif","lamhu","lamhf","lamuf","numero_reproductivo","O","F","U","H","R","I","E","S"';
const csvRow = (date: string, lamih: number, rt: number) =>
  [`"${date}"`, lamih, 0.0001, 0.1, 0.07, 0.43, rt, 8, 7, 6, 5, 4, 3, 2, 100].join(',');
const NL = String.fromCharCode(10);
const csv = [header, csvRow('2022-10-14', 0.001, 3), csvRow('2022-10-15', 0.003, 4)].join(NL) + NL;
vi.mock('fs', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs')>();
  return {
    ...actual,
    // `csv` se lee recién al llamar a readFile (después de inicializarse)
    default: { ...actual, promises: { readFile: vi.fn(async () => csv) } },
  };
});

import {
  getSimulation,
  getFirstSimulation,
  classifyPythonError,
  parseInitialConditions,
  getSimulationDefaults,
} from './simulation-adapter.js';
import { AppError } from '../../utils/errorHandler.js';
import { environment } from '../../config/environment.js';

describe('classifyPythonError', () => {
  it('PARAMETROS_INVALIDOS → AppError 400', () => {
    const e = classifyPythonError(new Error('PARAMETROS_INVALIDOS: Rt debe tener al menos un mes'));
    expect(e).toBeInstanceOf(AppError);
    expect((e as AppError).statusCode).toBe(400);
    expect(e.message).toMatch(/Rt debe tener al menos un mes/);
  });
  it('SIMULACION_INVALIDA → AppError 422', () => {
    const e = classifyPythonError(new Error('SIMULACION_INVALIDA: la población no se conserva'));
    expect((e as AppError).statusCode).toBe(422);
  });
  it('cualquier otro error se mantiene (→ 500)', () => {
    const original = new Error('Traceback: ImportError numpy');
    expect(classifyPythonError(original)).toBe(original);
  });
});

describe('simulation-adapter', () => {
  beforeEach(() => {
    shellState.stdout = [];
    shellState.stderr = [];
    shellState.mode = 'normal';
    shellState.killed = false;
    vi.useRealTimers();
  });

  it('si el intérprete de Python no existe rechaza con un mensaje claro (antes la petición quedaba colgada)', async () => {
    shellState.mode = 'enoent';
    await expect(getSimulation('[1]', 100, 1000, 0.01)).rejects.toThrow(
      /Python interpreter not found/,
    );
  });

  it('si Python no termina, corta por tiempo, mata el proceso y responde 504', async () => {
    vi.useFakeTimers();
    shellState.mode = 'hang';
    const pending = getSimulation('[1]', 100, 1000, 0.01);
    const assertion = expect(pending).rejects.toMatchObject({ statusCode: 504 });
    await vi.advanceTimersByTimeAsync(environment.SIMULATION_TIMEOUT_MS + 1);
    await assertion;
    expect(shellState.killed).toBe(true);
  });

  it('devuelve la última línea JSON del stdout en simulaciones dinámicas', async () => {
    shellState.stdout = ['warning de numpy', '{"uci":[]}'];
    await expect(getSimulation('[1]', 100, 1000, 0.01)).resolves.toBe('{"uci":[]}');
  });

  it('rechaza una simulación dinámica sin salida JSON', async () => {
    shellState.stdout = [];
    await expect(getSimulation('[1]', 100, 1000, 0.01)).rejects.toThrow(/No JSON output/);
  });

  it('getFirstSimulation se resuelve aunque Python no imprima nada (escribe a archivo)', async () => {
    shellState.stdout = [];
    await expect(getFirstSimulation()).resolves.toBeUndefined();
  });

  it('getFirstSimulation pasa firstSimulation=true, el estado inicial y las fracciones ajustadas', async () => {
    await getFirstSimulation();
    const { args } = shellState.lastArgs as { args: string[] };
    expect(JSON.parse(args[0] ?? '')).toEqual([100, 2, 3, 4, 5, 6, 7, 8]); // S,E,I,R,H,U,F,O
    expect(args[4]).toBe('0.002'); // λ I→H = promedio (0.001+0.003)/2, redondeado a 0,1 %
    expect(args[5]).toBe('true');
    expect(JSON.parse(args[6] ?? '')).toEqual({
      lambda_I_to_F: 0.0001,
      lambda_H_to_U: 0.1,
      lambda_H_to_F: 0.07,
      lambda_U_to_F: 0.43,
    });
  });

  it('getFirstSimulation propaga errores de Python', async () => {
    shellState.stderr = ['Traceback: boom'];
    await expect(getFirstSimulation()).rejects.toThrow(/Python error/);
  });
});

describe('parseInitialConditions', () => {
  it('toma el estado del último día y promedia la ventana', () => {
    const ic = parseInitialConditions(csv, 2);
    expect(ic.startDate).toBe('2022-10-15');
    expect(ic.x0).toEqual([100, 2, 3, 4, 5, 6, 7, 8]);
    expect(ic.fittedLambdaIH).toBeCloseTo(0.002);
    expect(ic.estimatedRt).toBeCloseTo(3.5);
  });
  it('con ventana 1 usa solo el último día', () => {
    expect(parseInitialConditions(csv, 1).fittedLambdaIH).toBeCloseTo(0.003);
  });
  it('acepta finales de línea CRLF', () => {
    const CRLF = String.fromCharCode(13, 10);
    expect(parseInitialConditions(csv.split(NL).join(CRLF), 2).x0[0]).toBe(100);
  });
  it('falla con un mensaje claro si falta una columna', () => {
    expect(() => parseInitialConditions(csv.replace('"lamhu"', '"otra"'))).toThrow(
      /falta la columna "lamhu"/,
    );
  });
  it('falla si el CSV no tiene datos', () => {
    expect(() => parseInitialConditions(header + NL)).toThrow(/too short/);
  });
});

describe('getSimulationDefaults', () => {
  it('combina el escenario base con los parámetros ajustados por R', async () => {
    const d = await getSimulationDefaults();
    expect(d).toMatchObject({
      startDate: '2022-10-15',
      Rt: [1.1, 1.2, 1.3, 0.8, 0.7, 0.9],
      UCI_threshold: 100,
      V_filtered: 1000,
      lambda_I_to_H: 0.002,
      estimatedRt: 3.5,
    });
  });
});
