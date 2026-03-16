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
    // Query parameters are already validated by middleware (validateQuery)
    // But we need to parse them to the correct types
    const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = req.query;

    // Parse Rt from JSON string to array
    let rtArray: number[];
    try {
      rtArray = JSON.parse(Rt as string);
      if (!Array.isArray(rtArray) || !rtArray.every((item) => typeof item === 'number')) {
        throw new AppError('Rt must be a valid JSON array of numbers', 400);
      }
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError('Rt must be a valid JSON array', 400);
    }

    // Transform query parameters to domain input
    const input: SimulationInput = {
      Rt: rtArray,
      UCI_threshold: Number(UCI_threshold),
      V_filtered: Number(V_filtered),
      lambda_I_to_H: Number(lambda_I_to_H),
    };

    // Validate numeric parameters
    if (isNaN(input.UCI_threshold) || input.UCI_threshold <= 0) {
      throw new AppError('UCI_threshold must be a positive number', 400);
    }
    if (isNaN(input.V_filtered) || input.V_filtered <= 0) {
      throw new AppError('V_filtered must be a positive number', 400);
    }
    if (isNaN(input.lambda_I_to_H) || input.lambda_I_to_H < 0 || input.lambda_I_to_H > 1) {
      throw new AppError('lambda_I_to_H must be a number between 0 and 1', 400);
    }

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
  getFirstSimulation = asyncHandler(async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const { filePath, fileName } = await this.simulationRepository.getSimulationFilePath();

    res.download(filePath, fileName, (err: Error | null) => {
      if (err && !res.headersSent) {
        next(new AppError(`Failed to download ${fileName}`, 500));
      }
    });
  });

  /**
   * Get first simulation data as JSON
   *
   * Returns the simulation data as JSON response
   */
  getFirstSimulationData = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const simulationData = await this.simulationRepository.getSimulationData();

    sendSuccessResponse(
      res,
      simulationData,
      'First simulation data retrieved successfully',
    );
  });

  /**
   * Get first simulation with execution (test endpoint)
   * 
   * Executes the first simulation and returns the file for download
   */
  getFirstSimulationWithExecution = asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      const { filePath, fileName } = await runFirstSimulationAndGetFile(
        this.simulationRepository,
      );

      res.download(filePath, fileName, (err: Error | null) => {
        if (err && !res.headersSent) {
          next(new AppError(`Failed to download ${fileName}`, 500));
        }
      });
    },
  );
}
