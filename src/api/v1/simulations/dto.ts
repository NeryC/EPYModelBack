import { z } from 'zod';

/**
 * Zod schemas for simulation API validation
 * Provides runtime type safety and validation
 */

// Base simulation parameter schema
export const SimulationParamsSchema = z.object({
  Rt: z.string().refine(
    (val) => {
      try {
        const parsed = JSON.parse(val);
        return Array.isArray(parsed) && parsed.every((item) => typeof item === 'number');
      } catch {
        return false;
      }
    },
    {
      message: 'Rt must be a valid JSON array of numbers',
    }
  ),
  UCI_threshold: z.coerce
    .number()
    .positive('UCI_threshold must be a positive number')
    .max(10000, 'UCI_threshold cannot exceed 10000'),
  V_filtered: z.coerce
    .number()
    .positive('V_filtered must be a positive number')
    .max(1000000, 'V_filtered cannot exceed 1,000,000'),
  lambda_I_to_H: z.coerce
    .number()
    .min(0, 'lambda_I_to_H must be at least 0')
    .max(1, 'lambda_I_to_H cannot exceed 1'),
});

// Query parameter schema for GET requests
// Note: Query parameters come as strings, so we validate them as strings
// The controller will parse them to the correct types
export const SimulationQuerySchema = z.object({
  Rt: z.string().refine(
    (val) => {
      try {
        const parsed = JSON.parse(val);
        return Array.isArray(parsed) && parsed.every((item) => typeof item === 'number');
      } catch {
        return false;
      }
    },
    {
      message: 'Rt must be a valid JSON array of numbers',
    },
  ),
  UCI_threshold: z.string().regex(/^\d+(\.\d+)?$/, 'UCI_threshold must be a valid number'),
  V_filtered: z.string().regex(/^\d+(\.\d+)?$/, 'V_filtered must be a valid number'),
  lambda_I_to_H: z.string().regex(/^\d+(\.\d+)?$/, 'lambda_I_to_H must be a valid number'),
});

// Response schemas
export const SimulationDataPointSchema = z.object({
  fecha: z.string(),
  value: z.number(),
  uncertainty_lower: z.number().optional(),
  uncertainty_upper: z.number().optional(),
});

export const SimulationResponseSchema = z.object({
  cumulative: z.array(SimulationDataPointSchema),
  cumulative_deaths: z.array(SimulationDataPointSchema),
  exposed: z.array(SimulationDataPointSchema),
  hospitalized: z.array(SimulationDataPointSchema),
  immune: z.array(SimulationDataPointSchema),
  infectious: z.array(SimulationDataPointSchema),
  susceptible: z.array(SimulationDataPointSchema),
  uci: z.array(SimulationDataPointSchema),
});

// API response wrapper schema
export const ApiResponseSchema = z.object({
  success: z.boolean(),
  data: z.any().optional(),
  message: z.string().optional(),
  error: z.string().optional(),
});

// Type exports
export type SimulationParams = z.infer<typeof SimulationParamsSchema>;
export type SimulationQuery = z.infer<typeof SimulationQuerySchema>;
export type SimulationDataPoint = z.infer<typeof SimulationDataPointSchema>;
export type SimulationResponse = z.infer<typeof SimulationResponseSchema>;
export type ApiResponse = z.infer<typeof ApiResponseSchema>;

// Validation helpers
export const validateSimulationParams = (data: unknown): SimulationParams => {
  return SimulationParamsSchema.parse(data);
};

export const validateSimulationQuery = (data: unknown): SimulationQuery => {
  return SimulationQuerySchema.parse(data);
};

export const validateApiResponse = (data: unknown): ApiResponse => {
  return ApiResponseSchema.parse(data);
};