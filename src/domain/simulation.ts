/**
 * Domain Layer - Simulation Entity and Interfaces
 * 
 * This file contains the core domain entities and repository interfaces
 * for the Simulation domain. It should not depend on any other layers.
 */

/**
 * Simulation parameters as domain value objects
 */
export interface SimulationParameters {
  Rt: number[];
  UCI_threshold: number;
  V_filtered: number;
  lambda_I_to_H: number;
}

/**
 * Simulation results data structure
 */
export interface SimulationResults {
  cumulative: SimulationDataPoint[];
  cumulative_deaths: SimulationDataPoint[];
  exposed: SimulationDataPoint[];
  hospitalized: SimulationDataPoint[];
  immune: SimulationDataPoint[];
  infectious: SimulationDataPoint[];
  susceptible: SimulationDataPoint[];
  uci: SimulationDataPoint[];
}

/**
 * Individual data point in simulation results
 */
export interface SimulationDataPoint {
  fecha: string;
  value: number;
  uncertainty_lower?: number;
  uncertainty_upper?: number;
}

/**
 * Simulation entity - core domain model
 */
export interface Simulation {
  id: string;
  parameters: SimulationParameters;
  results: SimulationResults;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Input for creating/executing a simulation
 * Used in Application layer use cases
 */
export interface SimulationInput {
  Rt: number[];
  UCI_threshold: number;
  V_filtered: number;
  lambda_I_to_H: number;
}

/**
 * Output from simulation execution
 * Used in Application layer use cases
 */
export interface SimulationOutput {
  results: SimulationResults;
}

/**
 * Repository interface for Simulation persistence
 * Implementations should be in Infrastructure layer
 */
export interface ISimulationRepository {
  /**
   * Save a simulation entity
   */
  save(simulation: Simulation): Promise<void>;

  /**
   * Find simulation by ID
   */
  findById(id: string): Promise<Simulation | null>;

  /**
   * Get the most recent simulation
   */
  findLatest(): Promise<Simulation | null>;

  /**
   * Get simulation file path for download
   */
  getSimulationFilePath(): Promise<{ filePath: string; fileName: string }>;

  /**
   * Get simulation data as JSON
   */
  getSimulationData(): Promise<SimulationResults>;
}

