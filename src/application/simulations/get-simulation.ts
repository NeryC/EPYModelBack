import { SimulationInput, SimulationOutput } from '../../domain/simulation.js';
import { getSimulation } from '../../infrastructure/processes/simulation-adapter.js';

export async function executeSimulationUseCase(input: SimulationInput): Promise<SimulationOutput> {
  const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = input;
  const result = await getSimulation(
    Rt,
    Number(UCI_threshold),
    Number(V_filtered),
    Number(lambda_I_to_H),
    false,
  );
  return result as unknown as SimulationOutput;
}
