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

## 📁 2. Test Directory Structure

- `.env.test`: Test environment configuration
- `jest.config.js`: Jest & ts-jest test runner configuration
- `tests/setup.ts`: Global environment bootstrap, in-memory DB hooks & mock resets. Mocks `admin.firestore()`, `admin.auth()`, `admin.storage()`, `admin.appCheck()`.
- `tests/helpers/`: Reusable test utilities (`mockFirestore.ts`, `authHelper.ts`, `testServer.ts`)
- `tests/factories/`: Standardized test data generators (`userFactory.ts`, `videoFactory.ts`, `orderFactory.ts`, `commentFactory.ts`, `channelFactory.ts`). All amounts must use honest round numbers (zero charm pricing).
- `tests/fixtures/`: Static payloads & HMAC signatures
- `tests/unit/`: Unit tests (auth, validators, etc.)
- `tests/api/`: Integration tests using Supertest
- `tests/load/`: Performance & load testing (`runner.js`, `k6_*.js`)

---

## 🚀 3. How to Run Tests

All test commands should be run from inside the `functions` directory:

### Run All Test Suites
```bash
npm run test
```

### Run Individual Test Suites
```bash
npm run test:unit
npm run test:integration
```

### Run a Single Test File
```bash
npx jest tests/api/publicFeedServer.test.ts --runInBand
```

### Run Code Coverage Report
```bash
npm run test:cov
# or
npx jest --coverage
```
Coverage includes economy, watchtime, search, channels, and pipelines, while excluding SEO, benchmarks, and resolutions. Results are stored in the `coverage/` directory.

### Run Load & SLA Percentile Benchmarks
We have two runners: Node.js runner and k6 scripts.

**Node.js Runner**
Makes real HTTP requests and calculates P95/P99 latencies, falling back to synthetic simulation if the target is unreachable.
```bash
# Configurable with environment variables:
TARGET_URL="http://127.0.0.1:5001/truthworld-1/asia-south1" VUS=30 OPERATIONS=10000 node tests/load/runner.js
```

**k6 Runner**
Runs specific scenarios for load tests.
```bash
k6 run -e BASE_URL="http://127.0.0.1:5001/truthworld-1/asia-south1" -e VUS=10 -e DURATION=10s tests/load/k6_health.js
```

---

## 🛡️ 4. Test Database & Isolation Strategy

1. **Zero Production Risk**: Automated tests NEVER connect to live production Firestore or Firebase Auth.
2. **Deterministic In-Memory Harness**: We use `testFirestore` from `helpers/mockFirestore.ts`.
3. **Database Cleanup**: `beforeEach()` automatically calls `testFirestore.clear()` and clears mocks via `setup.ts`, ensuring tests are 100% deterministic and independent. No arbitrary sleep calls are allowed.

---

## 🔒 5. External API & Secret Mocking Policy

- **No Real Third-Party API Calls**: External providers are mocked at the network layer (`jest.mock('axios')`, `jest.spyOn`).
- **Authentication Mocking**: Use `createMockToken`, `authHeader`, and `TEST_USERS` from `authHelper.ts` to simulate authenticated requests.
- **HMAC Verification**: Tests for Cashfree webhooks must verify true cryptographic HMAC-SHA256 signature generation.

---

## 🤖 6. Continuous Integration (CI)

Our `.github/workflows/ci.yml` runs automatically on `push` to `main` and `pull_request`:
- Uses Node.js 22.
- Installs dependencies (`npm ci`).
- Lints and typechecks (`npx tsc --noEmit`).
- Runs unit, integration tests, and coverage.
- Builds the Cloud Functions (`npm run build`).

---

## ➕ 7. How to Add a New Test

1. Add your test file inside `tests/unit/` or `tests/api/` (must end with `.test.ts`).
2. Use `createTestApp` for Supertest wrappers if testing an HTTP endpoint.
3. Use factories (e.g., `buildUser()`) to create data, maintaining honest round numbers.
4. Ensure zero raw developer errors leak to clients.
5. Do not use `$9.99` or charm pricing in test data—use `$10`, `$50`, etc.
