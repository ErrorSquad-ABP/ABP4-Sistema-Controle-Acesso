import { NotFoundError } from '../../domain/errors/domain-error.js';
import type { UserAdminRepository } from '../../domain/ports/user-admin-repository.js';

/** Exclusao logica: o usuario fica inativo e o historico de acessos e preservado. */
export class DeleteUserUseCase {
  constructor(private readonly users: UserAdminRepository) {}

  async execute(id: string): Promise<void> {
    const current = await this.users.findById(id);
    if (!current) throw new NotFoundError('Usuario nao encontrado');

    const updated = await this.users.update(id, { active: false });
    if (!updated) throw new NotFoundError('Usuario nao encontrado');
  }
}
