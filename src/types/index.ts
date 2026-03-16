// Environment configuration
export interface EnvironmentConfig {
  PORT: number;
  NODE_ENV: 'development' | 'production' | 'test';
  CORS_ORIGIN?: string;
  REDIS_URL?: string;
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
