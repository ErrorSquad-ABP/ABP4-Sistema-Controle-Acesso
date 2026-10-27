import type { AccessEventMessage, CommandAction } from '../terminal/messages.js';

export interface AccessDecision {
  readonly action: CommandAction;
  readonly reason: string;
  /**
   * Instante da decisao. Ancora o prazo do comando (DT-02): repetir a publicacao
   * depois da janela nao cria um prazo novo, apenas deixa de abrir.
   */
  readonly decidedAt: Date;
}

/** Decide o que fazer com uma tentativa de acesso do terminal. */
export interface AccessDecider {
  decide(event: AccessEventMessage): Promise<AccessDecision>;
}
