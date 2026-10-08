# 🧪 TruthWorld Backend Automated Testing System

This document outlines the testing architecture, methodology, directory organization, and execution procedures for the TruthWorld Cloud Functions (Node.js/TypeScript) backend.

---

## 🏗️ 1. Testing Stack

The testing ecosystem is built on modern, battle-tested tools configured for high execution speed, isolation, zero flaky tests, and complete determinism:

| Tool | Purpose |
|---|---|
| **Jest & ts-jest** | Test runner, TypeScript compilation in memory, assertions, and test isolation. |
| **Supertest** | Real HTTP integration testing for Cloud Functions `onRequest` handlers and Express routers. |
| **InMemoryFirestore** | High-fidelity, zero-dependency in-memory Firestore engine for deterministic unit & integration tests with zero risk to production data. |
| **k6 & Runner** | Concurrent Virtual User (VU) load simulations with P95/P99 latency percentile validation and SLA verification. |
| **dotenv** | Isolated `.env.test` environment variable configuration. |
| **V8 Coverage Engine** | Comprehensive line, statement, and branch coverage reporting. |

---

## 📁 2. Test Directory Organization

```
functions/
├── .env.test                         # Test environment configuration
├── jest.config.js                    # Jest & ts-jest test runner configuration
├── tests/
│   ├── setup.ts                      # Global environment bootstrap, in-memory DB hooks & mock resets
│   ├── helpers/                      # Reusable test utilities
│   │   ├── mockFirestore.ts          # In-memory Firestore harness (CRUD, where, orderBy, pagination, transactions)
│   │   ├── authHelper.ts             # Deterministic mock tokens (admin, regular, creator, expired, malformed)
│   │   └── testServer.ts             # Express test wrapper for Supertest with rawBody preservation
│   ├── factories/                    # Standardized test data generators
│   │   ├── userFactory.ts            # Builds test users and roles
│   │   ├── videoFactory.ts           # Builds test videos and metadata
│   │   ├── orderFactory.ts           # Builds honest-priced payment orders
│   │   └── commentFactory.ts         # Builds nested & flat comment documents
│   ├── fixtures/                     # Static payloads & HMAC signatures
│   │   └── payloads.ts               # Sample webhook events & moderation payloads
│   ├── unit/                         # Layer 1: Unit tests
│   │   ├── auth.test.ts              # verifyAuth, requireAuth, requireAdmin, step-up auth
│   │   ├── cashfreeService.test.ts   # Cashfree PG service logic, HMAC signature, sanitizers
│   │   ├── searchBackend.test.ts     # In-house vector/keyword search, ranking, LRU cache
│   │   ├── securityHeaders.test.ts   # OWASP enterprise security headers & session timing
│   │   ├── validators.test.ts        # Zod schemas, HTML/XSS sanitization, honest pricing
│   │   └── idempotency.test.ts       # Idempotent execution & duplicate event prevention
│   ├── api/                          # Layer 2: API & Integration tests
│   │   ├── publicFeedServer.test.ts  # GET /api/feed, /trending, query filters, limit bounds
│   │   ├── cashfreeWebhook.test.ts   # POST /cashfreeWebhook, HMAC auth, replay protection
│   │   └── userManagement.test.ts    # POST /moderateUser, RBAC, step-up auth, audit logging
│   ├── auth/                         # Layer 3: Authentication and authorization tests
│   │   └── auth_authorization.test.ts# Token integrity, RBAC, auto-provisioning claims, IDOR
│   ├── database/                     # Layer 4: Dedicated test database tests
│   │   └── firestore_operations.test.ts# CRUD, indexing, pagination, sorting, transaction rollback
│   ├── edge-cases/                   # Layer 5: Negative & edge-case resilience tests
│   │   └── negative_edge_cases.test.ts# Missing fields, wrong types, extreme limits, invalid IDs
│   ├── external/                     # Layer 6: External service tests
│   │   └── external_services.test.ts # Payment gateways, storage mocks, timeout handling
│   ├── payment/                      # Layer 7: Payment lifecycle tests
│   │   └── payment_lifecycle.test.ts # Order creation, payment fulfillment, duplicate webhooks
│   ├── reliability/                  # Layer 8: Reliability & error sanitization tests
│   │   └── reliability_resilience.test.ts # DB outages, timeouts, Zero Raw Developer Error policy
│   ├── security/                     # Layer 9: Security-focused automated audit tests
│   │   └── security_guard.test.ts    # Injection defense, header spoofing, sensitive field scrubbing
│   ├── smoke/                        # Layer 11: Smoke tests
│   │   └── smoke.test.ts             # Health check, DB ping, public feed, token decoding
│   └── load/                         # Layer 10: Performance & load testing
│       ├── k6_health.js              # Health endpoint load scenario
│       ├── k6_feed_read.js           # Public feed read scenario
│       ├── k6_order_write.js         # Webhook write scenario
│       ├── k6_auth_endpoints.js      # Authenticated admin route scenario
│       └── runner.js                 # High-precision percentile latency SLA runner
```

