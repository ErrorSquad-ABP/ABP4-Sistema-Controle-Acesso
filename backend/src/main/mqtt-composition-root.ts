import { HandleAccessEventUseCase } from '../application/terminal/handle-access-event.use-case.js';
import { HandleAckUseCase } from '../application/terminal/handle-ack.use-case.js';
import { PublishQrCodeUseCase } from '../application/terminal/publish-qr-code.use-case.js';
import type { AccessDecider } from '../domain/ports/access-decider.js';
import type { AccessRepository } from '../domain/ports/access-repository.js';
import type { CommandStore } from '../domain/ports/command-store.js';
import type { MessageBus } from '../domain/ports/message-bus.js';
import type { TokenHasher } from '../domain/ports/token-hasher.js';
import { SeenMessages } from '../domain/terminal/seen-messages.js';
import { CryptoIdGenerator } from '../infrastructure/ids/crypto-id-generator.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import type { Logger } from '../shared/logger.js';
import { TerminalMessageRouter } from './mqtt/terminal-message-router.js';

/**
 * Montagem do processo MQTT (consumidor). Roda local na S1 e no Render a partir
 * da S2 (US-37); a API HTTP usa o composition-root.ts.
 */
export function buildMqttConsumer(
  bus: MessageBus,
  logger: Logger,
  onPresence: (terminalId: string, online: boolean) => void,
  dependencies: { decider: AccessDecider; commands: CommandStore; tokens?: { repository: AccessRepository; hasher: TokenHasher } },
) {
  const clock = new SystemClock();
  const ids = new CryptoIdGenerator();
  const pending = dependencies.commands;
  const seen = new SeenMessages();

  const handleAccessEvent = new HandleAccessEventUseCase(
    dependencies.decider,
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
    publishQr: new PublishQrCodeUseCase(bus, clock, ids, dependencies.tokens),
  };
}
