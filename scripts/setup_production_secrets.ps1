# ==============================================================================
# TruthWorld: Google Cloud Secret Manager Production Provisioning Script
# Project: truthworld-1
# Region: asia-south1
# ==============================================================================

param(
    [string]$ProjectId = "truthworld-1",
    [string]$CashfreeAppId,
    [string]$CashfreeSecretKey,
    [string]$AssemblyAiKey = "",
    [string]$ElevenLabsApiKey = "",
    [string]$SarvamApiKey = "",
    [string]$IndexNowKey = "truthworld-indexnow-key-2026"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " TruthWorld Production Secret Manager Setup" -ForegroundColor Cyan
Write-Host " Target Project: $ProjectId" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Prompt for keys if not passed as parameters
if (-not $CashfreeAppId) {
    $CashfreeAppId = Read-Host "Enter Cashfree Production Client ID (CASHFREE_APP_ID)"
}

if (-not $CashfreeSecretKey) {
    $CashfreeSecretKey = Read-Host -AsSecureString "Enter Cashfree Production Secret Key (CASHFREE_SECRET_KEY)"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CashfreeSecretKey)
    $CashfreeSecretKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

function Set-GcpSecret {
    param(
        [string]$SecretName,
        [string]$SecretValue
    )

    if (-not $SecretValue) {
        Write-Host "[-] Skipping $SecretName (empty value)" -ForegroundColor Yellow
        return
    }

    Write-Host "[*] Checking secret '$SecretName' in project '$ProjectId'..." -ForegroundColor Yellow
    
    # Check if secret already exists
    $exists = gcloud secrets describe $SecretName --project=$ProjectId 2>$null
    if (-not $exists) {
        Write-Host "[+] Creating secret '$SecretName'..." -ForegroundColor Green
        gcloud secrets create $SecretName --replication-policy="automatic" --project=$ProjectId
    }

    # Add a new secret version
    Write-Host "[+] Adding new secret version for '$SecretName'..." -ForegroundColor Green
    $SecretValue | gcloud secrets versions add $SecretName --data-file=- --project=$ProjectId

    # Grant Secret Accessor role to Cloud Functions default runtime service account
    $projectNumber = gcloud projects describe $ProjectId --format="value(projectNumber)"
    $computeSa = "$projectNumber-compute@developer.gserviceaccount.com"
    $appengineSa = "$ProjectId@appspot.gserviceaccount.com"

    gcloud secrets add-iam-policy-binding $SecretName `
        --member="serviceAccount:$computeSa" `
        --role="roles/secretmanager.secretAccessor" `
        --project=$ProjectId 2>$null

    gcloud secrets add-iam-policy-binding $SecretName `
        --member="serviceAccount:$appengineSa" `
        --role="roles/secretmanager.secretAccessor" `
        --project=$ProjectId 2>$null

    Write-Host "[✓] '$SecretName' successfully configured with access permissions." -ForegroundColor Green
}

Set-GcpSecret -SecretName "CASHFREE_APP_ID" -SecretValue $CashfreeAppId
Set-GcpSecret -SecretName "CASHFREE_SECRET_KEY" -SecretValue $CashfreeSecretKey

if ($AssemblyAiKey) {
    Set-GcpSecret -SecretName "ASSEMBLYAI_KEY" -SecretValue $AssemblyAiKey
}

if ($ElevenLabsApiKey) {
    Set-GcpSecret -SecretName "ELEVENLABS_API_KEY" -SecretValue $ElevenLabsApiKey
}

if ($SarvamApiKey) {
    Set-GcpSecret -SecretName "SARVAM_API_KEY" -SecretValue $SarvamApiKey
}

if ($IndexNowKey) {
    Set-GcpSecret -SecretName "INDEXNOW_KEY" -SecretValue $IndexNowKey
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [✓] All production secrets provisioned successfully!" -ForegroundColor Green
Write-Host " Next step: Deploy functions with: cd functions; npm run deploy" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
