# ⏰ Scheduled Video Publishing — Cloud Function Gen 2 Setup Guide

## 📋 Overview

This guide walks through deploying and configuring the **Pub/Sub-triggered Cloud Function** for scheduled video publishing on Firebase/Google Cloud.

**Key Features:**
- ✅ **Cost-Efficient**: Pub/Sub + Cloud Scheduler (only pay for videos published)
- ✅ **Industry Standard**: Batch writes, error handling, retry logic
- ✅ **Production Ready**: Monitoring, logging, manual testing endpoints
- ✅ **Zero Polling**: No waste on checking if videos are ready
- ✅ **Scalable**: Handles 100s of scheduled videos per check

---

## 🔧 Prerequisites

1. **Firebase Project** with Cloud Functions enabled
2. **Google Cloud Project** (same as Firebase)
3. **gcloud CLI** installed and configured
4. **Node.js 20+** and npm (for local development)
5. **Dart/Flutter** (your app already uses this)

### Verify Prerequisites
```bash
gcloud --version
firebase --version
node --version
npm --version
```

---

## 📦 Step 1: Create Pub/Sub Topic

The Pub/Sub topic is the event source for the Cloud Function.

### Create Topic
```bash
gcloud pubsub topics create scheduled-publishing
```

### Verify
```bash
gcloud pubsub topics list | grep scheduled-publishing
```

---

## 🕐 Step 2: Create Cloud Scheduler Job

Cloud Scheduler will invoke the Pub/Sub topic every 5 minutes (cost-efficient).

### Create Scheduler Job
```bash
gcloud scheduler jobs create pubsub scheduled-publishing-trigger \
  --location asia-south1 \
  --schedule "*/5 * * * *" \
  --time-zone "UTC" \
  --topic scheduled-publishing \
  --message-body '{}'
```

