import pg from 'pg';
import { DecideAccessUseCase } from '../application/access/decide-access.use-case.js';
import type { ValidateQrCredentialUseCase } from '../application/terminal/qr-credential.use-cases.js';
import type { AccessDecider } from '../domain/ports/access-decider.js';
import type { AccessRepository } from '../domain/ports/access-repository.js';
import type { Clock } from '../domain/ports/clock.js';
import type { CommandStore } from '../domain/ports/command-store.js';
import type { IdGenerator } from '../domain/ports/id-generator.js';
import { PostgresAccessRepository } from '../infrastructure/database/postgres-access-repository.js';
import { PostgresCommandStore } from '../infrastructure/database/postgres-command-store.js';
import { PostgresEventDeduplicator } from '../infrastructure/database/postgres-event-deduplicator.js';
import { DatabaseAccessDecider } from '../infrastructure/terminal/database-access-decider.js';
import type { Env } from './config/env.js';

export interface AccessRuntime {
  pool: pg.Pool;
  eventPool: pg.Pool;
  events: PostgresEventDeduplicator;
  repository: AccessRepository;
  commands: CommandStore;
  decide: DecideAccessUseCase;
  decider: AccessDecider;
}

/**
 * Pool propria da decisao de acesso: precisa do timezone UTC na sessao para
 * comparar os TIMESTAMP sem fuso gravados pelo Prisma.
 */
export function buildAccessRuntime(
  env: Env,
  deps: { clock: Clock; qr: ValidateQrCredentialUseCase; ids: IdGenerator },
): AccessRuntime | undefined {
  if (!env.DATABASE_URL) return undefined;
  const pool = new pg.Pool({
    connectionString: env.DATABASE_URL,
    max: 5,
    connectionTimeoutMillis: 5_000,
    query_timeout: 10_000,
    idleTimeoutMillis: 10_000,
    allowExitOnIdle: true,
    options: '-c timezone=UTC',
  });
  pool.on('error', () => {});
  const repository = new PostgresAccessRepository(pool);
  const commands = new PostgresCommandStore(pool);
  const eventPool = new pg.Pool({
    connectionString: env.DATABASE_URL,
    max: 2,
    connectionTimeoutMillis: 5_000,
    idleTimeoutMillis: 10_000,
    allowExitOnIdle: true,
  });
  eventPool.on('error', () => {});
  const events = new PostgresEventDeduplicator(eventPool);
  const decide = new DecideAccessUseCase(repository, deps.clock, deps.qr, deps.ids);
  return { pool, eventPool, events, repository, commands, decide, decider: new DatabaseAccessDecider(decide) };
}
