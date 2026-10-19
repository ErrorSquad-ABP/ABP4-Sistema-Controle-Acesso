import { createHash, randomBytes, scryptSync } from 'node:crypto';

const KEY_LENGTH = 64;
const SCRYPT = { N: 16384, r: 8, p: 1 } as const;

/** Formato unico de hash do projeto: `scrypt$N$r$p$salt$hash` (hex). */
export function hashPassword(password: string, salt: string): string {
  const hash = scryptSync(password, salt, KEY_LENGTH, SCRYPT).toString('hex');
  return `scrypt$${SCRYPT.N}$${SCRYPT.r}$${SCRYPT.p}$${salt}$${hash}`;
}

/** Salt aleatorio para cadastro real. */
export function newPasswordSalt(): string {
  return randomBytes(16).toString('hex');
}

/**
 * Salt deterministico por usuario: a seed precisa gerar o mesmo hash a cada execucao.
 * Nao usar em cadastro real — ali o salt vem de `newPasswordSalt()`.
 */
export function demoPasswordSalt(userId: string): string {
  return createHash('sha256').update(`abp4-demo:${userId}`).digest('hex').slice(0, 32);
}
