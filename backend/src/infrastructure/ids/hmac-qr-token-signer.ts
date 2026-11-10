import { createHmac, timingSafeEqual } from 'node:crypto';
import type { QrTokenSigner } from '../../domain/ports/id-generator.js';

/**
 * HMAC-SHA-256 truncado em 96 bits (16 caracteres base64url). O token vale 25 s,
 * e preso a um terminal e a API limita tentativas: 2^96 tentativas de forja ficam
 * fora de alcance, e o QR encolhe o bastante para caber grande no OLED 128x64.
 * The configured key is never logged.
 */
export const QR_SIGNATURE_BYTES = 12;

export class HmacQrTokenSigner implements QrTokenSigner {
  constructor(private readonly secret: string) {
    if (Buffer.byteLength(secret, 'utf8') < 32) {
      throw new Error('QR_TOKEN_SECRET deve conter ao menos 32 bytes');
    }
  }

  sign(payload: string): string {
    return createHmac('sha256', this.secret).update(payload).digest().subarray(0, QR_SIGNATURE_BYTES).toString('base64url');
  }

  verify(payload: string, signature: string): boolean {
    const expected = Buffer.from(this.sign(payload), 'base64url');
    let supplied: Buffer;
    try {
      supplied = Buffer.from(signature, 'base64url');
    } catch {
      return false;
    }
    // Rejeita base64url nao canonico: dois textos diferentes nao podem valer a mesma assinatura.
    if (supplied.toString('base64url') !== signature) return false;
    return supplied.length === expected.length && timingSafeEqual(supplied, expected);
  }
}
