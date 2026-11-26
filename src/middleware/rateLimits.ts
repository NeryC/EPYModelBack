import { Request, Response, RequestHandler } from 'express';
import rateLimit from 'express-rate-limit';

export interface RateLimitConfig {
  /** Ventana de conteo en minutos. */
  windowMinutes: number;
  /** Peticiones permitidas por IP y ventana, para toda la API. */
  max: number;
  /** Peticiones permitidas por IP y ventana a los endpoints que ejecutan Python. */
  simulationMax: number;
}

/**
 * Rutas que lanzan simulador.py (cada una consume ~0,7 s de CPU).
 * Tienen un límite propio, más estricto que el general.
 */
export const SIMULATION_PATHS = [
  '/api/v1/simulations',
  '/api/v1/get-simulation',
  '/api/v1/get-first-simulation',
  '/api/v1/get-first-simulation-2',
  '/simulations',
  '/get-simulation',
  '/get-first-simulation',
  '/get-first-simulation-2',
];

function limiter(windowMs: number, max: number, scope: 'api' | 'simulation'): RequestHandler {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req: Request, res: Response) => {
      const resetTime = (req as Request & { rateLimit?: { resetTime?: Date } }).rateLimit
        ?.resetTime;
      const retryAfterSeconds = resetTime
        ? Math.max(1, Math.ceil((resetTime.getTime() - Date.now()) / 1000))
        : Math.ceil(windowMs / 1000);
      res.setHeader('Retry-After', String(retryAfterSeconds));
      res.status(429).json({
        success: false,
        error: 'rate_limited',
        scope,
        retryAfterSeconds,
        message: `Too many requests. Try again in ${retryAfterSeconds} seconds.`,
      });
    },
  });
}

export function createRateLimiters(config: RateLimitConfig): {
  general: RequestHandler;
  simulations: RequestHandler;
} {
  const windowMs = config.windowMinutes * 60 * 1000;
  return {
    general: limiter(windowMs, config.max, 'api'),
    simulations: limiter(windowMs, config.simulationMax, 'simulation'),
  };
}
