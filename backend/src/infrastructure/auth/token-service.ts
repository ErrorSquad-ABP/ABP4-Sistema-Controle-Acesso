import type { UserRole } from '../../domain/user-role.js';

export interface TokenClaims {
  userId: string;
  role: UserRole;
}

export interface TokenService {
  issue(claims: TokenClaims): Promise<{ token: string; expiresIn: number }>;
  verify(token: string): Promise<TokenClaims>;
}
