import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { Queue, Worker, type Job } from 'bullmq';
import IORedis from 'ioredis';
import { startRedis } from '../helpers/redisTestcontainer.js';

const dockerAvailable = process.env.SKIP_TESTCONTAINERS !== '1';
const describeIfDocker = dockerAvailable ? describe : describe.skip;

describeIfDocker('BullMQ + Redis integration', () => {
  let stopRedis: () => Promise<void>;
  let connection: IORedis;
  let queue: Queue;
  let worker: Worker;
  const queueName = 'test-queue';

  beforeAll(async () => {
    const { url, stop } = await startRedis();
    stopRedis = stop;
    connection = new IORedis(url, { maxRetriesPerRequest: null });
    queue = new Queue(queueName, { connection });
  }, 60_000);

  afterAll(async () => {
    if (worker) await worker.close();
    if (queue) await queue.close();
    if (connection) await connection.quit();
    if (stopRedis) await stopRedis();
  });

  it('enqueues and processes a job, returning the worker result', async () => {
    const processed: Array<{ name: string; data: unknown }> = [];

    worker = new Worker(
      queueName,
      async (job: Job) => {
        processed.push({ name: job.name, data: job.data });
        return { ok: true, echoed: job.data };
      },
      { connection },
    );

    const job = await queue.add('echo', { msg: 'hola' });
    const result = await job.waitUntilFinished(
      new (await import('bullmq')).QueueEvents(queueName, { connection }),
      10_000,
    );

    expect(result).toEqual({ ok: true, echoed: { msg: 'hola' } });
    expect(processed).toHaveLength(1);
    expect(processed[0]).toEqual({ name: 'echo', data: { msg: 'hola' } });
  });
});
