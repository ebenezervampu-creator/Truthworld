# Cloud Function: engagement.ts

**Location:** `functions/src/community/engagement.ts`

## 📖 What it does & How it works
🚀 SCALABLE ENGAGEMENT ENGINE (v1.0)
 
 Handles likes and dislikes for videos using a sharded counter pattern.
 Optimized for high-concurrency and cost-effectiveness.
 
 Industry Standard: Mutual exclusion (Like vs Dislike) is handled here.

## ⚙️ Exports / Primary Functions
- **onVideoLikeChange**
- **onVideoDislikeChange**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/firestore`
- 🔄 **Internal Dependency**: `../pipeline/utils/logger`
