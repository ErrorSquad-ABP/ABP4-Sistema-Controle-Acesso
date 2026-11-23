import { QR_SIGNATURE_BYTES } from '../../domain/ports/id-generator.js';
import { QR_TTL_MS } from '../../domain/terminal/messages.js';

/** 41 digitos decimais: codigo (1 byte), epoch UTC (4 bytes) e HMAC de 96 bits. */
export const COMPACT_QR_DIGITS = 41;
export const COMPACT_QR_TTL_SECONDS = QR_TTL_MS / 1000;

const MAX_VALUE = 1n << 136n;
const SIGNATURE_MASK = (1n << 96n) - 1n;

export interface CompactQrClaims {
  code: number;
  issuedAt: number;
  signature: string;
}

export function compactPayload(code: number, terminalId: string, issuedAt: number): string {
  return `qr:v2:${code}:${terminalId}:${issuedAt}:${COMPACT_QR_TTL_SECONDS}`;
}

/** Codigo invalido e erro de programacao: quem chama resolve terminalId a partir de um codigo ja validado. */
export function encodeCompactQrToken(code: number, issuedAt: number, signer: (payload: string) => string, terminalId: string): string {
  if (!Number.isInteger(code) || code < 1 || code > 255) throw new Error('codigo de terminal fora de 1..255');
  if (!Number.isInteger(issuedAt) || issuedAt < 0 || issuedAt > 0xffffffff) {
    throw new Error('iat fora do intervalo de 32 bits');
  }
  const signature = Buffer.from(signer(compactPayload(code, terminalId, issuedAt)), 'base64url');
  if (signature.length !== QR_SIGNATURE_BYTES) throw new Error('assinatura QR com tamanho inesperado');
  const packed = (BigInt(code) << 128n) | (BigInt(issuedAt) << 96n) | BigInt(`0x${signature.toString('hex')}`);
  return packed.toString().padStart(COMPACT_QR_DIGITS, '0');
}

/** Devolve null para qualquer texto fora do formato; autenticidade e conferida pelo signer. */
export function decodeCompactQrToken(token: string): CompactQrClaims | null {
  if (!new RegExp(`^[0-9]{${COMPACT_QR_DIGITS}}$`).test(token)) return null;
  const packed = BigInt(token);
  if (packed >= MAX_VALUE) return null;
  const code = Number(packed >> 128n);
  if (code === 0) return null;
  const issuedAt = Number((packed >> 96n) & 0xffffffffn);
  const signature = Buffer.from((packed & SIGNATURE_MASK).toString(16).padStart(24, '0'), 'hex').toString('base64url');
  return { code, issuedAt, signature };
}
