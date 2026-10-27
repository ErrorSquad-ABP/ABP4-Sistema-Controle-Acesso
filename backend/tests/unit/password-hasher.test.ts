import { describe, expect, it } from 'vitest';
import { hashPassword, verifyPassword } from '../../src/shared/password-hasher.js';

const stored = hashPassword('senha-forte-123', 'salt-fixo');

describe('verifyPassword', () => {
  it('aceita a senha correta', () => {
    expect(verifyPassword('senha-forte-123', stored)).toBe(true);
  });

  it('recusa senha errada', () => {
    expect(verifyPassword('senha-errada', stored)).toBe(false);
  });

  it('recusa hash malformado sem estourar', () => {
    expect(verifyPassword('x', 'lixo')).toBe(false);
  });

  it('recusa hash com parametros de scrypt invalidos', () => {
    expect(verifyPassword('x', 'scrypt$3$8$1$salt$00')).toBe(false);
  });

  it('recusa hash hex com sufixo invalido ou nibble solto', () => {
    expect(verifyPassword('senha-forte-123', `${stored}zz`)).toBe(false);
    expect(verifyPassword('senha-forte-123', `${stored}f`)).toBe(false);
  });
});
