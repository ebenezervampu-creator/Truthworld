# ==============================================================================
# TruthWorld: Rotate & Clean AI Secrets (Sarvam AI, AssemblyAI, ElevenLabs)
# Project: truthworld-1
# ==============================================================================

[CmdletBinding()]
param(
    [string]$ProjectId = "truthworld-1",
    [string]$AssemblyAiKey = "",
    [string]$ElevenLabsApiKey = "",
    [string]$SarvamApiKey = "",
    [switch]$Interactive,
    [switch]$DestroyOldVersions,
    [switch]$UpdateLocalEnv
)

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " TruthWorld AI Secrets Rotation & Cleanup" -ForegroundColor Cyan
Write-Host " Target Project: $ProjectId" -ForegroundColor Cyan
Write-Host "==========================================================`n" -ForegroundColor Cyan

# 1. Interactive input if requested or parameters empty
if ($Interactive -or (-not $AssemblyAiKey -and -not $ElevenLabsApiKey -and -not $SarvamApiKey)) {
    Write-Host "Please enter the new production API keys (press Enter to skip any key):" -ForegroundColor Yellow

    if (-not $AssemblyAiKey) {
        $sec = Read-Host -AsSecureString "Enter New AssemblyAI API Key"
        if ($sec) {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
            $AssemblyAiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        }
    }

    if (-not $ElevenLabsApiKey) {
        $sec = Read-Host -AsSecureString "Enter New ElevenLabs API Key"
        if ($sec) {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
            $ElevenLabsApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        }
    }

    if (-not $SarvamApiKey) {
        $sec = Read-Host -AsSecureString "Enter New Sarvam AI API Key"
        if ($sec) {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
            $SarvamApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        }
    }
}

function Rotate-Secret {
    param(
        [string]$SecretName,
        [string]$SecretValue,
        [bool]$PurgeOld
    )

    if (-not $SecretValue) {
        Write-Host "[-] Skipping $SecretName (no new key provided)" -ForegroundColor Gray
        return
    }

    Write-Host "`n[*] Processing '$SecretName'..." -ForegroundColor Cyan

    # Ensure secret exists
    $exists = gcloud secrets describe $SecretName --project=$ProjectId 2>$null
    if (-not $exists) {
        Write-Host "  [+] Creating secret container '$SecretName'..." -ForegroundColor Green
        gcloud secrets create $SecretName --replication-policy="automatic" --project=$ProjectId
    }

    # Add new secret version
    Write-Host "  [+] Uploading new secret version for '$SecretName'..." -ForegroundColor Green
    $addOutput = $SecretValue | gcloud secrets versions add $SecretName --data-file=- --project=$ProjectId --format="value(name)"
    Write-Host "  [✓] New version added: $addOutput" -ForegroundColor Green

    # Ensure permissions for Cloud Functions runtime service accounts
    $projectNumber = gcloud projects describe $ProjectId --format="value(projectNumber)"
    $computeSa = "$projectNumber-compute@developer.gserviceaccount.com"
    $appengineSa = "$ProjectId@appspot.gserviceaccount.com"

    gcloud secrets add-iam-policy-binding $SecretName `
        --member="serviceAccount:$computeSa" `
        --role="roles/secretmanager.secretAccessor" `
        --project=$ProjectId 2>$null | Out-Null

    gcloud secrets add-iam-policy-binding $SecretName `
        --member="serviceAccount:$appengineSa" `
        --role="roles/secretmanager.secretAccessor" `
        --project=$ProjectId 2>$null | Out-Null

    # Purge old versions if requested
    if ($PurgeOld) {
        Write-Host "  [*] Inspecting previous versions to destroy for '$SecretName'..." -ForegroundColor Yellow
        $versions = gcloud secrets versions list $SecretName --project=$ProjectId --filter="state:ENABLED" --format="json" | ConvertFrom-Json
        
        # Sort descending by version number
        $sorted = $versions | Sort-Object { [int]($_.name -split '/')[-1] } -Descending
        
        if ($sorted.Count -gt 1) {
            # The newest enabled version is index 0; destroy older versions
            $oldVersions = $sorted | Select-Object -Skip 1
            foreach ($old in $oldVersions) {
                $vNum = ($old.name -split '/')[-1]
                Write-Host "  [-] Destroying old version $vNum for '$SecretName'..." -ForegroundColor Yellow
                gcloud secrets versions destroy $vNum --secret=$SecretName --project=$ProjectId --quiet | Out-Null
                Write-Host "  [✓] Old version $vNum destroyed." -ForegroundColor Green
            }
        } else {
            Write-Host "  [i] No prior enabled versions found to destroy." -ForegroundColor Gray
        }
    }
}

# Rotate production secrets
Rotate-Secret -SecretName "ASSEMBLYAI_KEY" -SecretValue $AssemblyAiKey -PurgeOld $DestroyOldVersions
Rotate-Secret -SecretName "ELEVENLABS_API_KEY" -SecretValue $ElevenLabsApiKey -PurgeOld $DestroyOldVersions
Rotate-Secret -SecretName "SARVAM_API_KEY" -SecretValue $SarvamApiKey -PurgeOld $DestroyOldVersions

# Optional local .env.local update for testing
if ($UpdateLocalEnv) {
    $envLocalPath = Join-Path $PSScriptRoot "..functions\.env.local"
    Write-Host "`n[*] Updating local emulator secrets in: $envLocalPath" -ForegroundColor Cyan
    
    $lines = @()
    if (Test-Path $envLocalPath) {
        $lines = Get-Content $envLocalPath | Where-Object {
            $_ -notmatch "^ASSEMBLYAI_KEY=" -and
            $_ -notmatch "^ELEVENLABS_API_KEY=" -and
            $_ -notmatch "^SARVAM_API_KEY="
        }
    }
    
    if ($AssemblyAiKey) { $lines += "ASSEMBLYAI_KEY=$AssemblyAiKey" }
    if ($ElevenLabsApiKey) { $lines += "ELEVENLABS_API_KEY=$ElevenLabsApiKey" }
    if ($SarvamApiKey) { $lines += "SARVAM_API_KEY=$SarvamApiKey" }
    
    Set-Content -Path $envLocalPath -Value $lines -Encoding utf8
    Write-Host "  [✓] Local .env.local updated with new testing keys." -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [✓] Secret rotation workflow complete!" -ForegroundColor Green
Write-Host " Next steps:" -ForegroundColor White
Write-Host " 1. Deploy Cloud Functions with latest secrets: cd functions; npm run deploy" -ForegroundColor White
Write-Host " 2. Revoke/Delete old keys in external dashboards (Sarvam, AssemblyAI, ElevenLabs)" -ForegroundColor White
Write-Host "==========================================================`n" -ForegroundColor Cyan
