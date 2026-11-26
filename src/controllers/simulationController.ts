/**
 * Presentation Layer - Simulation Controller
 *
 * This controller handles HTTP requests for simulation endpoints.
 * It transforms DTOs to domain inputs and orchestrates use cases.
 */

import { NextFunction, Request, Response } from 'express';
import { AppError, asyncHandler, sendSuccessResponse } from '../utils/errorHandler.js';
import { executeSimulationUseCase } from '../application/simulations/get-simulation.js';
import { runFirstSimulationAndGetFile } from '../application/simulations/get-first-simulation-file.js';
import { getSimulationDefaultsUseCase } from '../application/simulations/get-simulation-defaults.js';
import { FileSimulationRepository } from '../infrastructure/storage/simulation-repository.js';
import { SimulationInput } from '../domain/simulation.js';

/**
 * Simulation Controller
 * Handles HTTP requests for simulation-related endpoints
 */
export class SimulationController {
  private simulationRepository: FileSimulationRepository;

  constructor() {
    this.simulationRepository = new FileSimulationRepository();
  }

  /**
   * Get simulation with custom parameters
   *
   * Validates query parameters, transforms to domain input,
   * executes use case, and returns formatted response
   */
  getSimulation = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    // Los parámetros ya fueron validados (formato y rangos de SIMULATION_LIMITS)
    // por validateQuery(SimulationQuerySchema); aquí solo se convierten los tipos.
    const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = req.query;

    const input: SimulationInput = {
      Rt: JSON.parse(Rt as string) as number[],
      UCI_threshold: Number(UCI_threshold),
      V_filtered: Number(V_filtered),
      lambda_I_to_H: Number(lambda_I_to_H),
    };

    // Execute use case
    const result = await executeSimulationUseCase(input);

    // Return formatted response
    sendSuccessResponse(res, result.results, 'Simulation completed successfully');
  });

  /**
   * Get first simulation file (default parameters)
   *
   * Returns the simulation file for download
   */
  getFirstSimulation = asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      const { filePath, fileName } = await this.simulationRepository.getSimulationFilePath();

      res.download(filePath, fileName, (err: Error | null) => {
        if (err && !res.headersSent) {
          next(new AppError(`Failed to download ${fileName}`, 500));
        }
      });
    },
  );

  /**
   * Get first simulation data as JSON
   *
   * Returns the simulation data as JSON response
   */
  /**
   * Valores por defecto del simulador (escenario base + parámetros ajustados por R)
   */
  getSimulationDefaults = asyncHandler(async (_req: Request, res: Response): Promise<void> => {
    const defaults = await getSimulationDefaultsUseCase();
    sendSuccessResponse(res, defaults, 'Simulation defaults retrieved successfully');
  });

  getFirstSimulationData = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const simulationData = await this.simulationRepository.getSimulationData();

    sendSuccessResponse(res, simulationData, 'First simulation data retrieved successfully');
  });

  /**
   * Get first simulation with execution (test endpoint)
   *
   * Executes the first simulation and returns the file for download
   */
  getFirstSimulationWithExecution = asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      const { filePath, fileName } = await runFirstSimulationAndGetFile(this.simulationRepository);

      res.download(filePath, fileName, (err: Error | null) => {
        if (err && !res.headersSent) {
          next(new AppError(`Failed to download ${fileName}`, 500));
        }
      });
    },
  );
}
