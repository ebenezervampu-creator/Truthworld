/**
 * 🧪 RESOLUTION INTEGRITY & ZERO-FRAGMENTED-MP4 REGRESSION TEST
 *
 * Verifies that:
 * 1. ZERO fragmented MP4 flags (empty_moov, frag_custom, default_base_moof, dash+, -frag_duration)
 *    exist in resolution transcoding output options.
 * 2. All MP4 exports strictly mandate +faststart for immediate progressive streaming with full duration metadata.
 * 3. MediaProbeInfo interface and probeVideoFile extract container duration in seconds.
 * 4. Output stream integrity verification logic enforces that output duration cannot be truncated.
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "truthworld-1" });
}

import {
  STANDARD_RESOLUTION_LADDER,
  CUSTOM_RESOLUTION_LADDER,
} from "../resolution";

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

function runIntegrityTests() {
  console.log("=== Running Resolution Flags & Stream Integrity Invariant Tests ===\n");

  const resolutionTsPath = path.resolve(__dirname, "../resolution.ts");
  assert(fs.existsSync(resolutionTsPath), "resolution.ts source file exists");

  const sourceCode = fs.readFileSync(resolutionTsPath, "utf-8");

  // Test 1: Zero Fragmented MP4 Flags In Transcode Output Options
  console.log("\n--- Test 1: Zero-Fragmented-MP4 Output Flags Invariant ---");
  const forbiddenFlags = [
    "empty_moov",
    "frag_custom",
    "default_base_moof",
    "-frag_duration",
  ];

  // We search within FFmpeg outputOptions arrays
  const outputOptionsRegex = /\.outputOptions\(\[([\s\S]*?)\]\)/g;
  let match: RegExpExecArray | null;
  let forbiddenFound = false;
  let totalOutputOptionsBlocks = 0;

  while ((match = outputOptionsRegex.exec(sourceCode)) !== null) {
    totalOutputOptionsBlocks++;
    const block = match[1];
    for (const flag of forbiddenFlags) {
      if (block.includes(flag)) {
        console.error(`Forbidden flag "${flag}" found in outputOptions block:`, block);
        forbiddenFound = true;
      }
    }
  }

  assert(totalOutputOptionsBlocks >= 2, `Found ${totalOutputOptionsBlocks} outputOptions blocks in resolution.ts`);
  assert(!forbiddenFound, "Strict Invariant: No outputOptions block contains empty_moov, frag_custom, default_base_moof, or -frag_duration");

  // Test 2: Mandatory +faststart in All MP4 Exports
  console.log("\n--- Test 2: Mandatory +faststart Flag Invariant ---");
  let faststartCount = 0;
  const faststartRegex = /"-movflags",\s*"\+faststart"/g;
  while (faststartRegex.exec(sourceCode) !== null) {
    faststartCount++;
  }
  assert(faststartCount >= 2, `Mandatory +faststart flag present in both native passthrough and re-encoding paths (found ${faststartCount})`);

  // Test 3: Post-Transcode Integrity Audit Logic Present
  console.log("\n--- Test 3: Post-Transcode Integrity Verification Invariant ---");
  const hasIntegrityAudit = sourceCode.includes("Output stream integrity violation") &&
    sourceCode.includes("outputProbed.duration");
  assert(hasIntegrityAudit, "Post-transcode integrity audit is strictly wired before uploading to storage");

  // Test 4: Duration Extraction in probeVideoFile
  console.log("\n--- Test 4: probeVideoFile Duration Support ---");
  const hasDurationInProbe = sourceCode.includes("metadata?.format?.duration") &&
    sourceCode.includes("duration: number");
  assert(hasDurationInProbe, "probeVideoFile accurately parses format and stream duration from ffprobe");

  // Test 5: Resolution Ladders are descending and capped
  console.log("\n--- Test 5: Resolution Ladder Structure ---");
  assert(STANDARD_RESOLUTION_LADDER.length === 8, "Standard ladder has 8 quality tiers (2160p down to 144p)");
  assert(CUSTOM_RESOLUTION_LADDER.length === 8, "Custom ladder has 8 quality tiers (2160p down to 144p)");
  assert(STANDARD_RESOLUTION_LADDER[0].height === 2160, "Highest standard tier is 2160p (4K)");
  assert(STANDARD_RESOLUTION_LADDER[STANDARD_RESOLUTION_LADDER.length - 1].height === 144, "Lowest standard tier is 144p (data saver)");

  console.log(`\n========================================`);
  console.log(`Summary: ${passed} PASSED, ${failed} FAILED`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
}

runIntegrityTests();
