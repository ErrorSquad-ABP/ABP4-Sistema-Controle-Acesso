import type { Authorization, AuthorizationStatus } from '../../domain/authorizations/authorization.js';
import { presentAuthorization } from '../../domain/authorizations/authorization.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { AuthorizationRepository } from '../../domain/ports/authorization-repository.js';

export interface ListAuthorizationsInput {
  userId?: string;
  locationId?: string;
  status?: AuthorizationStatus;
  from?: Date;
  to?: Date;
  page: number;
  pageSize: number;
}
export interface ListAuthorizationsOutput {
  items: Authorization[];
  page: number;
  pageSize: number;
  total: number;
}

export class ListAuthorizationsUseCase {
  constructor(private readonly repository: AuthorizationRepository, private readonly clock: Clock) {}

  async execute(input: ListAuthorizationsInput): Promise<ListAuthorizationsOutput> {
    const now = this.clock.now();
    const result = await this.repository.list({ ...input, now });
    return { ...result, items: result.items.map((record) => presentAuthorization(record, now)), page: input.page, pageSize: input.pageSize };
  }
}
