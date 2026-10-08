#!/usr/bin/env bash
# =============================================================================
# TruthWorld Secure Production Release Builder (Linux / CI / macOS)
# =============================================================================
set -euo pipefail

FLAVOR="${1:-app}"
FORMAT="${2:-appbundle}"
SKIP_TESTS="${3:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "================================================================"
echo " TruthWorld Secure Production Release Builder"
echo " Flavor: $FLAVOR | Format: $FORMAT | Obfuscation: ENABLED"
echo "================================================================"

# -----------------------------------------------------------------------------
# Phase 1: Pre-Build Security Verification Suite
# -----------------------------------------------------------------------------
if [ "$SKIP_TESTS" != "true" ]; then
    echo -e "\n>>> [1/3] Running Pre-Build Security Verification Suite..."
    flutter test test/core/security/
    flutter test test/core/ui_contrast_guard_test.dart
    echo "[+] All security and contrast guards passed."
fi

# -----------------------------------------------------------------------------
# Phase 2: Obfuscated Build Execution
# -----------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SYMBOLS_DIR="$PROJECT_ROOT/build/app/outputs/symbols/$FLAVOR/$TIMESTAMP"
RELEASES_DIR="$PROJECT_ROOT/releases/android"
mkdir -p "$SYMBOLS_DIR" "$RELEASES_DIR"

echo -e "\n>>> [2/3] Compiling Secure Release Artifact ($FORMAT)..."
echo "Output symbols directory: $SYMBOLS_DIR"

if [ "$FORMAT" = "appbundle" ]; then
    flutter build appbundle --release --flavor "$FLAVOR" -t lib/main.dart --obfuscate --split-debug-info="$SYMBOLS_DIR"
    SOURCE="$PROJECT_ROOT/build/app/outputs/bundle/${FLAVOR}Release/app-$FLAVOR-release.aab"
    DESTINATION="$RELEASES_DIR/truthworld-$FLAVOR-release-$TIMESTAMP.aab"
else
    flutter build apk --release --flavor "$FLAVOR" -t lib/main.dart --obfuscate --split-debug-info="$SYMBOLS_DIR"
    SOURCE="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-$FLAVOR-release.apk"
    DESTINATION="$RELEASES_DIR/truthworld-$FLAVOR-release-$TIMESTAMP.apk"
fi

# -----------------------------------------------------------------------------
# Phase 3: Integrity Checksum & Symbol Archival
# -----------------------------------------------------------------------------
echo -e "\n>>> [3/3] Generating Artifact Checksums & Integrity Metadata..."
cp "$SOURCE" "$DESTINATION"
SHA256=$(sha256sum "$DESTINATION" | awk '{print $1}')
FILESIZE=$(du -h "$DESTINATION" | awk '{print $1}')

echo "================================================================"
echo " SUCCESSFUL SECURE RELEASE BUILD"
echo " Artifact:  $DESTINATION"
echo " File Size: $FILESIZE"
echo " SHA-256:   $SHA256"
echo " Symbols:   $SYMBOLS_DIR"
echo "================================================================"
