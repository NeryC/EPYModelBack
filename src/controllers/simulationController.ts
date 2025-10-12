import { Request, Response } from 'express';
import { AppError, asyncHandler } from '../utils/errorHandler.js';
import { SimulationService } from '../services/simulationService.js';
import { executeSimulationUseCase } from '../application/simulations/get-simulation.js';
import { runFirstSimulationAndGetFile } from '../application/simulations/get-first-simulation-file.js';

export class SimulationController {
  private simulationService: SimulationService;

  constructor() {
    this.simulationService = new SimulationService();
  }

  /**
   * Get simulation with custom parameters
   */
  getSimulation = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    console.log('/get-simulation');

    const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = req.query;

    try {
      // Validate parameters using service
      this.simulationService.validateSimulationParams({
        Rt: Rt as string,
        UCI_threshold: UCI_threshold as string,
        V_filtered: V_filtered as string,
        lambda_I_to_H: lambda_I_to_H as string,
      });

      const responseData = await executeSimulationUseCase({
        Rt: Rt as string,
        UCI_threshold: UCI_threshold as string,
        V_filtered: V_filtered as string,
        lambda_I_to_H: lambda_I_to_H as string,
      });

      // Parse the response if it's a JSON string
      let parsedData = responseData;
      if (typeof responseData === 'string') {
        try {
          parsedData = JSON.parse(responseData);
        } catch (parseError) {
          console.warn('Failed to parse simulation response as JSON:', parseError);
          // If parsing fails, return the raw string
          parsedData = responseData;
        }
      }

      res.json({
        success: true,
        data: parsedData,
        message: 'Simulation completed successfully',
      });
    } catch (error) {
      throw new AppError(
        `Simulation failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        500,
      );
    }
  });

  /**
   * Get first simulation (default parameters)
   */
  getFirstSimulation = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    console.log('/get-first-simulation');

    try {
      const { filePath, fileName } = await this.simulationService.getSimulationFile();

      res.download(filePath, fileName, (err: Error | null) => {
        if (err) {
          throw new AppError(`Failed to download ${fileName}`, 500);
        }
      });
    } catch (error) {
      throw new AppError(
        `Failed to get simulation file: ${
          error instanceof Error ? error.message : 'Unknown error'
        }`,
        500,
      );
    }
  });

  /**
   * Get first simulation data as JSON
   */
  getFirstSimulationData = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    console.log('/get-first-simulation-data');

    try {
      const simulationData = await this.simulationService.getFirstSimulationData();

      res.json({
        success: true,
        data: simulationData,
        message: 'First simulation data retrieved successfully',
      });
    } catch (error) {
      throw new AppError(
        `Failed to get simulation data: ${
          error instanceof Error ? error.message : 'Unknown error'
        }`,
        500,
      );
    }
  });

  /**
   * Get first simulation with execution (test endpoint)
   */
  getFirstSimulationWithExecution = asyncHandler(
    async (req: Request, res: Response): Promise<void> => {
      console.log('/get-first-simulation-2');

      try {
        const { filePath, fileName } = await runFirstSimulationAndGetFile();

        res.download(filePath, fileName, (err: Error | null) => {
          if (err) {
            throw new AppError(`Failed to download ${fileName}`, 500);
          }
        });
      } catch (error) {
        throw new AppError(
          `Simulation execution failed: ${
            error instanceof Error ? error.message : 'Unknown error'
          }`,
          500,
        );
      }
    },
  );
}
