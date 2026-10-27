import type { UserRole } from '../user-role.js';
import type { UserRecord, UserRepository } from './user-repository.js';

export interface UserListFilters {
  page: number;
  pageSize: number;
  role?: UserRole | undefined;
  active?: boolean | undefined;
  search?: string | undefined;
}

export interface NewUserRecord {
  name: string;
  email: string;
  passwordHash: string;
  role: UserRole;
}

/** Campos ja normalizados pelo caso de uso (e-mail minusculo, senha em hash). */
export interface UserChanges {
  name?: string | undefined;
  email?: string | undefined;
  passwordHash?: string | undefined;
  role?: UserRole | undefined;
  active?: boolean | undefined;
}

export interface UserUpdateOptions {
  /** Bloqueia a mudanca se ela deixar o sistema sem nenhum ADMIN ativo. */
  requireAnotherAdmin?: boolean;
}

/** Cadastro administrativo; herda as consultas usadas pela autenticacao. */
export interface UserAdminRepository extends UserRepository {
  list(filters: UserListFilters): Promise<{ items: UserRecord[]; total: number }>;
  create(user: NewUserRecord): Promise<UserRecord>;
  update(id: string, changes: UserChanges, options?: UserUpdateOptions): Promise<UserRecord | null>;
}
