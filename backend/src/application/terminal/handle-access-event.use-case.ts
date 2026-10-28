import type { AccessDecider } from '../../domain/ports/access-decider.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import type { AccessEventMessage, CommandMessage } from '../../domain/terminal/messages.js';
import type { EventDeduplicator } from '../../domain/ports/event-deduplicator.js';
import { isFreshAccessEvent } from '../../domain/terminal/event-freshness.js';
import { StaleEventError } from '../../domain/errors/domain-error.js';
import type { Logger } from '../../shared/logger.js';
import { PublishCommandUseCase } from './publish-command.use-case.js';

export type HandleAccessEventOutput =
  | { status: 'duplicate' }
  | { status: 'stale' }
  | { status: 'commanded'; command: CommandMessage }
  | { status: 'expired'; command: CommandMessage };

/** Tentativa de acesso vinda do terminal: decide e responde com um comando. */
export class HandleAccessEventUseCase {
  constructor(
    private readonly decider: AccessDecider,
    private readonly bus: MessageBus,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
    private readonly seen: EventDeduplicator,
    private readonly pending: CommandStore,
    private readonly logger: Logger,
  ) {}

  async execute(event: AccessEventMessage): Promise<HandleAccessEventOutput> {
    if (!isFreshAccessEvent(event.timestamp, this.clock.now())) {
      this.logger.warn('tentativa fora da janela de frescor', { messageId: event.messageId });
      return { status: 'stale' };
    }
    const result = await this.seen.run(event.messageId, () => this.process(event));
    if (result.duplicate) {
      this.logger.warn('tentativa duplicada descartada', { messageId: event.messageId });
      return { status: 'duplicate' };
    }
    return result.value;
  }

  private async process(event: AccessEventMessage): Promise<HandleAccessEventOutput> {
    // Revalida apos esperar pela reserva/pool: fila nao renova frescor.
    if (!isFreshAccessEvent(event.timestamp, this.clock.now())) {
      this.logger.warn('tentativa descartada por frescor apos a reserva', {
        messageId: event.messageId,
        terminalId: event.terminalId,
      });
      return { status: 'stale' };
    }
    let decision;
    try {
      decision = await this.decider.decide(event);
    } catch (err) {
      if (!(err instanceof StaleEventError)) throw err;
      // O lock da decisao pode ter atravessado a janela de frescor: descarta sem publicar.
      this.logger.warn('tentativa descartada por frescor na decisao', {
        messageId: event.messageId,
        terminalId: event.terminalId,
      });
      return { status: 'stale' };
    }
    const result = await new PublishCommandUseCase(this.pending, this.bus, this.clock, this.ids).execute({
      requestId: event.messageId,
      terminalId: event.terminalId,
      action: decision.action,
      reason: decision.reason,
      // Ancora no instante da decisao: retentativa tardia nao ganha prazo novo.
      decidedAt: decision.decidedAt,
    });

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
