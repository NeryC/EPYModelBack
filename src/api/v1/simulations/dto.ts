import { z } from 'zod';
import { SIMULATION_LIMITS as L } from '../../../domain/simulation.js';

/**
 * Zod schemas for simulation API validation
 * Provides runtime type safety and validation.
 * Los rangos vienen de SIMULATION_LIMITS (domain/simulation.ts).
 */

// Shared Rt validator used by both SimulationParamsSchema and SimulationQuerySchema:
// JSON array de 1–12 números, cada uno entre 0 y 2.
const rtValidator = z.string().superRefine((val, ctx) => {
  let parsed: unknown;
  try {
    parsed = JSON.parse(val);
  } catch {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Rt must be a valid JSON array of numbers',
    });
    return;
  }
  if (
    !Array.isArray(parsed) ||
    !parsed.every((item) => typeof item === 'number' && Number.isFinite(item))
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Rt must be a valid JSON array of numbers',
    });
    return;
  }
  if (parsed.length < L.RT_MONTHS_MIN || parsed.length > L.RT_MONTHS_MAX) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: `Rt must have between ${L.RT_MONTHS_MIN} and ${L.RT_MONTHS_MAX} monthly values`,
    });
    return;
  }
  if (parsed.some((v: number) => v < L.RT_MIN || v > L.RT_MAX)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: `Each Rt value must be between ${L.RT_MIN} and ${L.RT_MAX}`,
    });
  }
});

const rangeMessage = (name: string, min: number, max: number): string =>
  `${name} must be between ${min} and ${max}`;

// Base simulation parameter schema
export const SimulationParamsSchema = z.object({
  Rt: rtValidator,
  UCI_threshold: z.coerce
    .number()
    .int('UCI_threshold must be a whole number')
    .min(L.UCI_MIN, rangeMessage('UCI_threshold', L.UCI_MIN, L.UCI_MAX))
    .max(L.UCI_MAX, rangeMessage('UCI_threshold', L.UCI_MIN, L.UCI_MAX)),
  V_filtered: z.coerce
    .number()
    .int('V_filtered must be a whole number')
    .min(L.V_MIN, rangeMessage('V_filtered', L.V_MIN, L.V_MAX))
    .max(L.V_MAX, rangeMessage('V_filtered', L.V_MIN, L.V_MAX)),
  lambda_I_to_H: z.coerce
    .number()
    .min(L.LAMBDA_MIN, rangeMessage('lambda_I_to_H', L.LAMBDA_MIN, L.LAMBDA_MAX))
    .max(L.LAMBDA_MAX, rangeMessage('lambda_I_to_H', L.LAMBDA_MIN, L.LAMBDA_MAX)),
});

/**
 * Número decimal en texto (query string) dentro de [min, max].
 * Se mantiene como string porque validateQuery copia el resultado a req.query
 * y el controlador hace la conversión final.
 */
const numericQueryString = (name: string, min: number, max: number, integer = false) =>
  z
    .string()
    .regex(/^\d+(\.\d+)?$/, `${name} must be a valid number`)
    // Camas y personas por día: enteros (antes se aceptaba 12.5 camas)
    .refine((v) => !integer || Number.isInteger(Number(v)), {
      message: `${name} must be a whole number`,
    })
    .refine((v) => Number(v) >= min && Number(v) <= max, {
      message: rangeMessage(name, min, max),
    });

// Query parameter schema for GET requests
// Note: Query parameters come as strings, so we validate them as strings
// The controller will parse them to the correct types
export const SimulationQuerySchema = z.object({
  Rt: rtValidator,
  UCI_threshold: numericQueryString('UCI_threshold', L.UCI_MIN, L.UCI_MAX, true),
  V_filtered: numericQueryString('V_filtered', L.V_MIN, L.V_MAX, true),
  lambda_I_to_H: numericQueryString('lambda_I_to_H', L.LAMBDA_MIN, L.LAMBDA_MAX),
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
