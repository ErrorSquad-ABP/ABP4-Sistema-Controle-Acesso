import type { AckMessage, CommandMessage } from '../terminal/messages.js';

export type AckResult =
  | { status: 'unknown' | 'duplicate' }
  | { status: 'correlated'; command: CommandMessage };

/** Compartilhado entre publicadores e consumidor; ACK e terminal conferidos atomicamente. */
export interface CommandStore {
  save(command: CommandMessage, requestId: string): Promise<CommandMessage>;
  findByRequestId(requestId: string): Promise<CommandMessage | undefined>;
  acknowledge(ack: AckMessage): Promise<AckResult>;
  /** Marca a entrega ao broker; sem a marca o relay ainda tenta publicar (DT-13). */
  markPublished(commandId: string, at: Date): Promise<void>;
  /**
   * Intencoes ainda nao entregues e nao vencidas em `now`, decididas ate `decidedBefore`
   * (folga para nao disputar com a publicacao em curso), das que vencem primeiro.
   */
  listUndispatched(now: Date, decidedBefore: Date, limit: number): Promise<CommandMessage[]>;
  /** Remove ate `limit` comandos com `expiresAt` antes de `before` (DT-18). */
  purgeExpired(before: Date, limit: number): Promise<number>;
}
