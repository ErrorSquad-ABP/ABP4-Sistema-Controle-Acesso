// Worker exclusivo dos E2E: usa os adapters reais e injeta falhas somente no teste.
import { buildAccessRuntime } from '../../../dist/main/access-composition-root.js';
import { buildMqttConsumer } from '../../../dist/main/mqtt-composition-root.js';
import { loadEnvOrExit } from '../../../dist/main/config/load-env-or-exit.js';
import { ValidateQrCredentialUseCase } from '../../../dist/application/terminal/qr-credential.use-cases.js';
import { SystemClock } from '../../../dist/infrastructure/clock/system-clock.js';
import { CryptoIdGenerator } from '../../../dist/infrastructure/ids/crypto-id-generator.js';
import { HmacQrTokenSigner } from '../../../dist/infrastructure/ids/hmac-qr-token-signer.js';
import { MqttMessageBus } from '../../../dist/infrastructure/mqtt/mqtt-message-bus.js';
import { createLogger } from '../../../dist/shared/logger.js';

const env = loadEnvOrExit();
const logger = createLogger(env.LOG_LEVEL);
const clock = new SystemClock();
const access = buildAccessRuntime(env, {
  clock,
  ids: new CryptoIdGenerator(),
  qr: new ValidateQrCredentialUseCase(clock, new HmacQrTokenSigner(env.QR_TOKEN_SECRET)),
});
if (!access) throw new Error('DT-05 exige banco real');
await access.repository.ready();
await access.events.ready();
const terminalId = process.env.DT05_TERMINAL;
const mode = process.env.DT05_FAULT;
const signal = (message) => process.send?.(message);
let release;
const gate = new Promise((resolve) => { release = resolve; });
process.on('message', (message) => {
  if (message === 'release') release();
});
const bus = await MqttMessageBus.connect({
  url: env.MQTT_URL,
  clientId: `dt05-test-${process.pid}`,
}, logger);
let injected = false;
const instrumentedBus = {
  publish: async (channel, message) => {
    if (channel === 'commands') {
      signal({ type: 'publish-attempt', command: message });
      if (!injected && mode === 'before-publish') {
        injected = true;
        throw new Error('DT05_PUBLICATION_FAILURE');
      }
    }
    await bus.publish(channel, message);
    if (channel === 'commands' && mode === 'after-publish') {
      signal({ type: 'published-before-commit', command: message });
      // Mantem a transacao aberta ate o teste matar este processo.
      await new Promise(() => {});
    }
  },
};
const { router } = buildMqttConsumer(instrumentedBus, logger, () => {}, env, {
  commands: access.commands,
  decider: {
    decide: async (event) => {
      signal({ type: 'decide', messageId: event.messageId });
      return access.decider.decide(event);
    },
  },
  events: {
    run: async (id, work) => {
      if (process.env.DT05_GATE === '1') {
        signal({ type: 'arrived', messageId: id });
        await gate;
      }
      return access.events.run(id, work);
    },
  },
});
await bus.subscribe([
  `terminals/${terminalId}/access-events`,
  `terminals/${terminalId}/acks`,
], (topic, payload) => {
  const { messageId } = JSON.parse(payload.toString());
  router.route(topic, payload).then(
    () => signal({ type: 'handled', messageId }),
    (error) => signal({ type: 'failed', messageId, error: error.message }),
  );
});
signal({ type: 'ready' });
