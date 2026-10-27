import type { AccessDecider } from '../../domain/ports/access-decider.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import type { AccessEventMessage, CommandMessage } from '../../domain/terminal/messages.js';
import type { SeenMessages } from '../../domain/terminal/seen-messages.js';
import type { Logger } from '../../shared/logger.js';
import { PublishCommandUseCase } from './publish-command.use-case.js';

export type HandleAccessEventOutput =
  | { status: 'duplicate' }
  | { status: 'commanded'; command: CommandMessage }
  | { status: 'expired'; command: CommandMessage };

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

    let result;
    try {
      const decision = await this.decider.decide(event);
      result = await new PublishCommandUseCase(this.pending, this.bus, this.clock, this.ids).execute({
        requestId: event.messageId,
        terminalId: event.terminalId,
        action: decision.action,
        reason: decision.reason,
        // Ancora no instante da decisao: retentativa tardia nao ganha prazo novo.
        decidedAt: decision.decidedAt,
      });
    } catch (err) {
      // Sem comando no ar: a retentativa consulta a decisao persistida e reusa o mesmo prazo.
      this.seen.forget(event.messageId);
      throw err;
    }

    if (!result.published) {
      this.logger.warn('comando vencido nao publicado', {
        terminalId: event.terminalId,
        commandId: result.command.commandId,
        attemptMessageId: event.messageId,
      });
      return { status: 'expired', command: result.command };
    }

    this.logger.info('comando enviado', {
      terminalId: result.command.terminalId,
      commandId: result.command.commandId,
      action: result.command.action,
      attemptMessageId: event.messageId,
    });
    return { status: 'commanded', command: result.command };
  }
}
