// Environment configuration
export interface EnvironmentConfig {
  PORT: number;
  NODE_ENV: 'development' | 'production' | 'test';
  CORS_ORIGIN?: string;
  REDIS_URL?: string;
  /** Intérprete de Python que ejecuta simulador.py (debe tener numpy y scipy). */
  PYTHON_PATH: string;
  /** Tiempo máximo de una simulación antes de cortarla (ms). */
  SIMULATION_TIMEOUT_MS: number;
  /** Límites de peticiones por IP (ver middleware/rateLimits.ts). */
  RATE_LIMIT: {
    windowMinutes: number;
    max: number;
    simulationMax: number;
  };
}

// Simulation parameters
export interface SimulationParams {
  Rt: string;
  UCI_threshold: string;
  V_filtered: string;
  lambda_I_to_H: string;
}

// API response types
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}
