import { SystemClock } from '../clock/system-clock.js';
import type { AccessDecider, AccessDecision } from '../../domain/ports/access-decider.js';
import type { Clock } from '../../domain/ports/clock.js';

/**
 * Somente demo explicito fora de producao (DT-01). Nunca e fallback de erro.
 * O boot escolhe DatabaseAccessDecider no modo real.
 */
export class AlwaysOpenAccessDecider implements AccessDecider {
  constructor(private readonly clock: Clock = new SystemClock()) {}

  decide(): Promise<AccessDecision> {
    return Promise.resolve({
      action: 'open',
      reason: 'stub_s1_always_open',
      decidedAt: this.clock.now(),
    });
  }
}
