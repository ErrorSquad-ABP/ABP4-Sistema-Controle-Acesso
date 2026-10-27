import { InvalidEnvError, loadEnv, type Env } from './env.js';

/** Fail-fast legivel nos entry points: configuração invalida nao vira stack trace. */
export function loadEnvOrExit(): Env {
  try {
    return loadEnv();
  } catch (err) {
    if (!(err instanceof InvalidEnvError)) throw err;
    process.stderr.write(`${err.message}\n`);
    process.exit(1);
  }
}
