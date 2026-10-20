import type { AccessEventMessage, CommandAction } from '../terminal/messages.js';

export interface AccessDecision {
  readonly action: CommandAction;
  readonly reason: string;
}

/** Decide o que fazer com uma tentativa de acesso do terminal. */
export interface AccessDecider {
  decide(event: AccessEventMessage): Promise<AccessDecision>;
}
