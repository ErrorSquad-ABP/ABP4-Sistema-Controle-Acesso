import type { AuthorizationStatus, AuthorizationView } from '../authorizations/authorization.js';

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
}
