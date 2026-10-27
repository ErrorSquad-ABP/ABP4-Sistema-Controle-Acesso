import { describe, expect, it, vi } from 'vitest';
import { createKeepAlive, scheduleKeepAlive, type Scheduler } from '../../src/main/mqtt/keep-alive.js';
import { createLogger } from '../../src/shared/logger.js';

const logger = createLogger('silent');

describe('keep-alive do worker', () => {
  it('pinga /healthz na URL do Render', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));

    await createKeepAlive({ url: 'https://abp4.onrender.com', fetchImpl, logger }).ping();

    expect(fetchImpl).toHaveBeenCalledWith('https://abp4.onrender.com/healthz', expect.anything());
  });

  it('erro de rede nao propaga', async () => {
    const fetchImpl = vi.fn().mockRejectedValue(new Error('offline'));

    await expect(
      createKeepAlive({ url: 'https://x', fetchImpl, logger }).ping(),
    ).resolves.toBeUndefined();
  });

  it('agenda no intervalo e devolve cancelamento', () => {
    let scheduledMs = 0;
    let task: (() => void) | undefined;
    const scheduler: Scheduler = {
      every: (intervalMs, callback) => {
        scheduledMs = intervalMs;
        task = callback;
        return () => {
          task = undefined;
        };
      },
    };
    const keepAlive = createKeepAlive({
      url: 'https://x',
      fetchImpl: vi.fn().mockResolvedValue(new Response('{}')),
      logger,
    });

    const cancel = scheduleKeepAlive(keepAlive, scheduler, 600_000);

    expect(scheduledMs).toBe(600_000);
    expect(task).toBeTypeOf('function');
    cancel();
    expect(task).toBeUndefined();
  });
});
