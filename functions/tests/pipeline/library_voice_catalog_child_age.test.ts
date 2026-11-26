import {
  toAgeBucket,
  libraryVoiceToCandidate,
  loadLibraryCatalog,
  libraryVoicesFor,
  type LibraryVoice,
} from "../../src/pipeline/services/library-voice-catalog";
import {
  voiceMatcher,
  AGE_BUCKET_ANCHORS,
  VERIFIED_PRESET_CALIBRATIONS,
  type DiarizedSpeakerProfile,
} from "../../src/pipeline/services/voice-matcher";

describe("Library Voice Catalog & Child Voice Matching (Fix 1)", () => {
  describe("toAgeBucket", () => {
    it("returns 'child' for 'child' or 'kid' labels", () => {
      expect(toAgeBucket("child")).toBe("child");
      expect(toAgeBucket("kid")).toBe("child");
      expect(toAgeBucket("Kid")).toBe("child");
      expect(toAgeBucket("CHILD")).toBe("child");
      expect(toAgeBucket("young kid")).toBe("child");
    });

    it("returns appropriate buckets for adult labels", () => {
      expect(toAgeBucket("young")).toBe("young");
      expect(toAgeBucket("middle_aged")).toBe("middle_aged");
      expect(toAgeBucket("middle aged")).toBe("middle_aged");
      expect(toAgeBucket("old")).toBe("old");
      expect(toAgeBucket("senior")).toBe("old");
    });

    it("anchors child age to 10", () => {
      expect(AGE_BUCKET_ANCHORS.child).toBe(10);
    });
  });

  describe("libraryVoiceToCandidate with calibrations", () => {
    it("applies VERIFIED_PRESET_CALIBRATIONS overrides to known child presets", () => {
      const munniVoice: LibraryVoice = {
        voiceId: "VOGEEZj2Kly5dP9LrQy8",
        publicOwnerId: "owner_munni",
        name: "Munni",
        gender: "female",
        age: "child",
        accent: "indian",
        verifiedForLanguage: true,
        noticePeriodDays: 30,
      };

      const candidate = libraryVoiceToCandidate(munniVoice, "hi");
      const cal = VERIFIED_PRESET_CALIBRATIONS["VOGEEZj2Kly5dP9LrQy8"]!;

      expect(candidate.ageBucket).toBe("child");
      expect(candidate.representativeAge).toBe(cal.representativeAge);
      expect(candidate.typicalPitchHz).toBe(cal.typicalPitchHz);
      expect(candidate.representativeAge).toBe(9);
      expect(candidate.typicalPitchHz).toBe(265);
    });

    it("defaults uncalibrated child library voice to AGE_BUCKET_ANCHORS.child (10)", () => {
      const customChildVoice: LibraryVoice = {
        voiceId: "uncalibrated_child_voice_123",
        publicOwnerId: "owner_xyz",
        name: "Custom Kid",
        gender: "male",
        age: "child",
        accent: "indian",
        verifiedForLanguage: true,
        noticePeriodDays: 30,
      };

      const candidate = libraryVoiceToCandidate(customChildVoice, "te");
      expect(candidate.ageBucket).toBe("child");
      expect(candidate.representativeAge).toBe(10);
      expect(candidate.pitchMeasured).toBe(false);
    });
  });

  describe("scoreCandidate with mixed child and adult voice pool", () => {
    const catalog = loadLibraryCatalog();
    const teVoices = libraryVoicesFor(catalog, "te").map((v) => libraryVoiceToCandidate(v, "te"));
    const hiVoices = libraryVoicesFor(catalog, "hi").map((v) => libraryVoiceToCandidate(v, "hi"));
    const pool = [...teVoices, ...hiVoices];

    const childVoiceIds = new Set([
      "VOGEEZj2Kly5dP9LrQy8", // Munni
      "4iqKdEXMW8NRF8USiS3Q", // Bittu
      "5krdMTA5HonvWAlY2vSx", // Bholu
      "CNKl99QEbWm8RQ4D8GfC", // Chutki
      "psk8YLODv4ETdKheNwwz", // Gappu
      "uyv82ARGSiPieXDxTMOc", // Kavya
    ]);

    it("assigns a child voice to a child speaker (age 9, child bucket, 260 Hz)", () => {
      const childSpeaker: DiarizedSpeakerProfile = {
        speakerId: "child_speaker_1",
        estimatedAge: 9,
        ageBucket: "child",
        gender: "male",
        medianPitchHz: 260,
        timbreTags: ["child", "animated"],
        confidence: 0.95,
      };

      // Filter pool to male voices matching speaker gender
      const malePool = pool.filter((v) => v.gender === "male");
      expect(malePool.length).toBeGreaterThan(0);

      const scored = malePool.map((candidate) => ({
        candidate,
        distance: voiceMatcher.scoreCandidate(childSpeaker, candidate),
      })).sort((a, b) => a.distance - b.distance);

      const bestMatch = scored[0].candidate;
      expect(bestMatch.ageBucket).toBe("child");
      expect(childVoiceIds.has(bestMatch.voiceId)).toBe(true);
    });

    it("never assigns a child voice to an adult male speaker (age 40, ~110 Hz), even with pitchMeasured: false for all candidates", () => {
      const adultMaleSpeaker: DiarizedSpeakerProfile = {
        speakerId: "adult_male_speaker",
        estimatedAge: 40,
        ageBucket: "middle_aged",
        gender: "male",
        medianPitchHz: 110,
        timbreTags: ["conversational", "calm"],
        confidence: 0.95,
      };

      // Force pitchMeasured: false across every candidate in the pool
      const unmeasuredMalePool = pool
        .filter((v) => v.gender === "male")
        .map((c) => ({ ...c, pitchMeasured: false }));

      expect(unmeasuredMalePool.some((c) => childVoiceIds.has(c.voiceId))).toBe(true);

      const scored = unmeasuredMalePool.map((candidate) => ({
        candidate,
        distance: voiceMatcher.scoreCandidate(adultMaleSpeaker, candidate),
      })).sort((a, b) => a.distance - b.distance);

      const bestMatch = scored[0].candidate;
      // Adult male MUST receive an adult voice, NEVER a child voice
      expect(bestMatch.ageBucket).not.toBe("child");
      expect(childVoiceIds.has(bestMatch.voiceId)).toBe(false);

      // Verify that every single child candidate has a significantly worse distance than the winning adult voice
      const bestAdultDistance = scored[0].distance;
      const childCandidatesScored = scored.filter((s) => childVoiceIds.has(s.candidate.voiceId));
      for (const childScored of childCandidatesScored) {
        expect(childScored.distance).toBeGreaterThan(bestAdultDistance);
      }
    });
  });
});
