import type { Clock } from '../../domain/ports/clock.js';
import type { AccessRepository } from '../../domain/ports/access-repository.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import { hashCredential } from '../../shared/credential-hash.js';

export const NFC_CREDENTIAL_TTL_MS = 60_000;

export interface NfcCredentialIssued {
  token: string;
  expiresAt: string;
}

/**
 * Emite uma prova efemera para o NFC do celular. O banco guarda so o hash;
 * o texto em claro existe apenas na resposta e no cache em memoria do app.
 */
export class IssueNfcCredentialUseCase {
  constructor(
    private readonly repository: AccessRepository,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
  ) {}

  async execute(userId: string): Promise<NfcCredentialIssued> {
    const now = this.clock.now();
    const token = this.ids.uuid().replace(/-/g, '').toLowerCase();
    const validUntil = new Date(now.getTime() + NFC_CREDENTIAL_TTL_MS);
    await this.repository.saveNfcCredential({
      userId,
      valueHash: hashCredential(token),
      validFrom: now,
      validUntil,
    });
    return { token, expiresAt: validUntil.toISOString() };
  }
}
