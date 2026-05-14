#!/bin/bash

# 🚀 QUICK START: WINDOWS SCHEDULED PUBLISHING DEPLOYMENT
#
# This PowerShell script automates the setup of scheduled video publishing.
# Run this in your project root after cloning.
#
# Usage:
#   .\deploy-scheduled-publishing.ps1 -ProjectId <PROJECT_ID> -Region <REGION>
#
# Example:
#   .\deploy-scheduled-publishing.ps1 -ProjectId my-firebase-project -Region asia-south1

param(
    [Parameter(Mandatory=$true, HelpMessage="Your Google Cloud Project ID")]
    [string]$ProjectId,
    
    [Parameter(Mandatory=$false, HelpMessage="Region for Cloud Functions (default: asia-south1)")]
    [string]$Region = "asia-south1"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 SCHEDULED PUBLISHING SETUP (Windows)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Project ID: $ProjectId" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Set up gcloud configuration
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "📝 [1/6] Configuring gcloud..." -ForegroundColor Yellow
gcloud config set project $ProjectId
Write-Host "✅ Project configured" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Enable APIs
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "📡 [2/6] Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "cloudscheduler.googleapis.com",
    "firestore.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "  - Enabling $api..."
    gcloud services enable $api --project=$ProjectId
}
Write-Host "✅ APIs enabled" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Create Pub/Sub Topic
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "🔔 [3/6] Creating Pub/Sub topic..." -ForegroundColor Yellow
$topicExists = gcloud pubsub topics describe scheduled-publishing --project=$ProjectId 2>$null
if ($topicExists) {
    Write-Host "   ℹ️  Topic already exists" -ForegroundColor Cyan
} else {
    gcloud pubsub topics create scheduled-publishing --project=$ProjectId
    Write-Host "✅ Pub/Sub topic created" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: Create Cloud Scheduler Job
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "⏰ [4/6] Creating Cloud Scheduler job..." -ForegroundColor Yellow
$schedulerExists = gcloud scheduler jobs describe scheduled-publishing-trigger `
    --location=$Region `
    --project=$ProjectId 2>$null

if ($schedulerExists) {
    Write-Host "   ℹ️  Scheduler job already exists" -ForegroundColor Cyan
    Write-Host "   Updating schedule..." -ForegroundColor Cyan
    gcloud scheduler jobs update pubsub scheduled-publishing-trigger `
        --location=$Region `
        --schedule="*/5 * * * *" `
        --project=$ProjectId 2>$null
} else {
    gcloud scheduler jobs create pubsub scheduled-publishing-trigger `
        --location=$Region `
        --schedule="*/5 * * * *" `
        --time-zone="UTC" `
        --topic=scheduled-publishing `
        --message-body='{}' `
        --project=$ProjectId
    Write-Host "✅ Cloud Scheduler job created" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: Grant IAM Permissions
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "🔐 [5/6] Configuring IAM permissions..." -ForegroundColor Yellow

$schedulerSA = "cloud-scheduler@system.gserviceaccount.com"
gcloud projects add-iam-policy-binding $ProjectId `
    --member="serviceAccount:$schedulerSA" `
    --role="roles/pubsub.publisher" `
    --quiet 2>$null

Write-Host "✅ IAM permissions configured" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6: Deploy Cloud Functions
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "🚀 [6/6] Building and deploying functions..." -ForegroundColor Yellow
Push-Location functions
npm run build
firebase deploy --only functions --project=$ProjectId
Pop-Location
Write-Host "✅ Functions deployed" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# SUCCESS
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ SCHEDULED PUBLISHING IS READY!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "🧪 NEXT STEPS (Testing):" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Create a test scheduled video in your Flutter app" -ForegroundColor White
Write-Host "   - Upload video" -ForegroundColor Gray
Write-Host "   - Enable 'Schedule for later'" -ForegroundColor Gray
Write-Host "   - Set time to 2 minutes from now" -ForegroundColor Gray
Write-Host "   - Click 'Publish'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Manually trigger the function:" -ForegroundColor White
Write-Host "   `$token = gcloud auth print-access-token" -ForegroundColor Gray
Write-Host "   curl -X POST https://$Region-$ProjectId.cloudfunctions.net/manualTriggerPublishing ``" -ForegroundColor Gray
Write-Host "     -H `"Authorization: Bearer `$token`" ``" -ForegroundColor Gray
Write-Host "     -H `"Content-Type: application/json`" ``" -ForegroundColor Gray
Write-Host "     -d '{}'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Check logs:" -ForegroundColor White
Write-Host "   firebase functions:log --only scheduledPublishing" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Monitor scheduled videos:" -ForegroundColor White
Write-Host "   `$token = gcloud auth print-access-token" -ForegroundColor Gray
Write-Host "   curl -X GET https://$Region-$ProjectId.cloudfunctions.net/getScheduledVideos ``" -ForegroundColor Gray
Write-Host "     -H `"Authorization: Bearer `$token`"" -ForegroundColor Gray
Write-Host ""
Write-Host "📖 For detailed setup, see: SCHEDULED_PUBLISHING_SETUP.md" -ForegroundColor Cyan
Write-Host ""
