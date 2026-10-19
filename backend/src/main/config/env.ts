import { z } from 'zod';
import { TERMINAL_ID_PATTERN } from '../../shared/terminal-id.js';
import { LOG_LEVELS } from '../../shared/logger.js';

/** String opcional: vazia conta como ausente (`VAR=` no .env). */
const optionalString = z
  .string()
  .trim()
  .transform((v) => v || undefined)
  .optional();

/**
 * Unico ponto do backend que le `process.env`. Variavel nova entra aqui
 * e no `.env.example` — o resto do codigo recebe `Env` ja validado.
 */
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z.enum(LOG_LEVELS).default('info'),
  APP_VERSION: optionalString,
  MQTT_URL: z
    .string()
    .regex(/^mqtts?:\/\/\S+$/, 'deve comecar com mqtt:// ou mqtts://')
    .default('mqtt://localhost:1884'),
  MQTT_USERNAME: optionalString,
  MQTT_PASSWORD: optionalString,
  SIM_TERMINAL_ID: z.string().regex(TERMINAL_ID_PATTERN).default('terminal-01'),
  SIM_NFC_UID: z
    .string()
    .regex(/^[0-9A-F]{4,20}$/, 'deve ser hexadecimal maiusculo (4 a 20 caracteres)')
    .default('04A1B2C3'),
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
