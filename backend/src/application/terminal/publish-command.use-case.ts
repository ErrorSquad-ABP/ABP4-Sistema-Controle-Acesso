import { ConflictError } from '../../domain/errors/domain-error.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import { COMMAND_TTL_MS, CONTRACT_VERSION, type CommandAction, type CommandMessage } from '../../domain/terminal/messages.js';

export interface PublishCommandInput {
  /** Chave de idempotencia: a tentativa de acesso que originou a decisao. */
  requestId: string;
  terminalId: string;
  action: CommandAction;
  reason?: string | undefined;
  /** Instante da decisao; ancora o prazo do comando (DT-02). */
  decidedAt: Date;
}

export interface PublishCommandOutput {
  command: CommandMessage;
  /** `false` quando a janela do comando ja passou: nada foi publicado. */
  published: boolean;
}

/**
 * Publica a intencao de comando ja persistida. Repetir a solicitacao reusa o
 * mesmo `commandId` e o mesmo `expiresAt`; se a janela venceu, nao abre de novo.
 */
export class PublishCommandUseCase {
  constructor(
    private readonly store: CommandStore,
    private readonly bus: MessageBus,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
  ) {}

  async execute(input: PublishCommandInput): Promise<PublishCommandOutput> {
    const previous = await this.store.findByRequestId(input.requestId);
    const command =
      previous ??
      (await this.store.save(
        {
          v: CONTRACT_VERSION,
          messageId: this.ids.uuid(),
          commandId: this.ids.uuid(),
          terminalId: input.terminalId,
          timestamp: input.decidedAt.toISOString(),
          expiresAt: new Date(input.decidedAt.getTime() + COMMAND_TTL_MS).toISOString(),
          action: input.action,
          ...(input.reason === undefined ? {} : { reason: input.reason }),
        },
        input.requestId,
      ));

    if (command.terminalId !== input.terminalId || command.action !== input.action) {
      throw new ConflictError('Identificador de solicitacao ja utilizado para outro comando');
    }
    if (Date.parse(command.expiresAt) <= this.clock.now().getTime()) {
      return { command, published: false };
    }
    // Uma falha de transporte pode ocorrer depois da entrega: preserve id e prazo para retentativa.
    await this.bus.publish('commands', command);
    return { command, published: true };
  }
}
