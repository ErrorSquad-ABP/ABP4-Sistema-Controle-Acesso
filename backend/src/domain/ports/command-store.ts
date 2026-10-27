import type { AckMessage, CommandMessage } from '../terminal/messages.js';

export type AckResult =
  | { status: 'unknown' | 'duplicate' }
  | { status: 'correlated'; command: CommandMessage };

/** Compartilhado entre publicadores e consumidor; ACK e terminal conferidos atomicamente. */
export interface CommandStore {
  save(command: CommandMessage, requestId: string): Promise<CommandMessage>;
  findByRequestId(requestId: string): Promise<CommandMessage | undefined>;
  acknowledge(ack: AckMessage): Promise<AckResult>;
}
