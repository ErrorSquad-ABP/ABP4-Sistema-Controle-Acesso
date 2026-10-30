import { EventEmitter } from 'node:events';
import type pg from 'pg';
import { describe, expect, it, vi } from 'vitest';
import {
  DEFAULT_DEDUP_TIMEOUTS,
  PostgresEventDeduplicator,
  type DedupTimeouts,
} from '../../src/infrastructure/database/postgres-event-deduplicator.js';
import { UUID_A } from '../support/terminal-fakes.js';

const SET_TIMEOUTS = "SELECT set_config('lock_timeout'";
const LOCK = 'SELECT pg_advisory_xact_lock(hashtextextended($1, 5))';
const INSERT = 'INSERT INTO "ProcessedAccessMessage" ("messageId") VALUES ($1)';

function setup(failAt?: string, rollbackFails = false, failure?: Error, timeouts?: DedupTimeouts) {
  const query = vi.fn(async (sql: string, _params?: unknown[]) => {
    if ((failAt && sql.startsWith(failAt)) || (rollbackFails && sql === 'ROLLBACK')) throw failure ?? new Error(sql);
    return { rowCount: 0, rows: [] };
  });
  const release = vi.fn();
  const client = Object.assign(new EventEmitter(), { query, release });
  const pool = { connect: async () => client } as unknown as pg.Pool;
  return { dedup: new PostgresEventDeduplicator(pool, timeouts), query, release, client };
}

const sqls = (query: ReturnType<typeof setup>['query']) => query.mock.calls.map(([sql]) => sql);

describe('PostgresEventDeduplicator', () => {
  it.each([
    'BEGIN',
    SET_TIMEOUTS,
    LOCK,
    'SELECT 1 FROM "ProcessedAccessMessage" WHERE "messageId" = $1',
    INSERT,
    'COMMIT',
  ])('faz rollback e libera a conexao quando falha em %s', async (sql) => {
    const { dedup, query, release } = setup(sql);
    await expect(dedup.run(UUID_A, async () => 'ok')).rejects.toThrow(sql);
    expect(query).toHaveBeenCalledWith('ROLLBACK');
    expect(release).toHaveBeenCalledWith(false);
  });

  it('preserva falha original e descarta conexao se rollback falha', async () => {
    const { dedup, release } = setup(undefined, true);
    await expect(dedup.run(UUID_A, async () => { throw new Error('broker fora'); }))
      .rejects.toThrow('broker fora');
    expect(release).toHaveBeenCalledWith(true);
  });

  it('normaliza UUID antes de reservar para nao criar locks distintos por caixa', async () => {
    const { dedup, query } = setup();
    await dedup.run(UUID_A.toUpperCase(), async () => 'ok');
    expect(query).toHaveBeenCalledWith(LOCK, [UUID_A.toLowerCase()]);
  });
});

describe('PostgresEventDeduplicator: prazos da reserva (DT-16)', () => {
  it('aplica os prazos no servidor logo apos o BEGIN, antes do lock', async () => {
    const { dedup, query } = setup();
    await dedup.run(UUID_A, async () => 'ok');

    expect(sqls(query).slice(0, 3).map((sql) => sql.slice(0, 32))).toEqual(['BEGIN', SET_TIMEOUTS, LOCK.slice(0, 32)]);
    expect(query.mock.calls[1]![1]).toEqual(['3000ms', '3500ms', '20000ms']);
  });

  it('servidor aborta antes do cliente: lock < consulta < query_timeout de 4 s', () => {
    const { lockMs, statementMs, reservationMs } = DEFAULT_DEDUP_TIMEOUTS;
    expect(lockMs).toBe(3_000);
    expect(lockMs).toBeLessThan(statementMs);
    expect(statementMs).toBeLessThan(4_000);
    expect(reservationMs).toBe(20_000);
  });

  it('usa os prazos injetados', async () => {
    const { dedup, query } = setup(undefined, false, undefined, { lockMs: 300, statementMs: 400, reservationMs: 800 });
    await dedup.run(UUID_A, async () => 'ok');
    expect(query.mock.calls[1]![1]).toEqual(['300ms', '400ms', '800ms']);
  });

  it.each(['55P03', '57014'])('timeout do servidor (%s) faz rollback, devolve a conexao e nao marca', async (code) => {
    const work = vi.fn();
    const { dedup, query, release } = setup(LOCK, false, Object.assign(new Error('canceling statement'), { code }));

    const error = (await dedup.run(UUID_A, work).catch((err: unknown) => err)) as Error;
    expect(error.message).toBe('reserva da deduplicacao excedeu o prazo');
    expect((error.cause as { code: string }).code).toBe(code);
    expect(work).not.toHaveBeenCalled();
    expect(sqls(query)).not.toContain(INSERT);
    expect(query).toHaveBeenCalledWith('ROLLBACK');
    expect(release).toHaveBeenCalledWith(false);
  });

  it('timeout do cliente descarta a conexao sem enfileirar ROLLBACK atras da consulta pendente', async () => {
    const { dedup, query, release } = setup(LOCK, false, new Error('Query read timeout'));

    await expect(dedup.run(UUID_A, async () => 'ok')).rejects.toThrow('Query read timeout');
    expect(query).not.toHaveBeenCalledWith('ROLLBACK');
    expect(release).toHaveBeenCalledWith(true);
  });

  it('sessao encerrada durante o callback nao derruba o processo e descarta a conexao', async () => {
    const { dedup, query, release, client } = setup(INSERT, false, new Error('Connection terminated'));

    await expect(
      dedup.run(UUID_A, async () => {
        client.emit('error', new Error('terminating connection due to idle-in-transaction timeout'));
        return 'ok';
      }),
    ).rejects.toThrow('Connection terminated');
    expect(query).not.toHaveBeenCalledWith('ROLLBACK');
    expect(release).toHaveBeenCalledWith(true);
    expect(client.listenerCount('error')).toBe(0);
  });
});

describe('PostgresEventDeduplicator: retencao (DT-15)', () => {
  function poolReturning(result: { rowCount?: number; rows?: unknown[] }) {
    const query = vi.fn(async () => result);
    return { dedup: new PostgresEventDeduplicator({ query } as unknown as pg.Pool), query };
  }

  it('expurga em lote unico com corte no relogio do banco', async () => {
    const { dedup, query } = poolReturning({ rowCount: 7 });

    expect(await dedup.purgeProcessed(24 * 60 * 60_000, 500)).toBe(7);
    const [sql, params] = query.mock.calls[0] as unknown as [string, unknown[]];
    expect(sql).toContain('LOCALTIMESTAMP - make_interval(secs => $1)');
    expect(sql).toContain('ORDER BY "processedAt" LIMIT $2');
    expect(params).toEqual([86_400, 500]);
  });

  it('converte o tamanho bigint da tabela para numero', async () => {
    const { dedup } = poolReturning({ rows: [{ rows: 3, bytes: '24576' }] });

    expect(await dedup.stats()).toEqual({ rows: 3, bytes: 24_576 });
  });
});
