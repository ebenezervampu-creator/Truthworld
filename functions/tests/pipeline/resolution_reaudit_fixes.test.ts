/**
 * Resolution service re-audit fixes (2026-11-20, findings R1-R5, R7, R8).
 *
 * R1: a variant is re-sent at most 3 times, then marked failed.
 * R2: files over 500 MB are probed (no hard-coded 1920x1080 / hasAudio).
 * R3: the low-tier batch event id includes the upload generation.
 * R4: Transcoder completion awaits chapter thumbnails.
 * R5: a new upload resets every playback field the service owns.
 * R7: the reconciler finalizes SUCCEEDED Transcoder jobs itself.
 * R8: sources a few pixels short of a tier still get it (+16 px).
 */

import * as fs from "fs";
import * as path from "path";
import {
  planVariantRetries,
  tierFitsSource,
  playbackResetFields,
  isResolutionHlsUrl,
  secondaryBatchEventId,
  MAX_VARIANT_DISPATCH_ATTEMPTS,
} from "../../src/resolution/resolutionPlanning";
import { TranscoderGateway } from "../../src/resolution/transcoderGateway";

const VIDEO_ID = "3f2b8c1e-9a4d-4e7b-8c21-5d6e7f8a9b0c";
const DELETE = { __delete: true };

describe("R1: planVariantRetries caps re-sends", () => {
  it("re-sends pending and stuck processing variants under the cap", () => {
    const plan = planVariantRetries({
      "1080p": { status: "completed", downloadUrl: "u" },
      "480p": { status: "pending" },
      "360p": { status: "processing", dispatchAttempts: 2 },
    });
    expect(plan).toEqual({ retry: ["480p", "360p"], giveUp: [] });
  });

  it("gives up on a variant once it has used its attempts", () => {
    const plan = planVariantRetries({
      "720p": { status: "processing", dispatchAttempts: MAX_VARIANT_DISPATCH_ATTEMPTS },
      "480p": { status: "pending", dispatchAttempts: 1 },
    });
    expect(plan).toEqual({ retry: ["480p"], giveUp: ["720p"] });
  });

  it("a variant that keeps dying is given up after exactly 3 re-sends", () => {
    const variant: Record<string, any> = { status: "processing" };
    let sends = 0;
    for (let cycle = 0; cycle < 10; cycle++) {
      const plan = planVariantRetries({ "1080p": variant });
      if (plan.giveUp.includes("1080p")) {
        variant.status = "failed";
        break;
      }
      if (plan.retry.includes("1080p")) {
        sends++;
        variant.dispatchAttempts = (variant.dispatchAttempts || 0) + 1;
        variant.status = "processing"; // the worker dies again
      }
    }
    expect(sends).toBe(MAX_VARIANT_DISPATCH_ATTEMPTS);
    expect(variant.status).toBe("failed");
  });

  it("ignores finished, failed and skipped variants and bad input", () => {
    expect(planVariantRetries({
      a: { status: "completed" },
      b: { status: "failed" },
      c: { status: "skipped" },
      d: null,
    } as any)).toEqual({ retry: [], giveUp: [] });
    expect(planVariantRetries(undefined)).toEqual({ retry: [], giveUp: [] });
  });
});

describe("R8: tier tolerance", () => {
  it("keeps a tier for sources up to 16 px short of it", () => {
    expect(tierFitsSource(1080, 1078)).toBe(true);
    expect(tierFitsSource(1080, 1064)).toBe(true);
    expect(tierFitsSource(1080, 1063)).toBe(false);
    expect(tierFitsSource(1080, 720)).toBe(false);
    expect(tierFitsSource(720, 0)).toBe(false);
  });

  it("Transcoder ladder keeps 1080p for a 1918x1078 source", () => {
    const labels = TranscoderGateway.buildDynamicProfiles({ sourceWidth: 1918, sourceHeight: 1078 }).map((p) => p.label);
    expect(labels[0]).toBe("1080p");
  });
});

describe("H4/R2: Transcoder ladder follows the real source", () => {
  it("4K landscape gets 2160p down to 360p, height-driven", () => {
    const profiles = TranscoderGateway.buildDynamicProfiles({ sourceWidth: 3840, sourceHeight: 2160, sourceFps: 30 });
    expect(profiles.map((p) => p.label)).toEqual(["2160p", "1440p", "1080p", "720p", "480p", "360p"]);
    expect(profiles.every((p) => p.height > 0 && p.width === 0)).toBe(true);
  });

  it("4K portrait at 60 fps is width-driven and keeps 60 fps from 720p up", () => {
    const profiles = TranscoderGateway.buildDynamicProfiles({ sourceWidth: 2160, sourceHeight: 3840, sourceFps: 60 });
    expect(profiles.map((p) => p.label)).toEqual(["2160p60", "1440p60", "1080p60", "720p60", "480p", "360p"]);
    expect(profiles.every((p) => p.width > 0 && p.height === 0)).toBe(true);
  });

  it("never upscales a 480p source", () => {
    const labels = TranscoderGateway.buildDynamicProfiles({ sourceWidth: 854, sourceHeight: 480 }).map((p) => p.label);
    expect(labels).toEqual(["480p", "360p"]);
  });

  it("delegates by size, duration or a >1080 shorter side", () => {
    expect(TranscoderGateway.isLongFormOr4K({ fileSizeBytes: 600 * 1024 * 1024 })).toBe(true);
    expect(TranscoderGateway.isLongFormOr4K({ durationSeconds: 601 })).toBe(true);
    expect(TranscoderGateway.isLongFormOr4K({ width: 3840, height: 2160, durationSeconds: 30 })).toBe(true);
    expect(TranscoderGateway.isLongFormOr4K({ width: 1080, height: 1920, durationSeconds: 30 })).toBe(false);
  });
});

