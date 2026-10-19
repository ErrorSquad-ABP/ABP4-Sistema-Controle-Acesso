import type { AckMessage, CommandMessage } from '../../domain/terminal/messages.js';
import type { PendingCommands } from '../../domain/terminal/pending-commands.js';
import type { SeenMessages } from '../../domain/terminal/seen-messages.js';
import type { Logger } from '../../shared/logger.js';

export type HandleAckOutput =
  | { status: 'duplicate' }
  | { status: 'unknown' }
  | { status: 'correlated'; command: CommandMessage };

/** ACK do terminal: correlaciona com o comando pelo `commandId`. Nao concede acesso. */
export class HandleAckUseCase {
  constructor(
    private readonly pending: PendingCommands,
    private readonly seen: SeenMessages,
    private readonly logger: Logger,
  ) {}

  execute(ack: AckMessage): HandleAckOutput {
    if (!this.seen.markIfNew(ack.messageId)) {
      this.logger.warn('ack duplicado descartado', { messageId: ack.messageId });
      return { status: 'duplicate' };
    }

    const command = this.pending.take(ack.commandId);
    if (!command) {
      this.logger.warn('ack de comando desconhecido', {
        terminalId: ack.terminalId,
        commandId: ack.commandId,
      });
      return { status: 'unknown' };
    }

    this.logger.info('ack correlacionado', {
      terminalId: ack.terminalId,
      commandId: ack.commandId,
      action: command.action,
      status: ack.status,
      reason: ack.reason,
    });
    return { status: 'correlated', command };
  }
}
