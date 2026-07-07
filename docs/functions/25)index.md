# Cloud Function: index.ts

**Location:** `functions/src/index.ts`

## 📖 What it does & How it works
🚀 FIREBASE CLOUD FUNCTIONS — ENTRY POINT (Updated: 2026-04-22T17:31Z)

 Exports EXACTLY 3 features:
   1. Pipeline  — 10-layer video processing pipeline
   2. Resolution — Video resolution processing (≤ 720p)
   3. Verification — Image verification (thumbnails, avatars, banners, community posts)

 ✅ NO REDIS
 ✅ minInstances: 0 (scale-to-zero) except edge (minInstances: 1)
 ✅ Explicit maxInstances caps per function
 ✅ Region: asia-south1

## ⚙️ Exports / Primary Functions
- **submitVideo**
- **getProgressiveStatus**
- **getFinalOutput**
- **onVideoUpload**
- **handleTranscription**
- **handleTranscriptionWebhook**
- **handleCredibility**
- **handleDubbing**
- **handleFactComplete**
- **handleDubbingComplete**
- **setupPipeline**
- **handleFastVerification**
- **getCreatorCostDashboard**
- **getSystemCostOverview**
- **getJobCostBreakdown**
- **onVideoPublished**
- **syncJobToShard**
- **reVerifyVideo**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2`
- 📦 **External Package**: `firebase-functions/v2/storage`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `firebase-functions/v2/firestore`
- 📦 **External Package**: `uuid`
- 🔄 **Internal Dependency**: `./pipeline/layers/01-edge`
- 🔄 **Internal Dependency**: `./pipeline/layers/03-ingestion`
- 🔄 **Internal Dependency**: `./pipeline/layers/04-distribution`
- 🔄 **Internal Dependency**: `./pipeline/layers/05-transcription`
- 🔄 **Internal Dependency**: `./pipeline/layers/06-credibility`
- 🔄 **Internal Dependency**: `./pipeline/layers/07-dubbing`
- 🔄 **Internal Dependency**: `./pipeline/layers/09-aggregation`
- 🔄 **Internal Dependency**: `./pipeline/utils/logger`
- 🔄 **Internal Dependency**: `./pipeline/config`
- 🔄 **Internal Dependency**: `./pipeline/services/fastVerification`
- 🔄 **Internal Dependency**: `./pipeline/services/cost-engine`
