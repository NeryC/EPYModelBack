import { ProjectionInput, ProjectionOutput } from '../../domain/projection.js';
import { ProjectionService } from '../../services/projectionService.js';

export async function executeGetProjectionsUseCase(
  input: ProjectionInput,
): Promise<ProjectionOutput> {
  const { format } = input;
  const projectionService = new ProjectionService();
  const result = await projectionService.getAllProjections(format);
  return result as ProjectionOutput;
}

