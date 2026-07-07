# Cloud Function: scheduledPublishing.ts

**Location:** `functions/src/publishing/scheduledPublishing.ts`

## 📖 What it does & How it works
⏰ SCHEDULED PUBLISHING FUNCTION (Gen 2 — Pub/Sub Triggered)

 Purpose:
   - Publishes scheduled videos at their exact scheduled time
   - Triggered by Cloud Scheduler every 5 minutes (cost-efficient)
   - Batches updates for Firestore efficiency
   - Implements industry-standard retry logic

 Cost Optimization:
   ✅ minInstances=0 (scale-to-zero when no publishes needed)
   ✅ Pub/Sub batching (checks many docs in one invocation)
   ✅ Firestore batch writes (≤ 500 docs per batch)
   ✅ Cloud Scheduler every 5 minutes (predictable, low cost)
   ✅ No polling overhead — only runs when scheduled

 Region: asia-south1
 Memory: 512MiB
 Timeout: 540 seconds (9 minutes for safety)

## ⚙️ Exports / Primary Functions
- **scheduledPublishing**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/pubsub`
- 📦 **External Package**: `@google-cloud/pubsub`
- 🔄 **Internal Dependency**: `../pipeline/utils/logger`
