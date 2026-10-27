import type { AccessAuthorization, AccessUser, DenialReason, TerminalContext } from '../access/access-policy.js';
import type { CommandMessage } from '../terminal/messages.js';

export interface AccessRecord {
  id: string;
  terminalId: string | null;
  occurredAt: string;
  method: 'NFC' | 'QR';
  decision: 'GRANTED' | 'DENIED';
  reason: DenialReason | null;
  user: AccessUser | null;
  location: { id: string; name: string } | null;
  authorizationId: string | null;
  credentialId: string | null;
  distanceMeters: number | null;
  latitude: number | null;
  longitude: number | null;
}

export interface AccessCredential {
  id: string; user: AccessUser; validFrom: Date | null; validUntil: Date | null; revokedAt: Date | null;
}

/**
 * Unidade de trabalho da decisao: evento, consumo da autorizacao e intencao de
 * comando entram na mesma transacao (DT-02), entao uma falha no meio nao deixa
 * acesso gravado sem comando nem comando sem auditoria.
 */
export interface AccessTransaction {
  findEvent(id: string): Promise<AccessRecord | null>;
  findTerminal(id: string): Promise<TerminalContext | null>;
  findUser(id: string): Promise<AccessUser | null>;
  findCredential(hash: string): Promise<AccessCredential | null>;
  findAuthorizations(userId: string, locationId: string): Promise<AccessAuthorization[]>;
  consumeAuthorization(id: string, now: Date): Promise<boolean>;
  record(event: AccessRecord): Promise<AccessRecord>;
  saveCommand(command: CommandMessage, requestId: string): Promise<CommandMessage>;
}

export interface AccessRepository {
  transaction<T>(requestId: string, work: (tx: AccessTransaction) => Promise<T>): Promise<T>;
  /** Confere que as tabelas da decisao existem antes de conectar no broker (DT-01). */
  ready(): Promise<void>;
  /** Terminal e local ativos agora: impede republicar comando de tentativa antiga. */
  canDispatch(terminalId: string): Promise<boolean>;
}
