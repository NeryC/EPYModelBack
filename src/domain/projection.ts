/**
 * Domain Layer - Projection Entity and Interfaces
 * 
 * This file contains the core domain entities and repository interfaces
 * for the Projection domain. It should not depend on any other layers.
 */

/**
 * Projection data point
 */
export interface ProjectionDataPoint {
  fecha: string;
  value: number;
  uncertainty_lower?: number;
  uncertainty_upper?: number;
}

/**
 * Projection entity - core domain model
 */
export interface Projection {
  id: string;
  data: ProjectionDataPoint[];
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Input for getting projections
 * Used in Application layer use cases
 */
export interface ProjectionInput {
  format: 'json' | 'csv';
}

/**
 * Output from projection retrieval
 * Used in Application layer use cases
 */
export interface ProjectionOutput {
  data: ProjectionDataPoint[] | string; // string for CSV format
  format: 'json' | 'csv';
}

/**
 * Repository interface for Projection persistence
 * Implementations should be in Infrastructure layer
 */
export interface IProjectionRepository {
  /**
   * Get all projections in the specified format
   */
  findAll(format: 'json' | 'csv'): Promise<ProjectionDataPoint[] | string>;

  /**
   * Find projection by ID
   */
  findById(id: string): Promise<Projection | null>;
}

