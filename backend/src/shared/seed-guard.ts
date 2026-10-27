/** Hosts que contam como banco local: o compose do dev e o Postgres efemero do CI. */
const LOCAL_DB_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '[::1]', 'postgres']);

/** E-mails da seed demo: contas com senha publica, proibidas no provisionamento real. */
export const DEMO_EMAIL_DOMAIN = '@abp4.local';

const MIN_ADMIN_PASSWORD_LENGTH = 12;

export class SeedRefusedError extends Error {
  constructor(reason: string) {
    super(`Seed recusada: ${reason}`);
    this.name = 'SeedRefusedError';
  }
}

type EnvSource = Readonly<Record<string, string | undefined>>;

function isProduction(env: EnvSource): boolean {
  return env['NODE_ENV'] === 'production' || env['VERCEL_ENV'] === 'production';
}

function databaseHost(databaseUrl: string): string {
  try {
    return new URL(databaseUrl).hostname.toLowerCase();
  } catch {
    throw new SeedRefusedError('DATABASE_URL nao e uma URL valida.');
  }
}

/**
 * Libera a seed de demonstracao (contas com senha publica, dados ficticios).
 * Producao nunca passa; banco remoto so com `ALLOW_DEMO_SEED=true` explicito.
 * Devolve a `DATABASE_URL` validada.
 */
export function assertDemoSeedAllowed(env: EnvSource): string {
  if (isProduction(env)) {
    throw new SeedRefusedError(
      'a seed de demonstracao nao roda em producao (NODE_ENV/VERCEL_ENV=production). ' +
        'Use `npm run db:provision` para criar o primeiro administrador.',
    );
  }

  const databaseUrl = env['DATABASE_URL']?.trim();
  if (!databaseUrl) {
    throw new SeedRefusedError('DATABASE_URL precisa estar configurada.');
  }

  const host = databaseHost(databaseUrl);
  if (!LOCAL_DB_HOSTS.has(host) && env['ALLOW_DEMO_SEED'] !== 'true') {
    throw new SeedRefusedError(
      `o banco "${host}" nao e local. A seed grava senhas publicas e reativa contas; ` +
        'se for mesmo um banco descartavel, repita com ALLOW_DEMO_SEED=true.',
    );
  }

  return databaseUrl;
}

export interface ProvisionConfig {
  readonly databaseUrl: string;
  readonly adminName: string;
  readonly adminEmail: string;
  readonly adminPassword: string;
}

/**
 * Le e valida os dados do primeiro administrador. Roda em qualquer ambiente,
 * inclusive producao, porque a senha vem do operador e nao esta no repositorio.
 */
export function parseProvisionConfig(env: EnvSource): ProvisionConfig {
  const databaseUrl = env['DATABASE_URL']?.trim();
  if (!databaseUrl) {
    throw new SeedRefusedError('DATABASE_URL precisa estar configurada.');
  }
  databaseHost(databaseUrl);

  const adminName = env['ADMIN_NAME']?.trim() || 'Administrador';
  const adminEmail = env['ADMIN_EMAIL']?.trim().toLowerCase();
  const adminPassword = env['ADMIN_PASSWORD'];

  if (!adminEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(adminEmail)) {
    throw new SeedRefusedError('ADMIN_EMAIL precisa ser um e-mail valido.');
  }
  if (adminEmail.endsWith(DEMO_EMAIL_DOMAIN)) {
    throw new SeedRefusedError(`ADMIN_EMAIL nao pode usar o dominio de demonstracao (${DEMO_EMAIL_DOMAIN}).`);
  }
  if (!adminPassword || adminPassword.length < MIN_ADMIN_PASSWORD_LENGTH) {
    throw new SeedRefusedError(`ADMIN_PASSWORD precisa ter ao menos ${MIN_ADMIN_PASSWORD_LENGTH} caracteres.`);
  }

  return { databaseUrl, adminName, adminEmail, adminPassword };
}
