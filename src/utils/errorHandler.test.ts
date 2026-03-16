import { describe, it, expect, vi } from 'vitest';
import { AppError, asyncHandler } from './errorHandler.js';
import type { Request, Response, NextFunction } from 'express';

describe('AppError', () => {
  it('should create an operational error with the given message and statusCode', () => {
    const error = new AppError('Not found', 404);
    expect(error.message).toBe('Not found');
    expect(error.statusCode).toBe(404);
    expect(error.isOperational).toBe(true);
  });

  it('should default to statusCode 500', () => {
    const error = new AppError('Internal error');
    expect(error.statusCode).toBe(500);
  });
});

describe('asyncHandler', () => {
  it('should call next with error when handler throws', async () => {
    const error = new Error('Test error');
    const handler = asyncHandler(async () => { throw error; });
    const req = {} as Request;
    const res = {} as Response;
    const next = vi.fn() as unknown as NextFunction;
    await handler(req, res, next);
    expect(next).toHaveBeenCalledWith(error);
  });

  it('should not call next when handler succeeds', async () => {
    const handler = asyncHandler(async (_req: Request, res: Response) => {
      (res as unknown as { json: (v: unknown) => void }).json({ ok: true });
    });
    const req = {} as Request;
    const res = { json: vi.fn() } as unknown as Response;
    const next = vi.fn() as unknown as NextFunction;
    await handler(req, res, next);
    expect(next).not.toHaveBeenCalled();
  });
});
