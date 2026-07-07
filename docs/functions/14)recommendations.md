# Cloud Function: recommendations.ts

**Location:** `functions/src/channels/recommendations.ts`

## 📖 What it does & How it works
âš–ï¸ CALCULATE FEED SCORE (Multiplicative)
 Balances Trust, Freshness, Relevance, and Social Proof.

## ⚙️ Exports / Primary Functions
- **getHomeFeed**
- **getDiscoveryModules**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/https`
- 🔄 **Internal Dependency**: `../pipeline/utils/logger`
