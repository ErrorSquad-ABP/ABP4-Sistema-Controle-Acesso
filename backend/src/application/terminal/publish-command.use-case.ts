import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import { ConflictError } from '../../domain/errors/domain-error.js';
import { COMMAND_TTL_MS, CONTRACT_VERSION, type CommandAction, type CommandMessage } from '../../domain/terminal/messages.js';

export class PublishCommandUseCase {
  constructor(
    private readonly store: CommandStore,
    private readonly bus: MessageBus,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
  ) {}

  async execute(input: { requestId: string; terminalId: string; action: CommandAction; reason?: string }): Promise<CommandMessage> {
    const now = this.clock.now();
    const previous = await this.store.findByRequestId(input.requestId);
    const command = previous ?? await this.store.save({
      v: CONTRACT_VERSION, messageId: this.ids.uuid(), commandId: this.ids.uuid(),
      terminalId: input.terminalId, timestamp: now.toISOString(),
      expiresAt: new Date(now.getTime() + COMMAND_TTL_MS).toISOString(),
      action: input.action, ...(input.reason === undefined ? {} : { reason: input.reason }),
    }, input.requestId);
    if (command.terminalId !== input.terminalId || command.action !== input.action) {
      throw new ConflictError('Identificador de solicitacao ja utilizado para outro comando');
    }
    if (Date.parse(command.expiresAt) <= now.getTime()) throw new Error('Comando expirado; nao sera republicado');
    // Uma falha de transporte pode ocorrer depois da entrega: preserve id e prazo para retentativa.
    await this.bus.publish('commands', command);
    return command;
  }
}
