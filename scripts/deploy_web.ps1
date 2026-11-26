# ============================================================
#  TruthWorld Web Deploy Script (WebAssembly Ready)
#  Usage: .\scripts\deploy_web.ps1 [-Target web-app|studio-app|admin-portal|advertiser-app|all|web-app,studio-app] [-NoWasm]
#         .\scripts\deploy_web.ps1          (defaults to all targets with Wasm enabled)
#
#  What it does on every run:
#    1. Bumps the build number in pubspec.yaml
#    2. Generates web/version.json  (force-updates every user globally)
#    3. Builds Flutter web with WebAssembly (--wasm) + JS fallback
#    4. Copies version.json + .well-known into each build output
#    5. Synchronizes SEO and web metadata files (sitemap, robots, icons, etc.)
#    6. Deploys to Firebase Hosting (all or selected target)
# ============================================================
param(
    [string]$Target = "all",
    [switch]$NoWasm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ROOT    = Split-Path $PSScriptRoot -Parent
$PUBSPEC = Join-Path $ROOT "pubspec.yaml"
$WEB_DIR = Join-Path $ROOT "web"

# ── Output helpers ───────────────────────────────────────────
function Info  { param($m) Write-Host "  $m"       -ForegroundColor Cyan    }
function OK    { param($m) Write-Host "  [OK] $m"  -ForegroundColor Green   }
function Warn  { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow  }
function Fail  { param($m) Write-Host "  [FAIL] $m" -ForegroundColor Red; exit 1 }
function Step  { param($m) Write-Host "`n=== $m ===" -ForegroundColor Magenta }

# ── 1. Bump build number in pubspec.yaml ────────────────────
Step "Bumping build number"
$content = Get-Content $PUBSPEC -Raw
if ($content -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    $semver      = $Matches[1]
    $buildNumber = [int]$Matches[2] + 1
    $newVersion  = "$semver+$buildNumber"
    $content     = $content -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion"
    Set-Content $PUBSPEC $content -NoNewline
    OK "pubspec.yaml -> version: $newVersion"
} else {
    Warn "Could not parse version from pubspec.yaml - skipping bump"
    $semver      = "1.0.0"
    $buildNumber = [int](Get-Date -Format "yyyyMMddHHmm")
    $newVersion  = "$semver+$buildNumber"
}

# ── 2. Generate web/version.json ─────────────────────────────
Step "Generating version.json"
$deployTime = (Get-Date).ToUniversalTime().ToString("o")
$versionObj = [ordered]@{
    version      = $semver
    build_number = $buildNumber
    signature    = "$semver-$buildNumber"
    deployed_at  = $deployTime
    cache_bust   = [System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}
$versionJson = $versionObj | ConvertTo-Json -Compress
$versionOutPath = Join-Path $WEB_DIR "version.json"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($versionOutPath, $versionJson, $utf8NoBom)
OK "web/version.json: $versionJson"

# ── 3. Flutter pub get ───────────────────────────────────────
Step "flutter pub get"
Push-Location $ROOT
flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get failed" }
OK "Dependencies resolved"

# ── Helper: build one Flutter web flavor ────────────────────
function Build-Flavor {
    param(
        [string]$EntryPoint,
        [string]$OutputDir,
        [string]$Label
    )
    Step "Building $Label"
    Info "Entry point : $EntryPoint"
    Info "Output dir  : $OutputDir"
    Info "Wasm mode   : $(if ($NoWasm) { 'Disabled (JS only)' } else { 'Enabled (Wasm + JS fallback)' })"

    if ($NoWasm) {
        flutter build web `
            --release `
            --no-tree-shake-icons `
            --no-wasm-dry-run `
            --target=$EntryPoint `
            --output=$OutputDir
    } else {
        flutter build web `
            --wasm `
            --no-tree-shake-icons `
            --target=$EntryPoint `
            --output=$OutputDir
    }

    if ($LASTEXITCODE -ne 0) { Fail "Build failed for $Label" }

    # Copy version.json into the build output
    $versionDst = Join-Path $ROOT "$OutputDir\version.json"
    [System.IO.File]::WriteAllText($versionDst, $versionJson, $utf8NoBom)
    OK "version.json copied -> $OutputDir"

    # Copy sw.js into the build output
    $swSrc = Join-Path $WEB_DIR "sw.js"
    $swDst = Join-Path $ROOT "$OutputDir\sw.js"
    if (Test-Path $swSrc) {
        Copy-Item $swSrc $swDst -Force
        OK "sw.js copied -> $OutputDir/sw.js"
    }

    # Copy safe flutter_service_worker.js into build output to prevent infinite reload loops
    $fswSrc = Join-Path $WEB_DIR "flutter_service_worker.js"
    $fswDst = Join-Path $ROOT "$OutputDir\flutter_service_worker.js"
    if (Test-Path $fswSrc) {
        Copy-Item $fswSrc $fswDst -Force
        OK "flutter_service_worker.js copied -> $OutputDir/flutter_service_worker.js"
    }

    # Copy .well-known folder
    $wellKnownSrc = Join-Path $WEB_DIR ".well-known"
    $wellKnownDst = Join-Path $ROOT "$OutputDir\.well-known"
    if (Test-Path $wellKnownSrc) {
        Copy-Item $wellKnownSrc $wellKnownDst -Recurse -Force
        OK ".well-known copied -> $OutputDir/.well-known"
    }

    OK "$Label build complete"
}

# ── 4. Build selected targets ────────────────────────────────
$rawTargets = $Target -split ',' | ForEach-Object { $_.Trim().ToLower() }
$targetList = @()
foreach ($t in $rawTargets) {
    switch ($t) {
        "consumer"   { $targetList += "web-app" }
        "web"        { $targetList += "web-app" }
        "web_app"    { $targetList += "web-app" }
        "studio"     { $targetList += "studio-app" }
        "studio_app" { $targetList += "studio-app" }
        "admin"      { $targetList += "admin-portal" }
        "advertiser" { $targetList += "advertiser-app" }
        "dubbing"    { $targetList += "dubbing-app" }
        "dubbing_app" { $targetList += "dubbing-app" }
        default      { $targetList += $t }
    }
}
$isAll = $Target.ToLower() -eq "all"
$buildWebApp     = $isAll -or ($targetList -contains "web-app")
$buildStudio     = $isAll -or ($targetList -contains "studio-app")
$buildAdmin      = $isAll -or ($targetList -contains "admin-portal")
$buildAdvertiser = $isAll -or ($targetList -contains "advertiser-app")
$buildDubbing    = $isAll -or ($targetList -contains "dubbing-app")

if ($buildWebApp) {
    Build-Flavor -EntryPoint "lib/main.dart" -OutputDir "build/web_app" -Label "Web App (Consumer)"
}
if ($buildStudio) {
    $studioEntry = if (Test-Path (Join-Path $ROOT "lib/main_studio.dart")) { "lib/main_studio.dart" } else { "lib/main.dart" }
    Build-Flavor -EntryPoint $studioEntry -OutputDir "build/web_studio" -Label "Studio App"
}
if ($buildAdmin) {
    $adminEntry = if (Test-Path (Join-Path $ROOT "lib/main_admin.dart")) { "lib/main_admin.dart" } else { "lib/main.dart" }
    Build-Flavor -EntryPoint $adminEntry -OutputDir "build/web_admin" -Label "Admin Portal"
}
if ($buildAdvertiser) {
    $advertiserEntry = if (Test-Path (Join-Path $ROOT "lib/main_advertiser.dart")) { "lib/main_advertiser.dart" } else { "lib/main.dart" }
    Build-Flavor -EntryPoint $advertiserEntry -OutputDir "build/web_advertiser" -Label "Advertiser Portal"
}
if ($buildDubbing) {
    $dubbingEntry = if (Test-Path (Join-Path $ROOT "lib/main_dubbing.dart")) { "lib/main_dubbing.dart" } else { "lib/main.dart" }
    Build-Flavor -EntryPoint $dubbingEntry -OutputDir "build/web_dubbing" -Label "Dubbing Studio"
}

# ── 5. Synchronize SEO and Web assets ────────────────────────
$copySeoScript = Join-Path $PSScriptRoot "copy-seo-files.ps1"
if (Test-Path $copySeoScript) {
    Step "Synchronizing SEO and Web metadata files"
    & $copySeoScript
}

# ── 6. Deploy to Firebase Hosting ────────────────────────────
Step "Deploying to Firebase Hosting"
if ($isAll) {
    firebase deploy --only "hosting:web-app,hosting:studio-app,hosting:admin-portal,hosting:advertiser-app,hosting:dubbing-app" --force
} else {
    $deployTargets = ($targetList | ForEach-Object { "hosting:$_" }) -join ","
    firebase deploy --only $deployTargets --force
}
if ($LASTEXITCODE -ne 0) { Fail "Firebase deploy failed" }

Pop-Location
Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  DEPLOYED SUCCESSFULLY!  version: $newVersion"        -ForegroundColor Green
Write-Host "  All global users will auto-refresh within 90 seconds" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
