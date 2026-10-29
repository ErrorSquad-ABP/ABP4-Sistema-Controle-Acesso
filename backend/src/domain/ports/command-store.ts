import type { AckMessage, CommandMessage } from '../terminal/messages.js';

export type AckResult =
  | { status: 'unknown' | 'duplicate' }
  | { status: 'correlated'; command: CommandMessage };

/** Compartilhado entre publicadores e consumidor; ACK e terminal conferidos atomicamente. */
export interface CommandStore {
  save(command: CommandMessage, requestId: string): Promise<CommandMessage>;
  findByRequestId(requestId: string): Promise<CommandMessage | undefined>;
  acknowledge(ack: AckMessage): Promise<AckResult>;
  /**
   * Grava a ultima entrega/tentativa ao broker (DT-13). O claim usa o mesmo campo
   * como reserva, entao a marca atualiza (nao so preenche) o instante.
   */
  markPublished(commandId: string, at: Date): Promise<void>;
  /**
   * Reserva ate `limit` intencoes ainda nao entregues e nao vencidas em `now`, decididas
   * ate `decidedBefore` (folga para nao disputar com a publicacao em curso), das que
   * vencem primeiro. A reserva e atomica: duas replicas do worker nao publicam o mesmo
   * comando (DT-13). `staleBefore` libera reserva orfa de um processo que morreu depois
   * de marcar; precisa ser menor que o TTL do comando para haver o que reclamar.
   */
  claimUndispatched(
    now: Date,
    decidedBefore: Date,
    limit: number,
    staleBefore: Date,
  ): Promise<CommandMessage[]>;
  /** Devolve a reserva sem entrega: o proximo ciclo tenta de novo (DT-13). */
  releaseClaim(commandId: string): Promise<void>;
  /** Remove ate `limit` comandos com `expiresAt` antes de `before` (DT-18). */
  purgeExpired(before: Date, limit: number): Promise<number>;
}
