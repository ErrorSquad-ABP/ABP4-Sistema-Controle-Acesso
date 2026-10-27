import { describe, expect, it } from 'vitest';
import { UnauthorizedError } from '../../src/domain/errors/domain-error.js';
import { JwtTokenService } from '../../src/infrastructure/auth/jwt.js';

const SECRET = 'segredo-de-teste-com-32-caracteres';
const service = new JwtTokenService(SECRET, 60);

describe('JwtTokenService', () => {
  it('emite e verifica um token com sub e role', async () => {
    const { token, expiresIn } = await service.issue({
      userId: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      role: 'ADMIN',
    });

    expect(expiresIn).toBe(60);
    await expect(service.verify(token)).resolves.toEqual({
      userId: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      role: 'ADMIN',
    });
  });

  it('rejeita token assinado com outro segredo', async () => {
    const outro = new JwtTokenService('outro-segredo-de-teste-32-caracteres', 60);
    const { token } = await outro.issue({ userId: 'a', role: 'VISITOR' });

    await expect(service.verify(token)).rejects.toBeInstanceOf(UnauthorizedError);
  });

  it('rejeita token expirado', async () => {
    const curto = new JwtTokenService(SECRET, -60);
    const { token } = await curto.issue({ userId: 'a', role: 'VISITOR' });

    await expect(service.verify(token)).rejects.toBeInstanceOf(UnauthorizedError);
  });

  it('rejeita lixo em vez de estourar erro cru', async () => {
    await expect(service.verify('nao-e-token')).rejects.toBeInstanceOf(UnauthorizedError);
  });
});
