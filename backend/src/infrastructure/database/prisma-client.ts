import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../generated/prisma/client.js';

export interface PrismaPoolLimits {
  max: number;
  applicationName: string;
  connectionTimeoutMillis: number;
}

/**
 * Prisma 7 exige o driver adapter; o pooler do Neon exige a URL `-pooler`.
 * Sem `limits`, vale o padrao do pg (max 10): so para testes e scripts (DT-14).
 */
export function createPrismaClient(connectionString: string, limits?: PrismaPoolLimits): PrismaClient {
  const pool = limits
    ? {
        max: limits.max,
        application_name: limits.applicationName,
        connectionTimeoutMillis: limits.connectionTimeoutMillis,
        idleTimeoutMillis: 10_000,
      }
    : {};
  return new PrismaClient({ adapter: new PrismaPg({ connectionString, ...pool }) });
}
