import { SignJWT, jwtVerify } from 'jose';
import { UnauthorizedError } from '../../domain/errors/domain-error.js';
import { isUserRole } from '../../domain/user-role.js';
import type { TokenClaims, TokenService } from '../../domain/ports/token-service.js';

const ISSUER = 'abp4-api';
const AUDIENCE = 'abp4-app';

/** JWT HS256: assinatura, emissor e audiencia conferidos a cada requisicao. */
export class JwtTokenService implements TokenService {
  private readonly secret: Uint8Array;

  constructor(
    secret: string,
    private readonly ttlSeconds: number,
  ) {
    this.secret = new TextEncoder().encode(secret);
  }

  async issue(claims: TokenClaims): Promise<{ token: string; expiresIn: number }> {
    // Epoch numerico evita depender do parser de duracao do jose (e aceita TTL negativo em teste).
    const issuedAt = Math.floor(Date.now() / 1000);
    const token = await new SignJWT({ role: claims.role })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(claims.userId)
      .setIssuer(ISSUER)
      .setAudience(AUDIENCE)
      .setIssuedAt(issuedAt)
      .setExpirationTime(issuedAt + this.ttlSeconds)
      .sign(this.secret);
    return { token, expiresIn: this.ttlSeconds };
  }

  async verify(token: string): Promise<TokenClaims> {
    try {
      const { payload } = await jwtVerify(token, this.secret, {
        issuer: ISSUER,
        audience: AUDIENCE,
        algorithms: ['HS256'],
      });
      if (typeof payload.sub !== 'string' || !isUserRole(payload.role)) {
        throw new UnauthorizedError('Token invalido');
      }
      return { userId: payload.sub, role: payload.role };
    } catch (err) {
      if (err instanceof UnauthorizedError) throw err;
      throw new UnauthorizedError('Token invalido');
    }
  }
}
