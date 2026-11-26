import fs from 'fs';
import { fileNames, pathNames } from '../../shared/constants.js';
import { getPath } from './get-script.js';
import { PythonShell } from 'python-shell';
import { environment } from '../../config/environment.js';
import { AppError } from '../../utils/errorHandler.js';
import { parseDayMonthYear, RAW_FILES } from './validate-data.js';
import {
  DEFAULT_SCENARIO,
  FITTED_WINDOW_DAYS,
  SIMULATION_LIMITS,
  SimulationDefaults,
  TransitionFractions,
} from '../../domain/simulation.js';

/**
 * Convierte los errores "controlados" de simulador.py (prefijos en stderr)
 * en AppError con su código HTTP. Cualquier otro error queda como 500.
 *   PARAMETROS_INVALIDOS  → 400 (la entrada no permite simular)
 *   SIMULACION_INVALIDA   → 422 (la integración numérica no fue confiable)
 */
export function classifyPythonError(err: unknown): Error {
  const text = err instanceof Error ? err.message : String(err);
  const match = /(PARAMETROS_INVALIDOS|SIMULACION_INVALIDA):\s*(.+)/.exec(text);
  if (!match) return err instanceof Error ? err : new Error(text);
  const [, kind, detail] = match;
  return kind === 'PARAMETROS_INVALIDOS'
    ? new AppError(`Invalid simulation parameters: ${detail}`, 400)
    : new AppError(`The simulation did not converge for these parameters: ${detail}`, 422);
}

/** Estado inicial y parámetros ajustados que salen del CSV del modelo R. */
export interface InitialConditions {
  /** [S, E, I, C, H, U, F, O] — C es la columna R (acumulado con subregistro). */
  x0: number[];
  startDate: string;
  fractions: TransitionFractions;
  /** Fracción I→H ajustada (promedio de la ventana). */
  fittedLambdaIH: number;
  /** Rt efectivo estimado (promedio de la ventana). */
  estimatedRt: number;
}

const STATE_COLUMNS = ['S', 'E', 'I', 'R', 'H', 'U', 'F', 'O'] as const;
const FRACTION_COLUMNS: Record<keyof TransitionFractions, string> = {
  lambda_I_to_F: 'lamif',
  lambda_H_to_U: 'lamhu',
  lambda_H_to_F: 'lamhf',
  lambda_U_to_F: 'lamuf',
};

/**
 * Lee sim_SEIRHUF.csv por NOMBRE de columna (antes se tomaban las posiciones
 * 20–27 a ciegas: un cambio de orden en el script R rompía el simulador en
 * silencio).
 */
