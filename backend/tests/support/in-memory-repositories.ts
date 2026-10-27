import { UnauthorizedError } from '../../src/domain/errors/domain-error.js';
import type { UserRepository } from '../../src/domain/ports/user-repository.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import type { TokenClaims, TokenService } from '../../src/domain/ports/token-service.js';
import type { Clock } from '../../src/domain/ports/clock.js';

export class InMemoryUserRepository implements UserRepository {
  constructor(private readonly users: UserRecord[] = []) {}

  async findByEmail(email: string): Promise<UserRecord | null> {
    return this.users.find((user) => user.email === email.toLowerCase()) ?? null;
  }

  async findById(id: string): Promise<UserRecord | null> {
    return this.users.find((user) => user.id === id) ?? null;
  }
}

/** Tokens previsiveis: `token-<n>-<userId>`; resolve o perfil no repositorio. */
export class FakeTokenService implements TokenService {
  private sequence = 0;

  constructor(private readonly users?: UserRepository) {}

  async issue(claims: TokenClaims): Promise<{ token: string; expiresIn: number }> {
    this.sequence += 1;
    return { token: `token-${this.sequence}-${claims.userId}`, expiresIn: 3600 };
  }

  async verify(token: string): Promise<TokenClaims> {
    const match = /^token-\d+-(.+)$/.exec(token);
    const user = match?.[1] ? await this.users?.findById(match[1]) : null;
    if (!user?.active) throw new UnauthorizedError('Token invalido');
    return { userId: user.id, role: user.role };
  }
}

export class FixedClock implements Clock {
  constructor(private current: Date) {}

  now(): Date {
    return this.current;
  }

  set(date: Date): void {
    this.current = date;
  }
}
