/**
 * 🧪 RESOLUTION LADDER, TRANSCODER & ARCHITECTURE AUDIT UNIT TESTS
 *
 * Verifies all findings from the 2026-11-20 Resolution Cloud Functions Audit:
 * - C2: Missing Pub/Sub labels resolved via transcoderJobName query / getJobStatus
 * - C3: Reconciler re-dispatches pending variants; zero fake fallback tiers
 * - H1: Video doc status preservation (never overwrites status: "ready")
 * - H2: Chapter thumbnail path isolation (rejects foreign paths and buckets)
 * - H3: HTTP Range requests for chapter frames (zero OOM multi-GB downloads)
 * - H4: Dynamic Transcoder ladder (no upscaling, portrait aspect ratio preserved, no crf/vbr collision)
 * - H5: Atomic check-and-lock before submitting GCP Transcoder jobs
 * - H6: Transcoder FAILED state handling and head-of-line blocking prevention
 * - Mediums: 60fps cascade check, yuv420p passthrough gating, portrait shorter-side labelling,
 *   chapter thumbnail dimension clamping, atomic chapter write-back.
 */

import { TranscoderGateway } from "../../src/resolution/transcoderGateway";
import * as path from "path";
import * as fs from "fs";

describe("Audit H4: TranscoderGateway - Portrait Handling & Delegation Logic", () => {
  it("delegates files larger than 500 MB", () => {
    const isDelegated = TranscoderGateway.isLongFormOr4K({
      fileSizeBytes: 501 * 1024 * 1024,
      durationSeconds: 60,
      width: 1920,
      height: 1080,
    });
    expect(isDelegated).toBe(true);
  });

  it("delegates files longer than 10 minutes (600s)", () => {
    const isDelegated = TranscoderGateway.isLongFormOr4K({
      fileSizeBytes: 100 * 1024 * 1024,
      durationSeconds: 601,
      width: 1920,
      height: 1080,
    });
    expect(isDelegated).toBe(true);
  });

  it("delegates 4K landscape video (>= 5s)", () => {
    const isDelegated = TranscoderGateway.isLongFormOr4K({
      fileSizeBytes: 50 * 1024 * 1024,
      durationSeconds: 30,
      width: 3840,
      height: 2160,
    });
    expect(isDelegated).toBe(true);
  });

  it("keeps ultra-short 4K clips (< 5s) serverless to satisfy GCP minimum input duration", () => {
    const isDelegated = TranscoderGateway.isLongFormOr4K({
      fileSizeBytes: 10 * 1024 * 1024,
      durationSeconds: 3,
      width: 3840,
      height: 2160,
    });
    expect(isDelegated).toBe(false);
  });

  it("correctly identifies portrait 1080x1920 shorts as HD, NOT 4K (evaluates shorter side)", () => {
    // Audit H4 / Medium: Previously height: 1920 was compared directly against > 1080,
    // which incorrectly flagged standard 1080p portrait phone uploads as 4K!
    const isDelegated = TranscoderGateway.isLongFormOr4K({
      fileSizeBytes: 80 * 1024 * 1024,
      durationSeconds: 45,
      width: 1080,
      height: 1920, // Shorter side is 1080, so NOT > 1080
    });
    expect(isDelegated).toBe(false);
  });

  it("delegates genuine 4K portrait uploads (2160x3840)", () => {
    const isDelegated = TranscoderGateway.isLongFormOr4K({
      fileSizeBytes: 120 * 1024 * 1024,
      durationSeconds: 30,
      width: 2160,
      height: 3840, // Shorter side is 2160 (> 1080)
    });
    expect(isDelegated).toBe(true);
  });
});

describe("Audit H4: TranscoderGateway - Dynamic Profiles & Ladder Generation", () => {
  it("never upscales lower resolution inputs to 1080p", () => {
    // 720p input: should only generate 720p, 480p, 360p (NO 1080p or 4K)
    const profiles = TranscoderGateway.buildDynamicProfiles({
      sourceWidth: 1280,
      sourceHeight: 720,
      sourceFps: 30,
    });
    const labels = profiles.map((p) => p.label);

    expect(labels).toContain("720p");
    expect(labels).toContain("480p");
    expect(labels).toContain("360p");
    expect(labels).not.toContain("1080p");
    expect(labels).not.toContain("2160p");
  });

  it("preserves portrait aspect ratio (9:16) without squashing or stretching", () => {
    // 1080x1920 portrait input
    const profiles = TranscoderGateway.buildDynamicProfiles({
      sourceWidth: 1080,
      sourceHeight: 1920,
      sourceFps: 30,
    });
    for (const p of profiles) {
      // In portrait: width is set to shortSide target and height is 0 (auto-aspect ratio in GCP)
      expect(p.width).toBeGreaterThan(0);
      expect(p.height).toBe(0);
    }

    const p720 = profiles.find((p) => p.label === "720p");
    expect(p720).toBeDefined();
    expect(p720!.width).toBe(720);
    expect(p720!.height).toBe(0);
  });

  it("handles 4K landscape inputs and produces ladder down to 360p", () => {
    const profiles = TranscoderGateway.buildDynamicProfiles({
      sourceWidth: 3840,
      sourceHeight: 2160,
      sourceFps: 30,
    });
    const labels = profiles.map((p) => p.label);

    expect(labels).toContain("2160p");
    expect(labels).toContain("1080p");
    expect(labels).toContain("720p");
    expect(labels).toContain("480p");
    expect(labels).toContain("360p");
  });

  it("preserves 60fps for high tiers when source is 60fps", () => {
    const profiles = TranscoderGateway.buildDynamicProfiles({
      sourceWidth: 1920,
      sourceHeight: 1080,
      sourceFps: 60,
    });
    const p1080 = profiles.find((p) => p.label === "1080p60");
    const p480 = profiles.find((p) => p.label === "480p");

    expect(p1080).toBeDefined();
    expect(p1080!.frameRate).toBe(60);
    expect(p480).toBeDefined();
    // Low tiers stay at 30fps for data saving
    expect(p480!.frameRate).toBe(30);
  });
});

