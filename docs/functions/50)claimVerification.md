# Cloud Function: claimVerification.ts

**Location:** `functions/src/pipeline/services/claimVerification.ts`

## 📖 What it does & How it works
v10.6: Dynamic batch timeout calculation.
 Accounts for model type, grounding mode, batch size, and retry pass.
 For long-form videos (50+ claims), this ensures no single batch
 blocks the pipeline beyond 2 minutes.

## ⚙️ Exports / Primary Functions
- **ClaimVerificationService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `@google/generative-ai`
- 🔄 **Internal Dependency**: `../config`
- 🔄 **Internal Dependency**: `./contentIntentDetector`
- 🔄 **Internal Dependency**: `../utils/ai-utils`
- 🔄 **Internal Dependency**: `../utils/logger`
- 🔄 **Internal Dependency**: `./sourceTrustService`
- 🔄 **Internal Dependency**: `./tier0Knowledge`
- 📦 **External Package**: `crypto`
- 🔄 **Internal Dependency**: `./telemetry`
