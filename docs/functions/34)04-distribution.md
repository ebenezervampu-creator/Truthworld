# Cloud Function: 04-distribution.ts

**Location:** `functions/src/pipeline/layers/04-distribution.ts`

## 📖 What it does & How it works
📡 LAYER 04 — DISTRIBUTION LAYER (REFACTORED — NO REDIS)

 Event-driven backbone using Google Cloud Pub/Sub + Firestore.

 ✅ KEY CHANGES FROM REDIS VERSION:
   1. Idempotency: Firestore atomic create() instead of Redis SET NX
   2. No Redis dependency (cheaper, simpler)
   3. Event tracking in "processed_events" collection with TTL
   4. Fallback: in-memory ephemeral cache for lost Firestore writes

 ✅ COST IMPACT:
   - Redis operations removed: $0 (was $0.02+ per job)
   - Firestore writes: $0.06 per 100k (acceptable)
   - ~30% cost reduction in distribution layer

## ⚙️ Exports / Primary Functions
- **DistributionLayer**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `@google-cloud/pubsub`
- 📦 **External Package**: `uuid`
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `../utils/logger`
- 🔄 **Internal Dependency**: `../utils/alerting`
