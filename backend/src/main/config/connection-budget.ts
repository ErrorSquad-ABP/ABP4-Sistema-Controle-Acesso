/**
 * Orcamento de conexoes PostgreSQL por processo (DT-14). Cada instancia
 * serverless da API soma `apiConnectionTotal()` no Neon; o worker roda em
 * instancia unica. Detalhes e concorrencia suportada em docs/guides/deploy.md.
 */
export interface PoolBudget {
  max: number;
  /** Aparece em `pg_stat_activity.application_name`: permite medir cada fonte. */
  applicationName: string;
}

export const API_CONNECTIONS = {
  prisma: { max: 3, applicationName: 'abp4-api-prisma' },
  access: { max: 3, applicationName: 'abp4-api-access' },
  probe: { max: 1, applicationName: 'abp4-api-probe' },
} as const satisfies Record<string, PoolBudget>;

export const WORKER_CONNECTIONS = {
  access: { max: 5, applicationName: 'abp4-worker-access' },
  /** Pool propria: a reserva da deduplicacao nao disputa conexao com a decisao. */
  events: { max: 2, applicationName: 'abp4-worker-events' },
} as const satisfies Record<string, PoolBudget>;

/** Espera maxima por uma conexao livre antes de falhar o pedido. */
export const POOL_CONNECTION_TIMEOUT_MS = 5_000;

/**
 * Teto de espera pela resposta de uma consulta ja enviada. O `pg` aplica no
 * cliente (`query_timeout`) e o Prisma herda pelo driver adapter: o pedido
 * falha mesmo com a consulta parada na fila do pooler. O servidor nao cancela a
 * consulta; `statement_timeout` como parametro de startup quebraria a conexao
 * com o pooler do Neon (parametro de startup nao suportado).
 */
export const POOL_QUERY_TIMEOUT_MS = 4_000;

const total = (budget: Record<string, PoolBudget>) =>
  Object.values(budget).reduce((sum, pool) => sum + pool.max, 0);

export const apiConnectionTotal = () => total(API_CONNECTIONS);
export const workerConnectionTotal = () => total(WORKER_CONNECTIONS);
