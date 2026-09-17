<#
.SYNOPSIS
    Builds and deploys all 4 Flutter Web applications and 4 Flutter Android applications for Truthworld.

.DESCRIPTION
    Apps covered:
      1. Consumer App / Web   (lib/main.dart, flavor: app, target: web-app, dir: build/web_app)
      2. Creator Studio       (lib/main.dart, flavor: studio, target: studio-app, dir: build/web_studio)
      3. Admin & Moderation   (lib/main.dart, flavor: admin, target: admin-portal, dir: build/web_admin)
      4. Advertiser Portal    (lib/main.dart, flavor: advertiser, target: advertiser-app, dir: build/web_advertiser)

.PARAMETER SkipWeb
    Skip building Flutter Web apps.

.PARAMETER SkipAndroid
    Skip building Flutter Android apps.

.PARAMETER SkipDeploy
    Skip deployment steps (builds only).

.PARAMETER OnlyDeploy
    Skip build phase and only execute deployment.

.PARAMETER Target
    Specify a single target: 'app', 'studio', 'admin', 'advertiser', or 'all' (default).

.PARAMETER AndroidFormat
    'apk' (default), 'appbundle', or 'both'.
#>

[CmdletBinding()]
param(
    [switch]$SkipWeb,
    [switch]$SkipAndroid,
    [switch]$SkipDeploy,
    [switch]$OnlyDeploy,
    [ValidateSet('all', 'app', 'studio', 'admin', 'advertiser')]
    [string]$Target = 'all',
    [ValidateSet('apk', 'appbundle', 'both')]
    [string]$AndroidFormat = 'apk'
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Truthworld Multi-App Build & Deployment Pipeline" -ForegroundColor Cyan
Write-Host " Target: $Target | Web: $(!$SkipWeb) | Android: $(!$SkipAndroid) | Deploy: $(!$SkipDeploy)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# App configurations
$apps = @(
    @{
        Name        = "Consumer App"
        Id          = "app"
        Entry       = "lib/main.dart"
        Flavor      = "app"
        PackageId   = "com.truthworld.app"
        WebTarget   = "web-app"
        WebOutDir   = "build/web_app"
        ApkOutput   = "build/app/outputs/flutter-apk/app-app-release.apk"
        AabOutput   = "build/app/outputs/bundle/appRelease/app-app-release.aab"
    },
    @{
        Name        = "Creator Studio"
        Id          = "studio"
        Entry       = "lib/main.dart"
        Flavor      = "studio"
        PackageId   = "com.truthworld.studio"
        WebTarget   = "studio-app"
        WebOutDir   = "build/web_studio"
        ApkOutput   = "build/app/outputs/flutter-apk/app-studio-release.apk"
        AabOutput   = "build/app/outputs/bundle/studioRelease/app-studio-release.aab"
    },
    @{
        Name        = "Admin & Moderation"
        Id          = "admin"
        Entry       = "lib/main.dart"
        Flavor      = "admin"
        PackageId   = "com.truthworld.admin"
        WebTarget   = "admin-portal"
        WebOutDir   = "build/web_admin"
        ApkOutput   = "build/app/outputs/flutter-apk/app-admin-release.apk"
        AabOutput   = "build/app/outputs/bundle/adminRelease/app-admin-release.aab"
    },
    @{
        Name        = "Advertiser Portal"
        Id          = "advertiser"
        Entry       = "lib/main.dart"
        Flavor      = "advertiser"
        PackageId   = "com.truthworld.advertiser"
        WebTarget   = "advertiser-app"
        WebOutDir   = "build/web_advertiser"
        ApkOutput   = "build/app/outputs/flutter-apk/app-advertiser-release.apk"
        AabOutput   = "build/app/outputs/bundle/advertiserRelease/app-advertiser-release.aab"
    }
)

# Filter targets if specific target requested
if ($Target -ne 'all') {
    $apps = $apps | Where-Object { $_.Id -eq $Target }
}

# -----------------------------------------------------------------------------
# Function: Copy SEO and Static Web Assets
# -----------------------------------------------------------------------------
function Copy-WebAssets {
    param([string]$DestinationDir)
    
    $webSourceDir = Join-Path $projectRoot "web"
    if (-not (Test-Path $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }

    $seoFiles = @(
        "sitemap.xml",
        "sitemap-static.xml",
        "robots.txt",
        "truthworld-indexnow-key-2026.txt",
        "truthworld_indexnow_key_2026.txt",
        "flutter_service_worker.js",
        "flutter.js.map",
        "llms.txt",
        "llms-full.txt"
    )
    foreach ($file in $seoFiles) {
        $sourcePath = Join-Path $webSourceDir $file
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath (Join-Path $DestinationDir $file) -Force
        }
    }

    $wellKnownDir = Join-Path $webSourceDir ".well-known"
    if (Test-Path $wellKnownDir) {
        $destWellKnown = Join-Path $DestinationDir ".well-known"
        Copy-Item -Path $wellKnownDir -Destination $destWellKnown -Recurse -Force
    }
}

# -----------------------------------------------------------------------------
# Phase 1: Build Flutter Web Apps
# -----------------------------------------------------------------------------
if (-not $SkipWeb -and -not $OnlyDeploy) {
    Write-Host "`n>>> [1/3] Building Flutter Web Applications..." -ForegroundColor Yellow
    
    # 1. Compile unified web application to build/web_app
    Write-Host "`n--- Compiling Unified Web App: lib/main.dart -> build/web_app ---" -ForegroundColor Green
    $buildArgs = @("build", "web", "--release", "--source-maps", "--no-wasm-dry-run", "-t", "lib/main.dart", "-o", "build/web_app")
    flutter @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build Web application"
    }
    Copy-WebAssets -DestinationDir (Join-Path $projectRoot "build/web_app")
    Write-Host "[+] Successfully built unified web application in build/web_app" -ForegroundColor Green

    # 2. Synchronize build artifacts to other active web targets
    $targetsToSync = $apps | Where-Object { $_.WebOutDir -ne "build/web_app" }
    $sourceDir = Join-Path $projectRoot "build/web_app"
    foreach ($webApp in $targetsToSync) {
        $destDir = Join-Path $projectRoot $webApp.WebOutDir
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Write-Host "--- Synchronizing $($webApp.Name) -> $($webApp.WebOutDir) ---" -ForegroundColor Cyan
        Copy-Item -Path "$sourceDir\*" -Destination $destDir -Recurse -Force
        Copy-WebAssets -DestinationDir $destDir
        Write-Host "[+] Synchronized $($webApp.Name)" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# Phase 2: Build Flutter Android Apps
# -----------------------------------------------------------------------------
$releasesDir = Join-Path $projectRoot "releases\android"
if (-not (Test-Path $releasesDir)) {
    New-Item -ItemType Directory -Path $releasesDir -Force | Out-Null
}

if (-not $SkipAndroid -and -not $OnlyDeploy) {
    Write-Host "`n>>> [2/3] Building Flutter Android Applications..." -ForegroundColor Yellow
    
    foreach ($app in $apps) {
        Write-Host "`n--- Building Android: $($app.Name) (Flavor: $($app.Flavor), Entry: $($app.Entry)) ---" -ForegroundColor Green
        
        if ($AndroidFormat -eq 'apk' -or $AndroidFormat -eq 'both') {
            Write-Host "Building Release APK for $($app.Flavor)..." -ForegroundColor Cyan
            flutter build apk --release --flavor $app.Flavor -t $app.Entry
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to build APK for $($app.Name)"
            }

            # Locate and stage APK
            $sourceApk = Join-Path $projectRoot $app.ApkOutput
            if (Test-Path $sourceApk) {
                $targetApk = Join-Path $releasesDir "truthworld-$($app.Id)-release.apk"
                Copy-Item $sourceApk $targetApk -Force
                $hash = (Get-FileHash $targetApk -Algorithm SHA256).Hash
                $sizeMb = [math]::Round(((Get-Item $targetApk).Length / 1MB), 2)
                Write-Host ("[+] Staged APK: {0} ({1} MB, SHA256: {2})" -f $targetApk, $sizeMb, $hash) -ForegroundColor Green
            } else {
                Write-Warning "Could not find expected APK at $sourceApk"
            }
        }

        if ($AndroidFormat -eq 'appbundle' -or $AndroidFormat -eq 'both') {
            Write-Host "Building Release AppBundle for $($app.Flavor)..." -ForegroundColor Cyan
            flutter build appbundle --release --flavor $app.Flavor -t $app.Entry
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to build AppBundle for $($app.Name)"
            }

            $sourceAab = Join-Path $projectRoot $app.AabOutput
            if (Test-Path $sourceAab) {
                $targetAab = Join-Path $releasesDir "truthworld-$($app.Id)-release.aab"
                Copy-Item $sourceAab $targetAab -Force
                $sizeMb = [math]::Round(((Get-Item $targetAab).Length / 1MB), 2)
                Write-Host ("[+] Staged AppBundle: {0} ({1} MB)" -f $targetAab, $sizeMb) -ForegroundColor Green
            }
        }
    }
}

