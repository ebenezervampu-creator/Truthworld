# Cloud Function: profile.ts

**Location:** `functions/src/channels/profile.ts`

## 📖 What it does & How it works
🛠️ UPDATE CHANNEL PROFILE (Callable)
 Allows owners to update their channel bio, links, and category.
 Backfills missing V2 fields on write.

## ⚙️ Exports / Primary Functions
- **updateChannelProfile**
- **getPublicChannelProfile**
- **migrateChannelsToV2**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `firebase-functions/v2`
