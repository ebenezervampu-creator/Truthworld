# 🚀 TruthWorld Cloud Functions (2nd Gen)

> **Enterprise Backend for AI-Powered Fact-Checking, Multilingual Dubbing & Creator Monetization.**
> Built with Node.js 22, TypeScript, Firebase Functions v2, and Google Cloud Platform.

---

## 📖 Table of Contents
1. [Architectural Overview](#-1-architectural-overview)
2. [TruthWorld Engineering Standards](#-2-truthworld-engineering-standards)
3. [Directory Map & Domain Layout](#-3-directory-map--domain-layout)
4. [Centralized Configuration (`@config`)](#-4-centralized-configuration-config)
5. [Standard Developer Patterns](#-5-standard-developer-patterns)
   - [Creating a Callable Function](#a-creating-a-callable-function)
   - [Creating a Firestore Trigger](#b-creating-a-firestore-trigger)
   - [Creating a Scheduled / Cron Function](#c-creating-a-scheduled--cron-function)
   - [Structured Logging](#d-structured-logging)
   - [Zero-Leak Error Handling](#e-zero-leak-error-handling)
6. [Testing & Build Procedures](#-6-testing--build-procedures)
7. [Deployment & Manifest Generation](#-7-deployment--manifest-generation)

---

## 🏗️ 1. Architectural Overview

TruthWorld backend processes live and pre-recorded video through a high-performance **10-layer event-driven pipeline**:
1. **01-Edge / Ingress**: Pre-signed uploads, checksum verification, and duplicate suppression.
2. **02-Input Validation**: Format checks, codec probe (FFprobe), and video collection integrity guard.
3. **03-Ingestion**: GCS object archiving and initial metadata recording.
4. **04-Distribution**: Multi-task event fan-out via Google Cloud Pub/Sub.
5. **05-Transcription**: Multilingual speech recognition with AssemblyAI Universal 3.7 and diarization.
6. **06-Credibility & Fact-Checking**: Gemini 3.8 Flash, Vertex AI Google Search Grounding, and multi-source credibility scoring.
7. **07-Multilingual Dubbing**: Google Cloud Translation v3 + ElevenLabs v4 Turbo voice synthesis with adaptive speed matching.
8. **09-Aggregation**: Audio-video muxing, subtitle burning, and master delivery packaging.
9. **10-Performance & Unit Economics**: Real-time cost ledger attribution across Gemini tokens, ElevenLabs chars, and GCS egress.
10. **Publish Gate**: Strict quality and moderation gating before public fan-out to edge feeds and Typesense search clusters.

---

## 🛡️ 2. TruthWorld Engineering Standards

All backend developers must adhere to the three foundational TruthWorld engineering tenets:

### A. Zero Mock Data Policy
* **Never** introduce mock arrays, dummy records, simulated endpoints, fake IDs (`acct_mock_`, `po_mock_`), or artificial delay stubs into production code.
* All logic must integrate with authentic Firestore collections, real Cloud Functions, verified database schemas, and authoritative external APIs.

### B. Zero Raw Developer Error Policy
* **Never** expose raw exceptions, stack traces, internal database codes, or technical tokens (`$e`, `e.toString()`, `[cloud_firestore/...]`, `SocketException`) to clients or end users.
* Always use `toHttpsError(err)` or `sendErrorResponse(res, err)`: internal diagnostics are logged server-side via `logger.error`, while callers receive friendly, polite, actionable standard English explanations.
* Do not use aggressive titles like `"Error"` or `"Validation Error"`.

### C. Zero Charm-Pricing & Marketing Gimmicks
* TruthWorld stands for absolute truth and transparency.
* **Never** use psychological charm pricing (e.g. $9, $9.99, $14.99, $29.99, $99, 9999).
* All prices, credit allocations, quotas, and subscription tiers must use clean, honest, transparent round numbers (e.g., $10, $15, $20, $25, $30, $50, $100).

---

## 📁 3. Directory Map & Domain Layout

All Cloud Functions source code lives under `functions/src/` organized into self-contained domain modules with standard barrel exports:

```
functions/src/
├── index.ts               # Central deployment entry point (198 endpoints)
├── config/                # Central environment variables & platform phase limits
│   ├── env.ts             # Strongly-typed environment configuration
│   ├── platformLimits.ts  # Dynamic phase quotas (Alpha, Beta, GA)
│   └── index.ts           # Config barrel
├── shared/                # Core shared infrastructure
│   ├── logger.ts          # Structured Cloud Logging with contextual metadata
│   ├── errors.ts          # Standard AppError hierarchy & zero-leak sanitizer
│   ├── callableHandler.ts # Standard v2 onCall wrapper (auth, admin, logging)
│   ├── idempotency.ts     # Distributed L1/L2 deduplication & double-billing guard
│   ├── memory-cache.ts    # High-throughput in-memory TTL cache
│   └── index.ts           # Shared barrel
├── utils/                 # General helpers
│   ├── auth.ts            # Bearer token verification & admin claims
│   ├── securityHeaders.ts # OWASP response headers & session freshness
│   ├── videosCollectionGuard.ts # Document key UUID integrity guard
│   └── index.ts           # Utils barrel
├── pipeline/              # 10-layer video processing & AI credibility pipeline
├── resolution/            # Multi-bitrate transcoding (≤ 1040p / 60fps) & thumbnails
├── publishing/            # Video publication gating, shard sync & scheduled release
├── channels/              # Creator channels, following feeds, trust badges & discovery
├── economy/               # Cashfree payments, creator revenue splits, payouts & wallet
├── search/                # AI Search assistant & Typesense full-text cluster sync
├── moderation/            # Vision/speech safety filters & playlist moderation
├── verification/          # Multi-priority queue workers for image verification
├── watchtime/             # Real-time viewer pulses, watch limits & daily rollups
├── notifications/         # Activity triggers, topic subscriptions & push dispatches
├── admin/                 # Admin portal APIs, unit economics & member provisioning
├── community/             # Nested comments, discussions & reaction tracking
├── ads/                   # Contextual AI ad generation & impression revenue auditing
├── seo/                   # Dynamic SSR meta tag rendering & sitemap regenerators
├── users/                 # Registration capacity & account lifecycle management
└── feed/                  # Edge Feed CDN distribution server
```

---

## 🌐 4. Centralized Configuration (`@config`)

Never read `process.env.MY_VAR` randomly inside services. Use the typed `env` export from `src/config`:

```typescript
import { env } from "../config";

// Fully typed, validated with safe production fallbacks:
const region = env.firebase.region;              // "asia-south1"
const geminiModel = env.ai.verificationModel;     // "gemini-3.8-flash"
const cashfreeEnv = env.payment.cashfreeEnv;      // "SANDBOX" | "PRODUCTION"
const isProd = env.isProduction;                 // boolean
```

---

## 🛠️ 5. Standard Developer Patterns

### A. Creating a Callable Function
Use `createCallableHandler` to ensure automatic auth checks, admin validation, latency metrics, and error sanitization:

```typescript
import { createCallableHandler } from "../shared";

export const getCreatorAnalytics = createCallableHandler(
  {
    name: "getCreatorAnalytics",
    requireAuth: true,     // Rejects unauthenticated callers automatically
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (request) => {
    const { channelId } = request.data;
    const uid = request.auth!.uid;

    const data = await fetchAnalytics(channelId, uid);
    return { success: true, data };
  }
);
```

### B. Creating a Firestore Trigger
Always ensure document key guards and structured logging are present:

```typescript
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "../shared";
import { assertVideoId } from "../utils";

export const onVideoMetaUpdated = onDocumentWritten(
  {
    document: "videos/{videoId}",
    region: "asia-south1",
  },
  async (event) => {
    const videoId = event.params.videoId;
    assertVideoId(videoId); // Enforces UUID format; blocks temp IDs

    const after = event.data?.after.data();
    if (!after) return; // Handle deletion

    logger.info(`[VideoMeta] Processing update for ${videoId}`, { videoId });
  }
);
```

### C. Creating a Scheduled / Cron Function
All scheduled functions should run with scale-to-zero and idempotent execution:

```typescript
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "../shared";

export const midnightCleanupJob = onSchedule(
  {
    schedule: "every day 00:00",
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
    maxInstances: 1,
  },
  async (event) => {
    logger.info("[Scheduler] Starting midnight cleanup task...");
    await executeCleanup();
  }
);
```

### D. Structured Logging
Use the shared `logger` to generate Cloud Logging structured JSON:

```typescript
import { logger } from "../shared";

// Simple message
logger.info("Video processed successfully");

// Contextual metadata
logger.info("Credibility analysis completed", {
  videoId: "123e4567-e89b-12d3-a456-426614174000",
  score: 88,
  verdict: "VERIFIED_TRUE",
});

// Child logger with bound context
const videoLogger = logger.withContext({ videoId: "123e4567-..." });
videoLogger.info("Starting audio transcription");
```

### E. Zero-Leak Error Handling
Throw structured errors that know how to safely present themselves to end users:

```typescript
import { ValidationError, NotFoundError, toHttpsError } from "../shared";

export async function processPayment(orderId: string) {
  if (!orderId) {
    throw new ValidationError(
      "Missing order ID parameter",
      "Please provide a valid order ID to process payment."
    );
  }

  const order = await getOrder(orderId);
  if (!order) {
    throw new NotFoundError(
      `Order ${orderId} does not exist`,
      "The specified order could not be found."
    );
  }
}
```

---

## 🧪 6. Testing & Build Procedures

All tests run from the `functions/` root directory:

```bash
# Compile TypeScript and generate functions.yaml
npm run build

# Run fast unit tests
npm run test:unit

# Run full pipeline tests
npm run test:pipeline

# Run dubbing & translation tests
npm run test:dubbing

# Run integration tests (requires emulators)
npm run test:integration
```

---

## 🚀 7. Deployment & Manifest Generation

Functions are deployed using Firebase CLI 2nd Generation with pre-built deployment manifests:

```bash
# Verify build & endpoints
npm run build

# Deploy to Firebase (all 198 endpoints)
npm run deploy

# View real-time logs
npm run logs
```
