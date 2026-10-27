import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator, QrTokenSigner } from '../../domain/ports/id-generator.js';
import { QR_TTL_MS } from '../../domain/terminal/messages.js';
import { TERMINAL_ID_PATTERN } from '../../shared/terminal-id.js';

export interface QrCredentialClaims {
  terminalId: string;
  issuedAt: number;
  expiresAt: number;
}

/**
 * `expired` separa o QR vencido (assinatura boa, fora da janela de 10 s) do
 * token invalido: a auditoria registra CREDENTIAL_EXPIRED so no primeiro caso.
 */
export type QrCredentialValidation =
  | { valid: true; claims: QrCredentialClaims }
  | { valid: false; reason: 'invalid' | 'expired' };

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
    const invalid = { valid: false, reason: 'invalid' } as const;
    if (typeof token !== 'string' || typeof terminalId !== 'string') return invalid;
    const parts = token.split('.');
    if (parts.length !== 5 || parts[0] !== 'v1') return invalid;

    const [, terminal, issuedRaw, expiresRaw, signature] = parts as [string, string, string, string, string];
    if (!TERMINAL.test(terminal) || terminal !== terminalId) return invalid;
    if (!/^\d{1,12}$/.test(issuedRaw) || !/^\d{1,12}$/.test(expiresRaw)) return invalid;
    if (!SIGNATURE.test(signature)) return invalid;

    const payload = `v1.${terminal}.${issuedRaw}.${expiresRaw}`;
    if (!this.signer.verify(payload, signature)) return invalid;

    const issuedAt = Number(issuedRaw);
    const expiresAt = Number(expiresRaw);
    if (expiresAt - issuedAt !== TTL_SECONDS) return invalid;

    const now = Math.floor(this.clock.now().getTime() / 1000);
    if (issuedAt > now) return invalid;
    if (expiresAt <= now) return { valid: false, reason: 'expired' };

    return {
      valid: true,
      claims: { terminalId, issuedAt: issuedAt * 1000, expiresAt: expiresAt * 1000 },
    };
  }
}
