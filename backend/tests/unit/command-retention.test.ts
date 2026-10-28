import { describe, expect, it, vi } from 'vitest';
import { COMMAND_PURGE_INTERVAL_MS } from '../../src/domain/terminal/command-retention.js';
import { scheduleCommandPurge } from '../../src/main/mqtt/command-retention.js';
import type { Scheduler } from '../../src/main/mqtt/keep-alive.js';
import { silentLogger } from '../support/terminal-fakes.js';

function fakeScheduler() {
  const tasks: { intervalMs: number; task: () => void }[] = [];
  const scheduler: Scheduler = {
    every: (intervalMs, task) => {
      tasks.push({ intervalMs, task });
      return () => {};
    },
  };
  return { scheduler, tasks };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('DT-18: expurgo periodico no worker', () => {
  it('roda no boot e agenda a proxima execucao em 24 h', async () => {
    const { scheduler, tasks } = fakeScheduler();
    const logger = { ...silentLogger, info: vi.fn() };
    const purge = { execute: vi.fn().mockResolvedValue(12) };

    scheduleCommandPurge(purge, scheduler, logger);
    await flush();

    expect(purge.execute).toHaveBeenCalledOnce();
    expect(logger.info).toHaveBeenCalledWith('expurgo de comandos concluido', { removed: 12 });
    expect(tasks).toHaveLength(1);
    expect(tasks[0]!.intervalMs).toBe(COMMAND_PURGE_INTERVAL_MS);
  });

  it('falha no expurgo vira log de erro, sem derrubar o worker', async () => {
    const { scheduler, tasks } = fakeScheduler();
    const logger = { ...silentLogger, error: vi.fn() };
    const purge = { execute: vi.fn().mockRejectedValue(new Error('conexao perdida')) };

    const stop = scheduleCommandPurge(purge, scheduler, logger);
    await flush();
    tasks[0]!.task();
    await flush();

    expect(purge.execute).toHaveBeenCalledTimes(2);
    expect(logger.error).toHaveBeenCalledWith('falha no expurgo de comandos', { error: 'conexao perdida' });
    expect(() => stop()).not.toThrow();
  });
});
