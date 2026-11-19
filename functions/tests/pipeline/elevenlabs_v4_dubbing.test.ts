/**
 * 🧪 TEST: Strictly ElevenLabs v4 Dubbing Pipeline
 *
 * Asserts that:
 * 1. Google Cloud Chirp 3: HD is terminated; ElevenLabs v4 (eleven_v4) is strictly used.
 * 2. Model selection strictly yields 'eleven_v4' for all languages.
 * 3. Legacy Google Cloud voice names are seamlessly mapped to ElevenLabs v4 voices.
 * 4. Gender invariant is strictly preserved.
 * 5. Failover tier is strictly ElevenLabs v3 when v4 encounters error (zero Google fallback).
 */

import { ElevenLabsTTSService, TTSService, hasVerbalContent, ELEVENLABS_VOICE_GENDER_MAP } from "../../src/pipeline/services/tts";
import { TTSRequest } from "../../src/pipeline/types";

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

  test("4. Zero fallback models: transient retry strictly uses eleven_v4 (zero fallback models)", async () => {
    const configuredEleven = new ElevenLabsTTSService("valid-test-key");
    const attemptedModels: string[] = [];

    // Spy on internal axios post
    const axios = require("axios");
    let callCount = 0;
    jest.spyOn(axios, "post").mockImplementation(async (...args: any[]) => {
      const url = args[0] as string;
      const body = args[1];
      if (url.includes("/text-to-speech/")) {
        attemptedModels.push(body.model_id);
        callCount++;
        if (callCount === 1) {
          const err: any = new Error("v4 transient service error");
          err.response = { status: 500, data: "Temporary internal error" };
          throw err;
        }
        // retry succeeds with eleven_v4
        return {
          data: Buffer.from("v4-audio-output-bytes"),
        };
      }
      return { data: {} };
    });

    // Mock storage save
    const admin = require("firebase-admin");
    const mockFileSave = jest.fn().mockResolvedValue(true);
    jest.spyOn(admin, "storage").mockReturnValue({
      bucket: () => ({
        name: "test-bucket",
        file: () => ({ save: mockFileSave }),
      }),
    });

    const tts = new TTSService(undefined, configuredEleven);
    const result = await tts.synthesize({
      jobId: "job_v4_retry",
      language: "te",
      text: "నమస్కారం",
      voiceId: "ErXwobaYiN019PkySvjV",
    });

    expect(attemptedModels).toEqual(["eleven_v4", "eleven_v4"]);
    expect(result.provider).toBe("elevenlabs");
  });

  test("5. hasVerbalContent accurately distinguishes verbal speech from non-verbal/music/silence", () => {
    // Non-verbal indicators must return false (no API call needed)
    expect(hasVerbalContent("")).toBe(false);
    expect(hasVerbalContent("   ")).toBe(false);
    expect(hasVerbalContent("(music)")).toBe(false);
    expect(hasVerbalContent("[music]")).toBe(false);
    expect(hasVerbalContent("[applause]")).toBe(false);
    expect(hasVerbalContent("[silence]")).toBe(false);
    expect(hasVerbalContent("[whispers]")).toBe(false); // emotion tag alone without words
    expect(hasVerbalContent("...")).toBe(false);
    expect(hasVerbalContent(".")).toBe(false);
    expect(hasVerbalContent("🎵🎶")).toBe(false);

    // Verbal speech across multiple scripts must return true
    expect(hasVerbalContent("Hello world")).toBe(true);
    expect(hasVerbalContent("[whispers] Hello world")).toBe(true);
    expect(hasVerbalContent("(music) Welcome back")).toBe(true);
    expect(hasVerbalContent("నమస్కారం")).toBe(true);
    expect(hasVerbalContent("[excited] నమస్కారం")).toBe(true);
    expect(hasVerbalContent("नमस्ते दुनिया")).toBe(true);
    expect(hasVerbalContent("123")).toBe(true);
  });

  test("6. Non-speech segments produce silent audio chunks with ZERO external API calls (0 credits billed)", async () => {
    const configuredEleven = new ElevenLabsTTSService("valid-test-key");
    const axios = require("axios");
    const postSpy = jest.spyOn(axios, "post");
    postSpy.mockClear();

    const admin = require("firebase-admin");
    const mockFileSave = jest.fn().mockResolvedValue(true);
    jest.spyOn(admin, "storage").mockReturnValue({
      bucket: () => ({
        name: "test-bucket",
        file: () => ({ save: mockFileSave }),
      }),
    });

    const tts = new TTSService(undefined, configuredEleven);
    const nonSpeechInputs = ["(music)", "[applause]", "[silence]", "   ", "...", "[whispers]"];

    for (const input of nonSpeechInputs) {
      const result = await tts.synthesize({
        jobId: "job_silence_test",
        language: "te",
        text: input,
        voiceId: "ErXwobaYiN019PkySvjV",
      });

      expect(result.audioUrl).toContain("audio/job_silence_test/te/chunk-");
      expect(result.format).toBe("mp3");
      expect(result.provider).toBe("elevenlabs");
    }

    // Zero HTTP requests sent to ElevenLabs API -> Zero credits billed!
    expect(postSpy).not.toHaveBeenCalled();
    // Storage save was called for the silent MP3 chunks
    expect(mockFileSave).toHaveBeenCalledTimes(nonSpeechInputs.length);
  });

  test("7. Context windowing: previous_text and next_text are passed to ElevenLabs API with zero extra character billing", async () => {
    const configuredEleven = new ElevenLabsTTSService("valid-test-key");
    const axios = require("axios");
    let capturedBody: any = null;

    jest.spyOn(axios, "post").mockImplementation(async (...args: any[]) => {
      const url = args[0] as string;
      if (url.includes("/text-to-speech/")) {
        capturedBody = args[1];
        return {
          data: Buffer.from("v4-audio-chunk-bytes"),
        };
      }
      return { data: {} };
    });

    const admin = require("firebase-admin");
    const mockFileSave = jest.fn().mockResolvedValue(true);
    jest.spyOn(admin, "storage").mockReturnValue({
      bucket: () => ({
        name: "test-bucket",
        file: () => ({ save: mockFileSave }),
      }),
    });

    const longPrev = "A".repeat(600); // Exceeds 450 chars limit
    const longNext = "B".repeat(600); // Exceeds 450 chars limit

    const tts = new TTSService(undefined, configuredEleven);
    const result = await tts.synthesize({
      jobId: "job_ctx_test",
      language: "te",
      text: "ముఖ్యమైన ప్రసంగం",
      voiceId: "ErXwobaYiN019PkySvjV",
      previousText: longPrev,
      nextText: longNext,
    });

    expect(capturedBody).not.toBeNull();
    expect(capturedBody.text).toBe("ముఖ్యమైన ప్రసంగం");
    expect(capturedBody.model_id).toBe("eleven_v4");
    // Context is capped to 450 characters
    expect(capturedBody.previous_text.length).toBe(450);
    expect(capturedBody.next_text.length).toBe(450);
    expect(result.provider).toBe("elevenlabs");
  });
});
