import { createServer } from 'node:http';
import { createLogger } from '../shared/logger.js';
import { loadEnvOrExit } from './config/load-env-or-exit.js';
import { createKeepAlive, scheduleKeepAlive, systemScheduler } from './mqtt/keep-alive.js';
import { startWorkerRuntime, type WorkerRuntime } from './mqtt/worker-runtime.js';

/**
 * Entry do Render (US-37): mantem o processo MQTT vivo e expoe /healthz.
 * O plano free dorme sem trafego HTTP, por isso o self-ping a cada 10 min.
 */
const env = loadEnvOrExit();
const logger = createLogger(env.LOG_LEVEL);

// O health sobe antes do runtime; ate la nao ha expurgo para mostrar.
const booted: { runtime?: WorkerRuntime } = {};
const health = createServer((req, res) => {
  if (req.url === '/healthz') {
    // DT-15: valor em memoria; o self-ping de 10 min nao gera consulta e o Neon pode suspender.
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', dedupPurge: booted.runtime?.dedupPurge() ?? null }));
    return;
  }
  res.writeHead(404).end();
});
health.listen(env.PORT, () => logger.info('health do worker no ar', { port: env.PORT }));

const runtime = await startWorkerRuntime(env, logger);
booted.runtime = runtime;
const stopKeepAlive = env.RENDER_EXTERNAL_URL
  ? scheduleKeepAlive(
      createKeepAlive({ url: env.RENDER_EXTERNAL_URL, fetchImpl: fetch, logger }),
      systemScheduler,
    )
  : undefined;

const shutdown = async (signal: string) => {
  logger.info('encerrando worker', { signal });
  stopKeepAlive?.();
  health.close();
  await runtime.stop();
  process.exit(0);
};
process.on('SIGTERM', (signal) => void shutdown(signal));
process.on('SIGINT', (signal) => void shutdown(signal));