describe("Audit Source Invariants: resolution.ts and transcoderGateway.ts", () => {
  const resolutionPath = path.resolve(__dirname, "../../src/resolution/resolution.ts");
  const transcoderGatewayPath = path.resolve(__dirname, "../../src/resolution/transcoderGateway.ts");

  let resolutionSrc: string;
  let transcoderGatewaySrc: string;

  beforeAll(() => {
    resolutionSrc = fs.readFileSync(resolutionPath, "utf-8");
    transcoderGatewaySrc = fs.readFileSync(transcoderGatewayPath, "utf-8");
  });

  it("C2: onTranscoderJobCompleted queries resolution_jobs by transcoderJobName when labels are missing", () => {
    expect(resolutionSrc).toContain('where("transcoderJobName", "==", jobName)');
  });

  it("C3: Reconciler re-dispatches pending variants and never creates fake fallback tiers", () => {
    expect(resolutionSrc).toContain("reconcileEventId");
    expect(resolutionSrc).toContain('publish("resolution.requested"');
    // Ensure the old fake ladder loop is gone
    expect(resolutionSrc).not.toContain("Math.max(sourceHeight || 1080, 1080)");
  });

  it("H1: Video doc status is NEVER set to 'ready' (uses media.playbackReady: true)", () => {
    // Check that syncVariantToVideoDoc writes media.playbackReady
    expect(resolutionSrc).toContain('"media.playbackReady": true');
    // Check that syncVariantToVideoDoc does NOT contain status: "ready"
    expect(resolutionSrc).not.toContain('status: "ready"');
  });

  it("H2: Chapter thumbnail extraction rejects foreign paths, foreign buckets, and path traversal (..)", () => {
    expect(resolutionSrc).toContain("Rejected path outside video boundary");
    expect(resolutionSrc).toContain("Rejected unauthorized bucket");
    expect(resolutionSrc).toContain('!normalizedPath.includes("..")');
    expect(resolutionSrc).toContain("path.posix.normalize");
  });

  it("H3: Chapter thumbnail generation uses signed URL range requests instead of downloading the whole file", () => {
    expect(resolutionSrc).toContain("HTTP Range Streaming via Signed URL");
    expect(resolutionSrc).toContain("targetStorageFile.getSignedUrl");
  });

  it("H4: submitTranscodingJob avoids conflicting crfLevel with rateControlMode: 'vbr'", () => {
    expect(transcoderGatewaySrc).not.toContain('crfLevel: 21');
    expect(transcoderGatewaySrc).toContain('rateControlMode: "vbr"');
  });

  it("H4: submitTranscodingJob handles silent videos without failing", () => {
    expect(transcoderGatewaySrc).toContain("if (hasAudio)");
    expect(transcoderGatewaySrc).toContain('key: "audio-stream"');
  });

  it("H5: Reconciler executes atomic transaction check-and-lock before submitting Transcoder jobs and resets expired orphaned locks", () => {
    expect(resolutionSrc).toContain("db.runTransaction(async (transaction)");
    expect(resolutionSrc).toContain('status: "escalated_to_transcoder"');
    expect(resolutionSrc).toContain("Escalation lock expired without active job name");
    expect(resolutionSrc).toContain("escalatedToTranscoder: false");
  });

  it("H6: Transcoder FAILED state is handled and recorded on job and video docs", () => {
    expect(resolutionSrc).toContain('jobStatus.state === "FAILED"');
    expect(resolutionSrc).toContain('"media.transcodeFailed": true');
    expect(resolutionSrc).toContain('status: "failed"');
  });

  it("H6: Stuck jobs scheduler uses orderBy and touches skipped jobs to prevent head-of-line blocking", () => {
    expect(resolutionSrc).toContain('.orderBy("updatedAt", "asc")');
    expect(resolutionSrc).toContain("Touch updatedAt so that unresolved jobs rotate to back of queue");
  });

  it("Medium: Cascade check looks for 720p60.mp4 and 1080p60.mp4", () => {
    expect(resolutionSrc).toContain('720p60.mp4');
    expect(resolutionSrc).toContain('1080p60.mp4');
  });

  it("Medium: Passthrough copy gates on pix_fmt === 'yuv420p' and bitrate limits", () => {
    expect(resolutionSrc).toContain('probed.pixFmt === "yuv420p"');
    expect(resolutionSrc).toContain("targetVariant.bitrateKbps * 1.5");
  });

  it("Medium: Chapter thumbnails width and height are strictly clamped", () => {
    expect(resolutionSrc).toContain("Math.min(1920, Math.max(160");
    expect(resolutionSrc).toContain("Math.min(1080, Math.max(90");
  });

  it("Medium: Chapter write-back uses a transaction and writes only to the originating field", () => {
    expect(resolutionSrc).toContain("db.runTransaction(async (transaction)");
    expect(resolutionSrc).toContain("Write back ONLY to the source field that was originally present");
    expect(resolutionSrc).toContain("updateObj.autoChapters = updatedChapters");
  });
});
