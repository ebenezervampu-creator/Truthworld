# Cloud Function: adminEndpoints.ts

**Location:** `functions/src/publishing/adminEndpoints.ts`

## 📖 What it does & How it works
🔧 ADMIN HTTP ENDPOINTS FOR SCHEDULED PUBLISHING

 Purpose:
   - Manual trigger for testing (without waiting for Cloud Scheduler)
   - Status checks for debugging
   - Admin diagnostics

 Security:
   - Requires Firebase Auth + admin claim
   - All requests are logged

## ⚙️ Exports / Primary Functions
- **manualTriggerPublishing**
- **getScheduledVideos**
- **publishSingleVideo**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `@google-cloud/pubsub`
- 🔄 **Internal Dependency**: `../pipeline/utils/logger`
