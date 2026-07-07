# Cloud Function: liveViewers.ts

**Location:** `functions/src/watchtime/liveViewers.ts`

## 📖 What it does & How it works
RTDB Trigger: Updates concurrent viewer count when a session is written/deleted.
 Triggered on /activeViewers/{videoId}/{sessionId}

## ⚙️ Exports / Primary Functions
- **onActiveViewerWrite**
- **cleanupStaleSessions**
- **aggregateLiveWatchTime**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/database`
- 📦 **External Package**: `firebase-functions/v2/scheduler`
- 📦 **External Package**: `firebase-functions/v2`
