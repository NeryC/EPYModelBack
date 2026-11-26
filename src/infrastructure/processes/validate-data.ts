/**
 * Validación de los datos crudos del MSPBS antes de limpiarlos y ajustar el modelo.
 *
 * Origen: en jul-2023 los CSV se reescribieron con un script que leía las fechas
 * día/mes/año como mes/día/año (pd.to_datetime sin dayfirst). Los días ≤ 12
 * quedaron con día y mes intercambiados y los archivos, ordenados por esas
 * fechas falsas. Nada lo detectó: el modelo R se ajustó con hospitalizados
 * desordenados (~65 días de desfase) y la página mostró el pico de 2021 en
 * agosto en vez de junio. Estas reglas detienen el pipeline ante ese patrón.
 *
 * Umbrales calibrados con los datos reales: feb-2023 (correctos) los cumple
 * todos; jul-2023 (corruptos) los viola todos.
 */
import fs from 'fs';
import path from 'path';

/** Primer caso confirmado de COVID-19 en Paraguay (MSPBS, 7-mar-2020). */
export const FIRST_CASE_DATE = '2020-03-07';
/** Mínimo de fallecidos cuya fecha de óbito es 0–60 días antes de su divulgación. */
export const MIN_DEATH_DATE_COHERENCE = 0.85;

export const RAW_FILES = {
  registry: 'REGISTRO DIARIO_Datos completos_data.csv',
  cases: 'Descargar datos_Datos completos_data.csv',
  deaths: 'FALLECIDOS_Datos completos_data.csv',
} as const;

/** "7/3/2020" o "07/03/2020" (día/mes/año) → "2020-03-07"; null si no es una fecha válida. */
export function parseDayMonthYear(text: string): string | null {
  const m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(text.trim());
  if (!m) return null;
  const [, d, mo, y] = m;
  const iso = `${y}-${(mo as string).padStart(2, '0')}-${(d as string).padStart(2, '0')}`;
  const date = new Date(`${iso}T00:00:00Z`);
  return Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== iso ? null : iso;
}

const BOM = new RegExp('^' + String.fromCharCode(0xfeff));

/** Columna (por nombre de encabezado) de un CSV separado por ";". */
function column(csv: string, name: string): string[] {
  const lines = csv
    .replace(BOM, '')
    .split(/\r?\n/)
    .filter((l) => l.trim() !== '');
  const header = (lines[0] ?? '').split(';').map((h) => h.trim().replace(/^"|"$/g, ''));
  const i = header.indexOf(name);
  if (i < 0) throw new Error(`falta la columna "${name}"`);
  return lines.slice(1).map((l) => l.split(';')[i] ?? '');
}

const daysBetween = (a: string, b: string): number =>
  (Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 864e5;

export function validateRegistry(csv: string): string[] {
  const problems: string[] = [];
  const raw = column(csv, 'Fecha');
  const dates = raw.map(parseDayMonthYear);
  const invalid = dates.filter((d) => d === null).length;
  if (invalid > 0) problems.push(`registro diario: ${invalid} fechas ilegibles como día/mes/año`);
  const valid = dates.filter((d): d is string => d !== null);
  const early = valid.filter((d) => d < FIRST_CASE_DATE).length;
  if (early > 0) {
    problems.push(
      `registro diario: ${early} fechas anteriores al primer caso (${FIRST_CASE_DATE}); ` +
        'probable intercambio día/mes',
    );
  }
  const duplicated = valid.length - new Set(valid).size;
  if (duplicated > 0) problems.push(`registro diario: ${duplicated} fechas duplicadas`);
  return problems;
}

export function validateCases(csv: string): string[] {
  const dates = column(csv, 'Fecha Confirmacion').map(parseDayMonthYear);
  const problems: string[] = [];
  const invalid = dates.filter((d) => d === null).length;
  if (invalid > 0) problems.push(`casos: ${invalid} fechas de confirmación ilegibles`);
  const early = dates.filter((d) => d !== null && d < FIRST_CASE_DATE).length;
  if (early > 0) {
    problems.push(
      `casos: ${early} confirmados antes del primer caso (${FIRST_CASE_DATE}); probable intercambio día/mes`,
    );
  }
  return problems;
}

export function validateDeaths(csv: string): string[] {
  const death = column(csv, 'Fecha Obito').map(parseDayMonthYear);
  const report = column(csv, 'Fecha de Divulgación').map(parseDayMonthYear);
  const problems: string[] = [];
  const invalid = death.filter((d) => d === null).length + report.filter((d) => d === null).length;
  if (invalid > 0) problems.push(`fallecidos: ${invalid} fechas ilegibles`);
  const early = death.filter((d) => d !== null && d < FIRST_CASE_DATE).length;
  if (early > 0)
    problems.push(`fallecidos: ${early} óbitos antes del primer caso (${FIRST_CASE_DATE})`);
  let comparable = 0;
  let coherent = 0;
  death.forEach((d, i) => {
    const r = report[i];
    if (!d || !r) return;
    comparable++;
    const lag = daysBetween(d, r);
    if (lag >= 0 && lag <= 60) coherent++;
  });
  const ratio = comparable ? coherent / comparable : 0;
  if (ratio < MIN_DEATH_DATE_COHERENCE) {
    problems.push(
      `fallecidos: solo el ${(ratio * 100).toFixed(1)}% de los óbitos cae 0–60 días antes de su ` +
        `divulgación (mínimo ${MIN_DEATH_DATE_COHERENCE * 100}%); probable intercambio día/mes`,
    );
  }
  return problems;
}

/** Valida los tres archivos crudos; devuelve la lista de problemas (vacía = OK). */
export function validateRawData(dataDir: string): string[] {
  const read = (f: string): string => fs.readFileSync(path.join(dataDir, f), 'utf8');
  return [
    ...validateRegistry(read(RAW_FILES.registry)),
    ...validateCases(read(RAW_FILES.cases)),
    ...validateDeaths(read(RAW_FILES.deaths)),
  ];
}

/** Lanza un error (detiene el pipeline) si los datos crudos no pasan la validación. */
export function assertRawDataValid(dataDir: string): void {
  const problems = validateRawData(dataDir);
  if (problems.length > 0) {
    throw new Error(
      'Datos crudos inválidos, se detiene el pipeline:\n  - ' +
        problems.join('\n  - ') +
        '\nRevisar si los CSV fueron abiertos o reescritos con fechas mes/día/año.',
    );
  }
}
