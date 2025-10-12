import fs from 'fs/promises';
import path from 'path';
import { getFirstSimulation } from '../../infrastructure/processes/simulation-adapter.js';

const LEGACY_FILE = 'public/results/simulation.json';
const STORAGE_FILE = 'storage/results/simulation.json';

export async function runFirstSimulationAndGetFile(): Promise<{
  filePath: string;
  fileName: string;
}> {
  await Promise.resolve(getFirstSimulation());
  try {
    await fs.access(STORAGE_FILE);
    return { filePath: STORAGE_FILE, fileName: path.basename(STORAGE_FILE) };
  } catch {
    await fs.access(LEGACY_FILE);
    return { filePath: LEGACY_FILE, fileName: path.basename(LEGACY_FILE) };
  }
}