# -----------------------------------------------------------------------------
# Phase 3: Deployment Phase
# -----------------------------------------------------------------------------
if (-not $SkipDeploy) {
    Write-Host "`n>>> [3/3] Deployment Phase..." -ForegroundColor Yellow
    
    # Check Firebase CLI Authentication
    $firebaseAuthOk = $false
    try {
        $checkAuth = cmd /c "firebase projects:list 2>nul"
        if ($LASTEXITCODE -eq 0 -and ($checkAuth -match "truthworld-1")) {
            $firebaseAuthOk = $true
        }
    } catch {
        $firebaseAuthOk = $false
    }

    if ($firebaseAuthOk) {
        Write-Host "Firebase CLI authenticated. Deploying Hosting targets..." -ForegroundColor Green
        foreach ($app in $apps) {
            Write-Host "Deploying Hosting target: $($app.WebTarget) from $($app.WebOutDir)..." -ForegroundColor Cyan
            firebase deploy --only "hosting:$($app.WebTarget)"
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed deploying hosting:$($app.WebTarget)"
            } else {
                Write-Host "[+] Deployed hosting:$($app.WebTarget)" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "`n[NOTICE] Firebase CLI authentication is required to deploy hosting." -ForegroundColor Yellow
        Write-Host "To complete hosting deployment:" -ForegroundColor White
        Write-Host "  1. Run 'firebase login' in your terminal." -ForegroundColor White
        Write-Host "  2. Then run '.\scripts\build_and_deploy_all.ps1 -OnlyDeploy -SkipAndroid'" -ForegroundColor White
    }
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host " Build & Deployment Completed!" -ForegroundColor Cyan
Write-Host " Staged Android Releases: $releasesDir" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
