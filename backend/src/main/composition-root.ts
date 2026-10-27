import { CheckHealthUseCase } from '../application/health/check-health.use-case.js';
import type { DatabaseProbe } from '../domain/ports/database-probe.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { PostgresDatabaseProbe } from '../infrastructure/database/postgres-database-probe.js';
import { createLogger, type Logger } from '../shared/logger.js';
import type { Env } from './config/env.js';
import { buildAccessRuntime } from './access-composition-root.js';
import { AuthenticateUseCase } from '../application/access/authenticate.use-case.js';
import { ListAccessEventsUseCase } from '../application/access/list-access-events.use-case.js';
import { RequestQrAccessUseCase } from '../application/access/request-qr-access.use-case.js';
import { PublishCommandUseCase } from '../application/terminal/publish-command.use-case.js';
import { JwtIdentityVerifier } from '../infrastructure/auth/jwt-identity-verifier.js';
import { CryptoIdGenerator } from '../infrastructure/ids/crypto-id-generator.js';
import { LazyMqttMessageBus } from '../infrastructure/mqtt/lazy-mqtt-message-bus.js';

/**
 * Injecao de dependencia manual: unico lugar que instancia adapters
 * (infrastructure) e os entrega aos casos de uso (application).
 */
export interface Container {
  logger: Logger;
  useCases: {
    checkHealth: CheckHealthUseCase;
    access?: { authenticate: AuthenticateUseCase; requestQr: RequestQrAccessUseCase; list: ListAccessEventsUseCase };
  };
  close?: () => Promise<void>;
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
  const access = env.JWT_SECRET ? buildAccessRuntime(env) : undefined;
  const ids = new CryptoIdGenerator();
  const bus = new LazyMqttMessageBus({ url: env.MQTT_URL, clientId: `abp4-api-${ids.uuid()}`,
    username: env.MQTT_USERNAME, password: env.MQTT_PASSWORD }, logger);
  return {
    logger,
    close: async () => { await bus.close(); await access?.pool.end(); },
    useCases: {
      ...(access && env.JWT_SECRET ? { access: {
        authenticate: new AuthenticateUseCase(new JwtIdentityVerifier(env.JWT_SECRET), access.repository),
        list: new ListAccessEventsUseCase(access.repository),
        requestQr: new RequestQrAccessUseCase(access.decide,
          new PublishCommandUseCase(access.commands, bus, clock, ids), ids),
      } } : {}),
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
