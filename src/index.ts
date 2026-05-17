import { createApp } from './app.js';
import { environment, validateEnvironment } from './config/environment.js';
import { logger } from './utils/logger.js';

validateEnvironment();

import('./infrastructure/storage/file-repository.js')
  .then((m) => m.ensureStorage())
  .catch(() => {});

const app = createApp();

function displayWelcomeMessage(port: number, env: string) {
  const banner = `
╔══════════════════════════════════════════════════════════════╗
║                    🚀 EPI MODEL BACKEND 🚀                   ║
║  ✅ Server is running successfully!                          ║
║  🌐 Port: ${port.toString().padEnd(47)} ║
║  🔧 Environment: ${env.padEnd(42)} ║
║  📅 Started: ${new Date().toLocaleString().padEnd(44)} ║
╚══════════════════════════════════════════════════════════════╝`;
  console.log(banner);
}

const server = app.listen(environment.PORT, () => {
  displayWelcomeMessage(environment.PORT, environment.NODE_ENV);
  logger.info({ port: environment.PORT }, 'server_started');
});

process.on('SIGTERM', () => {
  logger.warn('SIGTERM received, shutting down gracefully');
  process.exit(0);
});
process.on('SIGINT', () => {
  logger.warn('SIGINT received, shutting down gracefully');
  process.exit(0);
});
process.on('unhandledRejection', (reason, promise) => {
  logger.error({ promise, reason }, 'unhandled_rejection');
  process.exit(1);
});
process.on('uncaughtException', (error: Error) => {
  logger.fatal({ err: error }, 'uncaught_exception');
  process.exit(1);
});

export { app, server };
