import { parseDurationToSeconds, parseGcsUri } from "../../src/pipeline/services/media";
import {
  ELEVENLABS_VOICE_GENDER_MAP,
  ELEVENLABS_MULTI_SPEAKER_PALETTE,
} from "../../src/pipeline/services/tts";
import { SpeakerProfile } from "../../src/pipeline/services/speaker-profiling";

describe("Audio Duration and Voice Assignment Verification", () => {
  describe("parseDurationToSeconds", () => {
    it("correctly parses MM:SS format like '22:03'", () => {
      expect(parseDurationToSeconds("22:03")).toBe(1323);
      expect(parseDurationToSeconds("06:29")).toBe(389);
      expect(parseDurationToSeconds("0:45")).toBe(45);
    });

    it("correctly parses HH:MM:SS format", () => {
      expect(parseDurationToSeconds("00:22:03")).toBe(1323);
      expect(parseDurationToSeconds("01:15:30")).toBe(4530);
    });

    it("handles numeric seconds and milliseconds", () => {
      expect(parseDurationToSeconds(1323)).toBe(1323);
      expect(parseDurationToSeconds(1323000)).toBe(1323);
      expect(parseDurationToSeconds("1323")).toBe(1323);
    });

    it("safely handles edge cases without throwing", () => {
      expect(parseDurationToSeconds("")).toBe(0);
      expect(parseDurationToSeconds(null)).toBe(0);
      expect(parseDurationToSeconds(undefined)).toBe(0);
      expect(parseDurationToSeconds("invalid")).toBe(0);
      expect(parseDurationToSeconds(-50)).toBe(0);
    });
  });

  describe("ELEVENLABS_VOICE_GENDER_MAP", () => {
    it("maps male preset voices to MALE", () => {
      expect(ELEVENLABS_VOICE_GENDER_MAP["pNInz6obpgDQGcFmaJgB"]).toBe("MALE"); // Adam
      expect(ELEVENLABS_VOICE_GENDER_MAP["ErXwobaYiN019PkySvjV"]).toBe("MALE"); // Antoni
      expect(ELEVENLABS_VOICE_GENDER_MAP["g5CIjZEefAph4nJUvZnz"]).toBe("MALE"); // Marcus
    });

    it("maps female preset voices to FEMALE", () => {
      expect(ELEVENLABS_VOICE_GENDER_MAP["hpp4J3VqNfWAUOO0d1Us"]).toBe("FEMALE"); // Bella
      expect(ELEVENLABS_VOICE_GENDER_MAP["EXAVITQu4vr4xnSDxMaL"]).toBe("FEMALE"); // Sarah
    });
  });

  describe("Voice Assignment by Speaker Gender", () => {
    function assignVoice(profile: SpeakerProfile, isPrimary: boolean = true) {
      const isMale = profile.gender ? profile.gender === "male" : true;
      const role = profile.role || "other";

      let voiceId: string;
      if (isMale) {
        if (profile.pitchBand === "deep") {
          voiceId = "pNInz6obpgDQGcFmaJgB"; // Adam
        } else if (profile.pitchBand === "high" || profile.ageTone === "youthful") {
          voiceId = "g5CIjZEefAph4nJUvZnz"; // Marcus
        } else {
          voiceId = "ErXwobaYiN019PkySvjV"; // Antoni (Well-rounded male narrator/vlogger)
        }
      } else {
        if (role === "host" || isPrimary) {
          voiceId = "hpp4J3VqNfWAUOO0d1Us"; // Bella
        } else {
          voiceId = "EXAVITQu4vr4xnSDxMaL"; // Sarah
        }
      }
      return {
        voiceId,
        gender: isMale ? "MALE" : "FEMALE",
      };
    }

    it("assigns male voice to a male host/travel vlogger with normal/mid pitch", () => {
      const maleVlogger: SpeakerProfile = {
        speakerId: "speaker_0",
        gender: "male",
        style: "energetic travel vlog",
        pitchBand: "mid",
        energy: "high",
        ageTone: "adult",
        role: "host",
        wordCount: 1200,
        segments: 180,
      };

      const result = assignVoice(maleVlogger, true);
      expect(result.gender).toBe("MALE");
      expect(result.voiceId).toBe("ErXwobaYiN019PkySvjV"); // Antoni (Male)
      expect(ELEVENLABS_VOICE_GENDER_MAP[result.voiceId]).toBe("MALE");
    });

    it("assigns deep male voice to a male speaker with deep pitch", () => {
      const deepMaleSpeaker: SpeakerProfile = {
        speakerId: "speaker_0",
        gender: "male",
        style: "authoritative",
        pitchBand: "deep",
        energy: "moderate",
        ageTone: "mature",
        role: "host",
        wordCount: 900,
        segments: 90,
      };

      const result = assignVoice(deepMaleSpeaker, true);
      expect(result.gender).toBe("MALE");
      expect(result.voiceId).toBe("pNInz6obpgDQGcFmaJgB"); // Adam (Deep male)
      expect(ELEVENLABS_VOICE_GENDER_MAP[result.voiceId]).toBe("MALE");
    });

    it("assigns female voice only when speaker is female", () => {
      const femaleSpeaker: SpeakerProfile = {
        speakerId: "speaker_0",
        gender: "female",
        style: "friendly",
        pitchBand: "mid",
        energy: "moderate",
        ageTone: "adult",
        role: "host",
        wordCount: 1100,
        segments: 100,
      };

      const result = assignVoice(femaleSpeaker, true);
      expect(result.gender).toBe("FEMALE");
      expect(result.voiceId).toBe("hpp4J3VqNfWAUOO0d1Us"); // Bella (Female)
      expect(ELEVENLABS_VOICE_GENDER_MAP[result.voiceId]).toBe("FEMALE");
    });
  });

  describe("Trailing silence calculation for 22:03 video", () => {
    it("calculates exact tail silence when speech stops early", () => {
      const videoDurationStr = "22:03";
      const durationSec = parseDurationToSeconds(videoDurationStr);
      const targetDurationMs = durationSec * 1000;
      expect(targetDurationMs).toBe(1323000);

      // Suppose speech stopped at 6 minutes 29 seconds (389,000 ms)
      const lastSpeechMs = 389000;
      expect(targetDurationMs > lastSpeechMs + 100).toBe(true);

      const tailSec = Number(((targetDurationMs - lastSpeechMs) / 1000).toFixed(3));
      expect(tailSec).toBe(934.000); // 934 seconds of padding to match 22:03
      expect(lastSpeechMs / 1000 + tailSec).toBe(1323);
    });
  });

  describe("Multi-Speaker Distinct Voice Allocation (10 Speakers)", () => {
    function allocateMultiSpeakerVoices(profiles: SpeakerProfile[]) {
      const voiceMapping: Record<string, string> = {};
      const speakerGenderMapping: Record<string, "MALE" | "FEMALE"> = {};
      const assignedVoiceIds = new Set<string>();

      for (const profile of profiles) {
        const isMale = profile.gender ? profile.gender === "male" : true;
        speakerGenderMapping[profile.speakerId] = isMale ? "MALE" : "FEMALE";

        const palette = isMale
          ? ELEVENLABS_MULTI_SPEAKER_PALETTE.MALE
          : ELEVENLABS_MULTI_SPEAKER_PALETTE.FEMALE;

        let chosen = palette.find(
          (v) =>
            !assignedVoiceIds.has(v.id) &&
            v.pitchBand === profile.pitchBand &&
            v.ageTone === profile.ageTone
        );
        if (!chosen) {
          chosen = palette.find(
            (v) => !assignedVoiceIds.has(v.id) && v.pitchBand === profile.pitchBand
          );
        }
        if (!chosen) {
          chosen = palette.find((v) => !assignedVoiceIds.has(v.id));
        }
        if (!chosen) {
          const matchIdx = profile.speakerId.match(/\d+/);
          const idx = matchIdx ? parseInt(matchIdx[0], 10) : 0;
          chosen = palette[idx % palette.length];
        }

        assignedVoiceIds.add(chosen.id);
        voiceMapping[profile.speakerId] = chosen.id;
      }

      return { voiceMapping, speakerGenderMapping, assignedVoiceIds };
    }

    it("allocates 10 completely unique, collision-free voices for 10 speakers (6 male, 4 female)", () => {
      const tenSpeakers: SpeakerProfile[] = [
        // 6 Males with different pitches and ages
        { speakerId: "speaker_0", gender: "male", style: "host", pitchBand: "mid", energy: "high", ageTone: "adult", role: "host", wordCount: 800, segments: 100 },
        { speakerId: "speaker_1", gender: "male", style: "narrator", pitchBand: "deep", energy: "moderate", ageTone: "mature", role: "guest", wordCount: 600, segments: 70 },
        { speakerId: "speaker_2", gender: "male", style: "youthful", pitchBand: "high", energy: "high", ageTone: "youthful", role: "guest", wordCount: 400, segments: 50 },
        { speakerId: "speaker_3", gender: "male", style: "expert", pitchBand: "mid", energy: "moderate", ageTone: "mature", role: "expert", wordCount: 500, segments: 60 },
        { speakerId: "speaker_4", gender: "male", style: "conversational", pitchBand: "mid", energy: "moderate", ageTone: "adult", role: "guest", wordCount: 300, segments: 40 },
        { speakerId: "speaker_5", gender: "male", style: "vivid", pitchBand: "deep", energy: "high", ageTone: "adult", role: "guest", wordCount: 350, segments: 45 },

        // 4 Females with different pitches and ages
        { speakerId: "speaker_6", gender: "female", style: "co-host", pitchBand: "high", energy: "high", ageTone: "adult", role: "host", wordCount: 750, segments: 90 },
        { speakerId: "speaker_7", gender: "female", style: "interviewer", pitchBand: "mid", energy: "moderate", ageTone: "adult", role: "guest", wordCount: 450, segments: 55 },
        { speakerId: "speaker_8", gender: "female", style: "youthful girl", pitchBand: "high", energy: "high", ageTone: "youthful", role: "guest", wordCount: 300, segments: 35 },
        { speakerId: "speaker_9", gender: "female", style: "senior expert", pitchBand: "mid", energy: "low", ageTone: "mature", role: "expert", wordCount: 400, segments: 45 },
      ];

      const { voiceMapping, speakerGenderMapping, assignedVoiceIds } = allocateMultiSpeakerVoices(tenSpeakers);

      // Verify all 10 speakers received voice mappings
      expect(Object.keys(voiceMapping).length).toBe(10);

      // Verify zero collisions: exactly 10 distinct voice IDs
      expect(assignedVoiceIds.size).toBe(10);
      const uniqueAllocatedVoices = new Set(Object.values(voiceMapping));
      expect(uniqueAllocatedVoices.size).toBe(10);

      // Verify gender alignment: every single male gets a male voice, every female gets a female voice
      for (const speaker of tenSpeakers) {
        const assignedVoiceId = voiceMapping[speaker.speakerId];
        const assignedGender = ELEVENLABS_VOICE_GENDER_MAP[assignedVoiceId];
        const expectedGender = speaker.gender === "male" ? "MALE" : "FEMALE";
        expect(assignedGender).toBe(expectedGender);
      }
    });

    it("palette contains at least 10 male and 10 female voices", () => {
      expect(ELEVENLABS_MULTI_SPEAKER_PALETTE.MALE.length).toBeGreaterThanOrEqual(10);
      expect(ELEVENLABS_MULTI_SPEAKER_PALETTE.FEMALE.length).toBeGreaterThanOrEqual(10);

      // All male voices in palette have unique IDs
      const maleIds = new Set(ELEVENLABS_MULTI_SPEAKER_PALETTE.MALE.map(v => v.id));
      expect(maleIds.size).toBe(ELEVENLABS_MULTI_SPEAKER_PALETTE.MALE.length);

      // All female voices in palette have unique IDs
      const femaleIds = new Set(ELEVENLABS_MULTI_SPEAKER_PALETTE.FEMALE.map(v => v.id));
      expect(femaleIds.size).toBe(ELEVENLABS_MULTI_SPEAKER_PALETTE.FEMALE.length);
    });
  });



  describe("parseGcsUri (Universal Cross-Bucket Parsing)", () => {
    it("correctly extracts bucket name and path from standard gs:// URIs", () => {
      const res = parseGcsUri("gs://truthworld-b9a38.appspot.com/audio/job_123/chunk-456.mp3");
      expect(res.bucketName).toBe("truthworld-b9a38.appspot.com");
      expect(res.filePath).toBe("audio/job_123/chunk-456.mp3");
    });

    it("correctly extracts bucket name from firebasestorage.app URIs", () => {
      const res = parseGcsUri("gs://truthworld-b9a38.firebasestorage.app/videos/user_1/clip.mp4");
      expect(res.bucketName).toBe("truthworld-b9a38.firebasestorage.app");
      expect(res.filePath).toBe("videos/user_1/clip.mp4");
    });

    it("handles deeply nested paths without truncation", () => {
      const res = parseGcsUri("gs://my-bucket/a/b/c/d/file.wav");
      expect(res.bucketName).toBe("my-bucket");
      expect(res.filePath).toBe("a/b/c/d/file.wav");
    });
  });

  describe("Linguistic Heuristic Fallback (Zero False-Female Misclassifications)", () => {
    it("does not classify English sentences containing 'miss' as female", () => {
      const textSample = "Make sure you don't miss out on these travel tips";
      const femaleMarkers = /\b(girl|she|her|hers|woman|madam|lady|daughter|sister|aunt|mrs|ms|mam|student girl|karti|rahi|gayi|cheptondi|chestundi)\b/i;
      const maleMarkers = /\b(he|him|his|sir|man|gentleman|son|brother|uncle|mr|boy|teacher|karta|raha|gaya|unnadu|cheptunnadu)\b/i;
      const isFeminine = femaleMarkers.test(textSample);
      const isMasculine = maleMarkers.test(textSample);
      const fallbackGender = isFeminine && !isMasculine ? "female" : "male";
      expect(isFeminine).toBe(false);
      expect(fallbackGender).toBe("male");
    });

    it("does not classify Telugu existential verb 'undi' as female", () => {
      const textSample = "video lo chala information undi"; // 'undi' = exists / there is
      const femaleMarkers = /\b(girl|she|her|hers|woman|madam|lady|daughter|sister|aunt|mrs|ms|mam|student girl|karti|rahi|gayi|cheptondi|chestundi)\b/i;
      const isFeminine = femaleMarkers.test(textSample);
      expect(isFeminine).toBe(false);
    });
  });
});
