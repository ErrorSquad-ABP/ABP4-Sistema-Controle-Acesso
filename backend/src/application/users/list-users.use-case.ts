import type { UserAdminRepository, UserListFilters } from '../../domain/ports/user-admin-repository.js';
import { toUserView, type UserView } from '../auth/user-view.js';

export interface UserPage {
  items: UserView[];
  page: number;
  pageSize: number;
  total: number;
}

export class ListUsersUseCase {
  constructor(private readonly users: UserAdminRepository) {}

  async execute(filters: UserListFilters): Promise<UserPage> {
    const { items, total } = await this.users.list(filters);
    return { items: items.map(toUserView), page: filters.page, pageSize: filters.pageSize, total };
  }
}
