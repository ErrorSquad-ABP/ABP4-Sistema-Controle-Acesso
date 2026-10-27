import { jwtVerify } from 'jose';
import { UnauthorizedError } from '../../domain/errors/domain-error.js';
import type { IdentityVerifier } from '../../domain/ports/identity-verifier.js';

export class JwtIdentityVerifier implements IdentityVerifier {
  constructor(private readonly secret: string) {}
  async verify(token: string): Promise<string> {
    try {
      const { payload } = await jwtVerify(token, new TextEncoder().encode(this.secret), {
        algorithms: ['HS256'], issuer: 'abp4', audience: 'abp4-api', requiredClaims: ['sub', 'iat', 'exp'], maxTokenAge: '1h',
      });
      if (typeof payload.sub !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(payload.sub)) throw new Error('subject invalido');
      return payload.sub;
    } catch {
      throw new UnauthorizedError('Token invalido ou expirado');
    }
  }
}
