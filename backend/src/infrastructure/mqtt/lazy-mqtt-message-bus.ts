import type { MessageBus } from '../../domain/ports/message-bus.js';
import type { Channel, MessagesByChannel } from '../../domain/terminal/messages.js';
import type { Logger } from '../../shared/logger.js';
import { MqttMessageBus, type MqttBusOptions } from './mqtt-message-bus.js';

/** A API conecta somente quando precisa publicar; cada instancia pode usar o mesmo store. */
export class LazyMqttMessageBus implements MessageBus {
  private connection: Promise<MqttMessageBus> | undefined;
  constructor(private readonly options: MqttBusOptions, private readonly logger: Logger) {}
  async publish<C extends Channel>(channel: C, message: MessagesByChannel[C]): Promise<void> {
    this.connection ??= MqttMessageBus.connect(this.options, this.logger).catch((error: unknown) => {
      this.connection = undefined;
      throw error;
    });
    await (await this.connection).publish(channel, message);
  }
  async close(): Promise<void> {
    const connection = this.connection;
    this.connection = undefined;
    if (connection) await (await connection).close();
  }
}
