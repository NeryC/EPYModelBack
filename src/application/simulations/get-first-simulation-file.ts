/**
 * Application Layer - Get First Simulation File Use Case
 * 
 * This use case executes the first simulation with default parameters
 * and returns the file path for download.
 */

import { ISimulationRepository } from '../../domain/simulation.js';
import { getFirstSimulation } from '../../infrastructure/processes/simulation-adapter.js';

/**
 * Execute first simulation with default parameters and get file path
 * 
 * @param repository - Simulation repository interface
 * @returns File path and name for download
 * @throws Error if simulation execution or file access fails
 */
export async function runFirstSimulationAndGetFile(
  repository: ISimulationRepository,
): Promise<{ filePath: string; fileName: string }> {
  // Execute first simulation with default parameters
  await Promise.resolve(getFirstSimulation());

  // Get file path from repository
  return await repository.getSimulationFilePath();
}
