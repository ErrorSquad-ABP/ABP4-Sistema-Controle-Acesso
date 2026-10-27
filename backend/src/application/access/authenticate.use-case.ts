import { ForbiddenError, UnauthorizedError } from '../../domain/errors/domain-error.js';
import type { AccessRepository } from '../../domain/ports/access-repository.js';
import type { IdentityVerifier } from '../../domain/ports/identity-verifier.js';

export class AuthenticateUseCase {
  constructor(private readonly verifier: IdentityVerifier, private readonly users: AccessRepository) {}

  async execute(authorization: string | undefined, admin = false) {
    const match = /^Bearer (\S+)$/i.exec(authorization ?? '');
    if (!match?.[1]) throw new UnauthorizedError('Bearer token obrigatorio');
    const user = await this.users.findUser(await this.verifier.verify(match[1]));
    if (!user?.active) throw new UnauthorizedError('Usuario inexistente ou inativo');
    if (admin && user.role !== 'ADMIN') throw new ForbiddenError('Perfil ADMIN obrigatorio');
    return user;
  }
}
