import type { Logger } from '../../shared/logger.js';

export interface KeepAliveOptions {
  url: string;
  fetchImpl: typeof fetch;
  logger: Logger;
}

export interface Scheduler {
  every(intervalMs: number, task: () => void): () => void;
}

/** O plano free do Render dorme apos 15 min sem trafego HTTP; 10 min deixa folga. */
export const RENDER_KEEP_ALIVE_MS = 10 * 60_000;

export function createKeepAlive({ url, fetchImpl, logger }: KeepAliveOptions) {
  return {
    async ping(): Promise<void> {
      try {
        const response = await fetchImpl(`${url}/healthz`, { signal: AbortSignal.timeout(10_000) });
        if (!response.ok) logger.warn('keep-alive respondeu erro', { status: response.status });
      } catch (err) {
        // Falhar o ping nao pode derrubar o worker: o proximo ciclo tenta de novo.
        logger.warn('keep-alive falhou', {
          error: err instanceof Error ? err.message : String(err),
        });
      }
    },
  };
}

export function scheduleKeepAlive(
  keepAlive: { ping: () => Promise<void> },
  scheduler: Scheduler,
  intervalMs = RENDER_KEEP_ALIVE_MS,
): () => void {
  return scheduler.every(intervalMs, () => void keepAlive.ping());
}

export const systemScheduler: Scheduler = {
  every: (intervalMs, task) => {
    const timer = setInterval(task, intervalMs);
    timer.unref();
    return () => clearInterval(timer);
  },
};
