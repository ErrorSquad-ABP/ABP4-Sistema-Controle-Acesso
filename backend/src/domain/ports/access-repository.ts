import type { AccessAuthorization, AccessUser, DenialReason, TerminalContext } from '../access/access-policy.js';

export interface AccessRecord {
  id: string; terminalId: string | null; occurredAt: string; method: 'NFC' | 'QR';
  decision: 'GRANTED' | 'DENIED'; reason: DenialReason | null;
  user: AccessUser | null; location: { id: string; name: string } | null;
  authorizationId: string | null; credentialId: string | null;
  distanceMeters: number | null; latitude: number | null; longitude: number | null;
}
export interface AccessCredential {
  id: string; user: AccessUser; validFrom: Date | null; validUntil: Date | null; revokedAt: Date | null;
}
export interface AccessQuery {
  page: number; pageSize: number; userId?: string | undefined; locationId?: string | undefined;
  method?: 'NFC' | 'QR' | undefined; decision?: 'GRANTED' | 'DENIED' | undefined;
  from?: string | undefined; to?: string | undefined;
}
export interface AccessTransaction {
  findEvent(id: string): Promise<AccessRecord | null>;
  findTerminal(id: string): Promise<TerminalContext | null>;
  findUser(id: string): Promise<AccessUser | null>;
  findCredential(hash: string): Promise<AccessCredential | null>;
  findQrToken(hash: string): Promise<{ terminalId: string; expiresAt: Date } | null>;
  findAuthorizations(userId: string, locationId: string): Promise<AccessAuthorization[]>;
  consumeAuthorization(id: string, now: Date): Promise<boolean>;
  record(event: AccessRecord): Promise<AccessRecord>;
}
export interface AccessRepository {
  transaction<T>(requestId: string, work: (tx: AccessTransaction) => Promise<T>): Promise<T>;
  findUser(id: string): Promise<AccessUser | null>;
  list(query: AccessQuery): Promise<{ items: AccessRecord[]; page: number; pageSize: number; total: number }>;
  saveQrToken(hash: string, terminalId: string, expiresAt: Date): Promise<boolean>;
}
