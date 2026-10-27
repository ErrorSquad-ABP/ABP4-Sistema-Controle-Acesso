import { HandleAccessEventUseCase } from '../application/terminal/handle-access-event.use-case.js';
import { HandleAckUseCase } from '../application/terminal/handle-ack.use-case.js';
import { PublishQrCodeUseCase } from '../application/terminal/publish-qr-code.use-case.js';
import { IssueQrCredentialUseCase } from '../application/terminal/qr-credential.use-cases.js';
import { PendingCommands } from '../domain/terminal/pending-commands.js';
import { SeenMessages } from '../domain/terminal/seen-messages.js';
import { CryptoIdGenerator } from '../infrastructure/ids/crypto-id-generator.js';
import type { MqttMessageBus } from '../infrastructure/mqtt/mqtt-message-bus.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { HmacQrTokenSigner } from '../infrastructure/ids/hmac-qr-token-signer.js';
import type { Env } from './config/env.js';
import { AlwaysOpenAccessDecider } from '../infrastructure/terminal/always-open-access-decider.js';
import type { Logger } from '../shared/logger.js';
import { TerminalMessageRouter } from './mqtt/terminal-message-router.js';

/**
 * Montagem do processo MQTT (consumidor). Roda local na S1 e no Render a partir
 * da S2 (US-37); a API HTTP usa o composition-root.ts.
 */
export function buildMqttConsumer(
  bus: MqttMessageBus,
  logger: Logger,
  onPresence: (terminalId: string, online: boolean) => void,
  env: Env,
) {
  const clock = new SystemClock();
  const ids = new CryptoIdGenerator();
  const signer = new HmacQrTokenSigner(env.QR_TOKEN_SECRET);
  const pending = new PendingCommands();
  const seen = new SeenMessages();

  const handleAccessEvent = new HandleAccessEventUseCase(
    new AlwaysOpenAccessDecider(),
    bus,
    clock,
    ids,
    seen,
    pending,
    logger,
  );
  const handleAck = new HandleAckUseCase(pending, seen, logger);

  return {
    router: new TerminalMessageRouter(handleAccessEvent, handleAck, logger, onPresence),
    publishQr: new PublishQrCodeUseCase(bus, ids, new IssueQrCredentialUseCase(clock, ids, signer)),
  };
}
