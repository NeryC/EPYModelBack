import { Request, Response } from 'express';
import { AppError, asyncHandler } from '../utils/errorHandler.js';
import { executeGetProjectionsUseCase } from '../application/projections/get-projections.js';

export class ProjectionController {
  /**
   * Get all projections in the specified format
   */
  getProjections = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    console.log('/projections');

    const { format } = req.query;

    try {
      const responseData = await executeGetProjectionsUseCase({
        format: (format as 'json' | 'csv') || 'json',
      });

      res.json({
        success: true,
        data: responseData,
        message: 'Projections retrieved successfully',
      });
    } catch (error) {
      throw new AppError(
        `Failed to get projections: ${error instanceof Error ? error.message : 'Unknown error'}`,
        500,
      );
    }
  });
}
