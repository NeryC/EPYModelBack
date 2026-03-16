import { z } from 'zod';

/**
 * Zod schemas for projection API validation
 * Provides runtime type safety and validation
 */

// Projection data point schema
export const ProjectionDataPointSchema = z.object({
  fecha: z.string(),
  value: z.number(),
  uncertainty_lower: z.number().optional(),
  uncertainty_upper: z.number().optional(),
  scenario: z.string().optional(),
});

// Format validation schema
export const ProjectionFormatSchema = z.enum(['json', 'csv']);

// Query parameter schema
export const ProjectionQuerySchema = z.object({
  format: ProjectionFormatSchema.default('json'),
});

// Projection response schema
export const ProjectionResponseSchema = z.object({
  R: z.array(ProjectionDataPointSchema),
  H: z.array(ProjectionDataPointSchema),
  U: z.array(ProjectionDataPointSchema),
  F: z.array(ProjectionDataPointSchema),
});

// API response wrapper schema
export const ProjectionApiResponseSchema = z.object({
  success: z.boolean(),
  data: ProjectionResponseSchema,
  message: z.string().optional(),
});

// Type exports
export type ProjectionDataPoint = z.infer<typeof ProjectionDataPointSchema>;
export type ProjectionFormat = z.infer<typeof ProjectionFormatSchema>;
export type ProjectionQuery = z.infer<typeof ProjectionQuerySchema>;
export type ProjectionResponse = z.infer<typeof ProjectionResponseSchema>;
export type ProjectionApiResponse = z.infer<typeof ProjectionApiResponseSchema>;

// Validation helpers
export const validateProjectionQuery = (data: unknown): ProjectionQuery => {
  return ProjectionQuerySchema.parse(data);
};

export const validateProjectionResponse = (data: unknown): ProjectionResponse => {
  return ProjectionResponseSchema.parse(data);
};

export const validateProjectionApiResponse = (data: unknown): ProjectionApiResponse => {
  return ProjectionApiResponseSchema.parse(data);
};