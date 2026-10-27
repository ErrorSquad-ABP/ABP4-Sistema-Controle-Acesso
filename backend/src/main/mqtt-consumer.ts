import { topicFilterFor } from '../domain/terminal/topics.js';
import { createLogger } from '../shared/logger.js';
import { InvalidEnvError, loadEnv, type Env } from './config/env.js';
import { buildMqttConsumer } from './mqtt-composition-root.js';
import { connectBusOrExit } from './mqtt/connect-bus.js';
import { buildAccessRuntime } from './access-composition-root.js';
import { resolveAccessDecider } from './config/access-decider.js';
import { PendingCommands } from '../domain/terminal/pending-commands.js';

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
// Decisor e schema validados antes de qualquer conexao ou assinatura MQTT.
const access = env.ACCESS_MODE === 'real' ? buildAccessRuntime(env) : undefined;
let decider;
try {
  decider = resolveAccessDecider(env, access?.decider, logger);
  await access?.repository.ready();
} catch (error) {
  logger.error('falha ao inicializar decisor real', { error: error instanceof Error ? error.message : String(error) });
  await access?.pool.end();
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

// QR opaco: somente o hash fica no banco e a validade e vinculada ao terminal.
const onlineTerminals = new Set<string>();
const { router, publishQr } = buildMqttConsumer(bus, logger, (terminalId, online) => {
  if (online) {
    const isNew = !onlineTerminals.has(terminalId);
    onlineTerminals.add(terminalId);
    if (isNew) queueMicrotask(() => { void publishQr.execute({ terminalId }).catch((error: unknown) => {
      logger.error('falha ao publicar qr', { terminalId, error: String(error) });
    }); });
  }
  else onlineTerminals.delete(terminalId);
}, { decider, commands: access?.commands ?? new PendingCommands(),
  ...(access ? { tokens: { repository: access.repository, hasher: access.hasher } } : {}) });

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
  Promise.all([bus.close(), access?.pool.end()]).finally(() => process.exit(0));
  setTimeout(() => process.exit(1), 5_000).unref();
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
