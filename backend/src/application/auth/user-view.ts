import type { UserRecord } from '../../domain/ports/user-repository.js';

export interface UserView {
  id: string;
  name: string;
  email: string;
  role: UserRecord['role'];
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

/** Contrato devolve datas em UTC; o dominio guarda `Date`. */
export function toUserView(user: UserRecord): UserView {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    active: user.active,
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
  };
}
