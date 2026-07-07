# Cloud Function: resolution.ts

**Location:** `functions/src/resolution/resolution.ts`

## 📖 What it does & How it works
🎥 RESOLUTION — Video Resolution Processing (≤ 720p)

 Firebase Cloud Function triggered by video uploads.
 Processes uploaded videos into adaptive bitrate ladder capped at 720p.

 ✅ FEATURES:
   - Storage trigger: onObjectFinalized for videos/ prefix
   - Resolution cap: Maximum 720p (free tier). Ladder: [720, 480, 360, 240, 144]
   - Stores processed metadata in Firestore
   - Stores processed files in Firebase Storage
   - minInstances: 0 (scale-to-zero)

 ✅ COST OPTIMIZATION:
   - Only transcode if source resolution > target
   - Skip redundant resolutions (e.g., don't upscale 480p to 720p)
   - Bitrate ladder dynamically set per resolution

## ⚙️ Exports / Primary Functions
- **onVideoUploadedForResolution**
- **getVideoResolutionStatus**
- **getResolutionProfiles**
- **handleResolution**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/storage`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `uuid`
- 🔄 **Internal Dependency**: `../shared/messaging`
- 🔄 **Internal Dependency**: `../shared/idempotency`
- 📦 **External Package**: `fluent-ffmpeg`
- 📦 **External Package**: `ffmpeg-static`
- 📦 **External Package**: `path`
- 📦 **External Package**: `os`
- 📦 **External Package**: `fs`
