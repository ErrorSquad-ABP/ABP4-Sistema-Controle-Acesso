import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator, QrTokenSigner } from '../../domain/ports/id-generator.js';
import { QR_TTL_MS } from '../../domain/terminal/messages.js';
import { TERMINAL_ID_PATTERN } from '../../shared/terminal-id.js';

export interface QrCredentialClaims {
  terminalId: string;
  issuedAt: number;
  expiresAt: number;
}

export type QrCredentialValidation =
  | { valid: true; claims: QrCredentialClaims }
  | { valid: false };

const TTL_SECONDS = QR_TTL_MS / 1000;
const SIGNATURE = /^[A-Za-z0-9_-]{43}$/;
const TERMINAL = new RegExp(TERMINAL_ID_PATTERN);

/**
 * Formato compacto `v1.<terminalId>.<iat>.<exp>.<assinatura>`: o QR do terminal
 * e versao 8 / ECC_LOW (152 bytes), entao JSON+base64 nao caberia no maior id.
 */
export class IssueQrCredentialUseCase {
  constructor(
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
    private readonly signer: QrTokenSigner,
  ) {}

  execute(terminalId: string): { token: string; issuedAt: number; expiresAt: number } {
    const issuedAtSeconds = Math.floor(this.clock.now().getTime() / 1000);
    const expiresAtSeconds = issuedAtSeconds + TTL_SECONDS;
    const payload = `v1.${terminalId}.${issuedAtSeconds}.${expiresAtSeconds}`;
    return {
      token: `${payload}.${this.signer.sign(payload)}`,
      issuedAt: issuedAtSeconds * 1000,
      expiresAt: expiresAtSeconds * 1000,
    };
  }
}

export class ValidateQrCredentialUseCase {
  constructor(
    private readonly clock: Clock,
    private readonly signer: QrTokenSigner,
  ) {}

  execute(token: string, terminalId: string): QrCredentialValidation {
    if (typeof token !== 'string' || typeof terminalId !== 'string') return { valid: false };
    const parts = token.split('.');
    if (parts.length !== 5 || parts[0] !== 'v1') return { valid: false };

    const [, terminal, issuedRaw, expiresRaw, signature] = parts as [string, string, string, string, string];
    if (!TERMINAL.test(terminal) || terminal !== terminalId) return { valid: false };
    if (!/^\d{1,12}$/.test(issuedRaw) || !/^\d{1,12}$/.test(expiresRaw)) return { valid: false };
    if (!SIGNATURE.test(signature)) return { valid: false };

    const payload = `v1.${terminal}.${issuedRaw}.${expiresRaw}`;
    if (!this.signer.verify(payload, signature)) return { valid: false };

    const issuedAt = Number(issuedRaw);
    const expiresAt = Number(expiresRaw);
    if (expiresAt - issuedAt !== TTL_SECONDS) return { valid: false };

    const now = Math.floor(this.clock.now().getTime() / 1000);
    if (issuedAt > now || expiresAt <= now) return { valid: false };

    return {
      valid: true,
      claims: { terminalId, issuedAt: issuedAt * 1000, expiresAt: expiresAt * 1000 },
    };
  }
}
