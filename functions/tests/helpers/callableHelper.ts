/**
 * 🔌 CALLABLE FUNCTION TEST HELPER
 *
 * Wraps Firebase Cloud Functions v2 onCall handlers for direct
 * invocation in tests without HTTP transport overhead.
 */

import { TEST_USERS, createMockToken } from './authHelper';

export interface CallableContext {
  data: any;
  auth?: {
    uid: string;
    token: Record<string, any>;
  };
}

/**
 * Invokes a Firebase v2 onCall Cloud Function directly in test context.
 * 
 * Firebase v2 onCall functions expose a .run() method that accepts
 * { data, auth } and returns the function's return value.
 * If .run() is not available, falls back to direct invocation.
 */
export async function callOnCall<T = any>(
  fn: any,
  context: CallableContext
): Promise<T> {
  // Firebase v2 onCall functions have a .run() method for testing
  if (typeof fn.run === 'function') {
    return fn.run(context);
  }
  
  // Fallback: try direct invocation (some versions expose the handler)
  if (typeof fn === 'function') {
    return fn(context);
  }
  
  throw new Error('Cannot invoke onCall function: no .run() method or direct handler found');
}

/**
 * Creates an authenticated callable context for a test user.
 */
export function authCallableContext(user: typeof TEST_USERS.regular, data: any = {}): CallableContext {
  return {
    data,
    auth: {
      uid: user.uid,
      token: {
        admin: user.admin,
        role: user.role,
        email: user.email,
        email_verified: user.email_verified,
        auth_time: Math.floor(Date.now() / 1000),
      },
    },
  };
}

/**
 * Creates an unauthenticated callable context.
 */
export function anonCallableContext(data: any = {}): CallableContext {
  return { data };
}
