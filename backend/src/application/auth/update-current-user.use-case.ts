import { UnauthorizedError } from '../../domain/errors/domain-error.js';
import type { UserRepository } from '../../domain/ports/user-repository.js';
import { toUserView, type UserView } from './user-view.js';

export interface UpdateCurrentUserInput {
  name?: string | undefined;
}

/** Perfil do proprio usuario: o id vem da sessao e so o nome muda. */
export class UpdateCurrentUserUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string, input: UpdateCurrentUserInput): Promise<UserView> {
    const current = await this.users.findById(userId);
    if (!current || !current.active) throw new UnauthorizedError('Sessao invalida');

    const updated = await this.users.updateProfile(userId, { name: input.name });
    if (!updated) throw new UnauthorizedError('Sessao invalida');
    return toUserView(updated);
  }
}
