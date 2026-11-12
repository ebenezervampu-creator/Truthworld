<#
.SYNOPSIS
    Builds production release artifacts for TruthWorld with full R8 & Dart code obfuscation,
    symbol stripping, and pre-build security integrity verification.

.DESCRIPTION
    Security guarantees applied:
      1. Pre-build automated security suite test run (RASP, SSL Pinning, Screen Security).
      2. Dart symbol stripping & obfuscation (--obfuscate --split-debug-info).
      3. R8 / ProGuard bytecode minification & debug log removal.
      4. SHA-256 checksum generation for integrity auditing.

.PARAMETER Flavor
    'app' (default), 'studio', 'admin', or 'advertiser'.

.PARAMETER Format
    'appbundle' (default for Google Play) or 'apk' (for direct release testing).

.PARAMETER SkipTests
    Skips the pre-build security test suite (not recommended for production).
#>

[CmdletBinding()]
param(
    [ValidateSet('app', 'studio', 'admin', 'advertiser')]
    [string]$Flavor = 'app',

    [ValidateSet('appbundle', 'apk')]
    [string]$Format = 'appbundle',

    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " TruthWorld Secure Production Release Builder" -ForegroundColor Cyan
Write-Host " Flavor: $Flavor | Format: $Format | Obfuscation: ENABLED" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Phase 1: Pre-Build Security Verification Suite
# -----------------------------------------------------------------------------
if (-not $SkipTests) {
    Write-Host "`n>>> [1/3] Running Pre-Build Security Verification Suite..." -ForegroundColor Yellow
    flutter test test/core/security/
    if ($LASTEXITCODE -ne 0) {
        throw "Security test suite failed! Release build aborted to prevent deploying vulnerable code."
    }

    flutter test test/core/ui_contrast_guard_test.dart
    if ($LASTEXITCODE -ne 0) {
        throw "UI Contrast verification failed! Release build aborted."
    }
    Write-Host "[+] All security and contrast guards passed." -ForegroundColor Green
} else {
    Write-Warning "Skipping security tests as requested."
}

# -----------------------------------------------------------------------------
# Phase 2: Obfuscated Build Execution
# -----------------------------------------------------------------------------
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$symbolsDir = Join-Path $projectRoot "build\app\outputs\symbols\$Flavor\$timestamp"
if (-not (Test-Path $symbolsDir)) {
    New-Item -ItemType Directory -Path $symbolsDir -Force | Out-Null
}

$releasesDir = Join-Path $projectRoot "releases\android"
if (-not (Test-Path $releasesDir)) {
    New-Item -ItemType Directory -Path $releasesDir -Force | Out-Null
}

$entryPoint = if (Test-Path (Join-Path $projectRoot "lib/main_$Flavor.dart")) { "lib/main_$Flavor.dart" } else { "lib/main.dart" }

Write-Host "`n>>> [2/3] Compiling Secure Release Artifact ($Format)..." -ForegroundColor Yellow
Write-Host "Target Entry Point:       $entryPoint" -ForegroundColor Cyan
Write-Host "Output symbols directory: $symbolsDir" -ForegroundColor Cyan

if ($Format -eq 'appbundle') {
    flutter build appbundle --release --flavor $Flavor -t $entryPoint --obfuscate --split-debug-info=$symbolsDir
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to compile AppBundle for flavor: $Flavor"
    }

    $source = Join-Path $projectRoot "build\app\outputs\bundle\${Flavor}Release\app-$Flavor-release.aab"
    $destination = Join-Path $releasesDir "truthworld-$Flavor-release-$timestamp.aab"
} else {
    flutter build apk --release --flavor $Flavor -t $entryPoint --obfuscate --split-debug-info=$symbolsDir
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to compile APK for flavor: $Flavor"
    }

    $source = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$Flavor-release.apk"
    $destination = Join-Path $releasesDir "truthworld-$Flavor-release-$timestamp.apk"
}

# -----------------------------------------------------------------------------
# Phase 3: Integrity Checksum & Symbol Archival
# -----------------------------------------------------------------------------
Write-Host "`n>>> [3/3] Generating Artifact Checksums & Integrity Metadata..." -ForegroundColor Yellow

if (Test-Path $source) {
    Copy-Item $source $destination -Force
    $hash = (Get-FileHash $destination -Algorithm SHA256).Hash
    $sizeMb = [math]::Round(((Get-Item $destination).Length / 1MB), 2)

    Write-Host "`n================================================================" -ForegroundColor Green
    Write-Host " SUCCESSFUL SECURE RELEASE BUILD" -ForegroundColor Green
    Write-Host " Artifact:  $destination" -ForegroundColor Green
    Write-Host " File Size: $sizeMb MB" -ForegroundColor Green
    Write-Host " SHA-256:   $hash" -ForegroundColor Green
    Write-Host " Symbols:   $symbolsDir" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
} else {
    throw "Build artifact was not found at expected path: $source"
}
