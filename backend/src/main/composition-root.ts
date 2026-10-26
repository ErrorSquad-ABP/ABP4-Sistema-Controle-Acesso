import { CheckHealthUseCase } from '../application/health/check-health.use-case.js';
import { GetCurrentUserUseCase } from '../application/auth/get-current-user.use-case.js';
import { LoginUseCase } from '../application/auth/login.use-case.js';
import { ListAccessEventsUseCase } from '../application/access-events/list-access-events.use-case.js';
import { ListMyAccessEventsUseCase } from '../application/access-events/list-my-access-events.use-case.js';
import type { AccessEventRepository } from '../domain/ports/access-event-repository.js';
import type { DatabaseProbe } from '../domain/ports/database-probe.js';
import type { TokenService } from '../domain/ports/token-service.js';
import type { UserRepository } from '../domain/ports/user-repository.js';
import { JwtTokenService } from '../infrastructure/auth/jwt.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { createPrismaClient } from '../infrastructure/database/prisma-client.js';
import { PostgresDatabaseProbe } from '../infrastructure/database/postgres-database-probe.js';
import { PrismaAccessEventRepository } from '../infrastructure/repositories/prisma-access-event-repository.js';
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
    accessEvents: AccessEventRepository | undefined;
  };
  useCases: {
    checkHealth: CheckHealthUseCase;
    login: LoginUseCase | undefined;
    getCurrentUser: GetCurrentUserUseCase | undefined;
    listMyAccessEvents: ListMyAccessEventsUseCase | undefined;
    listAccessEvents: ListAccessEventsUseCase | undefined;
  };
}

export interface ContainerOverrides {
  /** Troca o probe do banco (usado nos testes de integracao). */
  databaseProbe?: DatabaseProbe;
  /** Repositorios e tokens em memoria (testes) no lugar dos adapters reais. */
  userRepository?: UserRepository;
  accessEventRepository?: AccessEventRepository;
  tokenService?: TokenService;
}

export function buildContainer(env: Env, overrides: ContainerOverrides = {}): Container {
  const clock = new SystemClock();
  const logger = createLogger(env.LOG_LEVEL);
  const databaseProbe =
    overrides.databaseProbe ??
    (env.DATABASE_URL ? new PostgresDatabaseProbe(env.DATABASE_URL) : undefined);
  const needsPrisma = !overrides.userRepository || !overrides.accessEventRepository;
  const prisma = needsPrisma && env.DATABASE_URL ? createPrismaClient(env.DATABASE_URL) : undefined;
  const tokens = overrides.tokenService ?? new JwtTokenService(env.JWT_SECRET, env.JWT_TTL_SECONDS);
  const users =
    overrides.userRepository ?? (prisma ? new PrismaUserRepository(prisma) : undefined);
  const accessEvents =
    overrides.accessEventRepository ??
    (prisma ? new PrismaAccessEventRepository(prisma) : undefined);
  return {
    logger,
    tokens,
    repositories: { users, accessEvents },
    useCases: {
      checkHealth: new CheckHealthUseCase(
        clock,
        clock.now(),
        env.APP_VERSION ?? 'dev',
        databaseProbe,
        logger,
      ),
      login: users ? new LoginUseCase(users, tokens) : undefined,
      getCurrentUser: users ? new GetCurrentUserUseCase(users) : undefined,
      listMyAccessEvents: accessEvents ? new ListMyAccessEventsUseCase(accessEvents) : undefined,
      listAccessEvents: accessEvents ? new ListAccessEventsUseCase(accessEvents) : undefined,
    },
  };
}
