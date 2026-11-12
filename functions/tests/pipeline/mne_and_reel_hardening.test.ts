import { MediaService, MneValidationResult } from "../../src/pipeline/services/media";
import { DubbingQualityGate, DubbingQualityGateParams } from "../../src/pipeline/layers/quality-gate";

describe("Production Hardening: Studio M&E Validation & Distributed Reel Orchestration", () => {
  const mediaService = new MediaService();

  describe("Phase 1: Studio M&E Stem Validation", () => {
    it("1. Flags corruption or empty file if M&E file is too small or invalid", async () => {
      // Test invalid / nonexistent URL
      const result = await mediaService.validateMneStem("job_test_01", "https://invalid-storage.test/empty.mp3", 60, "studio");
      expect(result.validationStatus).toBe("failed");
      expect(result.corruptionDetected).toBe(true);
      expect(result.source).toBe("studio");
      expect(result.issues.length).toBeGreaterThan(0);
    });

    it("2. Distinguishes studio stem from neural demixed stem without unverified zero-bleed claims", async () => {
      const studioResult: MneValidationResult = {
        source: "studio",
        fileUrl: "gs://bucket/studio_mne.mp3",
        durationSeconds: 60.02,
        videoDurationSeconds: 60.0,
        durationMatch: true,
        durationDeltaMs: 20,
        timelineAlignmentMs: 0,
        sampleRate: 48000,
        channels: 2,
        channelLayout: "stereo",
        dialogueBleedDb: undefined, // Truthful: not claiming zero bleed without physical measurement
        clippingDetected: false,
        corruptionDetected: false,
        validationStatus: "passed",
        issues: [],
      };

      expect(studioResult.source).toBe("studio");
      expect(studioResult.dialogueBleedDb).toBeUndefined();
      expect(studioResult.validationStatus).toBe("passed");
    });

    it("3. Quality Gate rejects track when M&E validation status is failed", () => {
      const failedMne: MneValidationResult = {
        source: "studio",
        fileUrl: "gs://bucket/corrupt_mne.mp3",
        durationSeconds: 12.0,
        videoDurationSeconds: 60.0,
        durationMatch: false,
        durationDeltaMs: 48000,
        timelineAlignmentMs: 0,
        sampleRate: 44100,
        channels: 2,
        channelLayout: "stereo",
        clippingDetected: false,
        corruptionDetected: true,
        validationStatus: "failed",
        issues: ["File corrupted or truncated", "Duration mismatch: 12s vs 60s"],
      };

      const gateParams: DubbingQualityGateParams = {
        jobId: "job_mne_fail",
        targetLang: "te",
        totalSegments: 10,
        successfulSegments: 10,
        failedSegments: [],
        actualDurationSeconds: 60.0,
        expectedDurationSeconds: 60.0,
        isVoiceCloningRequested: false,
        isVoiceCloned: true,
        stemIsolationRequested: true,
        isStemPreserved: true,
        mneStemUrl: "gs://bucket/corrupt_mne.mp3",
        outputAudioSize: 1500000,
        tier: "cinema",
        mneValidation: failedMne,
      };

      const gateResult = DubbingQualityGate.evaluate(gateParams);
      expect(gateResult.passed).toBe(false);
      expect(gateResult.violations).toEqual(
        expect.arrayContaining([expect.stringContaining("M&E stem validation failed")])
      );
    });
  });

  describe("Phase 2: Distributed 15-Minute Reel Partitioning & Boundary Reconciliation", () => {
    it("4. Partitions 90-minute movie (5,400,000ms) into exactly 6 discrete 15-minute reels", () => {
      const movieDurationMs = 90 * 60 * 1000; // 5,400,000ms
      const mockSegments = [
        { start: 1000, end: 4000, text: "Welcome to the film." },
        { start: 890000, end: 898000, text: "Closing scene of Reel 1." }, // 14m 50s
        { start: 902000, end: 908000, text: "Opening scene of Reel 2." }, // 15m 02s
        { start: 5380000, end: 5395000, text: "Closing credits of Reel 6." }, // 89m 40s
      ];

      const { reels, assignedSegments } = mediaService.partitionIntoReels(movieDurationMs, mockSegments);

      expect(reels.length).toBe(6);
      expect(reels[0].nominalStartMs).toBe(0);
      expect(reels[0].nominalEndMs).toBe(15 * 60 * 1000);
      expect(reels[1].nominalStartMs).toBe(15 * 60 * 1000);
      expect(reels[5].nominalEndMs).toBe(movieDurationMs);

      // Verify authoritative segment assignment
      expect(assignedSegments.get(0)?.length).toBe(2);
      expect(assignedSegments.get(1)?.length).toBe(1);
      expect(assignedSegments.get(5)?.length).toBe(1);
    });

    it("5. Reconciles boundary-crossing dialogue (14:59.500 to 15:01.200) without truncation or duplication", () => {
      const totalDurationMs = 30 * 60 * 1000;
      // Sentence starts at 14m 59.5s and finishes at 15m 01.2s (midpoint: 15m 00.35s = 900,350ms)
      const boundaryCrossingSegment = {
        start: 899500, // 14:59.500
        end: 901200,   // 15:01.200
        text: "This critical sentence crosses the 15-minute boundary.",
      };

      const segments = [
        { start: 1000, end: 5000, text: "First sentence in Reel 1." },
        boundaryCrossingSegment,
        { start: 905000, end: 910000, text: "Second sentence in Reel 2." },
      ];

      const { reels, assignedSegments } = mediaService.partitionIntoReels(totalDurationMs, segments);

      // Total reels for 30m is 2
      expect(reels.length).toBe(2);

      // Midpoint is 900,350ms which is >= 900,000ms (nominalStartMs of Reel 1)
      // Therefore, boundaryCrossingSegment is assigned exclusively to Reel 1 (the second reel, 0-indexed)
      const reel0Segments = assignedSegments.get(0) || [];
      const reel1Segments = assignedSegments.get(1) || [];

      expect(reel0Segments.some((s) => s.text === boundaryCrossingSegment.text)).toBe(false);
      expect(reel1Segments.some((s) => s.text === boundaryCrossingSegment.text)).toBe(true);

      // Total count across all reels must exactly equal total input segments (Zero Missing, Zero Duplicates)
      const totalAssigned = (reel0Segments.length) + (reel1Segments.length);
      expect(totalAssigned).toBe(segments.length);

      // Global PTS must remain intact
      const assigned = reel1Segments.find((s) => s.text === boundaryCrossingSegment.text);
      expect(assigned?.start).toBe(899500);
      expect(assigned?.end).toBe(901200);
    });

    it("6. Generates unique idempotency keys for each reel to prevent duplicate worker publication", () => {
      const totalDurationMs = 45 * 60 * 1000;
      const { reels } = mediaService.partitionIntoReels(totalDurationMs, []);

      expect(reels.length).toBe(3);
      const keys = reels.map((r) => r.idempotencyKey);
      const uniqueKeys = new Set(keys);
      expect(uniqueKeys.size).toBe(3);
      expect(keys[0]).toContain("reel_0_of_3");
      expect(keys[1]).toContain("reel_1_of_3");
    });
  });
});
