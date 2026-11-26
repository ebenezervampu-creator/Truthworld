/**
 * 🧪 RESOLUTION RECONCILIATION & PLANNING INVARIANT TESTS (Audit C3, H1, R1, R3, R5, R8 Fixes)
 *
 * Replaces sample-data mocks with authentic assertions on the real planning helpers
 * and invariants in `resolutionPlanning.ts` and `resolution.ts`:
 *
 * 1. Variant Retry Planner (R1): Capping re-sends at MAX_VARIANT_DISPATCH_ATTEMPTS (3)
 *    so dead/stuck workers finalize instead of looping infinitely.
 * 2. Tier Tolerance & No-Upscale (R8 / H4): Allowing +16 px tolerance without upscaling.
 * 3. Playback Reset Fields (R5 / H1): Purging old ladders on re-upload while preserving
 *    external dubbing playlists and video publish state (no status: "ready" overwrite).
 * 4. Secondary Batch Event ID (R3): Generation-aware batch IDs preventing idempotency collisions.
 * 5. Resolution HLS URL Validator (R5 / C4): Exact discrimination of resolution outputs.
 */

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "truthworld-1" });
}

import {
  STANDARD_AUDIO_BITRATE_KBPS,
} from "../resolution";

import {
  MAX_VARIANT_DISPATCH_ATTEMPTS,
  TIER_TOLERANCE_PX,
  planVariantRetries,
  tierFitsSource,
  playbackResetFields,
  isResolutionHlsUrl,
  secondaryBatchEventId,
} from "../resolutionPlanning";

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

