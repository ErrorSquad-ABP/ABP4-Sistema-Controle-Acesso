/** Logger JSON minimo (uma linha por evento, legivel em Vercel/Render/Docker). */
export const LOG_LEVELS = ['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'] as const;
export type LogLevel = (typeof LOG_LEVELS)[number];
type EmitLevel = Exclude<LogLevel, 'silent'>;

export interface Logger {
  error(msg: string, meta?: Record<string, unknown>): void;
  warn(msg: string, meta?: Record<string, unknown>): void;
  info(msg: string, meta?: Record<string, unknown>): void;
  debug(msg: string, meta?: Record<string, unknown>): void;
}

export function createLogger(level: LogLevel): Logger {
  const threshold = LOG_LEVELS.indexOf(level);
  const log = (lvl: EmitLevel, msg: string, meta?: Record<string, unknown>) => {
    if (LOG_LEVELS.indexOf(lvl) > threshold || level === 'silent') return;
    const line = JSON.stringify({ level: lvl, time: new Date().toISOString(), msg, ...meta });
    (lvl === 'error' || lvl === 'fatal' ? process.stderr : process.stdout).write(`${line}\n`);
  };
  return {
    error: (msg, meta) => log('error', msg, meta),
    warn: (msg, meta) => log('warn', msg, meta),
    info: (msg, meta) => log('info', msg, meta),
    debug: (msg, meta) => log('debug', msg, meta),
  };
}
