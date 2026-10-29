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
  ACCESS_MODE: z.enum(['real', 'demo']).default('real'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z.enum(LOG_LEVELS).default('info'),
  APP_VERSION: optionalString,
  MQTT_URL: z
    .string()
    .regex(/^mqtts?:\/\/\S+$/, 'deve comecar com mqtt:// ou mqtts://')
    .default('mqtt://localhost:1884'),
  MQTT_USERNAME: optionalString,
  MQTT_PASSWORD: optionalString,
  QR_TOKEN_SECRET: z.string().regex(/^[A-Fa-f0-9]{64,}$/, 'deve ser hexadecimal com pelo menos 32 bytes aleatorios (64 caracteres)'),
  SIM_TERMINAL_ID: z.string().regex(TERMINAL_ID_PATTERN).default('terminal-01'),
  SIM_NFC_UID: z
    .string()
    .regex(/^[0-9A-F]{4,20}$/, 'deve ser hexadecimal maiusculo (4 a 20 caracteres)')
    .default('04A1B2C3'),
  /** Postgres (Neon em producao, compose no dev). Ausente = /health reporta not_configured. */
  DATABASE_URL: z
    .string()
    .trim()
    .transform((v) => v || undefined)
    .refine(
      (v) => v === undefined || /^postgres(ql)?:\/\/\S+$/.test(v),
      'deve comecar com postgres:// ou postgresql://',
    )
    .optional(),
  /** Segredo do JWT HS256. O default so vale fora de producao (guarda no composition-root). */
  JWT_SECRET: z
    .string()
    .min(32, 'JWT_SECRET precisa de pelo menos 32 caracteres')
    .default('dev-only-secret-nao-use-em-producao-32'),
  JWT_TTL_SECONDS: z.coerce.number().int().min(60).max(86_400).default(3600),
  /** URL publica do web service no Render; habilita o self-ping de keep-alive. */
  RENDER_EXTERNAL_URL: z
    .string()
    .trim()
    .transform((v) => v || undefined)
    .refine(
      (v) => v === undefined || /^https?:\/\/\S+$/.test(v),
      'deve ser uma URL http(s)',
    )
    .optional(),
  /**
   * Proxies confiaveis a frente do app (1 na Vercel/Render). 0 desliga: sem proxy,
   * confiar no X-Forwarded-For deixaria o cliente escolher a chave do rate limit.
   */
  TRUST_PROXY: z.coerce.number().int().min(0).max(10).default(0),
  /**
   * Intervalo do relay da outbox de comandos (DT-13). A consulta e leve e o comando
   * vale 10 s: 5 s deixa duas tentativas dentro do prazo sem manter o Neon acordado
   * a cada segundo (~12 SELECTs/min por replica do worker).
   */
  COMMAND_RELAY_INTERVAL_MS: z.coerce.number().int().min(500).max(60_000).default(5_000),
  /**
   * Janela de operacao do relay (DT-21). Fora dela o worker nao consulta o banco,
   * para o Neon poder suspender: o polling 24/7 estoura o free tier.
   */
  RELAY_WINDOW_ENABLED: z
    .enum(['true', 'false'])
    .default('true')
    .transform((value) => value === 'true'),
  RELAY_WINDOW_START: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'use HH:mm (00:00 a 23:59)')
    .default('18:45'),
  RELAY_WINDOW_END: z
    .string()
    .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'use HH:mm (00:00 a 23:59)')
    .default('23:05'),
  RELAY_WINDOW_TZ: z.string().default('America/Sao_Paulo'),
}).superRefine((env, ctx) => {
  if (env.NODE_ENV === 'production' && env.ACCESS_MODE === 'demo') {
    ctx.addIssue({ code: 'custom', path: ['ACCESS_MODE'], message: 'demo e proibido em production' });
  }
  if (env.RELAY_WINDOW_START === env.RELAY_WINDOW_END) {
    ctx.addIssue({
      code: 'custom',
      path: ['RELAY_WINDOW_END'],
      message: 'inicio e fim iguais deixam o relay sempre parado',
    });
  }
  try {
    new Intl.DateTimeFormat('en-GB', { timeZone: env.RELAY_WINDOW_TZ });
  } catch {
    ctx.addIssue({ code: 'custom', path: ['RELAY_WINDOW_TZ'], message: 'fuso horario invalido' });
  }
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
