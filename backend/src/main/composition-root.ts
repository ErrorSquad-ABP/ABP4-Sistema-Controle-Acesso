import { CheckHealthUseCase } from '../application/health/check-health.use-case.js';
import { GetCurrentUserUseCase } from '../application/auth/get-current-user.use-case.js';
import { LoginUseCase } from '../application/auth/login.use-case.js';
import { ListMyAuthorizationsUseCase } from '../application/authorizations/list-my-authorizations.use-case.js';
import { CancelAuthorizationUseCase, CreateAuthorizationUseCase, GetAuthorizationUseCase, ListAuthorizationsUseCase } from '../application/authorizations/admin-use-cases.js';
import { CreateUserUseCase } from '../application/users/create-user.use-case.js';
import { DeleteUserUseCase } from '../application/users/delete-user.use-case.js';
import { GetUserUseCase } from '../application/users/get-user.use-case.js';
import { ListUsersUseCase } from '../application/users/list-users.use-case.js';
import { UpdateUserUseCase } from '../application/users/update-user.use-case.js';
import { ListAccessEventsUseCase } from '../application/access-events/list-access-events.use-case.js';
import { ListMyAccessEventsUseCase } from '../application/access-events/list-my-access-events.use-case.js';
import { RequestQrAccessUseCase } from '../application/access/request-qr-access.use-case.js';
import { PublishCommandUseCase } from '../application/terminal/publish-command.use-case.js';
import type { AccessEventRepository } from '../domain/ports/access-event-repository.js';
import type { AuthorizationRepository } from '../domain/ports/authorization-repository.js';
import type { DatabaseProbe } from '../domain/ports/database-probe.js';
import type { TokenService } from '../domain/ports/token-service.js';
import type { UserAdminRepository } from '../domain/ports/user-admin-repository.js';
import type { UserRepository } from '../domain/ports/user-repository.js';
import { JwtTokenService } from '../infrastructure/auth/jwt.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { createPrismaClient } from '../infrastructure/database/prisma-client.js';
import { PostgresDatabaseProbe } from '../infrastructure/database/postgres-database-probe.js';
import { CryptoIdGenerator } from '../infrastructure/ids/crypto-id-generator.js';
import { HmacQrTokenSigner } from '../infrastructure/ids/hmac-qr-token-signer.js';
import { LazyMqttMessageBus } from '../infrastructure/mqtt/lazy-mqtt-message-bus.js';
import { ValidateQrCredentialUseCase } from '../application/terminal/qr-credential.use-cases.js';
import { PrismaAccessEventRepository } from '../infrastructure/repositories/prisma-access-event-repository.js';
import { PrismaAuthorizationRepository } from '../infrastructure/repositories/prisma-authorization-repository.js';
import { PrismaUserAdminRepository } from '../infrastructure/repositories/prisma-user-admin-repository.js';
import { PrismaUserRepository } from '../infrastructure/repositories/prisma-user-repository.js';
import { createLogger, type Logger } from '../shared/logger.js';
import { buildAccessRuntime } from './access-composition-root.js';
import { API_CONNECTIONS, POOL_CONNECTION_TIMEOUT_MS, POOL_QUERY_TIMEOUT_MS } from './config/connection-budget.js';
import { InvalidEnvError, type Env } from './config/env.js';

/**
 * Injecao de dependencia manual: unico lugar que instancia adapters
 * (infrastructure) e os entrega aos casos de uso (application).
 */
export interface Container {
  logger: Logger;
  /** 0 desliga o trust proxy; ver TRUST_PROXY em env.ts. */
  trustProxy: number;
  tokens: TokenService;
  repositories: {
    users: UserRepository | undefined;
    userAdmin: UserAdminRepository | undefined;
    authorizations: AuthorizationRepository | undefined;
    accessEvents: AccessEventRepository | undefined;
  };
  useCases: {
    checkHealth: CheckHealthUseCase;
    validateQrCredential: ValidateQrCredentialUseCase;
    login: LoginUseCase | undefined;
    getCurrentUser: GetCurrentUserUseCase | undefined;
    listUsers: ListUsersUseCase | undefined;
    createUser: CreateUserUseCase | undefined;
    getUser: GetUserUseCase | undefined;
    updateUser: UpdateUserUseCase | undefined;
    deleteUser: DeleteUserUseCase | undefined;
    listMyAuthorizations: ListMyAuthorizationsUseCase | undefined;
    listAuthorizations: ListAuthorizationsUseCase | undefined;
    getAuthorization: GetAuthorizationUseCase | undefined;
    createAuthorization: CreateAuthorizationUseCase | undefined;
    cancelAuthorization: CancelAuthorizationUseCase | undefined;
    listMyAccessEvents: ListMyAccessEventsUseCase | undefined;
    listAccessEvents: ListAccessEventsUseCase | undefined;
    /** Decisao real por QR; ausente sem banco, e a rota responde 503. */
    requestQrAccess: RequestQrAccessUseCase | undefined;
  };
  close?: () => Promise<void>;
}

