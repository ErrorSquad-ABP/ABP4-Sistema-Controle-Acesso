import type { AccessDecider } from '../../domain/ports/access-decider.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import {
  COMMAND_TTL_MS,
  CONTRACT_VERSION,
  type AccessEventMessage,
  type CommandMessage,
} from '../../domain/terminal/messages.js';
import type { PendingCommands } from '../../domain/terminal/pending-commands.js';
import type { SeenMessages } from '../../domain/terminal/seen-messages.js';
import type { Logger } from '../../shared/logger.js';

export type HandleAccessEventOutput =
  | { status: 'duplicate' }
  | { status: 'commanded'; command: CommandMessage };

/** Tentativa de acesso vinda do terminal: decide e responde com um comando. */
export class HandleAccessEventUseCase {
  constructor(
    private readonly decider: AccessDecider,
    private readonly bus: MessageBus,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
    private readonly seen: SeenMessages,
    private readonly pending: PendingCommands,
    private readonly logger: Logger,
  ) {}

  async execute(event: AccessEventMessage): Promise<HandleAccessEventOutput> {
    if (!this.seen.markIfNew(event.messageId)) {
      this.logger.warn('tentativa duplicada descartada', { messageId: event.messageId });
      return { status: 'duplicate' };
    }

    const decision = await this.decider.decide(event);
    const now = this.clock.now();
    const command: CommandMessage = {
      v: CONTRACT_VERSION,
      messageId: this.ids.uuid(),
      terminalId: event.terminalId,
      timestamp: now.toISOString(),
      commandId: this.ids.uuid(),
      expiresAt: new Date(now.getTime() + COMMAND_TTL_MS).toISOString(),
      action: decision.action,
      reason: decision.reason,
    };

    this.pending.register(command, now);
    try {
      await this.bus.publish('commands', command);
    } catch (err) {
      // Sem comando no ar: desfaz o estado para a retransmissao (QoS 1) tentar de novo.
      this.pending.take(command.commandId);
      this.seen.forget(event.messageId);
      throw err;
    }
    this.logger.info('comando enviado', {
      terminalId: command.terminalId,
      commandId: command.commandId,
      action: command.action,
      attemptMessageId: event.messageId,
    });
    return { status: 'commanded', command };
  }
}
