/**
 * Retencao do `ProcessedAccessMessage` (DT-15). O worker rejeita por frescor
 * antes de deduplicar (`isFreshAccessEvent`: ate 30 s de idade e 5 s no
 * futuro), entao uma retransmissao QoS 1 so chega a deduplicacao ate ~35 s
 * depois da primeira entrega. 24 h e mais de 2000x essa janela e absorve
 * qualquer desvio de relogio entre terminal, workers e banco.
 *
 * Apagar depois disso nao reabre acesso: a mesma mensagem ja seria descartada
 * como antiga antes de consultar a tabela.
 */
export const DEDUP_RETENTION_MS = 24 * 60 * 60_000;

/** Lote por DELETE: mantem a transacao curta e o indice de `processedAt` barato. */
export const DEDUP_PURGE_BATCH_SIZE = 500;

/** Teto por execucao: um backlog grande nao trava o processo do worker. */
export const DEDUP_PURGE_MAX_BATCHES = 10;

/** Intervalo do expurgo periodico no worker (uma vez por dia). */
export const DEDUP_PURGE_INTERVAL_MS = 24 * 60 * 60_000;
