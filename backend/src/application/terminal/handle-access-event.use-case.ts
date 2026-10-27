import type { AccessDecider } from '../../domain/ports/access-decider.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import { type AccessEventMessage, type CommandMessage } from '../../domain/terminal/messages.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { SeenMessages } from '../../domain/terminal/seen-messages.js';
import type { Logger } from '../../shared/logger.js';
import { PublishCommandUseCase } from './publish-command.use-case.js';

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
    private readonly pending: CommandStore,
    private readonly logger: Logger,
  ) {}

  async execute(event: AccessEventMessage): Promise<HandleAccessEventOutput> {
    if (!this.seen.markIfNew(event.messageId)) {
      this.logger.warn('tentativa duplicada descartada', { messageId: event.messageId });
      return { status: 'duplicate' };
    }

    let command: CommandMessage;
    try {
      const decision = await this.decider.decide(event);
      command = await new PublishCommandUseCase(this.pending, this.bus, this.clock, this.ids).execute({
        requestId: event.messageId, terminalId: event.terminalId, action: decision.action, reason: decision.reason,
      });
    } catch (err) {
      // Retentativa consulta a decisao persistida e reutiliza o mesmo comando/prazo.
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
