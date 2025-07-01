import { EnvironmentConfig } from "../types/index.js";

/**
 * Environment configuration with default values and type safety
 */
export const environment: EnvironmentConfig = {
  PORT: parseInt(process.env.PORT || "3001", 10),
  NODE_ENV: process.env.NODE_ENV || "development",
};

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
