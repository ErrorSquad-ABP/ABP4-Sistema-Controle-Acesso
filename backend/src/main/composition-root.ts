import { CheckHealthUseCase } from '../application/health/check-health.use-case.js';
import type { DatabaseProbe } from '../domain/ports/database-probe.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { PostgresDatabaseProbe } from '../infrastructure/database/postgres-database-probe.js';
import { createLogger, type Logger } from '../shared/logger.js';
import type { Env } from './config/env.js';

/**
 * Injecao de dependencia manual: unico lugar que instancia adapters
 * (infrastructure) e os entrega aos casos de uso (application).
 */
export interface Container {
  logger: Logger;
  useCases: {
    checkHealth: CheckHealthUseCase;
  };
}

export interface ContainerOverrides {
  /** Troca o probe do banco (usado nos testes de integracao). */
  databaseProbe?: DatabaseProbe;
}

export function buildContainer(env: Env, overrides: ContainerOverrides = {}): Container {
  const clock = new SystemClock();
  const logger = createLogger(env.LOG_LEVEL);
  const databaseProbe =
    overrides.databaseProbe ??
    (env.DATABASE_URL ? new PostgresDatabaseProbe(env.DATABASE_URL) : undefined);
  return {
    logger,
    useCases: {
      checkHealth: new CheckHealthUseCase(
        clock,
        clock.now(),
        env.APP_VERSION ?? 'dev',
        databaseProbe,
        logger,
      ),
    },
  };
}
