# Copy SEO files to build directory after Flutter build
# This script copies sitemap.xml and robots.txt from web/ to build/web/

$projectRoot = Split-Path -Parent $PSScriptRoot
$webDir = Join-Path $projectRoot "web"
$buildWebDir = Join-Path $projectRoot "build\web"

Write-Host "Copying SEO files to build directory..." -ForegroundColor Green

# Check if build/web directory exists
if (-not (Test-Path $buildWebDir)) {
    Write-Host "Error: build/web directory not found. Run 'flutter build web' first." -ForegroundColor Red
    exit 1
}

# Copy sitemap.xml
$sitemapSource = Join-Path $webDir "sitemap.xml"
$sitemapDest = Join-Path $buildWebDir "sitemap.xml"
if (Test-Path $sitemapSource) {
    Copy-Item $sitemapSource $sitemapDest -Force
    Write-Host "✓ Copied sitemap.xml" -ForegroundColor Green
} else {
    Write-Host "Warning: sitemap.xml not found in web/" -ForegroundColor Yellow
}

# Copy robots.txt
$robotsSource = Join-Path $webDir "robots.txt"
$robotsDest = Join-Path $buildWebDir "robots.txt"
if (Test-Path $robotsSource) {
    Copy-Item $robotsSource $robotsDest -Force
    Write-Host "✓ Copied robots.txt" -ForegroundColor Green
} else {
    Write-Host "Warning: robots.txt not found in web/" -ForegroundColor Yellow
}

Write-Host "SEO files copied successfully!" -ForegroundColor Green
