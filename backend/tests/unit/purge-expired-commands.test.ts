import { describe, expect, it, vi } from 'vitest';
import { PurgeExpiredCommandsUseCase } from '../../src/application/terminal/purge-expired-commands.use-case.js';
import type { AckResult, CommandStore } from '../../src/domain/ports/command-store.js';
import {
  COMMAND_PURGE_BATCH_SIZE,
  COMMAND_PURGE_MAX_BATCHES,
  COMMAND_RETENTION_MS,
} from '../../src/domain/terminal/command-retention.js';
import { FixedClock, NOW } from '../support/terminal-fakes.js';

function setup(removedPerBatch: number[]) {
  const calls: { before: Date; limit: number }[] = [];
  const store: CommandStore = {
    save: vi.fn(),
    findByRequestId: vi.fn(),
    acknowledge: vi.fn<() => Promise<AckResult>>(),
    markPublished: vi.fn(),
    listUndispatched: vi.fn(),
    purgeExpired: vi.fn(async (before: Date, limit: number) => {
      calls.push({ before, limit });
      return removedPerBatch[calls.length - 1] ?? 0;
    }),
  };
  const clock = new FixedClock(NOW);
  return { useCase: new PurgeExpiredCommandsUseCase(store, clock), calls, clock };
}

describe('DT-18: expurgo de TerminalCommand', () => {
  it('usa o corte de retencao a partir do relogio e no maximo o tamanho do lote', async () => {
    const { useCase, calls } = setup([3]);

    expect(await useCase.execute()).toBe(3);
    expect(calls).toEqual([{ before: new Date(NOW.getTime() - COMMAND_RETENTION_MS), limit: COMMAND_PURGE_BATCH_SIZE }]);
  });

  it('para quando o lote volta incompleto', async () => {
    const { useCase, calls } = setup([COMMAND_PURGE_BATCH_SIZE, 10]);

    expect(await useCase.execute()).toBe(COMMAND_PURGE_BATCH_SIZE + 10);
    expect(calls).toHaveLength(2);
  });

  it('limita o numero de lotes por execucao', async () => {
    const { useCase, calls } = setup(Array.from({ length: COMMAND_PURGE_MAX_BATCHES + 5 }, () => COMMAND_PURGE_BATCH_SIZE));

    expect(await useCase.execute()).toBe(COMMAND_PURGE_BATCH_SIZE * COMMAND_PURGE_MAX_BATCHES);
    expect(calls).toHaveLength(COMMAND_PURGE_MAX_BATCHES);
  });

  it('nao apaga nada quando o lote vem vazio', async () => {
    const { useCase, calls } = setup([0]);

    expect(await useCase.execute()).toBe(0);
    expect(calls).toHaveLength(1);
  });
});

describe('DT-18: retencao definida no dominio', () => {
  it('guarda o comando por dias depois de expirar, muito acima do prazo e do frescor', () => {
    // Frescor de evento e 30 s; prazo do comando, 10 s. A retencao cobre ACK tardio e auditoria.
    expect(COMMAND_RETENTION_MS).toBe(7 * 24 * 60 * 60_000);
    expect(COMMAND_PURGE_BATCH_SIZE).toBeGreaterThan(0);
    expect(COMMAND_PURGE_BATCH_SIZE * COMMAND_PURGE_MAX_BATCHES).toBeLessThanOrEqual(10_000);
  });
});
