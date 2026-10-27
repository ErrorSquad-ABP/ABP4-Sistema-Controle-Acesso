export type DenialReason = 'UNKNOWN_TERMINAL' | 'TERMINAL_INACTIVE' | 'INVALID_CREDENTIAL' |
  'CREDENTIAL_EXPIRED' | 'USER_INACTIVE' | 'NO_AUTHORIZATION' | 'AUTHORIZATION_NOT_STARTED' |
  'AUTHORIZATION_EXPIRED' | 'AUTHORIZATION_CANCELED' | 'NO_USES_LEFT' | 'OUT_OF_RANGE';

export interface AccessUser { id: string; name: string; role: 'ADMIN' | 'RESIDENT' | 'VISITOR'; active: boolean }
export interface TerminalContext {
  id: string;
  active: boolean;
  location: { id: string; name: string; active: boolean; latitude: number; longitude: number; radiusMeters: number };
}
export interface AccessAuthorization {
  id: string; userId: string; locationId: string; startsAt: Date; endsAt: Date;
  maxUses: number; usedCount: number; canceledAt: Date | null;
}
export interface AccessPolicyContext {
  terminal: TerminalContext | null;
  user: AccessUser | null;
  authorizations: AccessAuthorization[];
  credentialValid: boolean;
  credentialExpired?: boolean;
  method: 'NFC' | 'QR';
  position?: { latitude: number; longitude: number } | undefined;
  now: Date;
}
export interface PolicyDecision {
  action: 'open' | 'deny'; reason: DenialReason | 'authorized';
  authorizationId: string | null; distanceMeters: number | null;
}

export function decideAccess(ctx: AccessPolicyContext): PolicyDecision {
  let distanceMeters: number | null = null;
  const deny = (reason: DenialReason): PolicyDecision => ({ action: 'deny', reason, authorizationId: null, distanceMeters });
  if (!ctx.terminal) return deny('UNKNOWN_TERMINAL');
  const { location } = ctx.terminal;
  if (!ctx.terminal.active || !location.active) return deny('TERMINAL_INACTIVE');
  if (ctx.credentialExpired) return deny('CREDENTIAL_EXPIRED');
  if (!ctx.credentialValid || !ctx.user) return deny('INVALID_CREDENTIAL');
  if (!ctx.user.active) return deny('USER_INACTIVE');
  if (ctx.method === 'QR') {
    if (!ctx.position) return deny('OUT_OF_RANGE');
    const rad = (v: number) => v * Math.PI / 180;
    const dLat = rad(ctx.position.latitude - location.latitude);
    const dLon = rad(ctx.position.longitude - location.longitude);
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(location.latitude)) *
      Math.cos(rad(ctx.position.latitude)) * Math.sin(dLon / 2) ** 2;
    distanceMeters = 6_371_000 * 2 * Math.asin(Math.sqrt(Math.min(1, a)));
    if (distanceMeters > location.radiusMeters) return deny('OUT_OF_RANGE');
  }
  const authorizations = ctx.authorizations.filter((a) => a.locationId === location.id && a.userId === ctx.user?.id);
  if (authorizations.length === 0) return deny('NO_AUTHORIZATION');
  const unavailable = (a: AccessAuthorization): DenialReason | undefined => {
    if (a.canceledAt) return 'AUTHORIZATION_CANCELED';
    if (ctx.now < a.startsAt) return 'AUTHORIZATION_NOT_STARTED';
    if (ctx.now > a.endsAt) return 'AUTHORIZATION_EXPIRED';
    if (a.usedCount >= a.maxUses) return 'NO_USES_LEFT';
    return undefined;
  };
  const available = authorizations.find((a) => unavailable(a) === undefined);
  if (!available) return deny(unavailable(authorizations[0]!)!);
  return { action: 'open', reason: 'authorized', authorizationId: available.id, distanceMeters };
}
