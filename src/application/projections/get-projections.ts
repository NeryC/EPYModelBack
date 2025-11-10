/**
 * Application Layer - Get Projections Use Case
 * 
 * This use case orchestrates the retrieval of projections in the specified format.
 * It depends on domain interfaces and infrastructure repositories.
 */

import { ProjectionInput, ProjectionOutput, IProjectionRepository } from '../../domain/projection.js';

/**
 * Execute get projections use case
 * 
 * @param input - Projection input with format specification
 * @param repository - Projection repository interface
 * @returns Projection output in the specified format
 * @throws Error if projection retrieval fails
 */
export async function executeGetProjectionsUseCase(
  input: ProjectionInput,
  repository: IProjectionRepository,
): Promise<ProjectionOutput> {
  const { format } = input;
  
  // Get projections from repository
  const data = await repository.findAll(format);
  
  return {
    data,
    format,
  };
}

