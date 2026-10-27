import type { AckMessage, CommandMessage } from '../../domain/terminal/messages.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { SeenMessages } from '../../domain/terminal/seen-messages.js';
import type { Logger } from '../../shared/logger.js';

export type HandleAckOutput =
  | { status: 'duplicate' }
  | { status: 'unknown' }
  | { status: 'correlated'; command: CommandMessage };

/** ACK do terminal: correlaciona com o comando pelo `commandId`. Nao concede acesso. */
export class HandleAckUseCase {
  constructor(
    private readonly pending: CommandStore,
    private readonly seen: SeenMessages,
    private readonly logger: Logger,
  ) {}

  async execute(ack: AckMessage): Promise<HandleAckOutput> {
    if (!this.seen.markIfNew(ack.messageId)) {
      this.logger.warn('ack duplicado descartado', { messageId: ack.messageId });
      return { status: 'duplicate' };
    }

    let result;
    try {
      result = await this.pending.acknowledge(ack);
    } catch (error) {
      this.seen.forget(ack.messageId);
      throw error;
    }
    if (result.status !== 'correlated') {
      this.logger.warn('ack de comando desconhecido ou de outro terminal', {
        terminalId: ack.terminalId,
        commandId: ack.commandId,
      });
      return result;
    }
    const { command } = result;

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
