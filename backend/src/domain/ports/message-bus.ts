import type { Channel, MessagesByChannel } from '../terminal/messages.js';

/** Saida de mensagens para os terminais; o adapter decide QoS/retain pelo canal. */
export interface MessageBus {
  publish<C extends Channel>(channel: C, message: MessagesByChannel[C]): Promise<void>;
}
