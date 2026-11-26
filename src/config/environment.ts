import { existsSync } from 'fs';
import path from 'path';
import { EnvironmentConfig } from '../types/index.js';
import { logger } from '../utils/logger.js';

/**
 * Resuelve el intérprete de Python para los scripts del modelo:
 *   1. `PYTHON_PATH` si está definida en el entorno.
 *   2. El virtualenv del proyecto (`.venv/`), si existe.
 *   3. El intérprete del PATH: `python` en Windows, `python3` en Linux/macOS
 *      (mismo criterio que python-shell; la imagen Docker, basada en Ubuntu,
 *      solo trae `python3`).
 */
export function resolvePythonPath(
  env: Record<string, string | undefined> = process.env,
  cwd: string = process.cwd(),
  exists: (p: string) => boolean = existsSync,
  platform: string = process.platform,
): string {
  if (env.PYTHON_PATH) return env.PYTHON_PATH;
  const venvCandidates = [
    path.join(cwd, '.venv', 'Scripts', 'python.exe'), // Windows
    path.join(cwd, '.venv', 'bin', 'python'), // Linux / macOS
  ];
  return venvCandidates.find((p) => exists(p)) ?? (platform === 'win32' ? 'python' : 'python3');
}

/** Entero positivo desde una variable de entorno, o el valor por defecto. */
export function positiveInt(raw: string | undefined, fallback: number): number {
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}

const rawNodeEnv = process.env.NODE_ENV ?? 'development';
const nodeEnv: 'development' | 'production' | 'test' =
  rawNodeEnv === 'production' || rawNodeEnv === 'test' ? rawNodeEnv : 'development';

/**
 * Environment configuration with default values and type safety
 */
export const environment: EnvironmentConfig = {
  PORT: parseInt(process.env.PORT || '3001', 10),
  NODE_ENV: nodeEnv,
  // optional CORS allow list, comma-separated
  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',
  // optional redis url for BullMQ
  REDIS_URL: process.env.REDIS_URL || '',
  PYTHON_PATH: resolvePythonPath(),
  // Una simulación normal tarda ~1 s; los casos rígidos más extremos, ~10 s.
  SIMULATION_TIMEOUT_MS: positiveInt(process.env.SIMULATION_TIMEOUT_MS, 60_000),
  // Límites por IP y ventana. Antes: 100 peticiones / 15 min para TODA la API,
  // lo que una clase o una defensa detrás de una misma IP agotaba enseguida.
  RATE_LIMIT: {
    windowMinutes: positiveInt(process.env.RATE_LIMIT_WINDOW_MINUTES, 15),
    max: positiveInt(process.env.RATE_LIMIT_MAX, 10000),
    simulationMax: positiveInt(process.env.SIMULATION_RATE_LIMIT_MAX, 2000),
  },
};

if (environment.CORS_ORIGIN === '*' && environment.NODE_ENV === 'production') {
  logger.warn('CORS_ORIGIN is set to * in production');
}

/**
 * Validates that all required environment variables are present
 */
export function validateEnvironment(): void {
  const requiredVars = ['PORT'];

  for (const varName of requiredVars) {
    if (!process.env[varName] && environment.NODE_ENV === 'production') {
      throw new Error(`Missing required environment variable: ${varName}`);
    }
  }
}

/**
 * Checks if the application is running in development mode
 */
export function isDevelopment(): boolean {
  return environment.NODE_ENV === 'development';
}

/**
 * Checks if the application is running in production mode
 */
export function isProduction(): boolean {
  return environment.NODE_ENV === 'production';
}
