import { topicFilterFor } from '../../domain/terminal/topics.js';
import type { Logger } from '../../shared/logger.js';
import type { Env } from '../config/env.js';
import { buildMqttConsumer } from '../mqtt-composition-root.js';
import { connectBusOrExit } from './connect-bus.js';

const QR_INTERVAL_MS = 10_000;

export interface WorkerRuntime {
  stop(): Promise<void>;
}

/**
 * Corpo do processo MQTT compartilhado pelo entry local (`mqtt-consumer`) e pelo
 * worker do Render (`worker`). O entry cuida de sinais e HTTP.
 */
export async function startWorkerRuntime(env: Env, logger: Logger): Promise<WorkerRuntime> {
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
  const { router, publishQr } = buildMqttConsumer(
    bus,
    logger,
    (terminalId, online) => {
      if (online) onlineTerminals.add(terminalId);
      else onlineTerminals.delete(terminalId);
    },
    env,
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

  let stopped = false;
  return {
    async stop(): Promise<void> {
      if (stopped) return;
      stopped = true;
      clearInterval(qrTimer);
      await bus.close();
    },
  };
}
