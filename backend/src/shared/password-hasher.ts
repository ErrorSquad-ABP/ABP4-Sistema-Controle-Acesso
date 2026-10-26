import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

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

/** Confere a senha contra o formato `scrypt$N$r$p$salt$hash`; hash invalido nunca lanca. */
export function verifyPassword(password: string, stored: string): boolean {
  const parts = stored.split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return false;
  const [, n, r, p, salt, hash] = parts;
  if (!n || !r || !p || !salt || !hash) return false;
  const expected = Buffer.from(hash, 'hex');
  if (expected.length === 0 || !isPositiveInt(n) || !isPositiveInt(r) || !isPositiveInt(p)) return false;
  try {
    const actual = scryptSync(password, salt, expected.length, {
      N: Number(n),
      r: Number(r),
      p: Number(p),
    });
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  } catch {
    // Parametros fora do limite do scrypt viram negativa, nao um 500 no login.
    return false;
  }
}

function isPositiveInt(value: string): boolean {
  return /^\d+$/.test(value) && Number(value) > 0;
}
