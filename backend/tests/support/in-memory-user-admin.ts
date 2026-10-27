import { randomUUID } from 'node:crypto';
import type {
  NewUserRecord,
  UserAdminRepository,
  UserChanges,
  UserListFilters,
} from '../../src/domain/ports/user-admin-repository.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';

export class InMemoryUserAdminRepository implements UserAdminRepository {
  private readonly users: UserRecord[];

  constructor(users: UserRecord[] = []) {
    this.users = [...users];
  }

  async findByEmail(email: string): Promise<UserRecord | null> {
    return this.users.find((user) => user.email === email.toLowerCase()) ?? null;
  }

  async findById(id: string): Promise<UserRecord | null> {
    return this.users.find((user) => user.id === id) ?? null;
  }

  async list(filters: UserListFilters): Promise<{ items: UserRecord[]; total: number }> {
    const search = filters.search?.toLowerCase();
    const filtered = this.users
      .filter((user) => !filters.role || user.role === filters.role)
      .filter((user) => filters.active === undefined || user.active === filters.active)
      .filter(
        (user) => !search || user.name.toLowerCase().includes(search) || user.email.toLowerCase().includes(search),
      )
      .sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));

    const start = (filters.page - 1) * filters.pageSize;
    return { items: filtered.slice(start, start + filters.pageSize), total: filtered.length };
  }

  async create(user: NewUserRecord): Promise<UserRecord> {
    const now = new Date();
    const created: UserRecord = {
      id: randomUUID(),
      ...user,
      email: user.email.toLowerCase(),
      active: true,
      createdAt: now,
      updatedAt: now,
    };
    this.users.push(created);
    return created;
  }

  async update(id: string, changes: UserChanges): Promise<UserRecord | null> {
    const index = this.users.findIndex((user) => user.id === id);
    const current = this.users[index];
    if (index < 0 || !current) return null;

    const updated: UserRecord = {
      ...current,
      name: changes.name ?? current.name,
      email: (changes.email ?? current.email).toLowerCase(),
      passwordHash: changes.passwordHash ?? current.passwordHash,
      role: changes.role ?? current.role,
      active: changes.active ?? current.active,
      updatedAt: new Date(),
    };
    this.users[index] = updated;
    return updated;
  }
}
