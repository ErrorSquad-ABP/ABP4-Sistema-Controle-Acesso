import { HandleAccessEventUseCase } from '../application/terminal/handle-access-event.use-case.js';
import { DispatchPendingCommandsUseCase } from '../application/terminal/dispatch-pending-commands.use-case.js';
import { HandleAckUseCase } from '../application/terminal/handle-ack.use-case.js';
import { PublishCommandUseCase } from '../application/terminal/publish-command.use-case.js';
import { PublishQrCodeUseCase } from '../application/terminal/publish-qr-code.use-case.js';
import { IssueQrCredentialUseCase } from '../application/terminal/qr-credential.use-cases.js';
import type { AccessDecider } from '../domain/ports/access-decider.js';
import type { AccessRepository } from '../domain/ports/access-repository.js';
import type { CommandStore } from '../domain/ports/command-store.js';
import type { EventDeduplicator } from '../domain/ports/event-deduplicator.js';
import type { MessageBus } from '../domain/ports/message-bus.js';
import { SeenMessages } from '../domain/terminal/seen-messages.js';
import { CryptoIdGenerator } from '../infrastructure/ids/crypto-id-generator.js';
import { SystemClock } from '../infrastructure/clock/system-clock.js';
import { HmacQrTokenSigner } from '../infrastructure/ids/hmac-qr-token-signer.js';
import type { Env } from './config/env.js';
import type { Logger } from '../shared/logger.js';
import { TerminalMessageRouter } from './mqtt/terminal-message-router.js';

export interface MqttConsumerDependencies {
  /** Decisor ja validado no boot do runtime (DT-01); nunca um stub por fallback. */
  decider: AccessDecider;
  /** Store compartilhado com a API: o ACK de um comando publicado por ela correlaciona aqui. */
  commands: CommandStore;
  events: EventDeduplicator;
  /** Modo real: habilita o relay das intencoes nao publicadas (DT-13). */
  access?: Pick<AccessRepository, 'canDispatch'> | undefined;
  /** Janela de operacao do relay (DT-21); sem ela, o relay roda sempre. */
  withinRelayWindow?: ((now: Date) => boolean) | undefined;
}

/**
 * Montagem do processo MQTT (consumidor). Roda local na S1 e no Render a partir
 * da S2 (US-37); a API HTTP usa o composition-root.ts.
 */
export function buildMqttConsumer(
  bus: MessageBus,
  logger: Logger,
  onPresence: (terminalId: string, online: boolean) => void,
  env: Env,
  dependencies: MqttConsumerDependencies,
) {
  const clock = new SystemClock();
  const ids = new CryptoIdGenerator();
  const signer = new HmacQrTokenSigner(env.QR_TOKEN_SECRET);
  const seen = new SeenMessages();

  const handleAccessEvent = new HandleAccessEventUseCase(
    dependencies.decider,
    bus,
    clock,
    ids,
    dependencies.events,
    dependencies.commands,
    logger,
  );
  const handleAck = new HandleAckUseCase(dependencies.commands, seen, logger);

  const dispatchPending = dependencies.access
    ? new DispatchPendingCommandsUseCase(
        dependencies.commands,
        dependencies.access,
        new PublishCommandUseCase(dependencies.commands, bus, clock, ids),
        clock,
        logger,
        dependencies.withinRelayWindow,
      )
    : undefined;

  return {
    router: new TerminalMessageRouter(handleAccessEvent, handleAck, logger, onPresence, clock),
    publishQr: new PublishQrCodeUseCase(bus, ids, new IssueQrCredentialUseCase(clock, ids, signer)),
    dispatchPending,
  };
}
