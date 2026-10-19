import { topicFilterFor } from '../domain/terminal/topics.js';
import { createLogger } from '../shared/logger.js';
import { InvalidEnvError, loadEnv, type Env } from './config/env.js';
import { buildMqttConsumer } from './mqtt-composition-root.js';
import { connectBusOrExit } from './mqtt/connect-bus.js';

const QR_INTERVAL_MS = 10_000;

let env: Env;
try {
  env = loadEnv();
} catch (err) {
  if (!(err instanceof InvalidEnvError)) throw err;
  process.stderr.write(`${err.message}\n`);
  process.exit(1);
}

const logger = createLogger(env.LOG_LEVEL);
const bus = await connectBusOrExit(
  {
    url: env.MQTT_URL,
    clientId: `abp4-consumer-${process.pid}`,
    username: env.MQTT_USERNAME,
    password: env.MQTT_PASSWORD,
  },
  logger,
);

// Terminais vistos online recebem um QR de teste a cada 10 s (token real: US-19).
const onlineTerminals = new Set<string>();
const { router, publishQr } = buildMqttConsumer(bus, logger, (terminalId, online) => {
  if (online) onlineTerminals.add(terminalId);
  else onlineTerminals.delete(terminalId);
});

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

const shutdown = (signal: NodeJS.Signals) => {
  logger.info('encerrando consumidor', { signal });
  clearInterval(qrTimer);
  bus.close().finally(() => process.exit(0));
  setTimeout(() => process.exit(1), 5_000).unref();
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
