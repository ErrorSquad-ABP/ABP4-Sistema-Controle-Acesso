import { z } from 'zod';
import { LOG_LEVELS } from '../../shared/logger.js';

/**
 * Unico ponto do backend que le `process.env`. Variavel nova entra aqui
 * e no `.env.example` — o resto do codigo recebe `Env` ja validado.
 */
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z.enum(LOG_LEVELS).default('info'),
  APP_VERSION: z
    .string()
    .trim()
    .transform((v) => v || undefined)
    .optional(),
});

export type Env = Readonly<z.infer<typeof envSchema>>;

export class InvalidEnvError extends Error {
  constructor(issues: string) {
    super(`Variaveis de ambiente invalidas:\n${issues}`);
    this.name = 'InvalidEnvError';
  }
}

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = envSchema.safeParse(source);
  if (!parsed.success) {
    throw new InvalidEnvError(z.prettifyError(parsed.error));
  }
  return Object.freeze(parsed.data);
}
