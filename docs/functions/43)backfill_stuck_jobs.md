# Cloud Function: backfill_stuck_jobs.ts

**Location:** `functions/src/pipeline/scripts/backfill_stuck_jobs.ts`

## 📖 What it does & How it works
🛠️ BACKFILL: STUCK JOBS RECOVERY
 
 Target: Jobs in 'accepted' or 'processing' where all stages are terminal.
 Mode: Dry-run by default. Use --apply to execute.

## ⚙️ Exports / Primary Functions
*No explicit exports found.*

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `../types`
- 📦 **External Package**: `fs`
- 📦 **External Package**: `path`
