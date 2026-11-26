import { DubbingQualityGate, isBlockingViolation } from "../../src/pipeline/layers/quality-gate";

describe("Dubbing Automated Quality Gate", () => {
  const baseValidParams = {
    jobId: "test-job-123",
    targetLang: "en",
    totalSegments: 10,
    successfulSegments: 10,
    failedSegments: [],
    actualDurationSeconds: 62.5,
    expectedDurationSeconds: 63.0,
    isVoiceCloningRequested: true,
    isVoiceCloned: true,
    voiceId: "cloned-voice-001",
    stemIsolationRequested: true,
    isStemPreserved: true,
    mneStemUrl: "gs://truthworld-1/audio/test/mne.mp3",
    outputAudioSize: 1200000, // ~1.2MB
  };

  test("1. Passes when all quality standards are met", () => {
    const result = DubbingQualityGate.evaluate(baseValidParams);
    expect(result.passed).toBe(true);
    expect(result.status).toBe("PASSED");
    expect(result.violations).toHaveLength(0);
    expect(result.metadata.segmentCompletionRatio).toBe(1.0);
    expect(result.metadata.quotaExceeded).toBe(false);
  });

  test("2. Rejects when any segment fails (Zero Missing Segments Gate)", () => {
    const result = DubbingQualityGate.evaluate({
      ...baseValidParams,
      successfulSegments: 9,
      failedSegments: [
        { index: 0, text: "Some dialogue", error: "Synthesis timeout", isQuota: false },
      ],
    });

    expect(result.passed).toBe(false);
    expect(result.status).toBe("PARTIAL");
    expect(result.violations).toEqual(
      expect.arrayContaining([
        expect.stringContaining("Missing speech segments: 1 of 10 segments failed"),
      ])
    );
  });

  test("3. Explicitly flags quota exceeded failures", () => {
    const result = DubbingQualityGate.evaluate({
      ...baseValidParams,
      successfulSegments: 1,
      totalSegments: 2,
      failedSegments: [
        { index: 0, text: "Nehru envisioned...", error: "quota_exceeded: 288 credits remaining", isQuota: true },
      ],
    });

    expect(result.passed).toBe(false);
    expect(result.metadata.quotaExceeded).toBe(true);
    expect(result.violations[0]).toContain("Credit quota exceeded");
  });

  test("4. Rejects duration mismatch (e.g., 2.69s audio for 74s video)", () => {
    const result = DubbingQualityGate.evaluate({
      ...baseValidParams,
      actualDurationSeconds: 2.69,
      expectedDurationSeconds: 74.1,
    });

    expect(result.passed).toBe(false);
    expect(result.status).toBe("FAILED");
    expect(result.violations).toEqual(
      expect.arrayContaining([
        expect.stringContaining("Audio duration mismatch: Dubbed audio is 2.7s, but video is 74.1s"),
      ])
    );
  });

  test("5. Rejects suspiciously small/truncated audio files for long videos", () => {
    const result = DubbingQualityGate.evaluate({
      ...baseValidParams,
      outputAudioSize: 4300, // 4.3KB
      expectedDurationSeconds: 60.0,
      actualDurationSeconds: 60.0,
    });

    expect(result.passed).toBe(false);
    expect(result.violations).toEqual(
      expect.arrayContaining([
        expect.stringContaining("Audio file truncated: Output size (4300 bytes) is suspiciously low"),
      ])
    );
  });

  test("6. Rejects when voice cloning was requested but could not be verified", () => {
    const result = DubbingQualityGate.evaluate({
      ...baseValidParams,
      isVoiceCloningRequested: true,
      isVoiceCloned: false,
    });

    expect(result.passed).toBe(false);
    expect(result.violations).toEqual(
      expect.arrayContaining([
        expect.stringContaining("Voice cloning was requested, but fallback standard voice was used"),
      ])
    );
  });

  test("7. Rejects when background music was requested but stem preservation failed", () => {
    const result = DubbingQualityGate.evaluate({
      ...baseValidParams,
      stemIsolationRequested: true,
      isStemPreserved: false,
    });

    expect(result.passed).toBe(false);
    expect(result.violations).toEqual(
      expect.arrayContaining([
        expect.stringContaining("Background music preservation was requested, but discrete stem isolation or ducking failed"),
      ])
    );
  });

  test("8. Fix 2.3: translationBlockedLines produces blocking violation controlled by DUBBING_BLOCK_ON_TRANSLATION_ERRORS", () => {
    delete process.env.DUBBING_BLOCK_ON_TRANSLATION_ERRORS;
    const result = DubbingQualityGate.evaluate({
      ...baseValidParams,
      translationBlockedLines: [
        {
          index: 2,
          reason: "polarity_flip",
          source: "He did not leave.",
          text: "అతను వెళ్ళిపోయాడు.",
        },
      ],
    });

    expect(result.passed).toBe(false);
    const violation = result.violations.find((v) => v.startsWith("Translation meaning error"));
    expect(violation).toBeDefined();
    expect(violation).toContain("line 3 (polarity_flip)");
    expect(isBlockingViolation(violation!)).toBe(true);

    process.env.DUBBING_BLOCK_ON_TRANSLATION_ERRORS = "false";
    expect(isBlockingViolation(violation!)).toBe(false);
    delete process.env.DUBBING_BLOCK_ON_TRANSLATION_ERRORS;
  });
});
