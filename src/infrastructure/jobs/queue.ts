import { Queue, Worker, JobsOptions } from 'bullmq';
import { Redis as IORedis } from 'ioredis';
import { environment } from '../../config/environment.js';
import { logger } from '../logging/logger.js';

const connection = environment.REDIS_URL ? new IORedis(environment.REDIS_URL) : undefined;

export const jobsQueue = connection ? new Queue('jobs', { connection }) : null;
export const scheduler = connection ? new Queue('jobs', { connection }) : null;

export function registerWorker() {
  if (!connection) {
    logger.warn('BullMQ disabled (no REDIS_URL). Falling back to node-cron.');
    return;
  }
  new Worker(
    'jobs',
    async (job) => {
      logger.info({ name: job.name, id: job.id }, 'job:start');
      // Add job handling here
      logger.info({ name: job.name, id: job.id }, 'job:done');
    },
    { connection },
  );
}

export async function enqueue(name: string, data: unknown, opts?: JobsOptions) {
  if (!jobsQueue) {
    logger.warn('Queue not available, skipping job');
    return;
  }
  await jobsQueue.add(name, data, opts);
}
