import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import { CONTRACT_VERSION, QR_TTL_MS, type QrCodeMessage } from '../../domain/terminal/messages.js';

/**
 * Publica o QR rotativo (validade de 10 s) ao terminal. Na S1 o token e um valor
 * de teste; token assinado e validacao entram na US-19.
 */
export class PublishQrCodeUseCase {
  constructor(
    private readonly bus: MessageBus,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
  ) {}

  async execute(input: { terminalId: string }): Promise<QrCodeMessage> {
    const now = this.clock.now();
    const qr: QrCodeMessage = {
      v: CONTRACT_VERSION,
      messageId: this.ids.uuid(),
      terminalId: input.terminalId,
      timestamp: now.toISOString(),
      token: this.ids.token(),
      expiresAt: new Date(now.getTime() + QR_TTL_MS).toISOString(),
    };
    await this.bus.publish('qr', qr);
    return qr;
  }
}
