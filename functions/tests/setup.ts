/**
 * 🛠️ GLOBAL TEST SETUP & EMULATOR / IN-MEMORY HOOKS
 *
 * Configures deterministic environment variables, installs in-memory Firestore
 * and Firebase Auth mocks, and resets database state between test runs.
 */

import * as dotenv from 'dotenv';
import * as path from 'path';

// Load .env.test before anything else
dotenv.config({ path: path.resolve(__dirname, '../.env.test') });

process.env.NODE_ENV = 'test';
process.env.CASHFREE_ENV = 'SANDBOX';
process.env.CASHFREE_APP_ID = 'TEST_APP_ID_FOR_AUTOMATED_TESTS';
process.env.CASHFREE_SECRET_KEY = 'test_mock_secret_key_truthworld_12345';
process.env.GCLOUD_PROJECT = 'truthworld-test-safe';
process.env.PROJECT_ID = 'truthworld-test-safe';

import * as admin from 'firebase-admin';
import { testFirestore, FieldValue, Timestamp } from './helpers/mockFirestore';
import { decodeMockToken } from './helpers/authHelper';

// Ensure Firebase Admin is initialized in test mode
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'truthworld-test-safe',
  });
}

// Global Custom User Claims Registry for Auth tests
export const mockClaimsStore = new Map<string, Record<string, any>>();

// Mock Auth replacement object
export const mockAuth = {
  verifyIdToken: jest.fn(async (token: string) => {
    if (token === 'expired_token' || token.includes('expired')) {
      const err: any = new Error('Firebase ID token has expired.');
      err.code = 'auth/id-token-expired';
      throw err;
    }
    if (token === 'malformed_token' || token.includes('malformed')) {
      const err: any = new Error('Decoding Firebase ID token failed.');
      err.code = 'auth/argument-error';
      throw err;
    }
    if (token === 'invalid_signature_token' || token.includes('invalid_sig')) {
      const err: any = new Error('Firebase ID token has invalid signature.');
      err.code = 'auth/invalid-argument';
      throw err;
    }

    const decoded = decodeMockToken(token);
    if (decoded) {
      const existingClaims = mockClaimsStore.get(decoded.uid) || {};
      return {
        uid: decoded.uid,
        email: decoded.email,
        email_verified: decoded.email_verified ?? true,
        admin: existingClaims.admin ?? decoded.admin ?? false,
        role: existingClaims.role ?? decoded.role ?? 'user',
        auth_time: decoded.auth_time ?? Math.floor(Date.now() / 1000),
      };
    }

    // Default fallback for general valid test tokens
    return {
      uid: 'mock_test_uid',
      email: 'test@truthworld.test',
      email_verified: true,
      admin: false,
      role: 'user',
      auth_time: Math.floor(Date.now() / 1000),
    };
  }),

  setCustomUserClaims: jest.fn(async (uid: string, claims: Record<string, any>) => {
    mockClaimsStore.set(uid, claims);
  }),

  getUser: jest.fn(async (uid: string) => ({
    uid,
    email: `${uid}@truthworld.test`,
    disabled: false,
    customClaims: mockClaimsStore.get(uid) || {},
  })),
};

// Mock Storage bucket
export const mockFile = {
  exists: jest.fn(async () => [true]),
  download: jest.fn(async () => [Buffer.from('<html><head><title>TruthWorld</title></head><body></body></html>')]),
  save: jest.fn(async () => {}),
};

export const mockBucket = {
  file: jest.fn(() => mockFile),
};

// Use jest.spyOn for getter properties
const firestoreSpy = jest.spyOn(admin, 'firestore').mockReturnValue(testFirestore as any);
(admin.firestore as any).FieldValue = FieldValue;
(admin.firestore as any).Timestamp = Timestamp;

jest.spyOn(admin, 'auth').mockReturnValue(mockAuth as any);
jest.spyOn(admin, 'storage').mockReturnValue({
  bucket: jest.fn(() => mockBucket),
} as any);
jest.spyOn(admin, 'appCheck').mockReturnValue({
  verifyToken: jest.fn(async (token: string) => {
    if (token === 'invalid_app_check_token') {
      throw new Error('Invalid App Check token.');
    }
    return { appId: 'truthworld-test-app', token };
  }),
} as any);

// Reset database and mock state before each test
beforeEach(() => {
  testFirestore.clear();
  mockClaimsStore.clear();
  jest.clearAllMocks();
  firestoreSpy.mockReturnValue(testFirestore as any);
  (admin.firestore as any).FieldValue = FieldValue;
  (admin.firestore as any).Timestamp = Timestamp;
});

afterAll(() => {
  testFirestore.clear();
  mockClaimsStore.clear();
});
