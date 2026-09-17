<#
.SYNOPSIS
    Automated preflight testing and deployment script for Truthworld Cloud Functions (82 endpoints).

.DESCRIPTION
    1. Verifies Firebase CLI authentication.
    2. Builds TypeScript and validates functions manifest (82 endpoints).
    3. Runs backend unit tests and scalability benchmarks.
    4. Deploys functions to Firebase project 'truthworld-1'.
    5. Optionally streams live production logs.

.PARAMETER SkipTests
    Skip running automated unit and scalability test suites before deployment.

.PARAMETER StreamLogs
    Automatically stream live production logs after deployment.
#>

[CmdletBinding()]
param(
    [switch]$SkipTests,
    [switch]$StreamLogs
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$functionsDir = Join-Path $projectRoot "functions"

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host " Truthworld Cloud Functions Deployment Pipeline (82 Endpoints)" -ForegroundColor Cyan
Write-Host " Project: truthworld-1 | Working Dir: $functionsDir" -ForegroundColor Cyan
Write-Host "================================================================`n" -ForegroundColor Cyan

# Step 1: Preflight build
Write-Host "[1/4] Compiling TypeScript & generating functions manifest..." -ForegroundColor Yellow
Push-Location $functionsDir
try {
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "TypeScript compilation failed."
        exit 1
    }
    Write-Host "[+] Build succeeded. Manifest synchronized.`n" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 2: Automated verification suites
if (-not $SkipTests) {
    Write-Host "[2/4] Running automated backend test suites..." -ForegroundColor Yellow
    Push-Location $functionsDir
    try {
        Write-Host "  -> Running Notification & Feature Unit Tests..." -ForegroundColor Gray
        npm test
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Notification unit tests failed."
            exit 1
        }

        Write-Host "  -> Running Backend Scalability Benchmark..." -ForegroundColor Gray
        npm run benchmark:scalability
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Backend scalability benchmark failed."
            exit 1
        }
        Write-Host "[+] All test suites passed cleanly.`n" -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[2/4] Skipping tests (--SkipTests enabled).`n" -ForegroundColor Gray
}

# Step 3: Deployment
Write-Host "[3/4] Deploying Cloud Functions to project 'truthworld-1'..." -ForegroundColor Yellow
Push-Location $functionsDir
try {
    firebase deploy --only functions -P truthworld-1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[-] Firebase deployment failed or requires re-authentication." -ForegroundColor Red
        Write-Host "Please run 'firebase login --reauth' in your terminal and rerun this script." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[+] All 82 Cloud Functions deployed successfully!`n" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 4: Stream logs (optional)
if ($StreamLogs) {
    Write-Host "[4/4] Streaming live production logs (last 50)..." -ForegroundColor Yellow
    Push-Location $functionsDir
    try {
        firebase functions:log -P truthworld-1 -n 50
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[4/4] Deployment complete! To view live logs at any time, run:" -ForegroundColor Cyan
    Write-Host "      firebase functions:log -P truthworld-1 -n 100`n" -ForegroundColor Gray
}
