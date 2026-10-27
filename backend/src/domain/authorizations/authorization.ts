import type { UserRole } from '../user-role.js';

export const AUTHORIZATION_STATUSES = ['SCHEDULED', 'ACTIVE', 'EXPIRED', 'CANCELED'] as const;
export type AuthorizationStatus = (typeof AUTHORIZATION_STATUSES)[number];

export interface AuthorizationRecord {
  id: string;
  user: { id: string; name: string; role: UserRole };
  location: { id: string; name: string };
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  usedCount: number;
  canceledAt: Date | null;
  cancelReason: string | null;
  createdAt: Date;
}

/** Forma do contrato: datas em UTC e situacao/restante ja calculados. */
export interface AuthorizationView {
  id: string;
  user: { id: string; name: string; role: UserRole };
  location: { id: string; name: string };
  startsAt: string;
  endsAt: string;
  maxUses: number;
  usedCount: number;
  remainingUses: number;
  status: AuthorizationStatus;
  canceledAt: string | null;
  cancelReason: string | null;
  createdAt: string;
}

/**
 * Situacao derivada, na ordem das regras de negocio: cancelada vence tudo
 * (o historico precisa mostrar que foi cancelada mesmo fora da janela).
 */
export function authorizationStatus(
  authorization: Pick<AuthorizationRecord, 'startsAt' | 'endsAt' | 'maxUses' | 'usedCount' | 'canceledAt'>,
  now: Date,
): AuthorizationStatus {
  if (authorization.canceledAt) return 'CANCELED';
  if (now < authorization.startsAt) return 'SCHEDULED';
  if (now >= authorization.endsAt || authorization.usedCount >= authorization.maxUses) return 'EXPIRED';
  return 'ACTIVE';
}

export function remainingUses(authorization: Pick<AuthorizationRecord, 'maxUses' | 'usedCount'>): number {
  return Math.max(0, authorization.maxUses - authorization.usedCount);
}

export function toAuthorizationView(authorization: AuthorizationRecord, now: Date): AuthorizationView {
  return {
    id: authorization.id,
    user: authorization.user,
    location: authorization.location,
    startsAt: authorization.startsAt.toISOString(),
    endsAt: authorization.endsAt.toISOString(),
    maxUses: authorization.maxUses,
    usedCount: authorization.usedCount,
    remainingUses: remainingUses(authorization),
    status: authorizationStatus(authorization, now),
    canceledAt: authorization.canceledAt?.toISOString() ?? null,
    cancelReason: authorization.cancelReason,
    createdAt: authorization.createdAt.toISOString(),
  };
}
