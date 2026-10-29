import { ValidateQrCredentialUseCase } from '../../application/terminal/qr-credential.use-cases.js';
import { PurgeExpiredCommandsUseCase } from '../../application/terminal/purge-expired-commands.use-case.js';
import { PurgeProcessedMessagesUseCase } from '../../application/terminal/purge-processed-messages.use-case.js';
import type { AccessDecider } from '../../domain/ports/access-decider.js';
import { PendingCommands } from '../../domain/terminal/pending-commands.js';
import { isWithinRelayWindow, type RelayWindow } from '../../domain/terminal/relay-window.js';
import { SeenMessages } from '../../domain/terminal/seen-messages.js';
import { topicFilterFor } from '../../domain/terminal/topics.js';
import { SystemClock } from '../../infrastructure/clock/system-clock.js';
import { CryptoIdGenerator } from '../../infrastructure/ids/crypto-id-generator.js';
import { HmacQrTokenSigner } from '../../infrastructure/ids/hmac-qr-token-signer.js';
import type { Logger } from '../../shared/logger.js';
import { buildAccessRuntime, buildEventDeduplication } from '../access-composition-root.js';
import { resolveAccessDecider } from '../config/access-decider.js';
import { WORKER_CONNECTIONS } from '../config/connection-budget.js';
import type { Env } from '../config/env.js';
import { buildMqttConsumer } from '../mqtt-composition-root.js';
import { scheduleCommandPurge } from './command-retention.js';
import { connectBusOrExit } from './connect-bus.js';
import { scheduleDedupPurge, type DedupPurgeReport } from './dedup-retention.js';
import { systemScheduler } from './keep-alive.js';

const QR_INTERVAL_MS = 10_000;

export interface WorkerRuntime {
  /** Ultimo expurgo da deduplicacao; `undefined` no modo demo ou antes da primeira execucao. */
  dedupPurge(): DedupPurgeReport | undefined;
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
  const real = env.ACCESS_MODE === 'real';
  const access = real
    ? buildAccessRuntime(env, { clock, qr, ids: new CryptoIdGenerator() }, WORKER_CONNECTIONS.access)
    : undefined;
  const dedup = real ? buildEventDeduplication(env, WORKER_CONNECTIONS.events) : undefined;

  let decider: AccessDecider;
  try {
    decider = resolveAccessDecider(env, access?.decider, logger);
    await access?.repository.ready();
    await dedup?.events.ready();
  } catch (error) {
    logger.error('falha ao inicializar decisor real', {
      error: error instanceof Error ? error.message : String(error),
    });
    await access?.pool.end();
    await dedup?.pool.end();
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
      events: dedup?.events ?? new SeenMessages(),
      access: access?.repository,
      withinRelayWindow: (now) => isWithinRelayWindow(now, janela),
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
  // Roda no boot e no timer: o firmware da main nao publica heartbeat, entao presenca
  // de terminal nao existe no fluxo QR e nao pode condicionar a recuperacao.
  // DT-21: fora da janela de operacao o worker nem consulta o banco, para o Neon
  // suspender; e o polling continuo que estoura o free tier.
  const janela: RelayWindow = {
    enabled: env.RELAY_WINDOW_ENABLED,
    start: env.RELAY_WINDOW_START,
    end: env.RELAY_WINDOW_END,
    timeZone: env.RELAY_WINDOW_TZ,
  };
  let janelaAberta = true;
  let relaying = false;
  const relay = () => {
    if (!dispatchPending || relaying) return;
    if (!isWithinRelayWindow(clock.now(), janela)) {
      if (janelaAberta) {
        janelaAberta = false;
        logger.info('relay fora da janela de operacao', {
          start: janela.start,
          end: janela.end,
          timeZone: janela.timeZone,
        });
      }
      return;
    }
    if (!janelaAberta) {
      janelaAberta = true;
      logger.info('relay dentro da janela de operacao');
    }
    relaying = true;
    dispatchPending
      .execute()
      .then((summary) => {
        // Sem payload e sem token: so volume, para medir backlog e interrupcoes.
        if (summary.published > 0 || summary.failed > 0) logger.info('relay de comandos', { ...summary });
        else logger.debug('relay de comandos', { ...summary });
      })
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
  const relayTimer = dispatchPending
    ? setInterval(relay, env.COMMAND_RELAY_INTERVAL_MS)
    : undefined;

  // DT-18: comandos expirados ha mais de 7 dias saem em lotes, uma vez por dia.
  const stopPurge = access
    ? scheduleCommandPurge(
        new PurgeExpiredCommandsUseCase(access.commands, clock),
        systemScheduler,
        logger,
      )
    : undefined;

  // DT-15: marcas de deduplicacao com mais de 24 h saem em lotes, uma vez por dia.
  let lastDedupPurge: DedupPurgeReport | undefined;
  const stopDedupPurge = dedup
    ? scheduleDedupPurge(
        new PurgeProcessedMessagesUseCase(dedup.events),
        systemScheduler,
        clock,
        logger,
        (report) => {
          lastDedupPurge = report;
        },
      )
    : undefined;

  let stopped = false;
  return {
    dedupPurge: () => lastDedupPurge,
    async stop(): Promise<void> {
      if (stopped) return;
      stopped = true;
      clearInterval(qrTimer);
      clearInterval(relayTimer);
      stopPurge?.();
      stopDedupPurge?.();
      await bus.close();
      await access?.pool.end();
      await dedup?.pool.end();
    },
  };
}
