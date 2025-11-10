/**
 * Application Layer - Execute Simulation Use Case
 * 
 * This use case orchestrates the execution of a simulation with custom parameters.
 * It depends on domain interfaces and infrastructure adapters.
 */

import { SimulationInput, SimulationOutput, SimulationResults } from '../../domain/simulation.js';
import { getSimulation } from '../../infrastructure/processes/simulation-adapter.js';

/**
 * Execute a simulation with custom parameters
 * 
 * @param input - Simulation input parameters
 * @returns Simulation output with results
 * @throws Error if simulation execution fails
 */
export async function executeSimulationUseCase(
  input: SimulationInput,
): Promise<SimulationOutput> {
  const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = input;

  // Convert Rt array to JSON string for adapter
  const rtString = JSON.stringify(Rt);

  // Execute simulation via infrastructure adapter
  const result = await getSimulation(
    rtString,
    UCI_threshold,
    V_filtered,
    lambda_I_to_H,
    false,
  );

  // Parse and validate result
  let parsedResult: SimulationResults;
  if (typeof result === 'string') {
    try {
      parsedResult = JSON.parse(result) as SimulationResults;
    } catch (error) {
      throw new Error(
        `Failed to parse simulation result: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
    }
  } else {
    parsedResult = result as SimulationResults;
  }

  return {
    results: parsedResult,
  };
}
