/**
 * Retencao do `TerminalCommand` (DT-18). O prazo do comando e de 10 s
 * (`COMMAND_TTL_MS`), mas a linha guarda o payload publicado, o resultado do
 * ACK e a correlacao usada pelo worker: 7 dias cobrem ACK tardio, investigacao
 * de uma tentativa e uma janela folgada de margem de relogio entre processos.
 *
 * Apagar depois disso nao reabre acesso: a idempotencia vem do `AccessEvent`
 * (mesmo id da tentativa) e o `expiresAt` do comando e ancorado no instante da
 * decisao, entao republicar depois da janela devolve `published: false`.
 */
export const COMMAND_RETENTION_MS = 7 * 24 * 60 * 60_000;

/** Lote por DELETE: mantem a transacao curta e o indice de `expiresAt` barato. */
export const COMMAND_PURGE_BATCH_SIZE = 500;

/** Teto por execucao: um dia de backlog nao trava o processo do worker. */
export const COMMAND_PURGE_MAX_BATCHES = 10;

/** Intervalo do expurgo periodico no worker (uma vez por dia). */
export const COMMAND_PURGE_INTERVAL_MS = 24 * 60 * 60_000;
