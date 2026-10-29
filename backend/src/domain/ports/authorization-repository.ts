import type { AuthorizationRecord, AuthorizationStatus, AuthorizationView } from '../authorizations/authorization.js';

export interface AuthorizationForUserFilters {
  userId: string;
  page: number;
  pageSize: number;
  /** Filtro sobre a situacao calculada (nao e coluna do banco). */
  status?: AuthorizationStatus | undefined;
  now: Date;
}

export interface AuthorizationRepository {
  listForUser(filters: AuthorizationForUserFilters): Promise<{ items: AuthorizationView[]; total: number }>;
  list(filters: AuthorizationAdminFilters): Promise<{ items: AuthorizationView[]; total: number }>;
  findById(id: string): Promise<AuthorizationRecord | null>;
  create(input: NewAuthorization): Promise<AuthorizationRecord>;
  /**
   * Cancelamento condicional: `null` quando o id nao existe e `ConflictError`
   * quando a autorizacao ja foi cancelada ou expirou (inclusive na corrida).
   */
  cancel(id: string, at: Date, reason: string | null): Promise<AuthorizationRecord | null>;
}

export interface AuthorizationAdminFilters extends Omit<AuthorizationForUserFilters, 'userId'> {
  userId?: string | undefined;
  locationId?: string | undefined;
  from?: Date | undefined;
  to?: Date | undefined;
}

export interface NewAuthorization {
  userId: string;
  locationId: string;
  createdById: string;
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
}
