/**
 * 🔐 AUTHENTICATION & AUTHORIZATION TEST HELPERS
 *
 * Provides reusable mock tokens, identity configurations,
 * and auth verification stubs for testing protected endpoints.
 */

export interface MockTokenPayload {
  uid: string;
  email: string;
  email_verified?: boolean;
  admin?: boolean;
  role?: string;
  auth_time?: number;
}

export const TEST_USERS = {
  regular: {
    uid: "test_user_regular_101",
    email: "regular@truthworld.test",
    email_verified: true,
    admin: false,
    role: "user",
  },
  admin: {
    uid: "test_admin_super_999",
    email: "admin@truthworld.test",
    email_verified: true,
    admin: true,
    role: "admin",
  },
  creator: {
    uid: "test_creator_channel_505",
    email: "creator@truthworld.test",
    email_verified: true,
    admin: false,
    role: "creator",
  },
  victim: {
    uid: "test_victim_user_301",
    email: "victim@truthworld.test",
    email_verified: true,
    admin: false,
    role: "user",
  },
  attacker: {
    uid: "test_attacker_user_302",
    email: "attacker@truthworld.test",
    email_verified: true,
    admin: false,
    role: "user",
  },
};

/**
 * Creates a deterministic mock token string for a user payload.
 */
export function createMockToken(payload: Partial<MockTokenPayload> & { uid: string }): string {
  const fullPayload: MockTokenPayload = {
    email: `${payload.uid}@truthworld.test`,
    email_verified: true,
    admin: false,
    role: "user",
    auth_time: Math.floor(Date.now() / 1000),
    ...payload,
  };
  return `mock_token_${Buffer.from(JSON.stringify(fullPayload)).toString("base64")}`;
}

/**
 * Creates standard HTTP Authorization header.
 */
export function authHeader(tokenOrUser: string | Partial<MockTokenPayload> & { uid: string }): {
  authorization: string;
} {
  const token = typeof tokenOrUser === "string" ? tokenOrUser : createMockToken(tokenOrUser);
  return { authorization: `Bearer ${token}` };
}

/**
 * Parses a mock token back to payload if it follows the mock_token_ pattern.
 */
export function decodeMockToken(token: string): MockTokenPayload | null {
  if (!token || !token.startsWith("mock_token_")) return null;
  try {
    const raw = Buffer.from(token.replace("mock_token_", ""), "base64").toString("utf8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}
