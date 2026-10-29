import type { AckResult, CommandStore } from '../ports/command-store.js';
import type { AckMessage, CommandMessage } from './messages.js';

/** Comandos enviados que ainda aguardam ACK, indexados por `commandId`. */
export class PendingCommands implements CommandStore {
  private readonly byId = new Map<string, CommandMessage>();
  private readonly byRequest = new Map<string, CommandMessage>();
  private readonly acked = new Map<string, string>();
  /** Instante da reserva/ultima tentativa de entrega, como `publishedAt` no Postgres. */
  private readonly publishedAt = new Map<string, number>();

  constructor(private readonly graceMs = 60_000) {}

  async findByRequestId(requestId: string): Promise<CommandMessage | undefined> {
    return this.byRequest.get(requestId);
  }

  async save(command: CommandMessage, requestId: string): Promise<CommandMessage> {
    const previous = this.byRequest.get(requestId);
    if (previous) return previous;
    this.register(command, new Date(command.timestamp));
    this.byRequest.set(requestId, command);
    return command;
  }

  async acknowledge(ack: AckMessage): Promise<AckResult> {
    const ackedBy = this.acked.get(ack.commandId);
    if (ackedBy !== undefined) {
      return { status: ackedBy === ack.terminalId ? 'duplicate' : 'unknown' };
    }
    const command = this.take(ack.commandId, ack.terminalId);
    if (!command) return { status: 'unknown' };
    this.acked.set(ack.commandId, ack.terminalId);
    return { status: 'correlated', command };
  }

  async markPublished(commandId: string, at: Date): Promise<void> {
    this.publishedAt.set(commandId, at.getTime());
  }

  async claimUndispatched(now: Date, decidedBefore: Date, limit: number, staleBefore: Date): Promise<CommandMessage[]> {
    const claimed = [...this.byRequest.values()]
      .filter((command) =>
        (this.publishedAt.get(command.commandId) ?? -Infinity) < staleBefore.getTime() &&
        !this.acked.has(command.commandId) &&
        Date.parse(command.expiresAt) > now.getTime() &&
        Date.parse(command.timestamp) <= decidedBefore.getTime())
      .sort((a, b) => Date.parse(a.expiresAt) - Date.parse(b.expiresAt))
      .slice(0, limit);
    for (const command of claimed) this.publishedAt.set(command.commandId, now.getTime());
    return claimed;
  }

  async releaseClaim(commandId: string): Promise<void> {
    this.publishedAt.delete(commandId);
  }

  /** Em memoria nao ha historico a expurgar: o `prune` ja descarta o que venceu. */
  async purgeExpired(before: Date, _limit: number): Promise<number> {
    this.prune(before);
    return 0;
  }

  register(command: CommandMessage, now: Date): void {
    this.prune(now);
    this.byId.set(command.commandId, command);
  }

  /**
   * Remove e devolve o comando correlacionado, se ele ainda estiver pendente.
   * Com `terminalId`, so devolve quando o ACK veio do terminal que recebeu o comando.
   */
  take(commandId: string, terminalId?: string): CommandMessage | undefined {
    const command = this.byId.get(commandId);
    if (!command || (terminalId !== undefined && command.terminalId !== terminalId)) {
      return undefined;
    }
    this.byId.delete(commandId);
    return command;
  }

  get size(): number {
    return this.byId.size;
  }

  /** Descarta comandos vencidos ha mais que a folga: o ACK deles nao vem mais. */
  private prune(now: Date): void {
    for (const [id, command] of this.byId) {
      if (Date.parse(command.expiresAt) + this.graceMs <= now.getTime()) {
        this.byId.delete(id);
        this.publishedAt.delete(id);
      }
    }
  }
}
