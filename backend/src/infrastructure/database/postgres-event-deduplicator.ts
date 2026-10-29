import type pg from 'pg';
import type {
  Deduplicated,
  EventDeduplicator,
  ProcessedMessageRetention,
  ProcessedMessageStats,
} from '../../domain/ports/event-deduplicator.js';

/** Pool separada da decisao/comandos: callbacks nao disputam as conexoes reservadas aqui. */
export class PostgresEventDeduplicator implements EventDeduplicator, ProcessedMessageRetention {
  constructor(private readonly pool: pg.Pool) {}

  async ready(): Promise<void> {
    await this.pool.query('SELECT "messageId", "processedAt" FROM "ProcessedAccessMessage" LIMIT 0');
  }

  async run<T>(id: string, work: () => Promise<T>): Promise<Deduplicated<T>> {
    id = id.toLowerCase();
    const client = await this.pool.connect();
    let discardConnection = false;
    try {
      await client.query('BEGIN');
      // Lock transacional: crash/rollback libera a reserva sem deixar marca orfa.
      await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 5))', [id]);
      const existing = await client.query('SELECT 1 FROM "ProcessedAccessMessage" WHERE "messageId" = $1', [id]);
      if (existing.rowCount) {
        await client.query('COMMIT');
        return { duplicate: true };
      }
      const value = await work();
      await client.query('INSERT INTO "ProcessedAccessMessage" ("messageId") VALUES ($1)', [id]);
      await client.query('COMMIT');
      return { duplicate: false, value };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch {
        // Preserva a falha original mesmo quando a conexao foi perdida.
        discardConnection = true;
      }
      throw error;
    } finally {
      client.release(discardConnection);
    }
  }

  /**
   * Lote unico pelo indice de `processedAt` (DT-15). O corte usa o relogio e o
   * fuso da sessao do banco, os mesmos do `DEFAULT` que gravou a marca: o
   * relogio do worker nao entra na conta.
   */
  async purgeProcessed(olderThanMs: number, limit: number): Promise<number> {
    const result = await this.pool.query(
      `DELETE FROM "ProcessedAccessMessage" WHERE "messageId" IN (
        SELECT "messageId" FROM "ProcessedAccessMessage"
        WHERE "processedAt" < LOCALTIMESTAMP - make_interval(secs => $1)
        ORDER BY "processedAt" LIMIT $2)`,
      [olderThanMs / 1000, limit],
    );
    return result.rowCount ?? 0;
  }

  async stats(): Promise<ProcessedMessageStats> {
    const result = await this.pool.query<{ rows: number; bytes: string }>(
      `SELECT count(*)::int AS rows, pg_total_relation_size('"ProcessedAccessMessage"') AS bytes
       FROM "ProcessedAccessMessage"`,
    );
    const row = result.rows[0]!;
    // bigint chega como string no `pg`; o tamanho da tabela cabe com folga em Number.
    return { rows: row.rows, bytes: Number(row.bytes) };
  }
}
