import { NotFoundError } from '../../domain/errors/domain-error.js';
import type { UserAdminRepository } from '../../domain/ports/user-admin-repository.js';
import { toUserView, type UserView } from '../auth/user-view.js';

export class GetUserUseCase {
  constructor(private readonly users: UserAdminRepository) {}

  async execute(id: string): Promise<UserView> {
    const user = await this.users.findById(id);
    if (!user) throw new NotFoundError('Usuario nao encontrado');
    return toUserView(user);
  }
}
