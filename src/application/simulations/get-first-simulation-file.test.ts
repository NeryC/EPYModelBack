import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../../infrastructure/processes/simulation-adapter.js', () => ({
  getFirstSimulation: vi.fn(),
}));

import { runFirstSimulationAndGetFile } from './get-first-simulation-file.js';
import { getFirstSimulation } from '../../infrastructure/processes/simulation-adapter.js';
import type { ISimulationRepository } from '../../domain/simulation.js';

function makeRepo(
  path: { filePath: string; fileName: string } | Error,
): ISimulationRepository {
  return {
    save: vi.fn(),
    findById: vi.fn(),
    findLatest: vi.fn(),
    getSimulationFilePath:
      path instanceof Error
        ? vi.fn().mockRejectedValue(path)
        : vi.fn().mockResolvedValue(path),
    getSimulationData: vi.fn(),
  };
}

describe('runFirstSimulationAndGetFile', () => {
  beforeEach(() => {
    vi.mocked(getFirstSimulation).mockReset();
  });

  it('triggers getFirstSimulation and returns the repository file path', async () => {
    vi.mocked(getFirstSimulation).mockReturnValue('ok' as never);
    const repo = makeRepo({ filePath: '/tmp/a.csv', fileName: 'a.csv' });

    const out = await runFirstSimulationAndGetFile(repo);

    expect(getFirstSimulation).toHaveBeenCalledOnce();
    expect(repo.getSimulationFilePath).toHaveBeenCalledOnce();
    expect(out).toEqual({ filePath: '/tmp/a.csv', fileName: 'a.csv' });
  });

  it('propagates repository errors', async () => {
    vi.mocked(getFirstSimulation).mockReturnValue('ok' as never);
    const repo = makeRepo(new Error('missing file'));
    await expect(runFirstSimulationAndGetFile(repo)).rejects.toThrow('missing file');
  });
});
