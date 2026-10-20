import pg from 'pg';
import type { DatabaseProbe } from '../../domain/ports/database-probe.js';

const TIMEOUT_MS = 3000;

/**
 * Probe sobre o `pg` (`SELECT 1`). Pool de 1 conexao: serve ao pooler do Neon e a
 * funcoes serverless, que reaproveitam o pool entre invocacoes da mesma instancia.
 */
export class PostgresDatabaseProbe implements DatabaseProbe {
  private readonly pool: pg.Pool;

  constructor(connectionString: string) {
    this.pool = new pg.Pool({
      connectionString,
      max: 1,
      connectionTimeoutMillis: TIMEOUT_MS,
      query_timeout: TIMEOUT_MS,
      idleTimeoutMillis: 10_000,
      allowExitOnIdle: true,
    });
    // Sem listener, erro em conexao ociosa (ex.: Neon suspendendo) derruba o processo.
    this.pool.on('error', () => {});
  }

  async ping(): Promise<void> {
    await this.pool.query('SELECT 1');
  }
}
