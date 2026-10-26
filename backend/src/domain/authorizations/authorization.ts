export type AuthorizationStatus = 'SCHEDULED' | 'ACTIVE' | 'EXPIRED' | 'CANCELED';

export interface AuthorizationRecord {
  id: string;
  userId: string;
  user: { id: string; name: string; role: 'ADMIN' | 'RESIDENT' | 'VISITOR' };
  locationId: string;
  location: { id: string; name: string };
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  usedCount: number;
  canceledAt: Date | null;
  cancelReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface Authorization extends AuthorizationRecord {
  remainingUses: number;
  status: AuthorizationStatus;
}

export function deriveAuthorizationStatus(record: AuthorizationRecord, now: Date): AuthorizationStatus {
  if (record.canceledAt) return 'CANCELED';
  if (record.usedCount >= record.maxUses || now.getTime() > record.endsAt.getTime()) return 'EXPIRED';
  if (now.getTime() < record.startsAt.getTime()) return 'SCHEDULED';
  return 'ACTIVE';
}

export function presentAuthorization(record: AuthorizationRecord, now: Date): Authorization {
  return {
    ...record,
    remainingUses: Math.max(0, record.maxUses - record.usedCount),
    status: deriveAuthorizationStatus(record, now),
  };
}
