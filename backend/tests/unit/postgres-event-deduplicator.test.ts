import type pg from 'pg';
import { describe, expect, it, vi } from 'vitest';
import { PostgresEventDeduplicator } from '../../src/infrastructure/database/postgres-event-deduplicator.js';
import { UUID_A } from '../support/terminal-fakes.js';

function setup(failAt?: string, rollbackFails = false) {
  const query = vi.fn(async (sql: string) => {
    if (sql === failAt || (rollbackFails && sql === 'ROLLBACK')) throw new Error(sql);
    return { rowCount: 0, rows: [] };
  });
  const release = vi.fn();
  const pool = { connect: async () => ({ query, release }) } as unknown as pg.Pool;
  return { dedup: new PostgresEventDeduplicator(pool), query, release };
}

describe('PostgresEventDeduplicator', () => {
  it.each([
    'BEGIN',
    'SELECT pg_advisory_xact_lock(hashtextextended($1, 5))',
    'SELECT 1 FROM "ProcessedAccessMessage" WHERE "messageId" = $1',
    'INSERT INTO "ProcessedAccessMessage" ("messageId") VALUES ($1)',
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
    expect(query).toHaveBeenCalledWith('SELECT pg_advisory_xact_lock(hashtextextended($1, 5))', [UUID_A.toLowerCase()]);
  });
});
