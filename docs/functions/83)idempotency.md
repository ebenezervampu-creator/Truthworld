# Cloud Function: idempotency.ts

**Location:** `functions/src/shared/idempotency.ts`

## 📖 What it does & How it works
⚡ IDEMPOTENCY ENGINE (SHARED CORE)

 Prevents double-billing and duplicate processing across all services.
 USES: Firestore Transactions for atomic L2 check.

## ⚙️ Exports / Primary Functions
- **IdempotencyStatus**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `./memory-cache`
- 🔄 **Internal Dependency**: `./logger`
