# Cloud Function: claimCacheService.ts

**Location:** `functions/src/pipeline/services/claimCacheService.ts`

## 📖 What it does & How it works
🏛 v12.0: Institutional Claim Cache (Tier 1)
 
 Stores and retrieves verified claims to bypass expensive AI/Search calls.
 Uses SHA-256 hashing of normalized claim text for stable lookup.

## ⚙️ Exports / Primary Functions
- **ClaimCacheService**
- **claimCacheService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `crypto`
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `../utils/logger`
