import type { Clock } from '../../domain/ports/clock.js';

/** Tres heartbeats de 30 s (contrato MQTT v1) sem sinal: o terminal conta como offline. */
export const PRESENCE_TTL_MS = 90_000;

/**
 * Terminais com sinal recente (`status` online ou tentativa de acesso). O relay da
 * outbox so consulta o banco enquanto ha algum: sem terminal, nao ha a quem
 * entregar e o Neon pode suspender (DT-13). O prazo cobre terminal que caiu sem
 * LWT e firmware que ainda nao publica heartbeat.
 */
export class TerminalPresence {
  private readonly lastSeen = new Map<string, number>();

  constructor(
    private readonly clock: Clock,
    private readonly ttlMs = PRESENCE_TTL_MS,
  ) {}

  update(terminalId: string, online: boolean): void {
    if (online) this.lastSeen.set(terminalId, this.clock.now().getTime());
    else this.lastSeen.delete(terminalId);
  }

  anyOnline(): boolean {
    const now = this.clock.now().getTime();
    for (const [id, seenAt] of this.lastSeen) {
      if (now - seenAt < this.ttlMs) return true;
      this.lastSeen.delete(id);
    }
    return false;
  }
}
