import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import {
  CONTRACT_VERSION,
  type AckMessage,
  type AckStatus,
  type CommandMessage,
  type StatusMessage,
} from '../../domain/terminal/messages.js';
import { parseTopic } from '../../domain/terminal/topics.js';
import { parsePayload } from '../../infrastructure/mqtt/payload-parser.js';
import type { Logger } from '../../shared/logger.js';

/**
 * Terminal ESP32 simulado (sem hardware): publica status e leituras NFC e responde
 * comandos com ACK correlacionado, seguindo as regras do contrato (rejeita comando
 * expirado e nao executa duas vezes o mesmo `commandId`).
 */
export class SimulatedTerminal {
  private readonly acked = new Map<string, AckMessage>();

  constructor(
    readonly terminalId: string,
    private readonly bus: MessageBus,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
    private readonly logger: Logger,
  ) {}

  /** Tambem serve de LWT: o broker o publica se a conexao cair sem desconexao limpa. */
  statusMessage(state: StatusMessage['state']): StatusMessage {
    return {
      v: CONTRACT_VERSION,
      messageId: this.ids.uuid(),
      terminalId: this.terminalId,
      timestamp: this.clock.now().toISOString(),
      state,
      firmware: 'sim-0.1.0',
    };
  }

  async announce(state: StatusMessage['state']): Promise<void> {
    await this.bus.publish('status', this.statusMessage(state));
  }

  async readNfc(uid: string): Promise<void> {
    await this.bus.publish('access-events', {
      v: CONTRACT_VERSION,
      messageId: this.ids.uuid(),
      terminalId: this.terminalId,
      timestamp: this.clock.now().toISOString(),
      type: 'nfc_read',
      uid,
    });
    this.logger.info('leitura nfc publicada', { terminalId: this.terminalId, uid });
  }

  /** Trata uma mensagem recebida; devolve o ACK publicado, se houver. */
  async onMessage(topic: string, payload: Buffer | string): Promise<AckMessage | undefined> {
    const parsedTopic = parseTopic(topic);
    if (parsedTopic?.terminalId !== this.terminalId) return undefined;

    if (parsedTopic.channel === 'qr') {
      const qr = parsePayload('qr', this.terminalId, payload);
      if (qr.ok) this.logger.info('qr exibido no display', { expiresAt: qr.message.expiresAt });
      return undefined;
    }
    if (parsedTopic.channel !== 'commands') return undefined;

    const result = parsePayload('commands', this.terminalId, payload, { now: this.clock.now() });
    if (result.ok) return this.execute(result.message);
    if (result.code === 'expired' && result.command) {
      this.logger.warn('comando expirado rejeitado', { commandId: result.command.commandId });
      return this.ack(result.command, 'expired', 'command_expired');
    }
    this.logger.warn('comando invalido descartado', { code: result.code, reason: result.reason });
    return undefined;
  }

  private async execute(command: CommandMessage): Promise<AckMessage> {
    const previous = this.acked.get(command.commandId);
    if (previous) {
      this.logger.warn('comando repetido: reenviando ack anterior', {
        commandId: command.commandId,
      });
      await this.bus.publish('acks', previous);
      return previous;
    }

    this.logger.info(
      command.action === 'open'
        ? 'porta aberta (servo + led verde)'
        : 'acesso negado (led vermelho + buzzer)',
      { commandId: command.commandId },
    );
    return this.ack(command, 'executed');
  }

  private async ack(
    command: CommandMessage,
    status: AckStatus,
    reason?: string,
  ): Promise<AckMessage> {
    const ack: AckMessage = {
      v: CONTRACT_VERSION,
      messageId: this.ids.uuid(),
      terminalId: this.terminalId,
      timestamp: this.clock.now().toISOString(),
      commandId: command.commandId,
      status,
      reason,
    };
    this.acked.set(command.commandId, ack);
    await this.bus.publish('acks', ack);
    return ack;
  }
}
