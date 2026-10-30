import type pg from 'pg';
import type {
  Deduplicated,
  EventDeduplicator,
  ProcessedMessageRetention,
  ProcessedMessageStats,
} from '../../domain/ports/event-deduplicator.js';

/** Prazos da reserva, aplicados no servidor e so dentro da transacao (DT-16). */
export interface DedupTimeouts {
  /** Espera pelo advisory lock: a duplicata bloqueada desiste nesse prazo. */
  lockMs: number;
  /** Teto de cada consulta da reserva; abaixo do `query_timeout` de 4 s do cliente. */
  statementMs: number;
  /** Teto da transacao parada durante o callback; acima disso o servidor encerra a sessao. */
  reservationMs: number;
}

/**
 * 3 s < 3,5 s < 4 s (`POOL_QUERY_TIMEOUT_MS`): o servidor aborta antes do cliente
 * e a conexao volta limpa. 20 s cobrem decisao + PUBACK (3 s) com folga; o
 * frescor de 30 s ja descartaria uma tentativa mais lenta que isso.
 */
export const DEFAULT_DEDUP_TIMEOUTS: DedupTimeouts = { lockMs: 3_000, statementMs: 3_500, reservationMs: 20_000 };

/** `lock_not_available` (lock_timeout) e `query_canceled` (statement_timeout). */
const SERVER_TIMEOUT_CODES = new Set(['55P03', '57014']);

/** Pool separada da decisao/comandos: callbacks nao disputam as conexoes reservadas aqui. */
export class PostgresEventDeduplicator implements EventDeduplicator, ProcessedMessageRetention {
  constructor(
    private readonly pool: pg.Pool,
    private readonly timeouts: DedupTimeouts = DEFAULT_DEDUP_TIMEOUTS,
  ) {}

  async ready(): Promise<void> {
    await this.pool.query('SELECT "messageId", "processedAt" FROM "ProcessedAccessMessage" LIMIT 0');
  }

  async run<T>(id: string, work: () => Promise<T>): Promise<Deduplicated<T>> {
    id = id.toLowerCase();
    const client = await this.pool.connect();
    let discardConnection = false;
    // Sessao encerrada pelo servidor durante o callback emite 'error' no client em uso:
    // sem listener o processo cai. A falha reaparece na proxima consulta.
    const onClientError = () => {
      discardConnection = true;
    };
    client.on('error', onClientError);
    try {
      await client.query('BEGIN');
      await client.query(
        `SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true),
          set_config('idle_in_transaction_session_timeout', $3, true)`,
        [`${this.timeouts.lockMs}ms`, `${this.timeouts.statementMs}ms`, `${this.timeouts.reservationMs}ms`],
      );
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
      if (isClientTimeout(error)) {
        // Consulta ainda pendente no socket: um ROLLBACK ficaria na fila atras dela.
        // Descartar a conexao faz o servidor abortar a transacao e soltar o lock.
        discardConnection = true;
      } else if (!discardConnection) {
        try {
          await client.query('ROLLBACK');
        } catch {
          // Preserva a falha original mesmo quando a conexao foi perdida.
          discardConnection = true;
        }
      }
      if (isServerTimeout(error)) throw new Error('reserva da deduplicacao excedeu o prazo', { cause: error });
      throw error;
    } finally {
      client.off('error', onClientError);
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

function isServerTimeout(error: unknown): boolean {
  return SERVER_TIMEOUT_CODES.has((error as { code?: string } | null)?.code ?? '');
}

/** `query_timeout` do `pg`: o cliente desistiu, mas a consulta segue no servidor. */
function isClientTimeout(error: unknown): boolean {
  return error instanceof Error && error.message === 'Query read timeout';
}
