import { ConflictError } from '../../domain/errors/domain-error.js';
import type { UserAdminRepository } from '../../domain/ports/user-admin-repository.js';
import type { UserRole } from '../../domain/user-role.js';
import { hashPassword, newPasswordSalt } from '../../shared/password-hasher.js';
import { toUserView, type UserView } from '../auth/user-view.js';

export interface CreateUserInput {
  name: string;
  email: string;
  password: string;
  role: UserRole;
}

export class CreateUserUseCase {
  constructor(private readonly users: UserAdminRepository) {}

  async execute(input: CreateUserInput): Promise<UserView> {
    const email = input.email.toLowerCase();
    if (await this.users.findByEmail(email)) throw new ConflictError('E-mail ja cadastrado');

    const user = await this.users.create({
      name: input.name,
      email,
      passwordHash: hashPassword(input.password, newPasswordSalt()),
      role: input.role,
    });
    return toUserView(user);
  }
}