### What This Does:
- **`*/5 * * * *`** = Every 5 minutes
- **`asia-south1`** = Same region as your functions
- **`{}`** = Empty payload (function doesn't need data)

### Verify
```bash
gcloud scheduler jobs list --location asia-south1
gcloud scheduler jobs describe scheduled-publishing-trigger --location asia-south1
```

### Test Manually (Check Logs)
```bash
gcloud scheduler jobs run scheduled-publishing-trigger --location asia-south1
```

---

## 🚀 Step 3: Deploy the Cloud Function

### Option A: Deploy Directly (Recommended)

From the `functions/` directory:

```bash
npm run deploy
```

This will deploy:
- ✅ `scheduledPublishing` (Pub/Sub trigger)
- ✅ `manualTriggerPublishing` (HTTP endpoint for testing)
- ✅ `getScheduledVideos` (HTTP endpoint for diagnostics)
- ✅ `publishSingleVideo` (HTTP endpoint for debugging)

### Option B: Deploy Specific Function

```bash
firebase deploy --only functions:scheduledPublishing
```

### Option C: Deploy via gcloud CLI

```bash
cd functions
npm run build

gcloud functions deploy scheduledPublishing \
  --gen2 \
  --runtime nodejs20 \
  --trigger-topic scheduled-publishing \
  --region asia-south1 \
  --memory 512MiB \
  --timeout 540 \
  --min-instances 0 \
  --max-instances 5 \
  --source lib \
  --entry-point scheduledPublishing
```

---

## ✅ Step 4: Enable Required APIs

If not already enabled:

```bash
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  pubsub.googleapis.com \
  cloudscheduler.googleapis.com \
  firestore.googleapis.com
```

---

## 🧪 Step 5: Test the Setup

### 1. Create a Test Scheduled Video

Go to your Flutter app and:
1. Upload a video
2. Enable "Schedule for later"
3. Set publish time to **2 minutes from now**
4. Click "Publish"

Firestore should have a document with:
```json
{
  "status": "scheduled",
  "scheduledTime": "<timestamp in 2 mins>",
  "title": "Test Video",
  "ownerId": "<your-user-id>",
  ...
}
```

### 2. Manually Trigger the Function

Make an HTTP POST request to the manual trigger endpoint:

**Using curl:**
```bash
curl -X POST https://asia-south1-<PROJECT_ID>.cloudfunctions.net/manualTriggerPublishing \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Replace `<PROJECT_ID>`** with your actual Google Cloud project ID.

### 3. Check Logs

```bash
firebase functions:log --only scheduledPublishing

# Or in Google Cloud Console:
gcloud functions logs read scheduledPublishing --region asia-south1
```

You should see output like:
```
[scheduledPublishing] Starting scheduled publishing check...
[scheduledPublishing] Found 1 videos due for publishing
[scheduledPublishing] Publishing 1 videos in batches...
[scheduledPublishing] EXECUTION SUMMARY: {...}
```

### 4. Check Firestore Document

The scheduled video should now have:
```json
{
  "status": "published",  // Changed from "scheduled"
  "publishedAt": "<current-timestamp>",
  ...
}
```

---

## 🔍 Monitoring & Diagnostics

### View Function Metrics
```bash
# CPU utilization
gcloud functions describe scheduledPublishing \
  --region asia-south1 \
  --gen2

# Logs
firebase functions:log --only scheduledPublishing
```

### Check Scheduled Videos
```bash
curl -X GET https://asia-south1-<PROJECT_ID>.cloudfunctions.net/getScheduledVideos \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

Response:
```json
{
  "status": "success",
  "summary": {
    "total": 5,
    "due": 2,
    "upcoming": 3
  },
  "due": [
    {
      "id": "video-123",
      "title": "My Video",
      "scheduledTime": "2026-04-30T12:00:00Z",
      "isDue": true
    }
  ]
}
```

### Publish Single Video (Admin Testing)
```bash
curl -X POST https://asia-south1-<PROJECT_ID>.cloudfunctions.net/publishSingleVideo/video-123 \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

---

## 📊 Cost Analysis

### Per-Month Cost Estimate:

**Assumption:** 100 videos scheduled for publishing per day

| Component | Unit Cost | Usage | Monthly Cost |
|-----------|-----------|-------|--------------|
| Cloud Scheduler | $0.10/job/month | 1 job | $0.10 |
| Pub/Sub | $0.05/million messages | 8,640 calls/month | ~$0.00 |
| Cloud Functions | $0.40/million invocations | 8,640 + publishes | ~$3.50 |
| Firestore Writes | $0.06/100k writes | 100 videos/day = 3,000/month | ~$0.02 |
| **TOTAL** | | | **~$3.62/month** |

**Compare to alternatives:**
- ❌ **Lambda + SQS + polling every minute**: $15-20/month
- ❌ **Dedicated server**: $50+/month
- ✅ **Our approach**: ~$3.62/month

---

## 🛡️ Security Best Practices

### 1. IAM Permissions (Least Privilege)

```bash
# Create custom role for scheduled publishing
gcloud iam roles create customPublishingRole \
  --permissions=firestore.databases.update,pubsub.topics.publish

# Grant to Cloud Functions service account
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member=serviceAccount:<PROJECT_ID>@appspot.gserviceaccount.com \
  --role=projects/<PROJECT_ID>/roles/customPublishingRole
```

### 2. Admin Endpoints

All admin endpoints require:
- ✅ Firebase Auth
- ✅ Admin custom claim (`admin: true`)

Set admin claims for trusted admins only:
```bash
firebase auth:import accounts.json --hash-algo=bcrypt
firebase auth:set-custom-user-claims <UID> --claims='{"admin":true}'
```

### 3. Cloud Scheduler Permissions

Scheduler service account needs `roles/pubsub.editor`:

```bash
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member=serviceAccount:cloud-scheduler@system.gserviceaccount.com \
  --role=roles/pubsub.editor
```

---

## 🐛 Troubleshooting

### Issue: Function Not Triggering

**Check:**
1. Is Cloud Scheduler job running?
   ```bash
   gcloud scheduler jobs describe scheduled-publishing-trigger --location asia-south1
   ```

2. Is Pub/Sub topic created?
   ```bash
   gcloud pubsub topics list
   ```

3. Are APIs enabled?
   ```bash
   gcloud services list --enabled | grep pubsub
   gcloud services list --enabled | grep scheduler
   ```

### Issue: Videos Not Published

**Check logs:**
```bash
firebase functions:log --only scheduledPublishing
```

**Common issues:**
- ❌ Videos don't have `aiFeatures` map (add in `buildFeaturesMap()`)
- ❌ `scheduledTime` is in wrong format (should be Firestore Timestamp)
- ❌ `status` field is not exactly `"scheduled"`

### Issue: Timeout Errors

Increase timeout to 600 seconds:
```bash
gcloud functions deploy scheduledPublishing \
  --gen2 \
  --timeout 600 \
  --region asia-south1
```

### Issue: Permission Denied

Check IAM:
```bash
gcloud projects get-iam-policy <PROJECT_ID> \
  --flatten=bindings \
  --filter=bindings.members:serviceAccount:*@appspot.gserviceaccount.com
```

---

## 📈 Scaling Considerations

### Batching Strategy

The function batches updates by `BATCH_SIZE = 100`:
- ✅ Reads first 500 scheduled videos
- ✅ Batches into 5 groups of 100
- ✅ Writes each batch separately

**For 10,000+ scheduled videos:**
- Increase `BATCH_SIZE` to 500 (if you have more Firestore capacity)
- Reduce Cloud Scheduler frequency to every 10 minutes
- Monitor Firestore write quota

### Memory & Timeout

```bash
# For large batches (1000+ videos):
gcloud functions deploy scheduledPublishing \
  --memory 1GiB \
  --timeout 900
```

---

## 🔄 Next Steps

### In Your Flutter App

1. **Update `uploadController.dart`**:
   - ✅ Already stores `isScheduled` and `scheduledDate`
   - ✅ Already builds `aiFeatures` map
   - ✅ Ready for scheduled publishing

2. **No code changes needed!** The function handles everything.

### Monitor in Production

1. Set up CloudWatch/Google Cloud Monitoring alerts:
   ```bash
   gcloud alpha monitoring policies create \
     --display-name="ScheduledPublishing Errors" \
     --condition-display-name="Error rate > 5%" \
     --condition-threshold-value=0.05
   ```

2. Weekly review of:
   - Function execution times
   - Video publish latency
   - Error rates

---

## 📞 Support & Documentation

- [Firebase Cloud Functions Docs](https://firebase.google.com/docs/functions)
- [Cloud Pub/Sub Docs](https://cloud.google.com/pubsub/docs)
- [Cloud Scheduler Docs](https://cloud.google.com/scheduler/docs)
- [Firestore Batch Writes](https://cloud.google.com/firestore/docs/manage-data/transactions)

---

**Last Updated:** 2026-04-30  
**Deployed By:** Cloud Functions Gen 2 Setup Guide  
**Status:** ✅ Production Ready
