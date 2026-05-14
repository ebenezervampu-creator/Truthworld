#!/bin/bash

# 🚀 QUICK START: SCHEDULED PUBLISHING DEPLOYMENT
#
# This script automates the setup of scheduled video publishing.
# Run this in your project root after cloning.
#
# Usage:
#   bash deploy-scheduled-publishing.sh <PROJECT_ID> <REGION>
#
# Example:
#   bash deploy-scheduled-publishing.sh my-firebase-project asia-south1

set -e

PROJECT_ID="${1:-}"
REGION="${2:-asia-south1}"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: PROJECT_ID is required"
  echo "Usage: bash deploy-scheduled-publishing.sh <PROJECT_ID> [REGION]"
  exit 1
fi

echo "🚀 SCHEDULED PUBLISHING SETUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Set up gcloud configuration
# ─────────────────────────────────────────────────────────────────────────────

echo "📝 [1/6] Configuring gcloud..."
gcloud config set project "$PROJECT_ID"
echo "✅ Project configured"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Enable APIs
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "📡 [2/6] Enabling required APIs..."
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  pubsub.googleapis.com \
  cloudscheduler.googleapis.com \
  firestore.googleapis.com
echo "✅ APIs enabled"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Create Pub/Sub Topic
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "🔔 [3/6] Creating Pub/Sub topic..."
if gcloud pubsub topics describe scheduled-publishing --project="$PROJECT_ID" 2>/dev/null; then
  echo "   ℹ️  Topic already exists"
else
  gcloud pubsub topics create scheduled-publishing --project="$PROJECT_ID"
  echo "✅ Pub/Sub topic created"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: Create Cloud Scheduler Job
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "⏰ [4/6] Creating Cloud Scheduler job..."
if gcloud scheduler jobs describe scheduled-publishing-trigger \
  --location="$REGION" \
  --project="$PROJECT_ID" 2>/dev/null; then
  echo "   ℹ️  Scheduler job already exists"
  echo "   Updating schedule..."
  gcloud scheduler jobs update pubsub scheduled-publishing-trigger \
    --location="$REGION" \
    --schedule="*/5 * * * *" \
    --project="$PROJECT_ID" || true
else
  gcloud scheduler jobs create pubsub scheduled-publishing-trigger \
    --location="$REGION" \
    --schedule="*/5 * * * *" \
    --time-zone="UTC" \
    --topic=scheduled-publishing \
    --message-body='{}' \
    --project="$PROJECT_ID"
  echo "✅ Cloud Scheduler job created"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: Grant IAM Permissions
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "🔐 [5/6] Configuring IAM permissions..."

SCHEDULER_SA="cloud-scheduler@system.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SCHEDULER_SA" \
  --role="roles/pubsub.publisher" \
  --quiet 2>/dev/null || echo "   ℹ️  IAM binding already exists"

echo "✅ IAM permissions configured"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6: Deploy Cloud Functions
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "🚀 [6/6] Building and deploying functions..."
cd functions
npm run build
firebase deploy --only functions --project="$PROJECT_ID"
cd ..
echo "✅ Functions deployed"

# ─────────────────────────────────────────────────────────────────────────────
# SUCCESS
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ SCHEDULED PUBLISHING IS READY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🧪 NEXT STEPS (Testing):"
echo ""
echo "1. Create a test scheduled video in your Flutter app"
echo "   - Upload video"
echo "   - Enable 'Schedule for later'"
echo "   - Set time to 2 minutes from now"
echo "   - Click 'Publish'"
echo ""
echo "2. Manually trigger the function:"
echo "   curl -X POST https://$REGION-$PROJECT_ID.cloudfunctions.net/manualTriggerPublishing \\"
echo "     -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{}'"
echo ""
echo "3. Check logs:"
echo "   firebase functions:log --only scheduledPublishing"
echo ""
echo "4. Monitor scheduled videos:"
echo "   curl -X GET https://$REGION-$PROJECT_ID.cloudfunctions.net/getScheduledVideos \\"
echo "     -H \"Authorization: Bearer \$(gcloud auth print-access-token)\""
echo ""
echo "📖 For detailed setup, see: SCHEDULED_PUBLISHING_SETUP.md"
echo ""
