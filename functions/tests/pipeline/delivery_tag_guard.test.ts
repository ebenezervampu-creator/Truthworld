/**
 * 🛡️ Delivery Tag Guard Tests
 *
 * Verifies:
 * 1. Voiced quiet line (pitch present, low energy) proposed as `whispers` by Gemini → `soft`.
 * 2. Unvoiced line (no pitch) proposed as `whispers` → stays `whispers`.
 * 3. `intimate` → `soft`.
 * 4. Relative quietness: -34 dBFS line is `soft` for speaker median -24 dB, and untagged for speaker median -33 dB.
 * 5. Smoothing: calm → soft → calm for one speaker within 3 s with weak evidence → all calm; a `crying` line in between is untouched.
 * 6. Flag OFF (DUBBING_WHISPER_GUARD=false) → output identical to legacy behavior for fixed fixtures.
 * 7. Prosody cache key changes when the rule version changes (ruleVersion: PROSODY_RULE_VERSION), while fingerprint cache key is unaffected.
 */

import {
  decideDeliveryTag,
  smoothDeliveryTagsPerSpeaker,
  summarizeDeliveryTags,
  isDubbingWhisperGuardEnabled,
  MAX_WHISPER_VOICED_SHARE,
  QUIET_SPEAKER_OFFSET_DB,
  SHOUT_SPEAKER_OFFSET_DB,
  MAX_SCENE_GAP_MS,
  STRONG_ENERGY_CHANGE_THRESHOLD_DB,
  STRONG_EMOTION_INTENSITY_THRESHOLD,
  PROSODY_RULE_VERSION,
  isVerifiedWhisper,
  whisperEvidence,
  type DeliveryTagInput,
  type SmoothDeliveryItem,
} from "../../src/pipeline/services/delivery-tag-guard";
import {
  mapEmotionToElevenLabsCue,
  audioIdentityService,
} from "../../src/pipeline/services/audio-identity";
import { stepCacheKey } from "../../src/pipeline/services/dubbing-step-cache";

