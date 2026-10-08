import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "truthworld-1" });
}

import {
  STANDARD_RESOLUTION_LADDER,
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

function run60FpsTests() {
  console.log("=== Running Resolution 60 FPS Preservation Tests ===\n");

  // Simulate ladder generation for 60fps source at 4K (2160p)
  const is60Fps = true;
  const effectiveHeight = 2160;

  const applicableResolutions = STANDARD_RESOLUTION_LADDER
    .filter((r) => r.height <= effectiveHeight)
    .map((r) => {
      if (is60Fps && r.height >= 720) {
        return {
          ...r,
          label: `${r.height}p60`,
          fps: 60,
          bitrateKbps: Math.round(r.bitrateKbps * 1.5),
        };
      }
      return r;
    });

  console.log("--- Test 1: 60fps Preservation for High-Definition Tiers (>= 720p) ---");
  const p2160 = applicableResolutions.find((r) => r.height === 2160);
  assert(p2160?.label === "2160p60", "2160p is tagged as 2160p60");
  assert(p2160?.fps === 60, "2160p has fps = 60");
  assert(p2160?.bitrateKbps === Math.round(15000 * 1.5), "2160p has 50% higher bitrate (22500 kbps)");

  const p1080 = applicableResolutions.find((r) => r.height === 1080);
  assert(p1080?.label === "1080p60", "1080p is tagged as 1080p60");
  assert(p1080?.fps === 60, "1080p has fps = 60");
  assert(p1080?.bitrateKbps === Math.round(4500 * 1.5), "1080p has 50% higher bitrate (6750 kbps)");

  const p720 = applicableResolutions.find((r) => r.height === 720);
  assert(p720?.label === "720p60", "720p is tagged as 720p60");
  assert(p720?.fps === 60, "720p has fps = 60");
  assert(p720?.bitrateKbps === Math.round(2500 * 1.5), "720p has 50% higher bitrate (3750 kbps)");

  console.log("\n--- Test 2: Low-Resolution Tiers Preserved at 30fps/Data-Saver ---");
  const p480 = applicableResolutions.find((r) => r.height === 480);
  assert(p480?.label === "480p", "480p retains standard 480p label without 60fps suffix");
  assert(p480?.fps === 30, "480p remains at 30 fps");
  assert(p480?.bitrateKbps === 1200, "480p preserves standard data-saver bitrate (1200 kbps)");

  const p360 = applicableResolutions.find((r) => r.height === 360);
  assert(p360?.fps === 30, "360p remains at 30 fps");

  const p144 = applicableResolutions.find((r) => r.height === 144);
  assert(p144?.fps === 15, "144p remains at ultra data-saver 15 fps");

  console.log("\n========================================");
  console.log(`Summary: ${passed} PASSED, ${failed} FAILED`);
  console.log("========================================\n");

  if (failed > 0) {
    process.exit(1);
  }
}

run60FpsTests();
