export interface SimulationInput {
  Rt: string;
  UCI_threshold: string;
  V_filtered: string;
  lambda_I_to_H: string;
}

export interface SimulationOutput {
  // Keep as any for now until underlying scripts are typed
  [key: string]: unknown;
}