describe("R5: playbackResetFields", () => {
  it("clears the ladder and turns playbackReady off", () => {
    const fields = playbackResetFields(VIDEO_ID, {}, DELETE);
    expect(fields["adaptiveResolutions"]).toEqual([]);
    expect(fields["media.adaptiveResolutions"]).toEqual([]);
    expect(fields["media.variants"]).toEqual({});
    expect(fields["media.playbackReady"]).toBe(false);
    expect(fields["media.isHls"]).toBe(false);
    expect(fields["media.hlsUrl"]).toBe(DELETE);
    expect(fields["media.transcodeFailed"]).toBe(DELETE);
    expect("hlsUrl" in fields).toBe(false);
  });

  it("clears hlsUrl only when it is this service's Transcoder output", () => {
    const ours = `https://firebasestorage.googleapis.com/v0/b/b/o/${encodeURIComponent(`resolutions/${VIDEO_ID}/hls/master.m3u8`)}?alt=media&token=t`;
    const dubbing = "https://firebasestorage.googleapis.com/v0/b/b/o/hls%2Fx%2Fmaster.m3u8?alt=media";
    expect(playbackResetFields(VIDEO_ID, { hlsUrl: ours }, DELETE).hlsUrl).toBe(DELETE);
    expect("hlsUrl" in playbackResetFields(VIDEO_ID, { hlsUrl: dubbing }, DELETE)).toBe(false);
    expect(isResolutionHlsUrl(`gs://b/resolutions/${VIDEO_ID}/hls/master.m3u8`, VIDEO_ID)).toBe(true);
    expect(isResolutionHlsUrl(`gs://b/resolutions/other/hls/master.m3u8`, VIDEO_ID)).toBe(false);
  });
});

describe("R3: secondaryBatchEventId", () => {
  it("differs per upload generation", () => {
    expect(secondaryBatchEventId(VIDEO_ID, "1700000000000001")).toBe(`${VIDEO_ID}_secondary_1700000000000001`);
    expect(secondaryBatchEventId(VIDEO_ID, 42)).toBe(`${VIDEO_ID}_secondary_42`);
    expect(secondaryBatchEventId(VIDEO_ID, undefined)).toBe(`${VIDEO_ID}_secondary_1`);
    expect(secondaryBatchEventId(VIDEO_ID, "a")).not.toBe(secondaryBatchEventId(VIDEO_ID, "b"));
  });
});

describe("Wiring in resolution.ts", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../../src/resolution/resolution.ts"), "utf8");

  it("R2: no hard-coded 1920x1080 / hasAudio for large files", () => {
    expect(src).not.toMatch(/sourceHeight:\s*1080,\s*\n\s*sourceWidth:\s*1920/);
    expect(src).not.toContain("fileSize > 500 * 1024 * 1024");
  });

  it("R1: the reconciler uses the retry planner", () => {
    expect(src).toContain("planVariantRetries(variants)");
    expect(src).toContain("dispatchAttempts`] = admin.firestore.FieldValue.increment(1)");
  });

  it("R3: the low-tier batch id carries the generation stored on the job", () => {
    expect(src).toContain("secondaryBatchEventId(videoId, finalJobData.sourceGeneration)");
    expect((src.match(/sourceGeneration: String\(generation\)/g) || []).length).toBe(2);
  });

  it("R4: chapter thumbnails after Transcoder completion are awaited", () => {
    const finalize = src.slice(src.indexOf("async function finalizeTranscoderJob"), src.indexOf("export const onTranscoderJobCompleted"));
    expect(finalize).toContain("await generateHighQualityChapterThumbnailsForVideo(videoId)");
    expect(src).not.toMatch(/\n\s+generateHighQualityChapterThumbnailsForVideo\(videoId\)\.catch/);
  });

  it("R5: the upload trigger uses playbackResetFields", () => {
    expect(src).toContain("...playbackResetFields(videoId, videoData, admin.firestore.FieldValue.delete())");
  });

  it("R7: the reconciler finalizes SUCCEEDED Transcoder jobs", () => {
    const reconcile = src.slice(src.indexOf("export async function reconcileResolutionJob"), src.indexOf("export const getVideoResolutionStatus"));
    expect(reconcile).toContain("await finalizeTranscoderJob(videoId, { extractChapters: false })");
    expect(reconcile).not.toContain("Awaiting completion handler");
  });

  it("H1 stays fixed: no status \"ready\" writes", () => {
    expect(src).not.toMatch(/status:\s*"ready"/);
  });
});
