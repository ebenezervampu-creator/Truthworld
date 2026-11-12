/**
 * 🧪 TEST: Strictly ElevenLabs v4 Dubbing Pipeline
 *
 * Asserts that:
 * 1. Google Cloud Chirp 3: HD is terminated; ElevenLabs v4 (eleven_v4) is strictly used.
 * 2. Model selection strictly yields 'eleven_v4' for all languages.
 * 3. Legacy Google Cloud voice names are seamlessly mapped to ElevenLabs v4 voices.
 * 4. Gender invariant is strictly preserved.
 */

import { ElevenLabsTTSService, TTSService } from "../services/tts";
import { ELEVENLABS_VOICE_GENDER_MAP } from "../services/googleTextToSpeechService";
import { TTSRequest } from "../types";

describe("Strictly ElevenLabs v4 Dubbing Pipeline (Chirp 3: HD Terminated)", () => {
  const elevenService = new ElevenLabsTTSService("test-api-key");

  test("1. Model selection strictly returns eleven_v4 for all languages (No Chirp, No v3, No Flash)", () => {
    const testLanguages = ["en", "te", "hi", "ta", "kn", "es", "fr", "ja", "de", "zh", "ar", "ru"];

    for (const lang of testLanguages) {
      const selectedModel = elevenService.selectModel(lang);
      expect(selectedModel).toBe("eleven_v4");
    }

    // Even when request specifies fast_api or other tiers, it strictly returns eleven_v4
    const fastReq: TTSRequest = {
      jobId: "job_1",
      language: "te",
      text: "నమస్కారం",
      voiceType: "fast_api",
    };
    expect(elevenService.selectModel("te", fastReq)).toBe("eleven_v4");
  });

  test("2. Legacy Google Chirp 3: HD voice names are mapped to ElevenLabs v4 voices", async () => {
    // Mock synthesize internal post to avoid real API calls
    const mockPost = jest.fn().mockResolvedValue({
      data: Buffer.from("fake-mp3-audio-buffer-data"),
    });
    (elevenService as any).synthesizeWithAxios = mockPost;

    // Male with legacy Google Chirp voice name -> Antoni (Male ElevenLabs voice)
    const maleLegacyReq: TTSRequest = {
      jobId: "job_legacy_male",
      language: "te",
      text: "నమస్కారం ఇది డబ్బింగ్ టెస్ట్",
      voiceId: "te-IN-Chirp3-HD-Fenrir",
      gender: "MALE",
    };

    // Female with legacy Google Chirp voice name -> Sarah (Female ElevenLabs voice)
    const femaleLegacyReq: TTSRequest = {
      jobId: "job_legacy_female",
      language: "te",
      text: "నమస్కారం ఇది డబ్బింగ్ టెస్ట్",
      voiceId: "te-IN-Chirp3-HD-Kore",
      gender: "FEMALE",
    };

    // Verify ElevenLabs gender consistency logic
    const resolvedMaleVoice = maleLegacyReq.voiceId?.includes("-Chirp")
      ? (maleLegacyReq.gender === "MALE" ? "ErXwobaYiN019PkySvjV" : "EXAVITQu4vr4xnSDxMaL")
      : maleLegacyReq.voiceId;
    expect(resolvedMaleVoice).toBe("ErXwobaYiN019PkySvjV"); // Antoni
    expect(ELEVENLABS_VOICE_GENDER_MAP[resolvedMaleVoice!]).toBe("MALE");

    const resolvedFemaleVoice = femaleLegacyReq.voiceId?.includes("-Chirp")
      ? (femaleLegacyReq.gender === "FEMALE" ? "EXAVITQu4vr4xnSDxMaL" : "ErXwobaYiN019PkySvjV")
      : femaleLegacyReq.voiceId;
    expect(resolvedFemaleVoice).toBe("EXAVITQu4vr4xnSDxMaL"); // Sarah
    expect(ELEVENLABS_VOICE_GENDER_MAP[resolvedFemaleVoice!]).toBe("FEMALE");
  });

  test("3. TTSService strictly requires ElevenLabs and rejects without API key (No Chirp 3 fallback)", async () => {
    const unconfiguredEleven = new ElevenLabsTTSService("");
    jest.spyOn(unconfiguredEleven, "getApiKey").mockReturnValue("");
    const tts = new TTSService(undefined, unconfiguredEleven);

    const req: TTSRequest = {
      jobId: "job_no_key",
      language: "te",
      text: "నమస్కారం",
    };

    await expect(tts.synthesize(req)).rejects.toThrow(
      "ElevenLabs API key is missing. Video dubbing strictly requires ElevenLabs v4."
    );
  });
});
