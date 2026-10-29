import { PrismaPg } from '@prisma/adapter-pg';
import type { PoolConfig } from 'pg';
import { PrismaClient } from '../../generated/prisma/client.js';

export interface PrismaPoolLimits {
  max: number;
  applicationName: string;
  connectionTimeoutMillis: number;
  queryTimeoutMillis: number;
}

/**
 * Prisma 7 exige o driver adapter; o pooler do Neon exige a URL `-pooler`.
 * O adapter aceita o `PoolConfig` do `pg` e repassa tudo ao `new pg.Pool`, entao
 * `query_timeout` tambem vale para as consultas do Prisma (DT-14). Sem `limits`,
 * vale o padrao do pg (max 10): so para testes e scripts.
 */
export function prismaPoolOptions(connectionString: string, limits?: PrismaPoolLimits): PoolConfig {
  if (!limits) return { connectionString };
  return {
    connectionString,
    max: limits.max,
    application_name: limits.applicationName,
    connectionTimeoutMillis: limits.connectionTimeoutMillis,
    query_timeout: limits.queryTimeoutMillis,
    idleTimeoutMillis: 10_000,
  };
}

export function createPrismaClient(connectionString: string, limits?: PrismaPoolLimits): PrismaClient {
  return new PrismaClient({ adapter: new PrismaPg(prismaPoolOptions(connectionString, limits)) });
}
