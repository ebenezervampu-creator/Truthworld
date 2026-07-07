# Cloud Function: fastVerification.ts

**Location:** `functions/src/pipeline/services/fastVerification.ts`

## 📖 What it does & How it works
⚡ FAST VERIFICATION SERVICE (v11.0)
 
 Lightweight credibility signal for real-time use cases:
 - Browser extensions
 - Mobile app quick-check
 - API embeds
 - Live content triage
 
 Design: Flash model only, no grounding, registry lookup,
 max 5 claims. Returns traffic-light signal in < 5 seconds.
 
 Cost: ~$0.001 per call vs ~$0.05 for deep tier

## ⚙️ Exports / Primary Functions
- **FAST_TIER_CONFIG**
- **FastVerificationResult**
- **FastVerificationService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `@google/generative-ai`
- 🔄 **Internal Dependency**: `../utils/logger`
- 📦 **External Package**: `zod`
