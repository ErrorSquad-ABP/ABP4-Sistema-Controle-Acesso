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
import { POOL_CONNECTION_TIMEOUT_MS, POOL_QUERY_TIMEOUT_MS, type PoolBudget } from './config/connection-budget.js';
import type { Env } from './config/env.js';

export interface AccessRuntime {
  pool: pg.Pool;
  repository: AccessRepository;
  commands: CommandStore;
  decide: DecideAccessUseCase;
  decider: AccessDecider;
}

/** Exclusiva do worker MQTT: a API nao recebe mensagens e nao abre esta pool (DT-14). */
export interface EventDeduplicationRuntime {
  pool: pg.Pool;
  events: PostgresEventDeduplicator;
}

/**
 * Pool propria da decisao de acesso: precisa do timezone UTC na sessao para
 * comparar os TIMESTAMP sem fuso gravados pelo Prisma.
 */
export function buildAccessRuntime(
  env: Env,
  deps: { clock: Clock; qr: ValidateQrCredentialUseCase; ids: IdGenerator },
  budget: PoolBudget,
): AccessRuntime | undefined {
  if (!env.DATABASE_URL) return undefined;
  const pool = new pg.Pool({
    connectionString: env.DATABASE_URL,
    max: budget.max,
    application_name: budget.applicationName,
    connectionTimeoutMillis: POOL_CONNECTION_TIMEOUT_MS,
    query_timeout: POOL_QUERY_TIMEOUT_MS,
    idleTimeoutMillis: 10_000,
    allowExitOnIdle: true,
    options: '-c timezone=UTC',
  });
  pool.on('error', () => {});
  const repository = new PostgresAccessRepository(pool);
  const commands = new PostgresCommandStore(pool);
  const decide = new DecideAccessUseCase(repository, deps.clock, deps.qr, deps.ids);
  return { pool, repository, commands, decide, decider: new DatabaseAccessDecider(decide) };
}

export function buildEventDeduplication(env: Env, budget: PoolBudget): EventDeduplicationRuntime | undefined {
  if (!env.DATABASE_URL) return undefined;
  const pool = new pg.Pool({
    connectionString: env.DATABASE_URL,
    max: budget.max,
    application_name: budget.applicationName,
    connectionTimeoutMillis: POOL_CONNECTION_TIMEOUT_MS,
    query_timeout: POOL_QUERY_TIMEOUT_MS,
    idleTimeoutMillis: 10_000,
    allowExitOnIdle: true,
  });
  pool.on('error', () => {});
  return { pool, events: new PostgresEventDeduplicator(pool) };
}
