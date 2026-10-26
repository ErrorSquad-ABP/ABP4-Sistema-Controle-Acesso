import { createHmac, timingSafeEqual } from 'node:crypto';
import type { QrTokenSigner } from '../../domain/ports/id-generator.js';

/** HMAC-SHA-256 QR token signature adapter. The configured key is never logged. */
export class HmacQrTokenSigner implements QrTokenSigner {
  constructor(private readonly secret: string) {
    if (Buffer.byteLength(secret, 'utf8') < 32) {
      throw new Error('QR_TOKEN_SECRET deve conter ao menos 32 bytes');
    }
  }

  sign(payload: string): string {
    return createHmac('sha256', this.secret).update(payload).digest('base64url');
  }

  verify(payload: string, signature: string): boolean {
    const expected = Buffer.from(this.sign(payload), 'base64url');
    let supplied: Buffer;
    try {
      supplied = Buffer.from(signature, 'base64url');
    } catch {
      return false;
    }
    return supplied.length === expected.length && timingSafeEqual(supplied, expected);
  }
}
