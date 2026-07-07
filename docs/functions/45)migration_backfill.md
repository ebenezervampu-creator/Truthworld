# Cloud Function: migration_backfill.ts

**Location:** `functions/src/pipeline/scripts/migration_backfill.ts`

## 📖 What it does & How it works
🛠️ MIGRATION: BACKFILL CANONICAL TRUTH
 
 Logic:
 1. Iterate over central 'video_jobs' (index).
 2. For docs missing a 'version' field (legacy):
    a. Extract 'shard' and 'jobId'.
    b. Fetch full document from 'video_jobs_shard_X'.
    c. Write full document to central 'video_jobs' with version: 1.
    d. This automatically triggers 'syncJobToShard' for replication.

## ⚙️ Exports / Primary Functions
*No explicit exports found.*

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
