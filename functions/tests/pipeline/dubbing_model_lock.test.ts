import * as fs from "fs";
import * as path from "path";
import axios from "axios";
import { GEMINI_MODELS, PIPELINE_CONFIG } from "../../src/pipeline/config";
import { ElevenLabsTTSService, TTS_MODELS } from "../../src/pipeline/services/tts";
import { GeminiDubbingEditor } from "../../src/pipeline/services/geminiDubbingEditor";
import { countSourceSyllables } from "../../src/pipeline/services/speech-rate";
import { mediaService } from "../../src/pipeline/services/media";
import { audioIdentityService } from "../../src/pipeline/services/audio-identity";
import { VideoGatewayService } from "../../src/pipeline/services/videoGatewayService";
import * as aiUtils from "../../src/pipeline/utils/ai-utils";

/**
 * Model Lock Gate for Dubbing Low-Latency Work.
 *
 * Ensures latency optimizations never swap models, fallbacks, or quality settings:
 * - STT: assemblyai-stt-3-7
 * - Separation: Modal Demucs v4 (htdemucs, --two-stems vocals, exact worker payload)
 * - Translation MT: Google Cloud Translation v3 (general/translation-llm)
 * - Gemini editor: strictly gemini-3.8-flash (single model across file & calls)
 * - VideoGateway moderation: primary gemini-3.8-flash, fallback gemini-3.5-flash-lite
 * - Screen analyzer: gemini-3.5-flash-lite (verification fallback gemini-3.8-flash)
 * - TTS: strictly ElevenLabs eleven_v4 (no eleven_v4_turbo, eleven_flash_v2_5, or Chirp)
 */
