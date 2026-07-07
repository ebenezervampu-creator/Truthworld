# Cloud Function: 05-transcription.ts

**Location:** `functions/src/pipeline/layers/05-transcription.ts`

## 📖 What it does & How it works
🎤 LAYER 05 — TRANSCRIPTION LAYER (Universal-3 Pro + Universal-2 Fallback)

 Audio extraction → AssemblyAI (Multi-model) → structured word/segment output → emit event.

 ✅ ALL UPGRADES:
   1. Model: `universal-3-pro` + `universal-2` — Auto-fallback for 99+ languages support
   2. Native subtitle export — SRT/VTT fetched directly from AssemblyAI (source language)
   3. Consumer idempotency gate — checks eventId via DistributionLayer before doing any work
   4. Structured storage — full JSON stored in GCS (avoids Firestore doc size limit)
   5. Language detection result — stored for downstream use (translation skip if same lang)
   6. Stage updates are async — never blocks the processing pipeline
   7. Webhook-based architecture — returns immediately after submission

## ⚙️ Exports / Primary Functions
- **TranscriptionLayer**
- **transcriptionLayer**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `axios`
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `./04-distribution`
- 🔄 **Internal Dependency**: `./01-edge`
- 🔄 **Internal Dependency**: `./09-aggregation`
- 🔄 **Internal Dependency**: `../utils/logger`
- 🔄 **Internal Dependency**: `../services/cost-engine`
- 🔄 **Internal Dependency**: `../services/reputationService`
- 🔄 **Internal Dependency**: `../config`
