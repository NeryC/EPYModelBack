/**
 * Domain Layer - Simulation Entity and Interfaces
 *
 * This file contains the core domain entities and repository interfaces
 * for the Simulation domain. It should not depend on any other layers.
 */

/**
 * Rangos válidos de los parámetros del simulador.
 *
 * Única fuente de verdad del backend. El frontend replica estos valores en
 * epimodel-next/components/SimulationGraph/SimulationFilter/constants.ts —
 * si cambias uno, cambia el otro.
 *
 * - Rt: 0–2 por mes, de 1 a 12 meses (horizonte máximo de 360 días).
 * - UCI_threshold: camas UCI disponibles, 1–5000.
 * - V_filtered: nuevos vacunados POR DÍA, 1–5000.
 * - lambda_I_to_H: fracción I→H, 0–0.99. El tope es < 1 porque además el 0,2 %
 *   de I fallece sin hospitalizarse (lambda_I_to_F = 0.002): con λ > 0.998 la
 *   fracción de recuperados directos sería negativa.
 */
export const SIMULATION_LIMITS = {
  RT_MIN: 0,
  RT_MAX: 2,
  RT_MONTHS_MIN: 1,
  RT_MONTHS_MAX: 12,
  UCI_MIN: 1,
  UCI_MAX: 5000,
  V_MIN: 1,
  V_MAX: 5000,
  LAMBDA_MIN: 0,
  LAMBDA_MAX: 0.99,
} as const;

/**
 * Escenario por defecto del simulador (Rt efectivo por mes, camas UCI y
 * vacunados por día). La fracción I→H por defecto no está aquí: sale del
 * ajuste del modelo R (ver SimulationDefaults).
 */
export const DEFAULT_SCENARIO = {
  Rt: [1.1, 1.2, 1.3, 0.8, 0.7, 0.9],
  UCI_threshold: 100,
  V_filtered: 1000,
} as const;

/**
 * Días finales del ajuste de R que se promedian para estimar las fracciones.
 * 7 y no 14: la fracción I→H ajustada tuvo un cambio de régimen una semana
 * antes del final (0,44 % → 0,13 %) y una ventana de 14 días mezclaba ambos,
 * duplicando los hospitalizados en los primeros 10 días de la simulación.
 */
export const FITTED_WINDOW_DAYS = 7;

/** Fracciones de transición que usa simulador.py (UCI no saturada). */
export interface TransitionFractions {
  lambda_I_to_F: number;
  lambda_H_to_U: number;
  lambda_H_to_F: number;
  lambda_U_to_F: number;
}

/**
 * Valores con los que arranca el simulador, derivados del último tramo del
 * ajuste del modelo R (public/data/sim_SEIRHUF.csv).
 */
export interface SimulationDefaults {
  /** Fecha del estado inicial (día 0 de la simulación), YYYY-MM-DD. */
  startDate: string;
  Rt: number[];
  UCI_threshold: number;
  V_filtered: number;
  /** Fracción I→H ajustada por R, redondeada al paso del slider (0,1 %). */
  lambda_I_to_H: number;
  /** Rt efectivo estimado por R (promedio de los últimos FITTED_WINDOW_DAYS días). */
  estimatedRt: number;
  /** Fracciones ajustadas por R (promedio de los últimos FITTED_WINDOW_DAYS días). */
  fractions: TransitionFractions;
}

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
