import type { UserRole } from '../user-role.js';

export interface UserRecord {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  role: UserRole;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/** Edicao do proprio perfil: so o nome; papel, e-mail e situacao ficam fora. */
export interface UserProfileChanges {
  name?: string | undefined;
}

export interface UserRepository {
  findByEmail(email: string): Promise<UserRecord | null>;
  findById(id: string): Promise<UserRecord | null>;
  /** `null` quando o id nao existe mais (corrida com a exclusao). */
  updateProfile(id: string, changes: UserProfileChanges): Promise<UserRecord | null>;
}
