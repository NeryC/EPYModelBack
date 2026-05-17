import { RedisContainer, type StartedRedisContainer } from '@testcontainers/redis';

let running: StartedRedisContainer | null = null;

export async function startRedis(): Promise<{ url: string; stop: () => Promise<void> }> {
  running = await new RedisContainer('redis:7-alpine').start();
  const url = `redis://${running.getHost()}:${running.getMappedPort(6379)}`;
  return {
    url,
    stop: async () => {
      if (running) {
        await running.stop();
        running = null;
      }
    },
  };
}
