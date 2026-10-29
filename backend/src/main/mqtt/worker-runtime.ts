import { ValidateQrCredentialUseCase } from '../../application/terminal/qr-credential.use-cases.js';
import { PurgeExpiredCommandsUseCase } from '../../application/terminal/purge-expired-commands.use-case.js';
import type { AccessDecider } from '../../domain/ports/access-decider.js';
import { PendingCommands } from '../../domain/terminal/pending-commands.js';
import { SeenMessages } from '../../domain/terminal/seen-messages.js';
import { topicFilterFor } from '../../domain/terminal/topics.js';
import { SystemClock } from '../../infrastructure/clock/system-clock.js';
import { CryptoIdGenerator } from '../../infrastructure/ids/crypto-id-generator.js';
import { HmacQrTokenSigner } from '../../infrastructure/ids/hmac-qr-token-signer.js';
import type { Logger } from '../../shared/logger.js';
import { buildAccessRuntime } from '../access-composition-root.js';
import { resolveAccessDecider } from '../config/access-decider.js';
import type { Env } from '../config/env.js';
import { buildMqttConsumer } from '../mqtt-composition-root.js';
import { scheduleCommandPurge } from './command-retention.js';
import { connectBusOrExit } from './connect-bus.js';
import { systemScheduler } from './keep-alive.js';

const QR_INTERVAL_MS = 10_000;
/** O comando vale 10 s: 1 s entre ciclos deixa varias tentativas dentro do prazo. */
const COMMAND_RELAY_INTERVAL_MS = 1_000;

export interface WorkerRuntime {
  stop(): Promise<void>;
}

/**
 * Corpo do processo MQTT compartilhado pelo entry local (`mqtt-consumer`) e pelo
 * worker do Render (`worker`). Nenhum dos dois conecta no broker antes do gate
 * daqui: modo de acesso, decisor real e schema migrado (DT-01).
 */
export async function startWorkerRuntime(env: Env, logger: Logger): Promise<WorkerRuntime> {
  const clock = new SystemClock();
  const qr = new ValidateQrCredentialUseCase(clock, new HmacQrTokenSigner(env.QR_TOKEN_SECRET));
  const access =
    env.ACCESS_MODE === 'real'
      ? buildAccessRuntime(env, { clock, qr, ids: new CryptoIdGenerator() })
      : undefined;

  let decider: AccessDecider;
  try {
    decider = resolveAccessDecider(env, access?.decider, logger);
    await access?.repository.ready();
    await access?.events.ready();
  } catch (error) {
    logger.error('falha ao inicializar decisor real', {
      error: error instanceof Error ? error.message : String(error),
    });
    await access?.pool.end();
    await access?.eventPool.end();
    process.exit(1);
  }

  const bus = await connectBusOrExit(
    {
      url: env.MQTT_URL,
      clientId: `abp4-consumer-${process.pid}`,
      username: env.MQTT_USERNAME,
      password: env.MQTT_PASSWORD,
    },
    logger,
  );

  // Terminais vistos online recebem um QR assinado a cada 10 s.
  const onlineTerminals = new Set<string>();
  const { router, publishQr, dispatchPending } = buildMqttConsumer(
    bus,
    logger,
    (terminalId, online) => {
      if (online) onlineTerminals.add(terminalId);
      else onlineTerminals.delete(terminalId);
    },
    env,
    {
      decider,
      commands: access?.commands ?? new PendingCommands(),
      events: access?.events ?? new SeenMessages(),
      access: access?.repository,
    },
  );

  await bus.subscribe(
    [topicFilterFor('access-events'), topicFilterFor('status'), topicFilterFor('acks')],
    (topic, payload) => {
      router.route(topic, payload).catch((err: unknown) => {
        logger.error('falha ao tratar mensagem', {
          topic,
          error: err instanceof Error ? err.message : String(err),
        });
      });
    },
  );

  const qrTimer = setInterval(() => {
    for (const terminalId of onlineTerminals) {
      publishQr.execute({ terminalId }).catch((err: unknown) => {
        logger.error('falha ao publicar qr', {
          terminalId,
          error: err instanceof Error ? err.message : String(err),
        });
      });
    }
  }, QR_INTERVAL_MS);

  // Outbox (DT-13): entrega intencoes que a API ou um processo anterior nao publicou.
  // Roda ja no boot para recuperar o que ficou pendente no reinicio.
  let relaying = false;
  const relay = () => {
    if (!dispatchPending || relaying) return;
    relaying = true;
    dispatchPending
      .execute()
      .catch((err: unknown) => {
        logger.error('falha no relay de comandos', {
          error: err instanceof Error ? err.message : String(err),
        });
      })
      .finally(() => {
        relaying = false;
      });
  };
  relay();
  const relayTimer = dispatchPending ? setInterval(relay, COMMAND_RELAY_INTERVAL_MS) : undefined;

  // DT-18: comandos expirados ha mais de 7 dias saem em lotes, uma vez por dia.
  const stopPurge = access
    ? scheduleCommandPurge(
        new PurgeExpiredCommandsUseCase(access.commands, clock),
        systemScheduler,
        logger,
      )
    : undefined;

  let stopped = false;
  return {
    async stop(): Promise<void> {
      if (stopped) return;
      stopped = true;
      clearInterval(qrTimer);
      clearInterval(relayTimer);
      stopPurge?.();
      await bus.close();
      await access?.pool.end();
      await access?.eventPool.end();
    },
  };
}
