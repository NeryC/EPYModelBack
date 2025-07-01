import { Request, Response } from "express";
import { AppError, asyncHandler } from "../utils/errorHandler.js";
import { ProjectionService } from "../services/projectionService.js";

export class ProjectionController {
  private projectionService: ProjectionService;

  constructor() {
    this.projectionService = new ProjectionService();
  }

  /**
   * Get all projections with specified format
   */
  getProjections = asyncHandler(
    async (req: Request, res: Response): Promise<void> => {
      const format = (req.query.format as "json" | "csv") || "json";

      console.log(`/projections?format=${format}`);

      try {
        const projections = await this.projectionService.getAllProjections(
          format
        );

        // Set appropriate headers
        res.setHeader("Content-Type", "application/json");
        res.setHeader("Cache-Control", "public, max-age=86400"); // Cache for 1 day

        res.json({
          success: true,
          format,
          timestamp: new Date().toISOString(),
          projections,
        });
      } catch (error) {
        throw new AppError(`Failed to read projection files: ${error}`, 500);
      }
    }
  );
}
