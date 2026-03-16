/**
 * Presentation Layer - Projection Controller
 * 
 * This controller handles HTTP requests for projection endpoints.
 * It transforms DTOs to domain inputs and orchestrates use cases.
 */

import { Request, Response } from 'express';
import { asyncHandler, sendSuccessResponse } from '../utils/errorHandler.js';
import { executeGetProjectionsUseCase } from '../application/projections/get-projections.js';
import { FileProjectionRepository } from '../infrastructure/storage/projection-repository.js';
import { ProjectionInput } from '../domain/projection.js';

/**
 * Projection Controller
 * Handles HTTP requests for projection-related endpoints
 */
export class ProjectionController {
  private projectionRepository: FileProjectionRepository;

  constructor() {
    this.projectionRepository = new FileProjectionRepository();
  }

  /**
   * Get all projections in the specified format
   * 
   * Validates query parameters, transforms to domain input,
   * executes use case, and returns formatted response
   */
  getProjections = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { format } = req.query;

    // Transform query parameter to domain input
    const input: ProjectionInput = {
      format: (format as 'json' | 'csv') || 'json',
    };

    // Execute use case
    const result = await executeGetProjectionsUseCase(input, this.projectionRepository);

    // Return formatted response
    sendSuccessResponse(res, result.data, 'Projections retrieved successfully');
  });
}