function runReconciliationTests() {
  console.log("=== Running Resolution Reconciliation & Integrity Tests (C3, H1, R1, R3, R5, R8 Invariants) ===\n");

  // ---------------------------------------------------------------------------
  // Test 1: Audio Bitrate Invariant
  // ---------------------------------------------------------------------------
  console.log("--- Test 1: Standard Audio Invariant ---");
  assert(STANDARD_AUDIO_BITRATE_KBPS === 192, "Standard audio invariant is strictly 192 kbps");

  // ---------------------------------------------------------------------------
  // Test 2: R1 - planVariantRetries Caps Re-sends at 3 Attempts
  // ---------------------------------------------------------------------------
  console.log("\n--- Test 2: R1 Variant Retry Planner ---");
  assert(MAX_VARIANT_DISPATCH_ATTEMPTS === 3, "Max variant dispatch attempts constant is 3");

  const mixedLadderVariants: Record<string, any> = {
    "1080p": { status: "completed", downloadUrl: "https://storage.googleapis.com/v/1080p.mp4" },
    "720p": { status: "pending", dispatchAttempts: 0 },
    "480p": { status: "processing", dispatchAttempts: 2 },
    "360p": { status: "processing", dispatchAttempts: 3 }, // exceeded -> give up
    "240p": { status: "pending", dispatchAttempts: 5 }, // exceeded -> give up
    "144p": { status: "failed", dispatchAttempts: 3 }, // already failed -> ignored
  };

  const plan = planVariantRetries(mixedLadderVariants);
  assert(plan.retry.includes("720p"), "720p (0 attempts) is scheduled for retry");
  assert(plan.retry.includes("480p"), "480p (2 attempts) is scheduled for retry");
  assert(!plan.retry.includes("360p"), "360p (3 attempts) is NOT scheduled for retry");
  assert(!plan.retry.includes("240p"), "240p (5 attempts) is NOT scheduled for retry");
  assert(plan.giveUp.includes("360p"), "360p (3 attempts) is marked for give-up");
  assert(plan.giveUp.includes("240p"), "240p (5 attempts) is marked for give-up");
  assert(!plan.retry.includes("144p") && !plan.giveUp.includes("144p"), "Failed 144p is excluded from plan");

  const emptyPlan = planVariantRetries(null);
  assert(emptyPlan.retry.length === 0 && emptyPlan.giveUp.length === 0, "Gracefully handles null/empty variants");

  // ---------------------------------------------------------------------------
  // Test 3: R8 - Tier Tolerance & No-Upscale Gate
  // ---------------------------------------------------------------------------
  console.log("\n--- Test 3: R8 Tier Tolerance (+16 px) ---");
  assert(TIER_TOLERANCE_PX === 16, "Tier tolerance constant is 16 px");
  assert(tierFitsSource(1080, 1080) === true, "Exact 1080p source fits 1080p tier");
  assert(tierFitsSource(1080, 1078) === true, "1078px source fits 1080p tier (-2 px within 16 px tolerance)");
  assert(tierFitsSource(1080, 1064) === true, "1064px source fits 1080p tier (-16 px boundary tolerance)");
  assert(tierFitsSource(1080, 1063) === false, "1063px source rejected for 1080p tier (-17 px beyond tolerance)");
  assert(tierFitsSource(1080, 720) === false, "720p source strictly rejected for 1080p tier (no upscaling)");
  assert(tierFitsSource(720, 480) === false, "480p source strictly rejected for 720p tier");
  assert(tierFitsSource(480, 0) === false, "Zero-dimension source returns false");

  // ---------------------------------------------------------------------------
  // Test 4: R5 & H1 - Playback Reset Fields on Re-upload
  // ---------------------------------------------------------------------------
  console.log("\n--- Test 4: R5 & H1 Playback Reset Fields ---");
  const DELETE_SENTINEL = Symbol("DELETE_FIELD");
  const testVideoId = "video_audit_test_99";

  // Case A: video has our resolution HLS playlist
  const resolutionHlsUrl = `https://firebasestorage.googleapis.com/v0/b/bucket/o/resolutions%2F${testVideoId}%2Fhls%2Fmaster.m3u8?alt=media&token=xyz`;
  const resetFieldsA = playbackResetFields(testVideoId, { hlsUrl: resolutionHlsUrl }, DELETE_SENTINEL);

  assert(resetFieldsA["media.playbackReady"] === false, "media.playbackReady is set to false");
  assert(resetFieldsA["media.isHls"] === false, "media.isHls is set to false");
  assert(!("status" in resetFieldsA), "status: 'ready' is NEVER written (Audit H1 invariant preserved)");
  assert(resetFieldsA["hlsUrl"] === DELETE_SENTINEL, "Resolution HLS URL is deleted on re-upload");
  assert(resetFieldsA["media.hlsUrl"] === DELETE_SENTINEL, "media.hlsUrl is deleted on re-upload");
  assert(resetFieldsA["media.transcodeFailed"] === DELETE_SENTINEL, "media.transcodeFailed sentinel is deleted");
  assert(resetFieldsA["media.transcodeError"] === DELETE_SENTINEL, "media.transcodeError sentinel is deleted");

  // Case B: video has external dubbing HLS playlist (must NOT be deleted)
  const dubbingHlsUrl = `https://storage.googleapis.com/bucket/dubbed/${testVideoId}/master.m3u8`;
  const resetFieldsB = playbackResetFields(testVideoId, { hlsUrl: dubbingHlsUrl }, DELETE_SENTINEL);
  assert(!("hlsUrl" in resetFieldsB), "External dubbing HLS URL is preserved (not deleted)");

  // ---------------------------------------------------------------------------
  // Test 5: R3 - Secondary Batch Event ID Generation
  // ---------------------------------------------------------------------------
  console.log("\n--- Test 5: R3 Secondary Batch Event ID ---");
  const eventId1 = secondaryBatchEventId("video_abc", 1);
  const eventId2 = secondaryBatchEventId("video_abc", 2);
  const eventIdDefault = secondaryBatchEventId("video_abc", null);

  assert(eventId1 === "video_abc_secondary_1", "Generation 1 event ID is formatted correctly");
  assert(eventId2 === "video_abc_secondary_2", "Generation 2 event ID is formatted correctly");
  assert(eventId1 !== eventId2, "Different upload generations yield unique event IDs (no retry skips)");
  assert(eventIdDefault === "video_abc_secondary_1", "Null generation defaults to 1");

  // ---------------------------------------------------------------------------
  // Test 6: R5 / C4 - Resolution HLS URL Identification
  // ---------------------------------------------------------------------------
  console.log("\n--- Test 6: Resolution HLS URL Matcher ---");
  assert(
    isResolutionHlsUrl(`https://storage.googleapis.com/bucket/resolutions/${testVideoId}/hls/master.m3u8`, testVideoId),
    "Plain resolution HLS path is recognized"
  );
  assert(
    isResolutionHlsUrl(`https://firebasestorage.googleapis.com/v0/b/bucket/o/resolutions%2F${testVideoId}%2Fhls%2Fmaster.m3u8`, testVideoId),
    "URL-encoded resolution HLS path is recognized"
  );
  assert(
    !isResolutionHlsUrl(`https://storage.googleapis.com/bucket/dubbed/${testVideoId}/master.m3u8`, testVideoId),
    "Dubbing HLS URL is NOT recognized as resolution URL"
  );
  assert(
    !isResolutionHlsUrl(`https://storage.googleapis.com/bucket/resolutions/other_video/hls/master.m3u8`, testVideoId),
    "Another video's resolution HLS URL is NOT matched"
  );

  console.log("\n========================================");
  console.log(`Summary: ${passed} PASSED, ${failed} FAILED`);
  console.log("========================================\n");

  if (failed > 0) {
    process.exit(1);
  }
}

runReconciliationTests();
