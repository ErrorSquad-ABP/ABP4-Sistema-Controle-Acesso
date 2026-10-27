import type { UserRole } from '../user-role.js';

export const ACCESS_METHODS = ['QR', 'NFC'] as const;
export type AccessMethod = (typeof ACCESS_METHODS)[number];

export const ACCESS_DECISIONS = ['GRANTED', 'DENIED'] as const;
export type AccessDecision = (typeof ACCESS_DECISIONS)[number];

export interface AccessEventView {
  id: string;
  occurredAt: string;
  /** Identificador recebido do terminal; null em eventos legados. */
  terminalId: string | null;
  method: AccessMethod;
  decision: AccessDecision;
  reason: string | null;
  user: { id: string; name: string; role: UserRole } | null;
  /** null quando o terminal nao possui local resolvido (DT-03). */
  location: { id: string; name: string } | null;
  authorizationId: string | null;
  distanceMeters: number | null;
}

export interface AccessEventPageQuery {
  page: number;
  pageSize: number;
  userId?: string | undefined;
  locationId?: string | undefined;
  method?: AccessMethod | undefined;
  decision?: AccessDecision | undefined;
  from?: string | undefined;
  to?: string | undefined;
}

export interface AccessEventFilters {
  page: number;
  pageSize: number;
  userId?: string | undefined;
  locationId?: string | undefined;
  method?: AccessMethod | undefined;
  decision?: AccessDecision | undefined;
  from?: Date | undefined;
  to?: Date | undefined;
}

export interface AccessEventRepository {
  list(filters: AccessEventFilters): Promise<{ items: AccessEventView[]; total: number }>;
}
