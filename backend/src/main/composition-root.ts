import { CheckHealthUseCase } from '../application/health/check-health.use-case.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
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

export function buildContainer(env: Env): Container {
  const clock = new SystemClock();
  return {
    logger: createLogger(env.LOG_LEVEL),
    useCases: {
      checkHealth: new CheckHealthUseCase(clock, clock.now(), env.APP_VERSION ?? 'dev'),
    },
  };
}
