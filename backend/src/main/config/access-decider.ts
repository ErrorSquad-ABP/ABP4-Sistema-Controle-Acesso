import type { AccessDecider } from '../../domain/ports/access-decider.js';
import { AlwaysOpenAccessDecider } from '../../infrastructure/terminal/always-open-access-decider.js';
import type { Logger } from '../../shared/logger.js';
import type { Env } from './env.js';

export function resolveAccessDecider(env: Env, real: AccessDecider | undefined, logger: Logger): AccessDecider {
  if (env.ACCESS_MODE === 'demo' && env.NODE_ENV !== 'production') {
    logger.warn('MODO DEMO: qualquer credencial sera liberada');
    return new AlwaysOpenAccessDecider();
  }
  if (!real || real instanceof AlwaysOpenAccessDecider) {
    throw new Error('Consumidor exige decisor real; configure DATABASE_URL ou selecione demo explicitamente fora de producao');
  }
  return real;
}
