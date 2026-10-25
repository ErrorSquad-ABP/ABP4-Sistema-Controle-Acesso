import { ValidationError } from '../errors/domain-error.js';

export type AuthorizationStatus = 'SCHEDULED' | 'ACTIVE' | 'EXPIRED' | 'CANCELED';

export interface AuthorizationFacts {
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  usedCount: number;
  canceledAt: Date | null;
}

/** Situação derivada dos fatos da autorização, conforme o modelo de dados. */
export function authorizationStatus(facts: AuthorizationFacts, now: Date): AuthorizationStatus {
  if (facts.canceledAt) return 'CANCELED';
  if (facts.usedCount >= facts.maxUses || now.getTime() > facts.endsAt.getTime()) return 'EXPIRED';
  if (now.getTime() < facts.startsAt.getTime()) return 'SCHEDULED';
  return 'ACTIVE';
}

export function validateAuthorizationPeriod(startsAt: Date, endsAt: Date, maxUses: number): void {
  if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime())) {
    throw new ValidationError('Periodo da autorizacao invalido');
  }
  if (endsAt.getTime() <= startsAt.getTime()) {
    throw new ValidationError('`endsAt` deve ser posterior a `startsAt`', { endsAt: ['Deve ser posterior a startsAt'] });
  }
  if (!Number.isInteger(maxUses) || maxUses < 1 || maxUses > 1000) {
    throw new ValidationError('`maxUses` deve ser um inteiro entre 1 e 1000', { maxUses: ['Valor invalido'] });
  }
}
