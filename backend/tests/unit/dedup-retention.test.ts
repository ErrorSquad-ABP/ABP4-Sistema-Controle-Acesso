import { describe, expect, it, vi } from 'vitest';
import { DEDUP_PURGE_INTERVAL_MS } from '../../src/domain/terminal/dedup-retention.js';
import { scheduleDedupPurge, type DedupPurgeReport } from '../../src/main/mqtt/dedup-retention.js';
import type { Scheduler } from '../../src/main/mqtt/keep-alive.js';
import { FixedClock, NOW, silentLogger } from '../support/terminal-fakes.js';

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

describe('DT-15: expurgo periodico da deduplicacao no worker', () => {
  it('roda no boot, agenda 24 h e publica o resultado no log e no relatorio', async () => {
    const { scheduler, tasks } = fakeScheduler();
    const logger = { ...silentLogger, info: vi.fn() };
    const result = { removed: 12, rows: 300, bytes: 65_536 };
    const purge = { execute: vi.fn().mockResolvedValue(result) };
    const reports: DedupPurgeReport[] = [];

    scheduleDedupPurge(purge, scheduler, new FixedClock(NOW), logger, (report) => reports.push(report));
    await flush();

    expect(purge.execute).toHaveBeenCalledOnce();
    expect(logger.info).toHaveBeenCalledWith('expurgo da deduplicacao concluido', result);
    expect(reports).toEqual([{ at: NOW.toISOString(), status: 'ok', ...result }]);
    expect(tasks).toHaveLength(1);
    expect(tasks[0]!.intervalMs).toBe(DEDUP_PURGE_INTERVAL_MS);
  });

  it('falha vira log e relatorio de erro, sem derrubar o worker', async () => {
    const { scheduler, tasks } = fakeScheduler();
    const logger = { ...silentLogger, error: vi.fn() };
    const purge = { execute: vi.fn().mockRejectedValue(new Error('conexao perdida')) };
    const reports: DedupPurgeReport[] = [];

    const stop = scheduleDedupPurge(purge, scheduler, new FixedClock(NOW), logger, (report) => reports.push(report));
    await flush();
    tasks[0]!.task();
    await flush();

    expect(purge.execute).toHaveBeenCalledTimes(2);
    expect(logger.error).toHaveBeenCalledWith('falha no expurgo da deduplicacao', { error: 'conexao perdida' });
    expect(reports.at(-1)).toEqual({ at: NOW.toISOString(), status: 'error', error: 'conexao perdida' });
    expect(() => stop()).not.toThrow();
  });
});
