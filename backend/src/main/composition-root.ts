import { CheckHealthUseCase } from '../application/health/check-health.use-case.js';
import type { DatabaseProbe } from '../domain/ports/database-probe.js';
import type { UserRepository } from '../domain/ports/user-repository.js';
import type { TokenService } from '../infrastructure/auth/token-service.js';
import { JwtTokenService } from '../infrastructure/auth/jwt.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { createPrismaClient } from '../infrastructure/database/prisma-client.js';
import { PostgresDatabaseProbe } from '../infrastructure/database/postgres-database-probe.js';
import { PrismaUserRepository } from '../infrastructure/repositories/prisma-user-repository.js';
import { createLogger, type Logger } from '../shared/logger.js';
import type { Env } from './config/env.js';

/**
 * Injecao de dependencia manual: unico lugar que instancia adapters
 * (infrastructure) e os entrega aos casos de uso (application).
 */
export interface Container {
  logger: Logger;
  tokens: TokenService;
  repositories: {
    users: UserRepository | undefined;
  };
  useCases: {
    checkHealth: CheckHealthUseCase;
  };
}

export interface ContainerOverrides {
  /** Troca o probe do banco (usado nos testes de integracao). */
  databaseProbe?: DatabaseProbe;
  /** Repositorios e tokens em memoria (testes) no lugar dos adapters reais. */
  userRepository?: UserRepository;
  tokenService?: TokenService;
}

export function buildContainer(env: Env, overrides: ContainerOverrides = {}): Container {
  const clock = new SystemClock();
  const logger = createLogger(env.LOG_LEVEL);
  const databaseProbe =
    overrides.databaseProbe ??
    (env.DATABASE_URL ? new PostgresDatabaseProbe(env.DATABASE_URL) : undefined);
  const prisma =
    !overrides.userRepository && env.DATABASE_URL ? createPrismaClient(env.DATABASE_URL) : undefined;
  return {
    logger,
    tokens: overrides.tokenService ?? new JwtTokenService(env.JWT_SECRET, env.JWT_TTL_SECONDS),
    repositories: {
      users: overrides.userRepository ?? (prisma ? new PrismaUserRepository(prisma) : undefined),
    },
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