export interface ContainerOverrides {
  /** Troca o probe do banco (usado nos testes de integracao). */
  databaseProbe?: DatabaseProbe;
  /** Repositorios e tokens em memoria (testes) no lugar dos adapters reais. */
  userRepository?: UserRepository;
  userAdminRepository?: UserAdminRepository;
  authorizationRepository?: AuthorizationRepository;
  accessEventRepository?: AccessEventRepository;
  tokenService?: TokenService;
}

export function buildContainer(env: Env, overrides: ContainerOverrides = {}): Container {
  // Guarda de auth no ponto que monta o token: o worker MQTT nao emite JWT e nao precisa do segredo.
  if (env.NODE_ENV === 'production' && env.JWT_SECRET.startsWith('dev-only')) {
    throw new InvalidEnvError('JWT_SECRET: defina um segredo proprio em producao');
  }
  const clock = new SystemClock();
  const logger = createLogger(env.LOG_LEVEL);
  const signer = new HmacQrTokenSigner(env.QR_TOKEN_SECRET);
  const validateQrCredential = new ValidateQrCredentialUseCase(clock, signer);
  const databaseProbe =
    overrides.databaseProbe ??
    (env.DATABASE_URL
      ? new PostgresDatabaseProbe(env.DATABASE_URL, API_CONNECTIONS.probe.applicationName)
      : undefined);
  const needsPrisma =
    !overrides.userRepository ||
    !overrides.accessEventRepository ||
    !overrides.userAdminRepository ||
    !overrides.authorizationRepository;
  // Limites do orcamento por instancia serverless (DT-14); o padrao do pg seria 10.
  const prisma =
    needsPrisma && env.DATABASE_URL
      ? createPrismaClient(env.DATABASE_URL, {
          ...API_CONNECTIONS.prisma,
          connectionTimeoutMillis: POOL_CONNECTION_TIMEOUT_MS,
          queryTimeoutMillis: POOL_QUERY_TIMEOUT_MS,
        })
      : undefined;
  const tokens = overrides.tokenService ?? new JwtTokenService(env.JWT_SECRET, env.JWT_TTL_SECONDS);
  const users =
    overrides.userRepository ?? (prisma ? new PrismaUserRepository(prisma) : undefined);
  const userAdmin =
    overrides.userAdminRepository ?? (prisma ? new PrismaUserAdminRepository(prisma) : undefined);
  const authorizations =
    overrides.authorizationRepository ??
    (prisma ? new PrismaAuthorizationRepository(prisma) : undefined);
  const accessEvents =
    overrides.accessEventRepository ??
    (prisma ? new PrismaAccessEventRepository(prisma) : undefined);
  const ids = new CryptoIdGenerator();
  // Sem a deduplicacao MQTT: a API nao recebe mensagens do broker (DT-14).
  const access = buildAccessRuntime(env, { clock, qr: validateQrCredential, ids }, API_CONNECTIONS.access, logger);
  // A API so conecta no broker quando precisa publicar: boot sem MQTT continua possivel.
  const accessBus = access
    ? new LazyMqttMessageBus(
        {
          url: env.MQTT_URL,
          clientId: `abp4-api-${process.pid}`,
          username: env.MQTT_USERNAME,
          password: env.MQTT_PASSWORD,
        },
        logger,
      )
    : undefined;

  return {
    logger,
    trustProxy: env.TRUST_PROXY,
    tokens,
    repositories: { users, userAdmin, authorizations, accessEvents },
    close: async () => {
      await accessBus?.close();
      await access?.pool.end();
      await prisma?.$disconnect();
    },
    useCases: {
      checkHealth: new CheckHealthUseCase(
        clock,
        clock.now(),
        env.APP_VERSION ?? 'dev',
        databaseProbe,
        logger,
      ),
      validateQrCredential,
      login: users ? new LoginUseCase(users, tokens) : undefined,
      getCurrentUser: users ? new GetCurrentUserUseCase(users) : undefined,
      listUsers: userAdmin ? new ListUsersUseCase(userAdmin) : undefined,
      createUser: userAdmin ? new CreateUserUseCase(userAdmin) : undefined,
      getUser: userAdmin ? new GetUserUseCase(userAdmin) : undefined,
      updateUser: userAdmin ? new UpdateUserUseCase(userAdmin) : undefined,
      deleteUser: userAdmin ? new DeleteUserUseCase(userAdmin) : undefined,
      listMyAuthorizations: authorizations
        ? new ListMyAuthorizationsUseCase(authorizations, clock)
        : undefined,
      listAuthorizations: authorizations ? new ListAuthorizationsUseCase(authorizations, clock) : undefined,
      getAuthorization: authorizations ? new GetAuthorizationUseCase(authorizations, clock) : undefined,
      createAuthorization: authorizations ? new CreateAuthorizationUseCase(authorizations, clock) : undefined,
      cancelAuthorization: authorizations ? new CancelAuthorizationUseCase(authorizations, clock) : undefined,
      listMyAccessEvents: accessEvents ? new ListMyAccessEventsUseCase(accessEvents) : undefined,
      listAccessEvents: accessEvents ? new ListAccessEventsUseCase(accessEvents) : undefined,
      requestQrAccess:
        access && accessBus
          ? new RequestQrAccessUseCase(
              access.decide,
              new PublishCommandUseCase(access.commands, accessBus, clock, ids),
              ids,
              access.repository,
              logger,
            )
          : undefined,
    },
  };
}