---

## 🚀 3. How to Run Tests

All test commands should be run from inside the `functions` directory:

### Run All Test Suites
```bash
npm run test
```

### Run Unit Tests
```bash
npm run test:unit
```

### Run Integration & API Tests
```bash
npm run test:integration
```

### Run Specific Test Categories
```bash
npm run test:api       # HTTP Endpoint tests
npm run test:auth      # Authentication and authorization tests
npm run test:db        # Dedicated database tests
npm run test:security  # Security and injection guard tests
npm run test:smoke     # Post-deployment smoke tests
```

### Run a Single Test File
```bash
npx jest tests/api/publicFeedServer.test.ts --runInBand
# or with pattern matching
npx jest auth.test.ts --runInBand
```

### Run in Watch Mode (TDD)
```bash
npm run test:watch
```

### Run Code Coverage Report
```bash
npm run test:coverage
```

### Run Load & SLA Percentile Benchmarks
```bash
npm run test:load

# Configurable with environment variables:
TARGET_URL="http://127.0.0.1:5001/truthworld-1/asia-south1" VUS=30 OPERATIONS=10000 npm run test:load
```

---

## 🛡️ 4. Test Database & Isolation Strategy

1. **Zero Production Risk**: Automated tests NEVER connect to live production Firestore or Firebase Auth.
2. **Deterministic In-Memory Harness**: `InMemoryFirestore` provides high-fidelity simulation of:
   - Full Collection, DocumentReference, DocumentSnapshot, and QuerySnapshot semantics.
   - Compound queries (`.where()`, `.orderBy()`, `.limit()`, `.startAfter()`).
   - Atomic Transactions (`runTransaction`) with strict rollback guarantees when errors occur.
   - Batch writes (`batch().set().update().delete().commit()`).
   - Firestore FieldValues (`serverTimestamp`, `increment`, `arrayUnion`, `delete`).
3. **Database Cleanup**: `beforeEach()` automatically calls `testFirestore.clear()` and `mockClaimsStore.clear()` between tests, ensuring tests are 100% deterministic and independent.

---

## 🔒 5. External API & Secret Mocking Policy

- **No Real Third-Party API Calls**: External providers like Cashfree and Vertex AI are mocked at the network layer (`jest.mock('axios')`).
- **No Real Secrets**: Dummy, clearly labeled test secrets (`TEST_APP_ID_FOR_AUTOMATED_TESTS`, `test_mock_secret_key_truthworld_12345`) are isolated inside `.env.test`.
- **HMAC Verification**: Tests verify true cryptographic HMAC-SHA256 signature generation and rejection of tampered payloads.

---

## 🤖 6. Continuous Integration (CI)

GitHub Actions workflow `.github/workflows/functions-ci.yml` runs automatically on all pull requests touching `functions/**`:

1. **Dependency Installation**: `npm ci`
2. **Type Check**: `npx tsc --noEmit`
3. **Unit Tests**: `npm run test:unit`
4. **Integration & API Tests**: `npm run test:integration`
5. **Smoke Tests**: `npm run test:smoke`
6. **Coverage Reporting**: `npm run test:coverage`
7. **Cloud Functions Build**: `npm run build`
8. **Build Size Summary**: Reports compiled bundle size to GitHub step summary.
