# Cloud Function: image-proxy.ts

**Location:** `functions/src/services/image-proxy.ts`

## 📖 What it does & How it works
🖼️ IMAGE PROXY SERVICE
 Caches and serves profile images to reduce rate limiting from Google
 Reduces direct requests to lh3.googleusercontent.com

## ⚙️ Exports / Primary Functions
- **getCachedImage**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/https`
- 🔄 **Internal Dependency**: `../pipeline/utils/logger`
- 📦 **External Package**: `https`
