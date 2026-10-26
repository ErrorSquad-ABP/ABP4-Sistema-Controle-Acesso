import { UnauthorizedError } from '../../domain/errors/domain-error.js';
import type { UserRepository } from '../../domain/ports/user-repository.js';
import { toUserView, type UserView } from './user-view.js';

export class GetCurrentUserUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string): Promise<UserView> {
    const user = await this.users.findById(userId);
    if (!user || !user.active) throw new UnauthorizedError('Sessao invalida');
    return toUserView(user);
  }
}
