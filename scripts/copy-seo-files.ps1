# Copy SEO files to build directories after Flutter build
# This script copies sitemap.xml, robots.txt, llms.txt, and web metadata to web build directories

[CmdletBinding()]
param(
    [string]$TargetDir = ""
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$webDir = Join-Path $projectRoot "web"

$candidateDirs = @()
if ($TargetDir -and $TargetDir.Trim().Length -gt 0) {
    $candidateDirs += (Join-Path $projectRoot $TargetDir)
} else {
    $candidateDirs = @(
        (Join-Path $projectRoot "build\web_app"),
        (Join-Path $projectRoot "build\web_studio"),
        (Join-Path $projectRoot "build\web_admin"),
        (Join-Path $projectRoot "build\web_advertiser"),
        (Join-Path $projectRoot "build\web_dubbing"),
        (Join-Path $projectRoot "build\web")
    )
}

$activeDirs = $candidateDirs | Where-Object { Test-Path $_ }

if ($activeDirs.Count -eq 0) {
    Write-Host "Warning: No web build output directories found. Run 'flutter build web' first." -ForegroundColor Yellow
    exit 0
}

Write-Host "Copying SEO and web metadata files to build directories..." -ForegroundColor Green

$filesToCopy = @(
    "sitemap.xml",
    "sitemap-static.xml",
    "robots.txt",
    "truthworld-indexnow-key-2026.txt",
    "truthworld_indexnow_key_2026.txt",
    "flutter_service_worker.js",
    "flutter.js.map",
    "llms.txt",
    "llms-full.txt",
    "favicon.ico",
    "favicon.png",
    "favicon-48x48.png",
    "manifest.json"
)

foreach ($buildWebDir in $activeDirs) {
    Write-Host "`nTarget: $buildWebDir" -ForegroundColor Cyan
    foreach ($file in $filesToCopy) {
        $src = Join-Path $webDir $file
        $dest = Join-Path $buildWebDir $file
        if (Test-Path $src) {
            Copy-Item $src $dest -Force
            Write-Host "  [+] Copied $file" -ForegroundColor Green
        }
    }

    $iconsDir = Join-Path $webDir "icons"
    if (Test-Path $iconsDir) {
        $destIcons = Join-Path $buildWebDir "icons"
        if (-not (Test-Path $destIcons)) {
            New-Item -ItemType Directory -Path $destIcons -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $iconsDir "*") -Destination $destIcons -Recurse -Force
        Write-Host "  [+] Copied icons folder" -ForegroundColor Green
    }

    $wellKnownDir = Join-Path $webDir ".well-known"
    if (Test-Path $wellKnownDir) {
        $destWellKnown = Join-Path $buildWebDir ".well-known"
        Copy-Item -Path $wellKnownDir -Destination $destWellKnown -Recurse -Force
        Write-Host "  [+] Copied .well-known" -ForegroundColor Green
    }
}

Write-Host "`nSEO and Web assets synchronized successfully!" -ForegroundColor Green

