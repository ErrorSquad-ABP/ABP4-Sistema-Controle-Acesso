import { topicFor } from '../domain/terminal/topics.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { CryptoIdGenerator } from '../infrastructure/ids/crypto-id-generator.js';
import { createLogger } from '../shared/logger.js';
import { InvalidEnvError, loadEnv, type Env } from './config/env.js';
import { connectBusOrExit } from './mqtt/connect-bus.js';
import { SimulatedTerminal } from './sim/simulated-terminal.js';

const ACK_TIMEOUT_MS = 10_000;
const HEARTBEAT_MS = 30_000;
const keepAlive = process.argv.includes('--keep-alive');

let env: Env;
try {
  env = loadEnv();
} catch (err) {
  if (!(err instanceof InvalidEnvError)) throw err;
  process.stderr.write(`${err.message}\n`);
  process.exit(1);
}

const logger = createLogger(env.LOG_LEVEL);
const clock = new SystemClock();
const ids = new CryptoIdGenerator();
const { SIM_TERMINAL_ID: terminalId } = env;

// O LWT precisa existir antes da conexao, e o bus so existe depois dela:
// um terminal de rascunho (sem bus real) monta a mensagem de LWT.
const draft = new SimulatedTerminal(
  terminalId,
  { publish: () => Promise.resolve() },
  clock,
  ids,
  logger,
);
const bus = await connectBusOrExit(
  {
    url: env.MQTT_URL,
    clientId: `abp4-sim-${terminalId}-${process.pid}`,
    username: env.MQTT_USERNAME,
    password: env.MQTT_PASSWORD,
    will: { channel: 'status', message: draft.statusMessage('offline') },
  },
  logger,
);
const terminal = new SimulatedTerminal(terminalId, bus, clock, ids, logger);

let resolveAck: () => void = () => {};
const firstAck = new Promise<void>((resolve) => {
  resolveAck = resolve;
});

await bus.subscribe(
  [topicFor('commands', terminalId), topicFor('qr', terminalId)],
  (topic, payload) => {
    terminal
      .onMessage(topic, payload)
      .then((ack) => {
        if (ack) resolveAck();
      })
      .catch((err: unknown) => {
        logger.error('falha ao tratar mensagem', {
          topic,
          error: err instanceof Error ? err.message : String(err),
        });
      });
  },
);

const finish = async (code: number): Promise<never> => {
  await terminal.announce('offline').catch(() => {});
  await bus.close();
  process.exit(code);
};

await terminal.announce('online');
await terminal.readNfc(env.SIM_NFC_UID);

if (keepAlive) {
  logger.info('simulador ativo (Ctrl+C para sair)', { terminalId });
  setInterval(() => {
    terminal.announce('online').catch(() => {});
  }, HEARTBEAT_MS).unref();
  process.on('SIGINT', () => void finish(0));
  process.on('SIGTERM', () => void finish(0));
} else {
  const timeout = new Promise<'timeout'>((resolve) => {
    setTimeout(() => resolve('timeout'), ACK_TIMEOUT_MS);
  });
  const outcome = await Promise.race([firstAck.then(() => 'ack' as const), timeout]);
  if (outcome === 'timeout') {
    logger.error('nenhum comando recebido: o consumidor esta rodando? (npm run mqtt:consumer)');
    await finish(1);
  }
  await finish(0);
}
