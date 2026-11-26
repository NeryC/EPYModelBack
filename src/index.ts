import { createApp } from './app.js';
import { environment, validateEnvironment } from './config/environment.js';
import { logger } from './utils/logger.js';

validateEnvironment();

import('./infrastructure/storage/file-repository.js')
  .then((m) => m.ensureStorage())
  .catch(() => {});

const app = createApp();

// Regenera la simulación inicial con la versión actual de simulador.py para que
// /get-first-simulation-data nunca sirva resultados de un modelo anterior.
// Si Python no está disponible se sigue sirviendo el archivo versionado
// (protegido por src/scripts/simulation-freshness.test.ts).
if (environment.NODE_ENV !== 'test') {
  import('./infrastructure/processes/simulation-adapter.js')
    .then((m) => m.getFirstSimulation())
    .then(() => logger.info({ python: environment.PYTHON_PATH }, 'first_simulation_regenerated'))
    .catch((err: unknown) =>
      logger.warn(
        { err, python: environment.PYTHON_PATH },
        'first_simulation_regeneration_failed: serving committed public/results/simulation.json',
      ),
    );
}

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
