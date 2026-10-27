import { createHash } from 'node:crypto';

/**
 * Hash do UID NFC (ja normalizado em maiusculo) e de valores opacos.
 * O valor original nunca vai para o banco nem para o log.
 */
export function hashCredential(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}
