import { Request, Response } from "express";
import { AppError, asyncHandler } from "../utils/errorHandler.js";
import { SimulationService } from "../services/simulationService.js";

export class SimulationController {
  private simulationService: SimulationService;

  constructor() {
    this.simulationService = new SimulationService();
  }

  /**
   * Get simulation with custom parameters
   */
  getSimulation = asyncHandler(
    async (req: Request, res: Response): Promise<void> => {
      console.log("/get-simulation");

      const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = req.query;

      try {
        // Validate parameters using service
        this.simulationService.validateSimulationParams({
          Rt: Rt as string,
          UCI_threshold: UCI_threshold as string,
          V_filtered: V_filtered as string,
          lambda_I_to_H: lambda_I_to_H as string,
        });

        const responseData = await this.simulationService.executeSimulation({
          Rt: Rt as string,
          UCI_threshold: UCI_threshold as string,
          V_filtered: V_filtered as string,
          lambda_I_to_H: lambda_I_to_H as string,
        });

        res.json({
          success: true,
          data: responseData,
          message: "Simulation completed successfully",
        });
      } catch (error) {
        throw new AppError(
          `Simulation failed: ${
            error instanceof Error ? error.message : "Unknown error"
          }`,
          500
        );
      }
    }
  );

  /**
   * Get first simulation (default parameters)
   */
  getFirstSimulation = asyncHandler(
    async (req: Request, res: Response): Promise<void> => {
      console.log("/get-first-simulation");

      try {
        const { filePath, fileName } =
          await this.simulationService.getSimulationFile();

        res.download(filePath, fileName, (err: Error | null) => {
          if (err) {
            throw new AppError(`Failed to download ${fileName}`, 500);
          }
        });
      } catch (error) {
        throw new AppError(
          `Failed to get simulation file: ${
            error instanceof Error ? error.message : "Unknown error"
          }`,
          500
        );
      }
    }
  );

  /**
   * Get first simulation with execution (test endpoint)
   */
  getFirstSimulationWithExecution = asyncHandler(
    async (req: Request, res: Response): Promise<void> => {
      console.log("/get-first-simulation-2");

      try {
        const { filePath, fileName } =
          await this.simulationService.executeAndGetSimulationFile();

        res.download(filePath, fileName, (err: Error | null) => {
          if (err) {
            throw new AppError(`Failed to download ${fileName}`, 500);
          }
        });
      } catch (error) {
        throw new AppError(
          `Simulation execution failed: ${
            error instanceof Error ? error.message : "Unknown error"
          }`,
          500
        );
      }
    }
  );
}
