/**
 * 🧪 RESOLUTION DELEGATION, NATIVE SPRITES & PARITY TEST SUITE
 *
 * Verifies:
 * 1. TranscoderGateway.isLongFormOr4K delegation thresholds:
 *    - Short-circuits on size > 500MB
 *    - Delegates on duration > 10m (600s)
 *    - Delegates on 4K (>1080p) if duration >= 5s
 *    - Retains ultra-short 4K (<5s) for serverless FFmpeg execution
 * 2. TranscoderGateway JobConfig produces native spriteSheets and pubsubDestination
 * 3. FFmpeg preset tuning uses 'superfast' for Tier 1 (>=720p) and 'ultrafast' for Tier 2 (<720p)
 */

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "truthworld-1" });
}

import { TranscoderGateway } from "../transcoderGateway";
import * as fs from "fs";
import * as path from "path";

let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, errorDetails?: any) {
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${testName}`, errorDetails ? errorDetails : "");
    failed++;
  }
}

function runDelegationAndParityTests() {
  console.log("=== Running Resolution Delegation, Native Sprites & Parity Tests ===\n");

  // --- Test 1: Size-Based Short-Circuit ---
  console.log("--- Test 1: Size-Based Short-Circuit (> 500 MB) ---");
  const size501MB = TranscoderGateway.isLongFormOr4K({ fileSizeBytes: 501 * 1024 * 1024 });
  assert(size501MB === true, "Files > 500 MB immediately delegate to GCP Transcoder");

  const size499MB = TranscoderGateway.isLongFormOr4K({ fileSizeBytes: 499 * 1024 * 1024, durationSeconds: 120, height: 1080 });
  assert(size499MB === false, "Files <= 500 MB (with duration <= 10m & height <= 1080) stay in serverless worker");

  // --- Test 2: Duration-Based Delegation (> 10 minutes / 600s) ---
  console.log("\n--- Test 2: Duration-Based Delegation (> 600s) ---");
  const dur601s = TranscoderGateway.isLongFormOr4K({ fileSizeBytes: 200 * 1024 * 1024, durationSeconds: 601, height: 1080 });
  assert(dur601s === true, "Videos > 10m (601s) delegate to prevent 540s serverless timeout");

  const dur599s = TranscoderGateway.isLongFormOr4K({ fileSizeBytes: 200 * 1024 * 1024, durationSeconds: 599, height: 1080 });
  assert(dur599s === false, "Videos <= 10m (599s) stay in serverless worker");

  // --- Test 3: 4K Resolution & Ultra-Short Clip Guard ---
  console.log("\n--- Test 3: 4K Resolution & 5s Minimum Clip Guard ---");
  const fourKStandard = TranscoderGateway.isLongFormOr4K({ fileSizeBytes: 100 * 1024 * 1024, durationSeconds: 30, height: 2160 });
  assert(fourKStandard === true, "4K videos >= 5s delegate to GCP Transcoder");

  const fourKUltraShort = TranscoderGateway.isLongFormOr4K({ fileSizeBytes: 20 * 1024 * 1024, durationSeconds: 3.5, height: 2160 });
  assert(fourKUltraShort === false, "Ultra-short 4K clips (< 5s) are retained for local FFmpeg to meet GCP minimum input duration");

  // --- Test 4: Dynamic Sprite Interval & Aspect Ratio Preservation ---
  console.log("\n--- Test 4: Dynamic Sprite Interval & Aspect Ratio Preservation ---");
  assert(TranscoderGateway.calculateSpriteInterval(300) === "3s", "Short video (5 min) interval is 3s");
  assert(TranscoderGateway.calculateSpriteInterval(1200) === "5s", "Medium video (20 min) interval is 5s");
  assert(TranscoderGateway.calculateSpriteInterval(2400) === "10s", "Long video (40 min) interval is 10s");
  assert(TranscoderGateway.calculateSpriteInterval(5000) === "15s", "1hr+ lecture interval is 15s (prevents sheet explosion)");

  const transcoderGatewayPath = path.resolve(__dirname, "../transcoderGateway.ts");
  const gatewaySource = fs.readFileSync(transcoderGatewayPath, "utf-8");

  assert(gatewaySource.includes("spriteSheets: ["), "JobConfig specifies native spriteSheets");
  assert(gatewaySource.includes('filePrefix: "storyboard"'), "SpriteSheet specifies 'storyboard' prefix");
  assert(gatewaySource.includes("spriteWidthPixels: 320"), "SpriteSheet sets width to 320px");
  assert(!gatewaySource.includes("spriteHeightPixels:"), "SpriteSheet omits spriteHeightPixels property to prevent 9:16 portrait distortion");
  assert(gatewaySource.includes("columnCount: 5") && gatewaySource.includes("rowCount: 5"), "SpriteSheet configures 5x5 grid");
  assert(gatewaySource.includes("pubsubDestination: {"), "JobConfig specifies pubsubDestination");
  assert(gatewaySource.includes("transcoder.completed"), "PubSub topic configured as 'transcoder.completed'");

  // --- Test 5: FFmpeg Preset Tuning & Reconciler Escalation Lock ---
  console.log("\n--- Test 5: Tier 1 superfast & Reconciler Escalation Lock Invariant ---");
  const resolutionSource = fs.readFileSync(path.resolve(__dirname, "../resolution.ts"), "utf-8");
  assert(resolutionSource.includes('preset = isHighTier ? "superfast" : "ultrafast"'), "Tier 1 uses 'superfast' and Tier 2 uses 'ultrafast'");
  assert(resolutionSource.includes('crf = isHighTier ? "22" : "23"'), "Tier 1 uses CRF 22 and Tier 2 uses CRF 23");
  assert(resolutionSource.includes("retry: false"), "handleResolution sets retry: false to prevent 540s retry loop");
  assert(resolutionSource.includes("onTranscoderJobCompleted"), "onTranscoderJobCompleted Cloud Function is defined");
  assert(resolutionSource.includes('status: "escalated_to_transcoder"'), "reconciler sets durable 'escalated_to_transcoder' lock to prevent duplicate paid GCP jobs");

  console.log(`\n========================================`);
  console.log(`Summary: ${passed} PASSED, ${failed} FAILED`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runDelegationAndParityTests();
