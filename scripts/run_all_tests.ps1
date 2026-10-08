# 🚀 TRUTHWORLD UNIFIED TEST & BENCHMARK ORCHESTRATOR
#
# Runs all required test categories across TruthWorld:
# 1. Backend Unit Tests
# 2. Backend Scalability Tests
# 3. Backend P95/P99 High-Resolution Latency Benchmark
# 4. k6 Performance & Load Testing Suite (Edge CDN, SEO, Search, Heartbeat, Comments, E2E)
# 5. HomeScreen Unit & P95/P99 Low-Latency Benchmark Tests
# 6. VideoScreen Unit & P95/P99 Low-Latency Benchmark Tests
# 7. Frontend Accessibility & Contrast Guard Tests
# 8. Frontend Core Scalability & Feed Caching Suites

$ErrorActionPreference = "Stop"

Write-Host "=========================================================================================" -ForegroundColor Cyan
Write-Host "⚡ TRUTHWORLD UNIFIED TEST & SLA BENCHMARK EXECUTION" -ForegroundColor Cyan
Write-Host "=========================================================================================`n" -ForegroundColor Cyan

$root = Split-Path -Parent $PSScriptRoot

# 1. Backend Unit Tests
Write-Host "--- [1/8] Running Backend Unit Tests (Cloud Functions) ---" -ForegroundColor Yellow
Push-Location "$root\functions"
try {
    npm run test:unit
    if ($LASTEXITCODE -ne 0) { throw "Backend Unit Tests Failed" }
} finally {
    Pop-Location
}

# 2. Backend Scalability Suite
Write-Host "`n--- [2/8] Running Backend Scalability Suite (50,000 Operations) ---" -ForegroundColor Yellow
Push-Location "$root\functions"
try {
    npm run test:scalability
    if ($LASTEXITCODE -ne 0) { throw "Backend Scalability Tests Failed" }
} finally {
    Pop-Location
}

# 3. Backend P95 / P99 Latency SLA Verification
Write-Host "`n--- [3/8] Running Backend P95 & P99 Latency Benchmark Suite ---" -ForegroundColor Yellow
Push-Location "$root\functions"
try {
    npm run test:p95-p99
    if ($LASTEXITCODE -ne 0) { throw "Backend P95/P99 Latency Tests Failed" }
} finally {
    Pop-Location
}

# 4. k6 Performance & Load Test Suite
Write-Host "`n--- [4/8] Running k6 Performance & Load Test Scenarios (8 Scenarios) ---" -ForegroundColor Yellow
Push-Location "$root\functions"
try {
    npm run test:k6
    if ($LASTEXITCODE -ne 0) { throw "k6 Load Tests Failed" }
} finally {
    Pop-Location
}

# 5. HomeScreen Unit & P95/P99 Low-Latency Benchmarks
Write-Host "`n--- [5/8] Running HomeScreen Unit & P95/P99 Low-Latency Benchmarks ---" -ForegroundColor Yellow
Push-Location "$root"
try {
    flutter test test/features/home/home_screen_unit_test.dart test/features/home/home_screen_latency_benchmark_test.dart test/features/home/home_feed_modular_test.dart
    if ($LASTEXITCODE -ne 0) { throw "HomeScreen Performance & Unit Tests Failed" }
} finally {
    Pop-Location
}

# 6. VideoScreen Unit & P95/P99 Low-Latency Benchmarks
Write-Host "`n--- [6/8] Running VideoScreen Unit & P95/P99 Low-Latency Benchmarks ---" -ForegroundColor Yellow
Push-Location "$root"
try {
    flutter test test/features/video/video_screen_unit_test.dart test/features/video/video_screen_latency_benchmark_test.dart test/features/video/video_screen_modular_test.dart
    if ($LASTEXITCODE -ne 0) { throw "VideoScreen Performance & Unit Tests Failed" }
} finally {
    Pop-Location
}

# 7. Frontend Accessibility & UI Contrast Guard Test
Write-Host "`n--- [7/8] Running Flutter Accessibility & UI Contrast Guard ---" -ForegroundColor Yellow
Push-Location "$root"
try {
    flutter test test/core/ui_contrast_guard_test.dart
    if ($LASTEXITCODE -ne 0) { throw "Flutter Contrast Guard Tests Failed" }
} finally {
    Pop-Location
}

# 8. Frontend Core Scalability & Caching Benchmarks
Write-Host "`n--- [8/8] Running Flutter Client Scalability & Caching Suites ---" -ForegroundColor Yellow
Push-Location "$root"
try {
    flutter test test/scalability/p95_p99_latency_benchmark_test.dart test/scalability/feed_cache_scalability_test.dart test/scalability/video_engagement_scalability_test.dart
    if ($LASTEXITCODE -ne 0) { throw "Flutter Client Scalability Tests Failed" }
} finally {
    Pop-Location
}

Write-Host "`n=========================================================================================" -ForegroundColor Green
Write-Host "🎉 ALL REQUIRED TESTS PASSED: Home & VideoScreen P95/P99, Unit, & k6 Suites 100% Green!" -ForegroundColor Green
Write-Host "=========================================================================================" -ForegroundColor Green
