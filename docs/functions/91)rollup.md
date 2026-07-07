# Cloud Function: rollup.ts

**Location:** `functions/src/watchtime/rollup.ts`

## 📖 What it does & How it works
Daily rollup: Snapshots today's stats into dailyStats subcollections.
 Runs at midnight IST (18:30 UTC previous day).

## ⚙️ Exports / Primary Functions
- **rollupDailyStats**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/scheduler`
- 📦 **External Package**: `firebase-functions/v2`
