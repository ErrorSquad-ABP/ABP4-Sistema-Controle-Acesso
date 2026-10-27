import { buildContainer } from './composition-root.js';
import { InvalidEnvError, loadEnv, type Env } from './config/env.js';
import { createApp } from './http/app.js';

let env: Env;
try {
  env = loadEnv();
} catch (err) {
  // Fail-fast legivel: sem stack trace para erro de configuracao.
  if (!(err instanceof InvalidEnvError)) throw err;
  process.stderr.write(`${err.message}\n`);
  process.exit(1);
}
const container = buildContainer(env);
const { logger } = container;

const server = createApp(container).listen(env.PORT, () => {
  logger.info('backend no ar', { port: env.PORT, env: env.NODE_ENV });
});

const shutdown = (signal: NodeJS.Signals) => {
  logger.info('encerrando', { signal });
  server.close(() => { void container.close?.().finally(() => process.exit(0)); });
  setTimeout(() => process.exit(1), 10_000).unref();
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
