import { ConflictError, NotFoundError } from '../../domain/errors/domain-error.js';
import type { UserAdminRepository, UserChanges } from '../../domain/ports/user-admin-repository.js';
import type { UserRole } from '../../domain/user-role.js';
import { hashPassword, newPasswordSalt } from '../../shared/password-hasher.js';
import { toUserView, type UserView } from '../auth/user-view.js';

export interface UpdateUserInput {
  name?: string | undefined;
  email?: string | undefined;
  password?: string | undefined;
  role?: UserRole | undefined;
  active?: boolean | undefined;
}

export class UpdateUserUseCase {
  constructor(private readonly users: UserAdminRepository) {}

  async execute(id: string, input: UpdateUserInput): Promise<UserView> {
    const current = await this.users.findById(id);
    if (!current) throw new NotFoundError('Usuario nao encontrado');

    const changes: UserChanges = {};
    if (input.name !== undefined) changes.name = input.name;
    if (input.role !== undefined) changes.role = input.role;
    if (input.active !== undefined) changes.active = input.active;
    if (input.password !== undefined) {
      changes.passwordHash = hashPassword(input.password, newPasswordSalt());
    }
    if (input.email !== undefined) {
      const email = input.email.toLowerCase();
      const owner = await this.users.findByEmail(email);
      if (owner && owner.id !== id) throw new ConflictError('E-mail ja cadastrado');
      changes.email = email;
    }

    const updated = await this.users.update(id, changes);
    if (!updated) throw new NotFoundError('Usuario nao encontrado');
    return toUserView(updated);
  }
}
