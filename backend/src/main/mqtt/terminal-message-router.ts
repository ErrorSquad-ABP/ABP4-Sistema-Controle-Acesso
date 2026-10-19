import type { HandleAccessEventUseCase } from '../../application/terminal/handle-access-event.use-case.js';
import type { HandleAckUseCase } from '../../application/terminal/handle-ack.use-case.js';
import { parseTopic } from '../../domain/terminal/topics.js';
import { parsePayload } from '../../infrastructure/mqtt/payload-parser.js';
import type { Logger } from '../../shared/logger.js';

export interface TerminalPresenceListener {
  (terminalId: string, online: boolean): void;
}

/**
 * Recebe topico + payload bruto do broker, valida pelo contrato v1 e despacha
 * para o caso de uso do canal. Mensagem invalida e logada e descartada.
 */
export class TerminalMessageRouter {
  constructor(
    private readonly handleAccessEvent: HandleAccessEventUseCase,
    private readonly handleAck: HandleAckUseCase,
    private readonly logger: Logger,
    private readonly onPresence: TerminalPresenceListener = () => {},
  ) {}

  async route(topic: string, payload: Buffer | string): Promise<void> {
    const parsedTopic = parseTopic(topic);
    if (!parsedTopic) {
      this.logger.warn('topico desconhecido', { topic });
      return;
    }
    const { channel, terminalId } = parsedTopic;

    switch (channel) {
      case 'access-events': {
        const result = parsePayload(channel, terminalId, payload);
        if (!result.ok) return this.discard(topic, result.code, result.reason);
        this.logger.info('tentativa de acesso recebida', {
          terminalId,
          type: result.message.type,
          uid: result.message.uid,
          messageId: result.message.messageId,
        });
        this.onPresence(terminalId, true);
        await this.handleAccessEvent.execute(result.message);
        return;
      }
      case 'acks': {
        const result = parsePayload(channel, terminalId, payload);
        if (!result.ok) return this.discard(topic, result.code, result.reason);
        this.logger.info('ack recebido', {
          terminalId,
          commandId: result.message.commandId,
          status: result.message.status,
        });
        this.handleAck.execute(result.message);
        return;
      }
      case 'status': {
        const result = parsePayload(channel, terminalId, payload);
        if (!result.ok) return this.discard(topic, result.code, result.reason);
        this.logger.info('status do terminal', { terminalId, state: result.message.state });
        this.onPresence(terminalId, result.message.state === 'online');
        return;
      }
      default:
        // qr e commands sao saidas do backend; nao assinamos nem tratamos.
        this.logger.debug('canal ignorado pelo consumidor', { topic });
    }
  }

  private discard(topic: string, code: string, reason: string): void {
    this.logger.warn('mensagem descartada', { topic, code, reason });
  }
}
