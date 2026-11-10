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
 * `expired` separa o QR vencido (assinatura boa, fora da janela de 25 s) do
 * token invalido: a auditoria registra CREDENTIAL_EXPIRED so no primeiro caso.
 */
export type QrCredentialValidation =
  | { valid: true; claims: QrCredentialClaims }
  | { valid: false; reason: 'invalid' | 'expired' };

const TTL_SECONDS = QR_TTL_MS / 1000;
const SIGNATURE = /^[A-Za-z0-9_-]{16}$/;
const TERMINAL = new RegExp(TERMINAL_ID_PATTERN);

/**
 * Formato compacto `v1.<terminalId>.<iat>.<ttl>.<assinatura>`: `ttl` em segundos
 * (hoje 25) e assinatura HMAC de 96 bits. Para o `terminal-dev-01` sao 49 bytes,
 * QR versao 3 (29x29), que cabe em escala 2 no OLED de 64 px. O maior id (64)
 * ainda cabe na versao 8. As 5 partes e o prefixo `v1` sao os mesmos que o app le.
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
    const payload = `v1.${terminalId}.${issuedAtSeconds}.${TTL_SECONDS}`;
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

    const [, terminal, issuedRaw, ttlRaw, signature] = parts as [string, string, string, string, string];
    if (!TERMINAL.test(terminal) || terminal !== terminalId) return invalid;
    if (!/^\d{1,12}$/.test(issuedRaw) || ttlRaw !== String(TTL_SECONDS)) return invalid;
    if (!SIGNATURE.test(signature)) return invalid;

    const payload = `v1.${terminal}.${issuedRaw}.${ttlRaw}`;
    if (!this.signer.verify(payload, signature)) return invalid;

    const issuedAt = Number(issuedRaw);
    const expiresAt = issuedAt + TTL_SECONDS;

    const now = Math.floor(this.clock.now().getTime() / 1000);
    if (issuedAt > now) return invalid;
    if (expiresAt <= now) return { valid: false, reason: 'expired' };

    return {
      valid: true,
      claims: { terminalId, issuedAt: issuedAt * 1000, expiresAt: expiresAt * 1000 },
    };
  }
}
