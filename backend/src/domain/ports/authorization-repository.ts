export type AuthorizationUserRole = 'ADMIN' | 'RESIDENT' | 'VISITOR';

/** Dados de pessoa necessários para existência e para a resposta da autorização. */
export interface AuthorizationUser {
  id: string;
  name: string;
  role: AuthorizationUserRole;
  active: boolean;
}

/** Dados de local necessários para existência e para a resposta da autorização. */
export interface AuthorizationLocation {
  id: string;
  name: string;
  isActive: boolean;
}

export interface NewAuthorization {
  id: string;
  userId: string;
  locationId: string;
  createdById: string;
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  usedCount: 0;
  canceledAt: null;
  cancelReason: null;
  createdAt: Date;
}

export interface CreatedAuthorization {
  id: string;
  userId: string;
  locationId: string;
  createdById: string;
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  usedCount: number;
  canceledAt: Date | null;
  cancelReason: string | null;
  createdAt: Date;
  user: AuthorizationUser;
  location: AuthorizationLocation;
}

/** Port de leitura e criação; adapters concretos ficam em infrastructure. */
export interface AuthorizationRepository {
  findUserById(id: string): Promise<AuthorizationUser | undefined>;
  findLocationById(id: string): Promise<AuthorizationLocation | undefined>;
  create(input: NewAuthorization): Promise<CreatedAuthorization>;
}
