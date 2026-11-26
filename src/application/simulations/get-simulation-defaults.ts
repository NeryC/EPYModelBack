/**
 * Application Layer - Get Simulation Defaults Use Case
 *
 * Devuelve los valores con los que arranca el simulador: el escenario base y
 * los parámetros ajustados por el modelo R (fecha de inicio, fracción I→H,
 * Rt efectivo estimado y fracciones de transición). El frontend inicializa el
 * formulario con ellos, así no hay valores escritos a mano en dos lugares.
 */

import { SimulationDefaults } from '../../domain/simulation.js';
import { getSimulationDefaults } from '../../infrastructure/processes/simulation-adapter.js';

export async function getSimulationDefaultsUseCase(): Promise<SimulationDefaults> {
  return getSimulationDefaults();
}
