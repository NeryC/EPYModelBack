import cron from 'node-cron';
import { logger } from '../utils/logger.js';
import { registerWorker, enqueue } from '../infrastructure/jobs/queue.js';
import { executeMainFlow } from '../application/main-flow.js';

// Example: every Sunday at 3:00am (exactly once, not every minute of that hour)
cron.schedule('0 3 * * 0', async () => {
  logger.info('cron:mainFlow:start');
  try {
    await executeMainFlow();
    logger.info('cron:mainFlow:success');
  } catch (err) {
    logger.error({ err }, 'cron:mainFlow:error');
  }
});

logger.info('worker_started');
registerWorker();

// If Redis available, schedule repeatable BullMQ job as example
enqueue('mainFlow', {}, { repeat: { pattern: '0 3 * * 0' } }).catch(() => {});
