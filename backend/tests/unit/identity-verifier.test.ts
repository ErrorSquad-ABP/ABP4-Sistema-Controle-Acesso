import { randomUUID } from 'node:crypto';
import { SignJWT } from 'jose';
import { describe, expect, it, vi } from 'vitest';
import { JwtIdentityVerifier } from '../../src/infrastructure/auth/jwt-identity-verifier.js';
import { AuthenticateUseCase } from '../../src/application/access/authenticate.use-case.js';
import type { AccessRepository } from '../../src/domain/ports/access-repository.js';

const secret = 'unit-test-secret-'.repeat(4);
const userId = randomUUID();
const verifier = new JwtIdentityVerifier(secret);
const sign = (jwt: SignJWT, key = secret) => jwt.sign(new TextEncoder().encode(key));
const valid = (alg = 'HS256') => new SignJWT({ role: 'ADMIN' }).setProtectedHeader({ alg })
  .setSubject(userId).setIssuedAt().setExpirationTime('1h').setIssuer('abp4').setAudience('abp4-api');

describe('identidade nas rotas de acesso', () => {
  it('aceita apenas identidade assinada, valida e destinada a API', async () => {
    expect(await verifier.verify(await sign(valid()))).toBe(userId);
  });

  it('rejeita assinatura, emissor, audiencia e algoritmo divergentes', async () => {
    for (const jwt of [valid().setIssuer('outro'), valid().setAudience('outra'), valid('HS384')]) {
      await expect(verifier.verify(await sign(jwt))).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
    }
    await expect(verifier.verify(await sign(valid(), 'outra-chave-'.repeat(6)))).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
  });

  it('rejeita subject invalido, ausencia de expiracao e token futuro', async () => {
    const noExpiry = new SignJWT({}).setProtectedHeader({ alg: 'HS256' }).setSubject(userId)
      .setIssuedAt().setIssuer('abp4').setAudience('abp4-api');
    for (const jwt of [valid().setSubject('nao-uuid'), noExpiry, valid().setIssuedAt(Math.floor(Date.now()/1000)+3600)]) {
      await expect(verifier.verify(await sign(jwt))).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
    }
  });

  it('busca o perfil atual no banco e ignora privilegios declarados no JWT', async () => {
    const findUser = vi.fn<AccessRepository['findUser']>().mockResolvedValue({ id: userId, name: 'Maria', role: 'RESIDENT', active: true });
    const repository: AccessRepository = { findUser, transaction: vi.fn(), list: vi.fn(), saveQrToken: vi.fn() };
    const authenticate = new AuthenticateUseCase(verifier, repository);
    const bearer = `Bearer ${await sign(valid())}`;
    await expect(authenticate.execute(bearer, true)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    findUser.mockResolvedValue({ id: userId, name: 'Maria', role: 'ADMIN', active: false });
    await expect(authenticate.execute(bearer)).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
    await expect(authenticate.execute(undefined)).rejects.toMatchObject({ code: 'UNAUTHORIZED' });
  });
});
