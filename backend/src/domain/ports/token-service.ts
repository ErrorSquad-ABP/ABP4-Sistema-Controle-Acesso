import type { UserRole } from '../user-role.js';

export interface TokenClaims {
  userId: string;
  role: UserRole;
}

/** Porta de emissao/verificacao de token; o adapter HS256 vive em infrastructure. */
export interface TokenService {
  issue(claims: TokenClaims): Promise<{ token: string; expiresIn: number }>;
  verify(token: string): Promise<TokenClaims>;
}