describe("Delivery Tag Guard (False Whisper Prevention)", () => {
  const originalEnv = process.env.DUBBING_WHISPER_GUARD;

  afterEach(() => {
    if (originalEnv !== undefined) {
      process.env.DUBBING_WHISPER_GUARD = originalEnv;
    } else {
      delete process.env.DUBBING_WHISPER_GUARD;
    }
  });

  describe("1. Voiced vs Unvoiced Whisper Guarding", () => {
    test("voiced quiet line (pitch present: f0Hz = 120Hz, voicedShare = 0.75, energyDb = -34) proposed as whispers by Gemini → downgraded to soft", () => {
      const input: DeliveryTagInput = {
        index: 0,
        speaker: "speaker_0",
        f0Hz: 120.5,
        voicedShare: 0.75,
        energyDb: -34.0,
        speakerMedianDb: -24.0,
        geminiTag: "whispers",
        proposedTag: "whispers",
        voiceQuality: "modal",
      };

      const decision = decideDeliveryTag(input);
      expect(decision.finalTag).toBe("soft");
      expect(decision.wasWhisperProposed).toBe(true);
      expect(decision.wasWhisperKept).toBe(false);
      expect(decision.wasDowngradedToSoft).toBe(true);
      expect(decision.reason).toContain("voiced_whisper_downgraded_to_soft");
    });

    test("unvoiced line (no measurable pitch: f0Hz = null, voicedShare = 0.05) proposed as whispers → stays whispers", () => {
      const input: DeliveryTagInput = {
        index: 1,
        speaker: "speaker_0",
        f0Hz: null,
        voicedShare: 0.05,
        energyDb: -38.0,
        speakerMedianDb: -24.0,
        geminiTag: "whispers",
        proposedTag: "whispers",
      };

      const decision = decideDeliveryTag(input);
      expect(decision.finalTag).toBe("whispers");
      expect(decision.wasWhisperProposed).toBe(true);
      expect(decision.wasWhisperKept).toBe(true);
      expect(decision.wasDowngradedToSoft).toBe(false);
      expect(decision.reason).toBe("unvoiced_whisper_verified");
    });

    test("boundary check: voicedShare exactly at MAX_WHISPER_VOICED_SHARE (0.20) counts as voiced → soft", () => {
      const input: DeliveryTagInput = {
        index: 2,
        speaker: "speaker_0",
        f0Hz: null,
        voicedShare: MAX_WHISPER_VOICED_SHARE, // 0.20
        proposedTag: "whispers",
      };

      const decision = decideDeliveryTag(input);
      expect(decision.finalTag).toBe("soft");
      expect(decision.wasDowngradedToSoft).toBe(true);
    });

    test("boundary check: voicedShare strictly below MAX_WHISPER_VOICED_SHARE (e.g. 0.15) with no pitch → whispers", () => {
      const input: DeliveryTagInput = {
        index: 3,
        speaker: "speaker_0",
        f0Hz: null,
        voicedShare: 0.15,
        proposedTag: "whispers",
      };

      const decision = decideDeliveryTag(input);
      expect(decision.finalTag).toBe("whispers");
      expect(decision.wasWhisperKept).toBe(true);
    });
  });

  describe("2. Alias Mapping: intimate → soft", () => {
    test("lexical or Gemini tag 'intimate' maps to 'soft' under guard", () => {
      const input: DeliveryTagInput = {
        index: 4,
        speaker: "speaker_1",
        proposedTag: "intimate",
        f0Hz: 180.0,
        voicedShare: 0.80,
      };

      const decision = decideDeliveryTag(input);
      expect(decision.finalTag).toBe("soft");
      expect(decision.wasWhisperProposed).toBe(false);
      expect(decision.wasDowngradedToSoft).toBe(false);
    });

    test("audioIdentityService.mapEmotionToElevenLabsCue maps 'intimate' to 'soft' when guard is ON", () => {
      const cue = mapEmotionToElevenLabsCue("intimate", -25, undefined, undefined, {
        whisperGuard: true,
      });
      expect(cue.emotionTag).toBe("soft");
      // soft stability remains locked/standard (0.55), not the legacy whisper 0.34
      expect(cue.stabilityOverride).toBe(0.55);
    });
  });

  describe("3. Relative, Not Absolute, Quietness", () => {
    test("same -34 dBFS line is 'soft' for speaker with median -24 dB (offset = 10 dB >= 10 dB)", () => {
      const input: DeliveryTagInput = {
        index: 5,
        speaker: "speaker_A",
        energyDb: -34.0,
        speakerMedianDb: -24.0, // difference is 10 dB <= median - 10
      };

      const decision = decideDeliveryTag(input);
      expect(decision.finalTag).toBe("soft");
      expect(decision.reason).toBe("accepted_soft");
    });

    test("same -34 dBFS line is untagged for speaker with median -33 dB (offset = 1 dB < 10 dB)", () => {
      const input: DeliveryTagInput = {
        index: 6,
        speaker: "speaker_B",
        energyDb: -34.0,
        speakerMedianDb: -33.0, // difference is only 1 dB
      };

      const decision = decideDeliveryTag(input);
      expect(decision.finalTag).toBeUndefined();
      expect(decision.reason).toBe("neutral_untagged");
    });

    test("energy alone never proposes or produces 'whispers' under guard", () => {
      const quietInput: DeliveryTagInput = {
        index: 7,
        speaker: "speaker_A",
        energyDb: -42.0, // very quiet
        speakerMedianDb: -20.0,
      };

      const decision = decideDeliveryTag(quietInput);
      expect(decision.finalTag).toBe("soft");
      expect(decision.wasWhisperProposed).toBe(false);
      expect(decision.finalTag).not.toBe("whispers");
    });

    test("shouts is also relative: line at -10 dB is shouts for speaker median -22 dB (diff 12 dB >= 10 dB)", () => {
      const loudInput: DeliveryTagInput = {
        index: 8,
        speaker: "speaker_A",
        energyDb: -10.0,
        speakerMedianDb: -22.0,
      };

      const decision = decideDeliveryTag(loudInput);
      expect(decision.finalTag).toBe("shouts");
    });
  });

  describe("4. Scene Delivery Smoothing", () => {
    test("calm → soft → calm for one speaker within 3 s with weak evidence smooths to all calm", () => {
      const items: SmoothDeliveryItem[] = [
        {
          index: 0,
          speaker: "speaker_0",
          startMs: 1000,
          endMs: 2500,
          energyDb: -22.0,
          finalTag: "calm",
        },
        {
          index: 1,
          speaker: "speaker_0",
          startMs: 3500, // gap = 1000 ms (< 3000 ms)
          endMs: 5000,
          energyDb: -24.0, // energyChange = 2.0 dB (< 6.0 dB)
          finalTag: "soft",
          peakIntensity: 0.30, // (< 0.72)
        },
        {
          index: 2,
          speaker: "speaker_0",
          startMs: 6000, // gap = 1000 ms (< 3000 ms)
          endMs: 7500,
          energyDb: -23.0, // energyChange = 1.0 dB (< 6.0 dB)
          finalTag: "calm",
          peakIntensity: 0.25,
        },
      ];

      const { smoothedSegments, smoothedCount, changes } = smoothDeliveryTagsPerSpeaker(items);

      expect(smoothedCount).toBe(1);
      expect(changes.length).toBe(1);
      expect(changes[0].index).toBe(1);
      expect(changes[0].fromTag).toBe("soft");
      expect(changes[0].toTag).toBe("calm");
      expect(smoothedSegments.map((s) => s.finalTag)).toEqual(["calm", "calm", "calm"]);
    });

    test("a 'crying' line in between is untouched during smoothing", () => {
      const items: SmoothDeliveryItem[] = [
        {
          index: 0,
          speaker: "speaker_0",
          startMs: 1000,
          endMs: 2500,
          energyDb: -22.0,
          finalTag: "calm",
        },
        {
          index: 1,
          speaker: "speaker_0",
          startMs: 3200,
          endMs: 4500,
          energyDb: -20.0,
          finalTag: "crying", // Strong emotion tag!
          peakIntensity: 0.85,
        },
        {
          index: 2,
          speaker: "speaker_0",
          startMs: 5200,
          endMs: 6500,
          energyDb: -23.0,
          finalTag: "calm",
        },
      ];

      const { smoothedSegments, smoothedCount } = smoothDeliveryTagsPerSpeaker(items);

      expect(smoothedCount).toBe(0);
      expect(smoothedSegments[1].finalTag).toBe("crying");
      expect(smoothedSegments.map((s) => s.finalTag)).toEqual(["calm", "crying", "calm"]);
    });

    test("delivery switch is preserved when energy change is strong (>= 6 dB)", () => {
      const items: SmoothDeliveryItem[] = [
        {
          index: 0,
          speaker: "speaker_0",
          startMs: 1000,
          endMs: 2000,
          energyDb: -20.0,
          finalTag: "calm",
        },
        {
          index: 1,
          speaker: "speaker_0",
          startMs: 3000,
          endMs: 4000,
          energyDb: -28.0, // delta = 8.0 dB (>= 6.0 dB)
          finalTag: "soft",
        },
      ];

      const { smoothedSegments, smoothedCount } = smoothDeliveryTagsPerSpeaker(items);
      expect(smoothedCount).toBe(0);
      expect(smoothedSegments[1].finalTag).toBe("soft");
    });

    test("lines separated by more than 3 s (> MAX_SCENE_GAP_MS) are not smoothed", () => {
      const items: SmoothDeliveryItem[] = [
        {
          index: 0,
          speaker: "speaker_0",
          startMs: 1000,
          endMs: 2000,
          energyDb: -22.0,
          finalTag: "calm",
        },
        {
          index: 1,
          speaker: "speaker_0",
          startMs: 6000, // gap = 4000 ms (> 3000 ms)
          endMs: 7000,
          energyDb: -23.0,
          finalTag: "soft",
        },
      ];

      const { smoothedSegments, smoothedCount } = smoothDeliveryTagsPerSpeaker(items);
      expect(smoothedCount).toBe(0);
      expect(smoothedSegments[1].finalTag).toBe("soft");
    });
  });

  describe("5. Rollback Flag: DUBBING_WHISPER_GUARD=false", () => {
    test("when DUBBING_WHISPER_GUARD=false, output is identical to legacy mapEmotionToElevenLabsCue", () => {
      process.env.DUBBING_WHISPER_GUARD = "false";
      expect(isDubbingWhisperGuardEnabled()).toBe(false);

      // Legacy test cases:
      // Case 1: energyDb <= -32 produces whispers regardless of pitch
      const cue1 = mapEmotionToElevenLabsCue(undefined, -34.0, undefined, undefined, {
        whisperGuard: false,
        f0Hz: 150.0, // pitch present!
        speakerMedianDb: -33.0,
      });
      expect(cue1.emotionTag).toBe("whispers");
      expect(cue1.stabilityOverride).toBe(0.34);

      // In decideDeliveryTag with enabled: false
      const decision1 = decideDeliveryTag(
        {
          index: 0,
          speaker: "speaker_0",
          energyDb: -34.0,
          f0Hz: 150.0,
          speakerMedianDb: -33.0,
        },
        { enabled: false }
      );
      expect(decision1.finalTag).toBe("whispers");
      expect(decision1.reason).toBe("guard_disabled");

      // Case 2: 'intimate' maps to 'whispers' under legacy
      const cue2 = mapEmotionToElevenLabsCue("intimate", -20, undefined, undefined, {
        whisperGuard: false,
      });
      expect(cue2.emotionTag).toBe("whispers");
      expect(cue2.stabilityOverride).toBe(0.34);

      const decision2 = decideDeliveryTag(
        {
          index: 1,
          speaker: "speaker_0",
          proposedTag: "intimate",
        },
        { enabled: false }
      );
      expect(decision2.finalTag).toBe("whispers");

      // Case 3: calm -> soft -> calm smoothing does nothing when disabled
      const items: SmoothDeliveryItem[] = [
        { index: 0, speaker: "spk", startMs: 1000, endMs: 2000, finalTag: "calm" },
        { index: 1, speaker: "spk", startMs: 2500, endMs: 3500, finalTag: "soft" },
      ];
      const { smoothedSegments, smoothedCount } = smoothDeliveryTagsPerSpeaker(items, { enabled: false });
      expect(smoothedCount).toBe(0);
      expect(smoothedSegments[1].finalTag).toBe("soft");
    });
  });

  describe("6. Telemetry & Summary Accounting", () => {
    test("summarizeDeliveryTags calculates exact proposed, kept, downgraded, and smoothed counts", () => {
      const decisions = [
        { wasWhisperProposed: true, wasWhisperKept: false, wasDowngradedToSoft: true },
        { wasWhisperProposed: true, wasWhisperKept: true, wasDowngradedToSoft: false },
        { wasWhisperProposed: false, wasWhisperKept: false, wasDowngradedToSoft: false },
        { wasWhisperProposed: true, wasWhisperKept: false, wasDowngradedToSoft: true },
      ];

      const summary = summarizeDeliveryTags(decisions, 2);
      expect(summary).toEqual({
        whispersProposed: 3,
        whispersKept: 1,
        downgradedToSoft: 2,
        smoothed: 2,
      });
    });
  });

  describe("7. Cache Invalidation Versioning", () => {
    test("prosody cache key changes when ruleVersion changes, while fingerprint is unaffected", () => {
      const audioSource = "gs://truthworld-staging/audio.wav";
      const segmentsHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

      // Prosody cache key with the current PROSODY_RULE_VERSION
      const prosodyKeyV2 = stepCacheKey("prosody", {
        audio: audioSource,
        segments: segmentsHash,
        ruleVersion: PROSODY_RULE_VERSION,
      });

      // Prosody cache key with legacy ruleVersion = 1
      const prosodyKeyV1 = stepCacheKey("prosody", {
        audio: audioSource,
        segments: segmentsHash,
        ruleVersion: 1,
      });

      expect(prosodyKeyV2).not.toBe(prosodyKeyV1);

      // Fingerprint cache key only depends on audio, not on prosody rules
      const fingerprintKeyA = stepCacheKey("fingerprint", { audio: audioSource });
      const fingerprintKeyB = stepCacheKey("fingerprint", { audio: audioSource });

      expect(fingerprintKeyA).toBe(fingerprintKeyB);
    });
  });

  describe("8. Whisper needs measured evidence (2026-11-24 te run: null pitch kept [whispers] on line 10)", () => {
    test("pitch and voiced share both unmeasured (null) → soft, not whispers", () => {
      const d = decideDeliveryTag({ index: 10, speaker: "A", f0Hz: null, voicedShare: null, voiceQuality: "breathy", proposedTag: "whispers" }, { enabled: true });
      expect(d.finalTag).toBe("soft");
      expect(d.wasWhisperKept).toBe(false);
      expect(d.reason).toContain("whisper_unverified_no_voicing_measurement");
    });

    test("low measured voiced share but Gemini hears a modal voice → soft", () => {
      const d = decideDeliveryTag({ index: 0, speaker: "A", f0Hz: null, voicedShare: 0.05, voiceQuality: "modal", proposedTag: "whispers" }, { enabled: true });
      expect(d.finalTag).toBe("soft");
      expect(d.reason).toContain("whisper_unverified_voice_heard");
    });

    test("low measured voiced share and breathy → whispers kept", () => {
      const d = decideDeliveryTag({ index: 1, speaker: "A", f0Hz: null, voicedShare: 0.05, voiceQuality: "breathy", proposedTag: "whispers" }, { enabled: true });
      expect(d.finalTag).toBe("whispers");
      expect(d.reason).toBe("unvoiced_whisper_verified");
    });

    test("whisperEvidence covers each case", () => {
      expect(whisperEvidence({ f0Hz: 120, voicedShare: 0.1 })).toBe("voiced");
      expect(whisperEvidence({ f0Hz: null, voicedShare: 0.5 })).toBe("voiced");
      expect(whisperEvidence({ f0Hz: null, voicedShare: undefined })).toBe("unmeasured");
      expect(whisperEvidence({ f0Hz: null, voicedShare: 0.1, voiceQuality: "pressed" })).toBe("voice_heard");
      expect(isVerifiedWhisper({ f0Hz: null, voicedShare: 0.1 })).toBe(true);
    });

    test("mapEmotionToElevenLabsCue uses the same rule: unmeasured whisper becomes soft", () => {
      const prev = process.env.DUBBING_WHISPER_GUARD;
      process.env.DUBBING_WHISPER_GUARD = "true";
      try {
        const cue = mapEmotionToElevenLabsCue("whispers", -30, "breathy", undefined, { f0Hz: null, voicedShare: null } as any);
        expect(cue.emotionTag).toBe("soft");
      } finally {
        if (prev === undefined) delete process.env.DUBBING_WHISPER_GUARD;
        else process.env.DUBBING_WHISPER_GUARD = prev;
      }
    });
  });
});
