import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import type { AccessRepository } from '../../domain/ports/access-repository.js';
import type { TokenHasher } from '../../domain/ports/token-hasher.js';
import { CONTRACT_VERSION, QR_TTL_MS, type QrCodeMessage } from '../../domain/terminal/messages.js';

/**
 * Publica QR opaco de 10 s. No modo real, persiste o hash/vinculo antes do envio.
 * Sem repository/hasher e usado somente pelo fluxo demo explicito.
 */
export class PublishQrCodeUseCase {
  constructor(
    private readonly bus: MessageBus,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
    private readonly tokens?: { repository: AccessRepository; hasher: TokenHasher },
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
    if (this.tokens) {
      const saved = await this.tokens.repository.saveQrToken(this.tokens.hasher.hash(qr.token), input.terminalId, new Date(qr.expiresAt));
      if (!saved) throw new Error('Terminal desconhecido ou inativo; QR nao publicado');
    }
    await this.bus.publish('qr', qr);
    return qr;
  }
}
