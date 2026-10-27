import type pg from 'pg';
import type { Deduplicated, EventDeduplicator } from '../../domain/ports/event-deduplicator.js';

/** Pool separada da decisao/comandos: callbacks nao disputam as conexoes reservadas aqui. */
export class PostgresEventDeduplicator implements EventDeduplicator {
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
}
