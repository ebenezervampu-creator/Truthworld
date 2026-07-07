# Cloud Function: reputationService.ts

**Location:** `functions/src/pipeline/services/reputationService.ts`

## 📖 What it does & How it works
🏆 REPUTATION SERVICE (The Trust Ledger)
 
 Aggregates per-video Credibility Results into long-term Creator Reputation.
 This turns verification data into a "Reputation Graph," which is the
 core competitive moat of TruthWorld.

## ⚙️ Exports / Primary Functions
- **ReputationService**
- **reputationService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `../utils/logger`
