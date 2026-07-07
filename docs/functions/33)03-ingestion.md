# Cloud Function: 03-ingestion.ts

**Location:** `functions/src/pipeline/layers/03-ingestion.ts`

## 📖 What it does & How it works
☁️ LAYER 03 — INGESTION LAYER (NO REDIS)

 Entry point for Cloud Storage trigger. Validates, deduplicates, tracks uploads.

 ✅ ARCHITECTURE (v8.0 — Publish-Gated Pipeline):
   1. Content-hash dedup    — Firestore-only (no Redis)
   2. Metadata extraction   — reads real GCS object metadata (size, duration hint)
   3. Lightweight tracking  — updates video doc with upload metadata ONLY
   4. NO pipeline trigger   — the pipeline is triggered by onVideoPublished (index.ts)
                              when the user publishes with complete metadata + aiFeatures

## ⚙️ Exports / Primary Functions
- **IngestionLayer**
- **ingestionLayer**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `../utils/logger`
