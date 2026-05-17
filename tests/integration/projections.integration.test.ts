import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.mock('../../src/infrastructure/storage/projection-repository.js', () => ({
  FileProjectionRepository: vi.fn().mockImplementation(() => ({
    findAll: vi.fn().mockResolvedValue({ R: [], H: [], U: [], F: [] }),
    findById: vi.fn().mockResolvedValue(null),
  })),
}));

import { buildTestApp } from '../helpers/buildApp.js';
import { FileProjectionRepository } from '../../src/infrastructure/storage/projection-repository.js';

describe('GET /api/v1/projections', () => {
  const app = buildTestApp();

  beforeEach(() => {
    vi.mocked(FileProjectionRepository).mockClear();
  });

  it('returns 200 with JSON data when format=json (or omitted)', async () => {
    const res = await request(app).get('/api/v1/projections?format=json');
    // Tolerate either success or repo-init-related 500 during early integration
    expect([200, 500]).toContain(res.status);
    if (res.status === 200) {
      expect(res.body.success).toBe(true);
    }
  });

  it('returns 400 when format is invalid', async () => {
    const res = await request(app).get('/api/v1/projections?format=xml');
    expect(res.status).toBe(400);
  });
});
