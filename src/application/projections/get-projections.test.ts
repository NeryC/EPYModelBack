import { describe, it, expect, vi } from 'vitest';
import { executeGetProjectionsUseCase } from './get-projections.js';
import type {
  IProjectionRepository,
  ProjectionDataPoint,
  ProjectionInput,
} from '../../domain/projection.js';

function makeRepo(
  data: ProjectionDataPoint[] | string,
): IProjectionRepository {
  return {
    findAll: vi.fn().mockResolvedValue(data),
    findById: vi.fn().mockResolvedValue(null),
  };
}

describe('executeGetProjectionsUseCase', () => {
  it('returns JSON data when format=json', async () => {
    const fixture: ProjectionDataPoint[] = [
      { fecha: '2024-01-01', value: 10 },
      { fecha: '2024-01-02', value: 12 },
    ];
    const repo = makeRepo(fixture);
    const input: ProjectionInput = { format: 'json' };

    const out = await executeGetProjectionsUseCase(input, repo);

    expect(repo.findAll).toHaveBeenCalledWith('json');
    expect(out.format).toBe('json');
    expect(out.data).toBe(fixture);
  });

  it('returns CSV string when format=csv', async () => {
    const csv = 'fecha,value\n2024-01-01,10\n2024-01-02,12';
    const repo = makeRepo(csv);
    const input: ProjectionInput = { format: 'csv' };

    const out = await executeGetProjectionsUseCase(input, repo);

    expect(repo.findAll).toHaveBeenCalledWith('csv');
    expect(out.format).toBe('csv');
    expect(out.data).toBe(csv);
  });

  it('propagates repository errors', async () => {
    const repo: IProjectionRepository = {
      findAll: vi.fn().mockRejectedValue(new Error('disk full')),
      findById: vi.fn(),
    };
    await expect(
      executeGetProjectionsUseCase({ format: 'json' }, repo),
    ).rejects.toThrow('disk full');
  });
});
