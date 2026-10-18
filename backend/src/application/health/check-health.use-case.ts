import type { Clock } from '../../domain/ports/clock.js';

// CASO DE USO MODELO — guia em docs/architecture/caso-de-uso-modelo.md

export interface CheckHealthOutput {
  status: 'ok';
  version: string;
  uptimeSeconds: number;
  timestamp: string;
}

export class CheckHealthUseCase {
  constructor(
    private readonly clock: Clock,
    private readonly startedAt: Date,
    private readonly version: string,
  ) {}

  execute(): CheckHealthOutput {
    const now = this.clock.now();
    return {
      status: 'ok',
      version: this.version,
      uptimeSeconds: Math.max(0, Math.floor((now.getTime() - this.startedAt.getTime()) / 1000)),
      timestamp: now.toISOString(),
    };
  }
}
