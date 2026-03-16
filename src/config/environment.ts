import { EnvironmentConfig } from "../types/index.js";
import { logger } from "../utils/logger.js";

const rawNodeEnv = process.env.NODE_ENV ?? "development";
const nodeEnv: 'development' | 'production' | 'test' =
  rawNodeEnv === "production" || rawNodeEnv === "test"
    ? rawNodeEnv
    : "development";

/**
 * Environment configuration with default values and type safety
 */
export const environment: EnvironmentConfig = {
  PORT: parseInt(process.env.PORT || "3001", 10),
  NODE_ENV: nodeEnv,
  // optional CORS allow list, comma-separated
  CORS_ORIGIN: process.env.CORS_ORIGIN || "*",
  // optional redis url for BullMQ
  REDIS_URL: process.env.REDIS_URL || "",
};

if (environment.CORS_ORIGIN === '*' && environment.NODE_ENV === 'production') {
  logger.warn('CORS_ORIGIN is set to * in production');
}

/**
 * Validates that all required environment variables are present
 */
export function validateEnvironment(): void {
  const requiredVars = ["PORT"];

  for (const varName of requiredVars) {
    if (!process.env[varName] && environment.NODE_ENV === "production") {
      throw new Error(`Missing required environment variable: ${varName}`);
    }
  }
}

/**
 * Checks if the application is running in development mode
 */
export function isDevelopment(): boolean {
  return environment.NODE_ENV === "development";
}

/**
 * Checks if the application is running in production mode
 */
export function isProduction(): boolean {
  return environment.NODE_ENV === "production";
}
