import type { AuthorizationRecord, AuthorizationStatus } from '../authorizations/authorization.js';

export interface AuthorizationFilters {
  userId?: string;
  locationId?: string;
  status?: AuthorizationStatus;
  from?: Date;
  to?: Date;
  page: number;
  pageSize: number;
  /** Uma única referência temporal para status derivado e filtro. */
  now: Date;
}

export interface AuthorizationPageResult {
  items: AuthorizationRecord[];
  total: number;
}

export interface AuthorizationRepository {
  list(filters: AuthorizationFilters): Promise<AuthorizationPageResult>;
  findById(id: string): Promise<AuthorizationRecord | null>;
  /** Atualização condicional ao snapshot lido; false indica alteração concorrente. */
  cancelIfUnchanged(
    record: AuthorizationRecord,
    canceledAt: Date,
    cancelReason: string | null,
  ): Promise<AuthorizationRecord | null>;
}
