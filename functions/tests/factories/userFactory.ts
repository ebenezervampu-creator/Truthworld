/**
 * 🏭 USER FACTORY
 * Creates standardized user fixture documents for tests.
 */

export interface TestUser {
  id: string;
  email: string;
  displayName: string;
  role: 'user' | 'creator' | 'admin' | 'banned';
  accountStatus: 'ACTIVE' | 'SUSPENDED' | 'BANNED' | 'DELETED';
  isBanned?: boolean;
  trustScore?: number;
  strikes?: number;
  hasChannel?: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export function buildUser(overrides: Partial<TestUser> = {}): TestUser {
  const id = overrides.id || `usr_${Math.random().toString(36).substring(2, 9)}`;
  return {
    id,
    email: overrides.email || `${id}@truthworld.test`,
    displayName: overrides.displayName || `User ${id}`,
    role: overrides.role || 'user',
    accountStatus: overrides.accountStatus || 'ACTIVE',
    trustScore: overrides.trustScore ?? 100,
    strikes: overrides.strikes ?? 0,
    hasChannel: overrides.hasChannel ?? false,
    createdAt: overrides.createdAt || new Date().toISOString(),
    updatedAt: overrides.updatedAt || new Date().toISOString(),
    ...overrides,
  };
}
