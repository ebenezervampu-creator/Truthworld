# Cloud Function: idempotency-engine.ts

**Location:** `functions/src/pipeline/utils/idempotency-engine.ts`

## 📖 What it does & How it works
⚡ IDEMPOTENCY ENGINE (BULLETPROOF VERSION)

 The SINGLE most important component — failure here = double billing.

 ✅ STRATEGY: Firestore transactions (atomic read + write)
 This prevents ALL race conditions, even under high concurrency.

## ⚙️ Exports / Primary Functions
- **IdempotencyStatus**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `./memory-cache`
- 🔄 **Internal Dependency**: `./logger`
