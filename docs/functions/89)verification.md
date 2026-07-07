# Cloud Function: verification.ts

**Location:** `functions/src/verification/verification.ts`

## 📖 What it does & How it works
verification.ts
 ═══════════════════════════════════════════════════════════════════════════════
 Scalable image moderation pipeline — all logic in one file.

 FIXES APPLIED (vs original):
   FIX 1: thumbnails path regex — now supports BOTH flat (thumbnails/<file>)
           AND nested (thumbnails/<contentId>/<file>) layouts.
   FIX 2: generateDocId() — Firestore doc ID is now the filename (e.g.
           "87fd02cf-71d3-40c3-9fed-c80e75d4acdf.png") so you can look it
           up by name.  Random suffix only added on collision.
   FIX 3: VALID_EXTENSIONS — ".jpeg" was present but the banners test file
           ends in ".jpeg"; confirmed to work.
   FIX 4: JPEG extension normalisation in VALID_MIME_TYPES — kept as-is,
           both "image/jpeg" and "image/jpg" accepted.

 Exports (consumed by index.ts):
   ingestUploadedImage          — Storage trigger
   prefilterWorker              — Pub/Sub image-prefilter
   moderationWorkerHigh/Medium/Low — Pub/Sub image-moderation-*
   retryQueueProcessor          — Pub/Sub retry trigger
   retryQueueProcessorManual    — HTTPS (testing only)
   deadLetterHandler            — Pub/Sub DLQ
   getImageVerificationStatus   — HTTPS
   cleanupVerificationRecord    — HTTPS

 Pipeline flow:
   Storage → ingest → Pub/Sub(prefilter) → prefilterWorker
     ├─ APPROVE FAST → Firestore
     ├─ REJECT FAST  → quarantine + Firestore
     └─ SCAN         → Pub/Sub(moderation) → moderationWorker → Vision API → Firestore
 ═══════════════════════════════════════════════════════════════════════════════

## ⚙️ Exports / Primary Functions
- **MediaAsset**
- **ingestUploadedImage**
- **prefilterWorker**
- **retryQueueProcessor**
- **scheduledRetryProcessor**
- **retryQueueProcessorManual**
- **moderationWorkerHigh**
- **moderationWorkerMedium**
- **moderationWorkerLow**
- **deadLetterHandler**
- **getImageVerificationStatus**
- **cleanupVerificationRecord**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-functions/v2/storage`
- 📦 **External Package**: `firebase-functions/v2/pubsub`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `firebase-functions/v2/scheduler`
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/logger`
- 📦 **External Package**: `@google-cloud/vision`
- 📦 **External Package**: `@google-cloud/pubsub`
- 📦 **External Package**: `crypto`
- 📦 **External Package**: `sharp`
