import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { MessageBus } from '../../domain/ports/message-bus.js';
import { CONTRACT_VERSION, type QrCodeMessage } from '../../domain/terminal/messages.js';
import type { IssueQrCredentialUseCase } from './qr-credential.use-cases.js';

/**
 * Publica o QR rotativo assinado ao terminal.
 */
export class PublishQrCodeUseCase {
  constructor(
    private readonly bus: MessageBus,
    private readonly ids: IdGenerator,
    private readonly issueCredential: IssueQrCredentialUseCase,
  ) {}

  async execute(input: { terminalId: string }): Promise<QrCodeMessage> {
    const credential = this.issueCredential.execute(input.terminalId);
    const qr: QrCodeMessage = {
      v: CONTRACT_VERSION,
      messageId: this.ids.uuid(),
      terminalId: input.terminalId,
      timestamp: new Date(credential.issuedAt).toISOString(),
      token: credential.token,
      expiresAt: new Date(credential.expiresAt).toISOString(),
    };
    await this.bus.publish('qr', qr);
    return qr;
  }
}