export function parseInitialConditions(
  csv: string,
  windowDays = FITTED_WINDOW_DAYS,
): InitialConditions {
  const lines = csv.split(/\r?\n/).filter((l) => l.trim() !== '');
  if (lines.length < 2) throw new Error('CSV file is too short');
  const header = (lines[0] ?? '').split(',').map((h) => h.trim().replace(/^"|"$/g, ''));
  const col = (name: string): number => {
    const i = header.indexOf(name);
    if (i < 0) throw new Error(`sim_SEIRHUF.csv: falta la columna "${name}"`);
    return i;
  };
  const rows = lines.slice(1).map((l) => l.split(','));
  const num = (row: string[], name: string): number => {
    const v = Number(row[col(name)]);
    if (!Number.isFinite(v)) throw new Error(`sim_SEIRHUF.csv: valor inválido en "${name}"`);
    return v;
  };
  const last = rows[rows.length - 1] as string[];
  const window = rows.slice(-windowDays);
  const avg = (name: string): number =>
    window.reduce((s, r) => s + num(r, name), 0) / window.length;

  const fractions = Object.fromEntries(
    Object.entries(FRACTION_COLUMNS).map(([key, column]) => [key, avg(column)]),
  ) as unknown as TransitionFractions;

  return {
    x0: STATE_COLUMNS.map((c) => num(last, c)),
    startDate: (last[col('date')] ?? '').replace(/"/g, ''),
    fractions,
    fittedLambdaIH: avg('lamih'),
    estimatedRt: avg('numero_reproductivo'),
  };
}

/**
 * Ancla los compartimentos que se MIDEN (hospitalizados H y UCI U) a lo
 * observado en el registro diario el día de inicio. El resto del estado
 * (S, E, I, C, F, O) sale del modelo, que es la única estimación disponible.
 *
 * Motivo: el ajuste de R se queda atrás en su último tramo (diciembre de 2022
 * fue el inicio de una ola): el último día estima H = 76 con 225 observados.
 * Validado contra los 14 días reales posteriores: el error medio baja de 52 % a
 * 16 % en H y de 34 % a 9 % en UCI.
 *
 * La diferencia se descuenta de I (infecciosos que ya se hospitalizaron) para
 * conservar la población total; si I no alcanza, el resto sale de S.
 */
export function anchorToObserved(x0: number[], observed: { H: number; U: number }): number[] {
  const x = [...x0];
  const delta = observed.H - (x[4] ?? 0) + (observed.U - (x[5] ?? 0));
  x[4] = observed.H;
  x[5] = observed.U;
  const fromI = Math.min(delta, x[2] ?? 0);
  x[2] = (x[2] ?? 0) - fromI;
  x[0] = (x[0] ?? 0) - (delta - fromI);
  return x;
}

/** Hospitalizados y UCI observados en `date` (YYYY-MM-DD) según el registro diario. */
export function observedOnDate(registryCsv: string, date: string): { H: number; U: number } | null {
  const lines = registryCsv
    .replace(new RegExp('^' + String.fromCharCode(0xfeff)), '')
    .split(/\r?\n/)
    .filter((l) => l.trim() !== '');
  const header = (lines[0] ?? '').split(';');
  const iF = header.indexOf('Fecha');
  const iH = header.indexOf('Internados Generales');
  const iU = header.indexOf('Internados UTI');
  if (iF < 0 || iH < 0 || iU < 0) return null;
  for (const line of lines.slice(1)) {
    const c = line.split(';');
    if (parseDayMonthYear(c[iF] ?? '') === date) {
      const H = Number(c[iH]);
      const U = Number(c[iU]);
      return Number.isFinite(H) && Number.isFinite(U) ? { H, U } : null;
    }
  }
  return null;
}

export const getInitialConditions = async (): Promise<InitialConditions> => {
  const csv = await fs.promises.readFile(getPath(pathNames.DATA_FILES, fileNames.SIM_CSV), 'utf8');
  const ic = parseInitialConditions(csv);
  try {
    const registry = await fs.promises.readFile(
      getPath(pathNames.DATA_FILES, RAW_FILES.registry),
      'utf8',
    );
    const observed = observedOnDate(registry, ic.startDate);
    if (observed) return { ...ic, x0: anchorToObserved(ic.x0, observed) };
  } catch {
    /* sin registro legible: se usa el estado del modelo */
  }
  return ic;
};

/** Valores por defecto del simulador (escenario base + parámetros ajustados por R). */
export const getSimulationDefaults = async (): Promise<SimulationDefaults> => {
  const ic = await getInitialConditions();
  const L = SIMULATION_LIMITS;
  // Redondeo al paso del slider (0,1 %) dentro de los límites permitidos
  const lambda = Math.min(
    L.LAMBDA_MAX,
    Math.max(0.001, Math.round(ic.fittedLambdaIH * 1000) / 1000),
  );
  return {
    startDate: ic.startDate,
    Rt: [...DEFAULT_SCENARIO.Rt],
    UCI_threshold: DEFAULT_SCENARIO.UCI_threshold,
    V_filtered: DEFAULT_SCENARIO.V_filtered,
    lambda_I_to_H: lambda,
    estimatedRt: Math.round(ic.estimatedRt * 100) / 100,
    fractions: ic.fractions,
  };
};

export const getSimulation = async (
  Rt: string,
  UCI_threshold: number,
  V_filtered: number,
  lambda_I_to_H: number,
  isFirstSimulation = false,
): Promise<string> => {
  const ic = await getInitialConditions();
  const params = [
    JSON.stringify(ic.x0),
    Rt,
    UCI_threshold.toString(),
    V_filtered.toString(),
    lambda_I_to_H.toString(),
    isFirstSimulation.toString(),
    JSON.stringify(ic.fractions),
  ];
  // Con firstSimulation=true Python escribe public/results/simulation.json y no imprime nada.
  const result = await execPythonScriptWithReturn(params, !isFirstSimulation);
  return result;
};

/**
 * Ejecuta la simulación con los valores por defecto y la guarda en
 * public/results/simulation.json (+ simulation.meta.json).
 */
export const getFirstSimulation = async (): Promise<void> => {
  const d = await getSimulationDefaults();
  await getSimulation(JSON.stringify(d.Rt), d.UCI_threshold, d.V_filtered, d.lambda_I_to_H, true);
};

// ── Tope global de procesos de Python simultáneos ───────────────────────────
// El límite de peticiones es por IP; sin este tope, muchas IPs a la vez podrían
// lanzar cientos de procesos y saturar la CPU. Las simulaciones que exceden el
// tope esperan en una cola acotada; si la cola está llena se responde 503.
let runningSimulations = 0;
const waitingSimulations: Array<() => void> = [];

async function acquireSimulationSlot(): Promise<void> {
  if (runningSimulations < environment.MAX_CONCURRENT_SIMULATIONS) {
    runningSimulations++;
    return;
  }
  if (waitingSimulations.length >= environment.SIMULATION_QUEUE_MAX) {
    throw new AppError('The simulation server is busy, please try again shortly', 503);
  }
  // El lugar se transfiere directamente al liberarse (no se re-cuenta aquí)
  await new Promise<void>((resolve) => waitingSimulations.push(resolve));
}

function releaseSimulationSlot(): void {
  const next = waitingSimulations.shift();
  if (next) next();
  else runningSimulations--;
}

const execPythonScriptWithReturn = async (
  params: string[],
  expectJsonOutput: boolean,
): Promise<string> => {
  await acquireSimulationSlot();
  try {
    return await runPythonScript(params, expectJsonOutput);
  } finally {
    releaseSimulationSlot();
  }
};

const runPythonScript = async (params: string[], expectJsonOutput: boolean): Promise<string> => {
  const options = {
    mode: 'text' as const,
    pythonPath: environment.PYTHON_PATH,
    scriptPath: getPath(pathNames.PY_SCRIPTS),
    args: params,
  };
  const pyshell = new PythonShell(fileNames.SIMULADOR_PY, options);

  const outputLines: string[] = [];
  pyshell.on('message', function (message) {
    outputLines.push(message);
  });

  return await new Promise<string>((resolve, reject) => {
    // La promesa se resuelve UNA sola vez, pase lo que pase primero:
    // fin normal, error del proceso o tiempo agotado.
    let settled = false;
    const finish = (fn: () => void): void => {
      if (settled) return;
      settled = true;
      globalThis.clearTimeout(timer);
      fn();
    };

    // Sin este límite, un Python colgado dejaba la petición HTTP sin respuesta.
    const timeoutMs = environment.SIMULATION_TIMEOUT_MS;
    const timer = globalThis.setTimeout(() => {
      finish(() => {
        try {
          pyshell.kill();
        } catch {
          /* el proceso ya terminó */
        }
        reject(
          new AppError(`The simulation timed out after ${Math.round(timeoutMs / 1000)} s`, 504),
        );
      });
    }, timeoutMs);

    // 'error' = fallo del PROCESO (no del script). Si el intérprete no existe
    // (ENOENT) python-shell nunca llama al callback de end(): había que cortar
    // aquí, o la petición quedaba colgada para siempre.
    pyshell.on('error', function (err: unknown) {
      finish(() => {
        const code = (err as { code?: string } | null)?.code;
        reject(
          code === 'ENOENT'
            ? new Error(
                `Python interpreter not found: "${environment.PYTHON_PATH}". ` +
                  'Set PYTHON_PATH to an interpreter with numpy and scipy.',
              )
            : new Error(`Python error: ${String(err)}`),
        );
      });
    });

    pyshell.end(function (err, _code, _signal) {
      finish(() => {
        if (err) {
          reject(classifyPythonError(err));
          return;
        }
        if (!expectJsonOutput) {
          resolve('');
          return;
        }
        // Find the last line that looks like a JSON object (starts with '{').
        // Any warnings or log messages printed by Python/numpy before the result are ignored.
        const jsonLine = [...outputLines]
          .reverse()
          .find((line) => line.trimStart().startsWith('{'));
        if (!jsonLine) {
          reject(new Error(`No JSON output from Python. Full output: ${outputLines.join('\n')}`));
          return;
        }
        resolve(jsonLine);
      });
    });
  });
};
