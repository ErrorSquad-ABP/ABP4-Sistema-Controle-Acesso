import { loadEnvOrExit } from './config/load-env-or-exit.js';
import { startWorkerRuntime } from './mqtt/worker-runtime.js';
import { createLogger } from '../shared/logger.js';

/** Entry local do processo MQTT (`npm run mqtt:consumer`). */
const env = loadEnvOrExit();
const logger = createLogger(env.LOG_LEVEL);

const runtime = await startWorkerRuntime(env, logger);

const shutdown = (signal: NodeJS.Signals) => {
  logger.info('encerrando consumidor', { signal });
  runtime.stop().finally(() => process.exit(0));
  setTimeout(() => process.exit(1), 5_000).unref();
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
