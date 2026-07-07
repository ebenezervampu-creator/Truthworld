# Cloud Function: backfill_ratings.ts

**Location:** `functions/src/pipeline/scripts/backfill_ratings.ts`

## 📖 What it does & How it works
Phase 3 Backfill Script
 
 Migrates `trustIndex` to `videoRating` in the `videos` collection.
 Migrates `reputation.avgTrustIndex` to `reputation.channelRating` in the `channels` collection.

## ⚙️ Exports / Primary Functions
*No explicit exports found.*

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
