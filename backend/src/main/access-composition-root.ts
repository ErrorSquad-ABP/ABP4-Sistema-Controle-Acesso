import pg from 'pg';
import { DecideAccessUseCase } from '../application/access/decide-access.use-case.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { Sha256TokenHasher } from '../infrastructure/crypto/sha256-token-hasher.js';
import { PostgresAccessRepository } from '../infrastructure/database/postgres-access-repository.js';
import { PostgresCommandStore } from '../infrastructure/database/postgres-command-store.js';
import { DatabaseAccessDecider } from '../infrastructure/terminal/database-access-decider.js';
import type { Env } from './config/env.js';

export function buildAccessRuntime(env: Env) {
  if (!env.DATABASE_URL) return undefined;
  const pool = new pg.Pool({ connectionString: env.DATABASE_URL, max: 5, connectionTimeoutMillis: 5_000,
    query_timeout: 10_000, idleTimeoutMillis: 10_000, allowExitOnIdle: true, options: '-c timezone=UTC' });
  pool.on('error', () => {});
  const repository = new PostgresAccessRepository(pool);
  const commands = new PostgresCommandStore(pool);
  const hasher = new Sha256TokenHasher();
  const decide = new DecideAccessUseCase(repository, new SystemClock(), hasher);
  return { pool, repository, commands, hasher, decide, decider: new DatabaseAccessDecider(decide) };
}
