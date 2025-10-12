import cors from 'cors';
import express, { Express, NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { randomUUID } from 'crypto';
import projectionRoutes from './routes/projectionRoutes.js';
import simulationRoutes from './routes/simulationRoutes.js';
import { AppError, sendErrorResponse } from './utils/errorHandler.js';
import { environment, validateEnvironment } from './config/environment.js';
import { logger } from './utils/logger.js';
import { setupSwagger } from './api/docs/swagger.js';
import { metricsRouter } from './api/metrics/metrics.js';
import filesRouter from './api/v1/files/routes.js';

// Initialize Express app
const app: Express = express();

// Validate environment variables
validateEnvironment();

// Middleware setup
// Serve only results, not entire public dir
app.use('/results', express.static('public/results'));
// CORS allow-list
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
// Basic rate limiting
const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 100 });
app.use(limiter);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
// Ensure storage exists
import('./infrastructure/storage/file-repository.js')
  .then((m) => m.ensureStorage())
  .catch(() => {});

// Request id + logging middleware
app.use((req: Request & { id?: string }, res: Response, next: NextFunction) => {
  const id = req.headers['x-request-id']?.toString() || randomUUID();
  req.id = id;
  res.setHeader('X-Request-Id', id);
  logger.info({ id, method: req.method, path: req.path, ip: req.ip }, 'request:start');
  res.on('finish', () => {
    logger.info({ id, status: res.statusCode }, 'request:finish');
  });
  next();
});

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    environment: environment.NODE_ENV,
    port: environment.PORT,
  });
});

// API routes (versioned)
app.use('/api/v1', projectionRoutes);
app.use('/api/v1', simulationRoutes);
app.use('/api/v1', metricsRouter);
app.use('/api/v1', filesRouter);
// Legacy mounts for backward compatibility
app.use('/', projectionRoutes);
app.use('/', simulationRoutes);

// 404 handler
app.use('*', (req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    error: `Route ${req.originalUrl} not found`,
    message: 'The requested resource does not exist',
  });
});

// Global error handling middleware
app.use((error: Error | AppError, req: Request, res: Response, next: NextFunction) => {
  logger.error({ err: error }, 'global_error');

  // Handle specific error types
  if (error instanceof AppError) {
    return sendErrorResponse(res, error, error.statusCode);
  }

  // Handle validation errors
  if (error.name === 'ValidationError') {
    return sendErrorResponse(res, new AppError(error.message, 400));
  }

  // Handle file system errors
  if (error.name === 'ENOENT') {
    return sendErrorResponse(res, new AppError('File not found', 404));
  }

  // Default error response
  return sendErrorResponse(res, error, 500);
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  logger.warn('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.warn('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Unhandled promise rejection handler
process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
  logger.error({ promise, reason }, 'unhandled_rejection');
  process.exit(1);
});

// Uncaught exception handler
process.on('uncaughtException', (error: Error) => {
  logger.fatal({ err: error }, 'uncaught_exception');
  process.exit(1);
});

// Welcome message function
function displayWelcomeMessage(port: number, env: string) {
  const banner = `
╔══════════════════════════════════════════════════════════════╗
║                    🚀 EPI MODEL BACKEND 🚀                   ║
║                                                              ║
║  ✅ Server is running successfully!                          ║
║  🌐 Port: ${port.toString().padEnd(47)} ║
║  🔧 Environment: ${env.padEnd(42)} ║
║  📅 Started: ${new Date().toLocaleString().padEnd(44)} ║
║                                                              ║
║  📋 Available Endpoints:                                     ║
║     • Health Check: http://localhost:${port}/health          ║
║     • API v1: http://localhost:${port}/api/v1               ║
║     • Simulations: http://localhost:${port}/api/v1/simulations ║
║     • Projections: http://localhost:${port}/api/v1/projections ║
║     • Files: http://localhost:${port}/api/v1/files           ║`;

  if (env === 'development') {
    const devBanner = `
║                                                              ║
║  🛠️  Development Tools:                                      ║
║     • Swagger Docs: http://localhost:${port}/api-docs        ║
║     • Metrics: http://localhost:${port}/api/v1/metrics       ║`;
    console.log(
      banner +
        devBanner +
        `
║                                                              ║
╚══════════════════════════════════════════════════════════════╝`,
    );
  } else {
    console.log(
      banner +
        `
║                                                              ║
╚══════════════════════════════════════════════════════════════╝`,
    );
  }
}

// Start server
const server = app.listen(environment.PORT, () => {
  // Display welcome message
  displayWelcomeMessage(environment.PORT, environment.NODE_ENV);

  // Log structured info
  logger.info({ port: environment.PORT }, 'server_started');
  logger.info({ env: environment.NODE_ENV, startedAt: new Date().toISOString() }, 'env_info');

  // Dev extras
  if (environment.NODE_ENV === 'development') {
    logger.info({ url: `http://localhost:${environment.PORT}/health` }, 'health_url');
    setupSwagger(app);
  }
});

// Export for testing purposes
export { app, server };
