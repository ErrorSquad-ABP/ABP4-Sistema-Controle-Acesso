import type { Clock } from '../../domain/ports/clock.js';
import type { DatabaseProbe } from '../../domain/ports/database-probe.js';
import type { Logger } from '../../shared/logger.js';

// CASO DE USO MODELO — guia em docs/architecture/caso-de-uso-modelo.md

/** O /health e publico: o resultado do banco e reaproveitado por alguns segundos para que
 * chamadas em rajada nao virem consultas (nem mantenham o Neon acordado). */
const DATABASE_CACHE_MS = 5000;

export type DatabaseStatus = 'ok' | 'unavailable' | 'not_configured';

export interface CheckHealthOutput {
  /** `error` quando o banco esta configurado mas nao responde. */
  status: 'ok' | 'error';
  version: string;
  uptimeSeconds: number;
  timestamp: string;
  database: DatabaseStatus;
}

export class CheckHealthUseCase {
  private cachedDatabase: { status: DatabaseStatus; at: number } | undefined;

  constructor(
    private readonly clock: Clock,
    private readonly startedAt: Date,
    private readonly version: string,
    private readonly database: DatabaseProbe | undefined,
    private readonly logger: Logger,
  ) {}

  async execute(): Promise<CheckHealthOutput> {
    const now = this.clock.now();
    const database = await this.databaseStatus(now);
    return {
      status: database === 'unavailable' ? 'error' : 'ok',
      version: this.version,
      uptimeSeconds: Math.max(0, Math.floor((now.getTime() - this.startedAt.getTime()) / 1000)),
      timestamp: now.toISOString(),
      database,
    };
  }

  private async databaseStatus(now: Date): Promise<DatabaseStatus> {
    const cached = this.cachedDatabase;
    if (cached && now.getTime() - cached.at < DATABASE_CACHE_MS) return cached.status;
    const status = await this.checkDatabase();
    this.cachedDatabase = { status, at: now.getTime() };
    return status;
  }

  private async checkDatabase(): Promise<DatabaseStatus> {
    if (!this.database) return 'not_configured';
    try {
      await this.database.ping();
      return 'ok';
    } catch (err) {
      // Detalhe so no log: a resposta publica nunca expoe host/credencial.
      this.logger.error('banco indisponivel', {
        error: err instanceof Error ? err.message : String(err),
      });
      return 'unavailable';
    }
  }
}
