import { decideAccess } from '../../domain/access/access-policy.js';
import { ConflictError } from '../../domain/errors/domain-error.js';
import type { AccessRecord, AccessRepository } from '../../domain/ports/access-repository.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import { COMMAND_TTL_MS, CONTRACT_VERSION } from '../../domain/terminal/messages.js';
import { hashCredential } from '../../shared/credential-hash.js';
import type { ValidateQrCredentialUseCase } from '../terminal/qr-credential.use-cases.js';

export interface AccessAttempt {
  id: string;
  terminalId: string;
  method: 'NFC' | 'QR';
  uid?: string;
  userId?: string;
  qrToken?: string;
  position?: { latitude: number; longitude: number } | undefined;
}

function sameAttempt(previous: AccessRecord, input: AccessAttempt): boolean {
  if (previous.terminalId !== input.terminalId || previous.method !== input.method) return false;
  // O id da tentativa e a chave de idempotencia: reusa-lo com outro usuario nao pode devolver o evento alheio.
  return input.method === 'NFC' || previous.user?.id === input.userId;
}

/**
 * Decide o acesso e grava, na mesma transacao, o evento, o consumo da
 * autorizacao e a intencao de comando. O prazo do comando nasce do instante da
 * decisao, nunca da republicacao (DT-02).
 */
export class DecideAccessUseCase {
  constructor(
    private readonly repository: AccessRepository,
    private readonly clock: Clock,
    private readonly qr: ValidateQrCredentialUseCase,
    private readonly ids: IdGenerator,
  ) {}

  async execute(input: AccessAttempt): Promise<AccessRecord> {
    return this.repository.transaction(input.id, async (tx) => {
      const previous = await tx.findEvent(input.id);
      if (previous) {
        if (!sameAttempt(previous, input)) {
          throw new ConflictError('Identificador de tentativa ja utilizado por outro terminal, metodo ou usuario');
        }
        return previous;
      }

      const terminal = await tx.findTerminal(input.terminalId);
      const credential =
        input.method === 'NFC' && input.uid
          ? await tx.findCredential(hashCredential(input.uid.toUpperCase()))
          : null;
      const user =
        input.method === 'NFC'
          ? credential?.user ?? null
          : input.userId
            ? await tx.findUser(input.userId)
            : null;
      const qr =
        input.method === 'QR' && input.qrToken
          ? this.qr.execute(input.qrToken, input.terminalId)
          : undefined;
      const authorizations = terminal && user ? await tx.findAuthorizations(user.id, terminal.location.id) : [];

      // A espera por um lock nao prolonga a validade da credencial ou da autorizacao.
      const now = this.clock.now();
      const credentialExpired =
        input.method === 'NFC'
          ? !!credential &&
            ((credential.validFrom !== null && now < credential.validFrom) ||
              (credential.validUntil !== null && now >= credential.validUntil))
          : qr?.valid === false && qr.reason === 'expired';
      const credentialValid = input.method === 'NFC' ? !!credential && !credential.revokedAt : qr?.valid === true;

      let decision = decideAccess({
        terminal,
        user,
        authorizations,
        credentialValid,
        credentialExpired,
        method: input.method,
        position: input.position,
        now,
      });
      if (decision.authorizationId && !(await tx.consumeAuthorization(decision.authorizationId, now))) {
        decision = { ...decision, action: 'deny', reason: 'NO_USES_LEFT', authorizationId: null };
      }

      const event = await tx.record({
        id: input.id,
        terminalId: input.terminalId,
        occurredAt: now.toISOString(),
        method: input.method,
        decision: decision.action === 'open' ? 'GRANTED' : 'DENIED',
        reason: decision.action === 'open' ? null : (decision.reason as AccessRecord['reason']),
        user,
        location: terminal ? { id: terminal.location.id, name: terminal.location.name } : null,
        authorizationId: decision.authorizationId,
        credentialId: credential?.id ?? null,
        distanceMeters: decision.distanceMeters,
        latitude: input.position?.latitude ?? null,
        longitude: input.position?.longitude ?? null,
      });

      if (event.decision === 'GRANTED') {
        await tx.saveCommand(
          {
            v: CONTRACT_VERSION,
            messageId: this.ids.uuid(),
            terminalId: input.terminalId,
            timestamp: event.occurredAt,
            commandId: this.ids.uuid(),
            expiresAt: new Date(Date.parse(event.occurredAt) + COMMAND_TTL_MS).toISOString(),
            action: 'open',
            reason: 'authorized',
          },
          input.id,
        );
      }
      return event;
    });
  }
}
