export interface ProjectionInput {
  format: 'json' | 'csv';
}

export interface ProjectionOutput {
  // Keep as any for now until underlying scripts are typed
  [key: string]: unknown;
}

