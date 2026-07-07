# Cloud Function: speakerTrustEngine.ts

**Location:** `functions/src/pipeline/services/speakerTrustEngine.ts`

## 📖 What it does & How it works
👥 SPEAKER TRUST ENGINE (v5.0)

 Computes per-speaker trust breakdown from verified claims.
 Fills the previously empty `speakers` array in CredibilityResult.

 Architecture:
   1. Group verified claims by speaker field
   2. Compute per-speaker accuracy, claim count, trust index
   3. Query historical speaker data (future: speaker_registry collection)
   4. Return SpeakerBreakdown[] for inclusion in results

 IMPORTANT: Speaker history should be used as a PRIOR (10-15% weight),
 never as a dominant signal. Current claim truth always takes priority.

## ⚙️ Exports / Primary Functions
- **SpeakerTrustEngine**
- **speakerTrustEngine**

## 🔗 Dependencies (What it depends on to work)
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `../utils/logger`
