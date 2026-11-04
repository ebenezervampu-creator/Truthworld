# ==============================================================================
# TruthWorld 100% Native Google Cloud Platform (GCP) GPU Worker Deployer
# ==============================================================================
# Deploys LatentSync + CodeFormer to Google Cloud Run with an NVIDIA L4 GPU.
# Zero third-party services. All data stays within project: truthworld-1
# Scales to 0 instances when idle ($0/month idle cost).
# ==============================================================================

$PROJECT_ID = "truthworld-1"
$REGION = "us-central1"
$REPO_NAME = "truthworld-docker"
$IMAGE_NAME = "latentsync-worker"
$SERVICE_NAME = "truthworld-lipsync-worker"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 Deploying TruthWorld AI GPU Worker to Google Cloud Run" -ForegroundColor Cyan
Write-Host "   Project: $PROJECT_ID" -ForegroundColor Gray
Write-Host "   Region:  $REGION (GPU enabled)" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Set Project
gcloud config set project $PROJECT_ID

# 2. Enable Required Google Cloud APIs
Write-Host "`n1. Enabling Google Cloud APIs (Cloud Run, Cloud Build, Artifact Registry)..." -ForegroundColor Yellow
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project $PROJECT_ID

# 3. Create Artifact Registry Docker Repository if it does not exist
Write-Host "`n2. Ensuring Artifact Registry repository exists..." -ForegroundColor Yellow
gcloud artifacts repositories describe $REPO_NAME --location=$REGION --project=$PROJECT_ID 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Creating Artifact Registry repository '$REPO_NAME' in $REGION..." -ForegroundColor Gray
    gcloud artifacts repositories create $REPO_NAME `
        --repository-format=docker `
        --location=$REGION `
        --description="TruthWorld AI Container Repository" `
        --project=$PROJECT_ID
}

# 4. Build Container using Google Cloud Build
$FULL_IMAGE = "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME`:latest"
Write-Host "`n3. Building container image with Google Cloud Build..." -ForegroundColor Yellow
Write-Host "   Target image: $FULL_IMAGE" -ForegroundColor Gray

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
gcloud builds submit $SCRIPT_DIR --tag $FULL_IMAGE --project $PROJECT_ID

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Cloud Build failed. Please check the logs above." -ForegroundColor Red
    exit 1
}

# 5. Deploy to Google Cloud Run with NVIDIA L4 GPU
Write-Host "`n4. Deploying to Google Cloud Run with NVIDIA L4 GPU..." -ForegroundColor Yellow
Write-Host "   Configuration: 1x NVIDIA L4 GPU, 4 vCPU, 16GB RAM, auto-scale down to 0" -ForegroundColor Gray

gcloud beta run deploy $SERVICE_NAME `
    --image $FULL_IMAGE `
    --region $REGION `
    --project $PROJECT_ID `
    --gpu 1 `
    --gpu-type nvidia-l4 `
    --cpu 4 `
    --memory 16Gi `
    --no-cpu-throttling `
    --no-gpu-zonal-redundancy `
    --min-instances 0 `
    --max-instances 2 `
    --timeout 600 `
    --allow-unauthenticated

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Cloud Run deployment failed." -ForegroundColor Red
    exit 1
}

# 6. Retrieve Service URL
$SERVICE_URL = gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --project $PROJECT_ID --format 'value(status.url)'

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "✅ TruthWorld GPU Worker Deployed Successfully to Google Cloud!" -ForegroundColor Green
Write-Host "   Service URL: $SERVICE_URL" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green

Write-Host "`nNext Step: Set this URL in your Firebase Functions environment:" -ForegroundColor Yellow
Write-Host "   firebase functions:secrets:set LIPSYNC_SERVICE_URL" -ForegroundColor Cyan
Write-Host "   (Paste: $SERVICE_URL)" -ForegroundColor Gray
