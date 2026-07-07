# Cloud Function: 06-credibility.ts

**Location:** `functions/src/pipeline/layers/06-credibility.ts`

## 📖 What it does & How it works
🧠 LAYER 06 — CREDIBILITY ENGINE (PATH 1)

 Fact-checking pipeline with explainability and cost-optimised caching.

## ⚙️ Exports / Primary Functions
- **CredibilityEngine**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `uuid`
- 🔄 **Internal Dependency**: `../services/factExtraction`
- 🔄 **Internal Dependency**: `../services/claimVerification`
- 🔄 **Internal Dependency**: `../services/scoringEngine`
- 🔄 **Internal Dependency**: `./04-distribution`
- 🔄 **Internal Dependency**: `./01-edge`
- 🔄 **Internal Dependency**: `./09-aggregation`
- 🔄 **Internal Dependency**: `./10-performance`
- 🔄 **Internal Dependency**: `../utils/logger`
- 🔄 **Internal Dependency**: `../utils/alerting`
- 🔄 **Internal Dependency**: `../config`
- 🔄 **Internal Dependency**: `../services/reputationService`
- 🔄 **Internal Dependency**: `../services/contentIntentDetector`
- 🔄 **Internal Dependency**: `../services/speakerTrustEngine`
- 🔄 **Internal Dependency**: `../services/speakerRegistry`
- 🔄 **Internal Dependency**: `../services/speakerReputationService`
- 🔄 **Internal Dependency**: `../registry/RegistryService`
