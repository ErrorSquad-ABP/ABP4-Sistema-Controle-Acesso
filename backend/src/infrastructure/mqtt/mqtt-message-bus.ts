import { connectAsync, type MqttClient } from 'mqtt';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import type { Channel, MessagesByChannel } from '../../domain/terminal/messages.js';
import { CHANNEL_DELIVERY, topicFor } from '../../domain/terminal/topics.js';
import type { Logger } from '../../shared/logger.js';

export interface MqttBusOptions {
  url: string;
  clientId: string;
  username?: string | undefined;
  password?: string | undefined;
  /** Last will: o broker publica se a conexao cair sem desconexao limpa. */
  will?: { [C in Channel]: { channel: C; message: MessagesByChannel[C] } }[Channel] | undefined;
  /** Espera maxima pelo PUBACK; padrao PUBLISH_TIMEOUT_MS. */
  publishTimeoutMs?: number | undefined;
}

/** Bem abaixo dos 10 s do comando: sobra prazo para o relay tentar de novo. */
export const PUBLISH_TIMEOUT_MS = 3_000;

export type RawMessageHandler = (topic: string, payload: Buffer) => void;

/** Adapter do MessageBus sobre o mqtt.js; QoS e retain vem da tabela do contrato. */
export class MqttMessageBus implements MessageBus {
  private constructor(
    private readonly client: MqttClient,
    private readonly logger: Logger,
    private readonly publishTimeoutMs: number,
  ) {}

  static async connect(options: MqttBusOptions, logger: Logger): Promise<MqttMessageBus> {
    const { will } = options;
    const client = await connectAsync(options.url, {
      clientId: options.clientId,
      ...(options.username ? { username: options.username } : {}),
      ...(options.password ? { password: options.password } : {}),
      reconnectPeriod: 2000,
      ...(will
        ? {
            will: {
              topic: topicFor(will.channel, will.message.terminalId),
              payload: Buffer.from(JSON.stringify(will.message)),
              ...CHANNEL_DELIVERY[will.channel],
            },
          }
        : {}),
    });
    client.on('reconnect', () => logger.warn('mqtt reconectando'));
    client.on('close', () => logger.warn('mqtt conexao fechada'));
    client.on('error', (err) => logger.error('mqtt erro', { error: err.message }));
    logger.info('mqtt conectado', { url: options.url, clientId: options.clientId });
    return new MqttMessageBus(client, logger, options.publishTimeoutMs ?? PUBLISH_TIMEOUT_MS);
  }

  /**
   * Falha em vez de esperar a reconexao: offline, o mqtt.js guarda o QoS 1 e so
   * resolve ao reconectar, o que penduraria o pedido HTTP e o relay (DT-13).
   * Apos o timeout o pacote pode sair atrasado, com o mesmo id; o terminal
   * deduplica e rejeita o que ja venceu.
   */
  async publish<C extends Channel>(channel: C, message: MessagesByChannel[C]): Promise<void> {
    if (!this.client.connected) throw new Error('mqtt desconectado: publicacao recusada');
    const topic = topicFor(channel, message.terminalId);
    const sending = this.client.publishAsync(topic, JSON.stringify(message), CHANNEL_DELIVERY[channel]);
    // Evita rejeicao nao tratada quando o envio termina depois do timeout.
    sending.catch(() => {});
    let timer: NodeJS.Timeout | undefined;
    try {
      await Promise.race([
        sending,
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => reject(new Error('mqtt sem confirmacao no prazo')), this.publishTimeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
    this.logger.debug('mqtt publicado', { topic, messageId: message.messageId });
  }

  async subscribe(filters: string[], handler: RawMessageHandler): Promise<void> {
    this.client.on('message', handler);
    await this.client.subscribeAsync(filters, { qos: 1 });
    this.logger.info('mqtt assinando', { filters });
  }

  async close(): Promise<void> {
    await this.client.endAsync();
  }
}
