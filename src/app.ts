import cors from 'cors';
import express, { Express, NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { randomUUID } from 'crypto';
import projectionRoutes from './routes/projectionRoutes.js';
import simulationRoutes from './routes/simulationRoutes.js';
import { AppError, sendErrorResponse } from './utils/errorHandler.js';
import { environment } from './config/environment.js';
import { logger } from './utils/logger.js';
import { setupSwagger } from './api/docs/swagger.js';
import { metricsRouter } from './api/metrics/metrics.js';
import filesRouter from './api/v1/files/routes.js';

export interface CreateAppOptions {
  /**
   * If true, disables the rate limiter. Useful for integration tests
   * to avoid 429s during bursts of test requests.
   */
  disableRateLimit?: boolean;
  /**
   * If true, skips Swagger setup. Swagger is only auto-mounted in development
   * (NODE_ENV === 'development'); in any other environment Swagger is already
   * off and this flag has no effect. Setting this true in test runs prevents
   * the dev-mode auto-mount from running.
   */
  skipSwagger?: boolean;
}

export function createApp(options: CreateAppOptions = {}): Express {
  const app: Express = express();

  app.use('/results', express.static('public/results'));

  app.use(
    cors({
      origin: (origin, callback) => {
        const allow = environment.CORS_ORIGIN as string | undefined;
        if (!origin || !allow || allow === '*') return callback(null, true);
        const allowed = allow.split(',').map((s) => s.trim());
        return callback(null, allowed.includes(origin));
      },
      credentials: true,
    }),
  );
  app.use(helmet());
  app.disable('x-powered-by');

  if (!options.disableRateLimit) {
    const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 100 });
    app.use(limiter);
  }

  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  app.use((req: Request, res: Response, next: NextFunction) => {
    const id = req.headers['x-request-id']?.toString() || randomUUID();
    req.id = id;
    res.setHeader('X-Request-Id', id);
    logger.info({ id, method: req.method, path: req.path, ip: req.ip }, 'request:start');
    res.on('finish', () => {
      logger.info({ id, status: res.statusCode }, 'request:finish');
    });
    next();
  });

  app.get('/health', (req: Request, res: Response) => {
    const isProduction = environment.NODE_ENV === 'production';
    res.json({
      status: 'OK',
      timestamp: new Date().toISOString(),
      ...(isProduction ? {} : { environment: environment.NODE_ENV, port: environment.PORT }),
    });
  });

  app.use('/api/v1', projectionRoutes);
  app.use('/api/v1', simulationRoutes);
  app.use('/api/v1', metricsRouter);
  app.use('/api/v1', filesRouter);
  app.use('/', projectionRoutes);
  app.use('/', simulationRoutes);

  if (environment.NODE_ENV === 'development' && !options.skipSwagger) {
    setupSwagger(app);
  }

  app.use('*', (req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      error: `Route ${req.originalUrl} not found`,
      message: 'The requested resource does not exist',
    });
  });

  app.use((error: Error | AppError, req: Request, res: Response, _next: NextFunction) => {
    logger.error({ err: error }, 'global_error');
    if (error instanceof AppError) return sendErrorResponse(res, error, error.statusCode);
    if (error.name === 'ValidationError') return sendErrorResponse(res, new AppError(error.message, 400));
    if (error.name === 'ENOENT') return sendErrorResponse(res, new AppError('File not found', 404));
    return sendErrorResponse(res, error, 500);
  });

  return app;
}
