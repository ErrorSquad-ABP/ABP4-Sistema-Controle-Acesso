import { decideAccess } from '../../domain/access/access-policy.js';
import type { AccessRecord, AccessRepository } from '../../domain/ports/access-repository.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { TokenHasher } from '../../domain/ports/token-hasher.js';
import { ConflictError } from '../../domain/errors/domain-error.js';

export interface AccessAttempt {
  id: string; terminalId: string; method: 'NFC' | 'QR'; uid?: string;
  userId?: string; qrToken?: string; position?: { latitude: number; longitude: number };
}

export class DecideAccessUseCase {
  constructor(private readonly repository: AccessRepository, private readonly clock: Clock, private readonly hasher: TokenHasher) {}

  async execute(input: AccessAttempt): Promise<AccessRecord> {
    return this.repository.transaction(input.id, async (tx) => {
      const previous = await tx.findEvent(input.id);
      if (previous) {
        if (previous.terminalId !== input.terminalId || previous.method !== input.method) {
          throw new ConflictError('Identificador de tentativa ja utilizado por outro terminal ou metodo');
        }
        return previous;
      }
      const terminal = await tx.findTerminal(input.terminalId);
      const credential = input.method === 'NFC' && input.uid ? await tx.findCredential(this.hasher.hash(input.uid.toUpperCase())) : null;
      const user = input.method === 'NFC' ? credential?.user ?? null : input.userId ? await tx.findUser(input.userId) : null;
      const qr = input.method === 'QR' && input.qrToken ? await tx.findQrToken(this.hasher.hash(input.qrToken)) : null;
      const authorizations = terminal && user ? await tx.findAuthorizations(user.id, terminal.location.id) : [];
      // A espera por um lock nao prolonga a validade da credencial ou da autorizacao.
      const now = this.clock.now();
      const credentialExpired = input.method === 'NFC'
        ? !!credential && ((credential.validFrom !== null && now < credential.validFrom) || (credential.validUntil !== null && now >= credential.validUntil))
        : !!qr && qr.terminalId === input.terminalId && now >= qr.expiresAt;
      const credentialValid = input.method === 'NFC'
        ? !!credential && !credential.revokedAt
        : !!qr && qr.terminalId === input.terminalId && now < qr.expiresAt;
      let decision = decideAccess({ terminal, user, authorizations, credentialValid, credentialExpired,
        method: input.method, position: input.position, now });
      if (decision.authorizationId && !await tx.consumeAuthorization(decision.authorizationId, now)) {
        decision = { ...decision, action: 'deny', reason: 'NO_USES_LEFT', authorizationId: null };
      }
      return tx.record({
        id: input.id, terminalId: input.terminalId, occurredAt: now.toISOString(), method: input.method,
        decision: decision.action === 'open' ? 'GRANTED' : 'DENIED',
        reason: decision.action === 'open' ? null : decision.reason as AccessRecord['reason'],
        user, location: terminal ? { id: terminal.location.id, name: terminal.location.name } : null,
        authorizationId: decision.authorizationId, credentialId: credential?.id ?? null,
        distanceMeters: decision.distanceMeters, latitude: input.position?.latitude ?? null,
        longitude: input.position?.longitude ?? null,
      });
    });
  }
}
