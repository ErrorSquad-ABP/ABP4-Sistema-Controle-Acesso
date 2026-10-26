import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator, QrTokenSigner } from '../../domain/ports/id-generator.js';
import { QR_TTL_MS } from '../../domain/terminal/messages.js';

export interface QrCredentialClaims {
  terminalId: string;
  issuedAt: number;
  expiresAt: number;
  id: string;
}

export type QrCredentialValidation =
  | { valid: true; claims: QrCredentialClaims }
  | { valid: false };

const encode = (value: string) => Buffer.from(value, 'utf8').toString('base64url');

export class IssueQrCredentialUseCase {
  constructor(
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
    private readonly signer: QrTokenSigner,
  ) {}

  execute(terminalId: string): { token: string; issuedAt: number; expiresAt: number } {
    const issuedAt = this.clock.now().getTime();
    const expiresAt = issuedAt + QR_TTL_MS;
    const payload = encode(JSON.stringify({ terminalId, issuedAt, expiresAt, id: this.ids.uuid() }));
    return { token: `${payload}.${this.signer.sign(payload)}`, issuedAt, expiresAt };
  }
}

export class ValidateQrCredentialUseCase {
  constructor(private readonly clock: Clock, private readonly signer: QrTokenSigner) {}

  execute(token: string, terminalId: string): QrCredentialValidation {
    if (typeof token !== 'string' || typeof terminalId !== 'string') return { valid: false };
    const parts = token.split('.');
    if (parts.length !== 2 || !/^[A-Za-z0-9_-]+$/.test(parts[0]!) || !/^[A-Za-z0-9_-]{43}$/.test(parts[1]!)) {
      return { valid: false };
    }
    const [payload, signature] = parts as [string, string];
    if (!this.signer.verify(payload, signature)) return { valid: false };
    try {
      const bytes = Buffer.from(payload, 'base64url');
      if (bytes.toString('base64url') !== payload) return { valid: false };
      const raw: unknown = JSON.parse(bytes.toString('utf8'));
      if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return { valid: false };
      const c = raw as Record<string, unknown>;
      if (Object.keys(c).sort().join(',') !== 'expiresAt,id,issuedAt,terminalId') return { valid: false };
      if (typeof c.terminalId !== 'string' || c.terminalId !== terminalId || typeof c.id !== 'string' || !c.id) return { valid: false };
      if (!Number.isSafeInteger(c.issuedAt) || !Number.isSafeInteger(c.expiresAt)) return { valid: false };
      const issuedAt = c.issuedAt as number;
      const expiresAt = c.expiresAt as number;
      if (expiresAt - issuedAt !== QR_TTL_MS || issuedAt > this.clock.now().getTime() || expiresAt <= this.clock.now().getTime()) return { valid: false };
      return { valid: true, claims: { terminalId, issuedAt, expiresAt, id: c.id } };
    } catch {
      return { valid: false };
    }
  }
}
