import type { CommandMessage } from './messages.js';

/** Comandos enviados que ainda aguardam ACK, indexados por `commandId`. */
export class PendingCommands {
  private readonly byId = new Map<string, CommandMessage>();

  constructor(private readonly graceMs = 60_000) {}

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
      if (Date.parse(command.expiresAt) + this.graceMs <= now.getTime()) this.byId.delete(id);
    }
  }
}
