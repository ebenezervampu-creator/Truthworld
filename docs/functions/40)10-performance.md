# Cloud Function: 10-performance.ts

**Location:** `functions/src/pipeline/layers/10-performance.ts`

## 📖 What it does & How it works
🚀 LAYER 10 — PERFORMANCE & COST OPTIMIZATION (REFACTORED — NO REDIS)

 Cross-cutting caching layer for Credibility, Dubbing, and optional AUX.

 ✅ KEY CHANGES:
   1. Redis removed: No Upstash dependency
   2. Caching now: in-memory LRU (fast) + Firestore (persistent)
   3. Circuit breaker simplified: only for Firestore, not Redis
   4. Cost reduction: $0.02 → $0.001 per job (95% savings)

 ✅ ARCHITECTURE:
   - L1 Cache: In-memory LRU (per-instance, ~<1ms)
   - L2 Cache: Firestore "cache" collection (persistent cross-instance)
   - Fallback: Re-compute if both misses

 ✅ TTL STRATEGY:
   - Claim cache: 1-7 days (by category)
   - Translation: 30 days (stable language outputs)
   - TTS audio: 3 days (lower retention for audio files)
   - In-memory: 1 hour max per instance (ephemeral)

## ⚙️ Exports / Primary Functions
- **PerformanceLayer**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `crypto`
- 🔄 **Internal Dependency**: `../utils/memory-cache`
- 🔄 **Internal Dependency**: `../utils/logger`
- 🔄 **Internal Dependency**: `../utils/alerting`
