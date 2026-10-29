import { describe, expect, it, vi } from 'vitest';
import { PurgeProcessedMessagesUseCase } from '../../src/application/terminal/purge-processed-messages.use-case.js';
import type { ProcessedMessageRetention } from '../../src/domain/ports/event-deduplicator.js';
import {
  DEDUP_PURGE_BATCH_SIZE,
  DEDUP_PURGE_MAX_BATCHES,
  DEDUP_RETENTION_MS,
} from '../../src/domain/terminal/dedup-retention.js';
import { ACCESS_EVENT_FUTURE_SKEW_MS, ACCESS_EVENT_MAX_AGE_MS } from '../../src/domain/terminal/event-freshness.js';

function setup(removedPerBatch: number[]) {
  const calls: { olderThanMs: number; limit: number }[] = [];
  const retention: ProcessedMessageRetention = {
    purgeProcessed: vi.fn(async (olderThanMs: number, limit: number) => {
      calls.push({ olderThanMs, limit });
      return removedPerBatch[calls.length - 1] ?? 0;
    }),
    stats: vi.fn(async () => ({ rows: 42, bytes: 16_384 })),
  };
  return { useCase: new PurgeProcessedMessagesUseCase(retention), calls, retention };
}

describe('DT-15: expurgo de ProcessedAccessMessage', () => {
  it('usa a retencao do dominio e no maximo o tamanho do lote', async () => {
    const { useCase, calls } = setup([3]);

    expect(await useCase.execute()).toEqual({ removed: 3, rows: 42, bytes: 16_384 });
    expect(calls).toEqual([{ olderThanMs: DEDUP_RETENTION_MS, limit: DEDUP_PURGE_BATCH_SIZE }]);
  });

  it('para quando o lote volta incompleto', async () => {
    const { useCase, calls } = setup([DEDUP_PURGE_BATCH_SIZE, 10]);

    expect((await useCase.execute()).removed).toBe(DEDUP_PURGE_BATCH_SIZE + 10);
    expect(calls).toHaveLength(2);
  });

  it('limita o numero de lotes por execucao', async () => {
    const { useCase, calls } = setup(Array.from({ length: DEDUP_PURGE_MAX_BATCHES + 5 }, () => DEDUP_PURGE_BATCH_SIZE));

    expect((await useCase.execute()).removed).toBe(DEDUP_PURGE_BATCH_SIZE * DEDUP_PURGE_MAX_BATCHES);
    expect(calls).toHaveLength(DEDUP_PURGE_MAX_BATCHES);
  });

  it('mede a tabela mesmo quando nada sai', async () => {
    const { useCase, retention } = setup([0]);

    expect(await useCase.execute()).toEqual({ removed: 0, rows: 42, bytes: 16_384 });
    expect(retention.stats).toHaveBeenCalledOnce();
  });
});

describe('DT-15: retencao definida no dominio', () => {
  it('guarda a marca muito alem da janela em que uma retransmissao ainda e aceita', () => {
    // Retransmissao so passa do filtro de frescor ate ~35 s; o resto e margem de relogio.
    const window = ACCESS_EVENT_MAX_AGE_MS + ACCESS_EVENT_FUTURE_SKEW_MS;
    expect(DEDUP_RETENTION_MS).toBe(24 * 60 * 60_000);
    expect(DEDUP_RETENTION_MS).toBeGreaterThan(window * 2000);
    expect(DEDUP_PURGE_BATCH_SIZE * DEDUP_PURGE_MAX_BATCHES).toBeLessThanOrEqual(10_000);
  });
});