describe("Dubbing model lock (no provider or model swaps)", () => {
  const srcRoot = path.resolve(__dirname, "../../src/pipeline");
  const repoRoot = path.resolve(__dirname, "../../..");

  afterEach(() => {
    jest.restoreAllMocks();
    delete process.env.DEMUX_WORKER_TOKEN;
  });

  test("ElevenLabs TTS strictly locks to eleven_v4 across languages and voiceType hints", () => {
    expect(TTS_MODELS.v4).toBe("eleven_v4");
    expect(TTS_MODELS.v3).toBe("eleven_v4");

    const tts = new ElevenLabsTTSService("test-api-key");
    for (const lang of ["te", "hi", "ta", "en", "es", "fr", "ja"]) {
      expect(tts.selectModel(lang)).toBe("eleven_v4");
      expect(tts.selectModel(lang, { jobId: "j1", language: lang, text: "test", voiceType: "fast_api" })).toBe("eleven_v4");
    }

    const ttsSrc = fs.readFileSync(path.join(srcRoot, "services/tts.ts"), "utf8");
    const dubbingSrc = fs.readFileSync(path.join(srcRoot, "layers/07-dubbing.ts"), "utf8");
    for (const forbidden of ["eleven_v4_turbo", "eleven_flash", "eleven_turbo"]) {
      expect(ttsSrc).not.toContain(forbidden);
      expect(dubbingSrc).not.toContain(forbidden);
    }
  });

  test("AssemblyAI STT strictly locks to assemblyai-stt-3-7 in 05-transcription and 07-dubbing", () => {
    const sttSrc = fs.readFileSync(path.join(srcRoot, "layers/05-transcription.ts"), "utf8");
    const dubbingSrc = fs.readFileSync(path.join(srcRoot, "layers/07-dubbing.ts"), "utf8");
    expect(sttSrc).toContain('const ASSEMBLYAI_STT_MODEL = "assemblyai-stt-3-7"');
    expect(dubbingSrc).toContain('transcriptModel !== "assemblyai-stt-3-7"');
  });

  test("Translation MT locks to Google Cloud Translation v3 general/translation-llm", () => {
    expect(PIPELINE_CONFIG.TRANSLATION_PROVIDER).toBe("google");
    expect(PIPELINE_CONFIG.TRANSLATION_API_VERSION).toBe("v3");
    expect(PIPELINE_CONFIG.TRANSLATION_MODEL).toBe("general/translation-llm");
    expect(PIPELINE_CONFIG.LAST_KNOWN_GOOD_TRANSLATION_CONFIG).toEqual({
      provider: "google",
      apiVersion: "v3",
      model: "general/translation-llm",
      location: "global",
    });
  });

  test("GeminiDubbingEditor passes gemini-3.8-flash on every call and defines no other Gemini model", async () => {
    const editorSrc = fs.readFileSync(path.join(srcRoot, "services/geminiDubbingEditor.ts"), "utf8");
    const geminiLiterals = Array.from(new Set(editorSrc.match(/gemini-[a-z0-9.-]+/gi) || []));
    expect(geminiLiterals).toEqual(["gemini-3.8-flash"]);

    const calledModels: string[] = [];
    const mockGenerate = jest.fn(async (req: { model: string; prompt: string }) => {
      calledModels.push(req.model);
      if (req.prompt.includes("Generate Localization Bible")) {
        return {
          text: JSON.stringify({
            locked_registers: [{ from_speaker: "speaker_0", to_speaker: "AUDIENCE", formality: "formal" }],
            key_terminology: [],
          }),
          inputTokens: 10,
          outputTokens: 10,
        };
      }
      if (req.prompt.includes("meaning check") || req.prompt.includes("verdicts")) {
        return { text: JSON.stringify({ verdicts: [{ id: "L1", ok: true }] }), inputTokens: 10, outputTokens: 10 };
      }
      return {
        text: JSON.stringify([{ id: "L1", text: "నమస్కారం", subtitleText: "నమస్కారం" }]),
        inputTokens: 10,
        outputTokens: 10,
      };
    });

    const editor = new GeminiDubbingEditor(mockGenerate);
    await editor.editSegments(
      [{ id: "L1", source: "Hello", draft: "నమస్కారం", speaker: "speaker_0" }],
      {
        jobId: "lock_test_job",
        sourceLanguage: "en",
        targetLanguage: "te",
        glossary: [],
        countSyllables: countSourceSyllables,
        countGlossaryViolations: () => 0,
      }
    );

    expect(calledModels.length).toBeGreaterThanOrEqual(2);
    expect(calledModels.every((m) => m === "gemini-3.8-flash")).toBe(true);
  });

  test("VideoGatewayService moderation locks primary gemini-3.8-flash and fallback gemini-3.5-flash-lite", async () => {
    expect(PIPELINE_CONFIG.GEMINI_MODELS.moderation).toBe("gemini-3.8-flash");
    const retrySpy = jest.spyOn(aiUtils, "withAiRetry").mockResolvedValue({
      status: "APPROVED",
      confidence: 0.99,
      evaluatedAt: Date.now(),
      summary: "ok",
      category: "General",
      tags: ["truthworld"],
      autoChapters: [],
      violatingPolicies: [],
      violatingClaims: [],
      sensitiveTopics: [],
      flaggedTimestamps: [],
    });

    const gateway = new VideoGatewayService();
    await gateway.evaluateVideo(
      "lock_mod_job",
      "Hello everyone, welcome back.",
      [{ text: "Hello everyone, welcome back.", start: 0, end: 2000 } as any],
      { jobId: "lock_mod_job", videoId: "lock_mod_job", title: "Test", tags: [] } as any,
      "en",
      true
    );

    expect(retrySpy).toHaveBeenCalledTimes(1);
    const chainArg = retrySpy.mock.calls[0][1];
    expect(chainArg).toEqual({
      primary: "gemini-3.8-flash",
      fallback: "gemini-3.5-flash-lite",
      forcePrimary: false,
    });
  });

  test("Demucs locks worker model htdemucs, settings, and MediaService request payload", async () => {
    expect(PIPELINE_CONFIG.DEMUX_SERVICE_URL).toContain("modal.run");
    process.env.DEMUX_WORKER_TOKEN = "lock-test-token";

    jest.spyOn(audioIdentityService, "getAccessibleUrl").mockImplementation(async (u: string) => u);
    const postSpy = jest.spyOn(axios, "post").mockResolvedValue({ data: {} });

    await mediaService.separateWithDemuxWorker(
      "job_demux_lock",
      "https://storage.googleapis.com/truthworld-1-staging/audio.mp3"
    );

    expect(postSpy).toHaveBeenCalledTimes(1);
    const [endpoint, body] = postSpy.mock.calls[0];
    expect(endpoint).toMatch(/^https:\/\/.*modal\.run\/demix$/);
    expect(body).toEqual({
      jobId: "job_demux_lock",
      audioUrl: "https://storage.googleapis.com/truthworld-1-staging/audio.mp3",
    });

    const workerSrc = fs.readFileSync(path.join(repoRoot, "scripts/modal_demux_worker.py"), "utf8");
    expect(workerSrc).toContain('DEMUCS_MODEL = os.environ.get("DEMUCS_MODEL", "htdemucs")');
    expect(workerSrc).toContain('"demucs.separate"');
    expect(workerSrc).toContain('"-n",');
    expect(workerSrc).toContain("DEMUCS_MODEL,");
    expect(workerSrc).toContain('"--two-stems",');
    expect(workerSrc).toContain('"vocals",');
    expect(workerSrc).not.toContain("--shifts");
    expect(workerSrc).not.toContain("--overlap");
    expect(workerSrc).not.toContain("--segment");
  });

  test("ScreenContentAnalyzer and profiling models stay locked", () => {
    expect(GEMINI_MODELS.extraction.model).toBe("gemini-3.5-flash-lite");
    expect(GEMINI_MODELS.verification.model).toBe("gemini-3.8-flash");
    expect(PIPELINE_CONFIG.GEMINI_MODELS.profiling).toBe("gemini-3.5-flash-lite");

    const screenSrc = fs.readFileSync(path.join(srcRoot, "services/screenContentAnalyzer.ts"), "utf8");
    expect(screenSrc).toContain('const MODEL = process.env.SUBTITLE_SCREEN_MODEL || "gemini-3.5-flash-lite"');
    expect(screenSrc).toContain('GEMINI_MODELS.verification?.model || "gemini-3.8-flash"');
  });
});
