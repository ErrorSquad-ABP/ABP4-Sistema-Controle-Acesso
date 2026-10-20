import type { AccessDecider, AccessDecision } from '../../domain/ports/access-decider.js';

/**
 * PROVISORIO (Sprint 1): libera qualquer UID para exercitar o fluxo ponta-a-ponta.
 * A regra real (credencial, janela de uso, local e distancia) entra nas US-19/US-20.
 */
export class AlwaysOpenAccessDecider implements AccessDecider {
  decide(): Promise<AccessDecision> {
    return Promise.resolve({ action: 'open', reason: 'stub_s1_always_open' });
  }
}
