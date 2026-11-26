/**
 * Comprehensive Zero-Credit Verification Suite for the 5 TruthWorld Dubbing Upgrades:
 *  1. Original Audio Emotion / Prosody Transfer + ElevenLabs eleven_v4 [audio tags] + subtitle stripping
 *  2. Hardened M&E Isolation (Demucs degraded fallback detection + empirical bleed probe)
 *  3. Long-Form Distributed 15-Minute Reel Orchestration (dispatch -> worker -> transactional assembly -> quality gate)
 *  4. Interactive Creator Dubbing Editor (manifest load, single-line resynthesis, pronunciation glossary, remaster)
 *  5. Live Dubbing Quality Benchmark Harness (dry-run local FFmpeg execution + Levenshtein WER & scoring math)
 */

import * as admin from "firebase-admin";
import axios from "axios";
import { PIPELINE_CONFIG } from "../../src/pipeline/config";
import { testFirestore } from "../helpers/mockFirestore";
import {
  applyPronunciationGlossary,
  sanitizeTextForElevenLabsV4,
  stripAudioTagsForSubtitles,
  TTSService,
  ElevenLabsTTSService,
} from "../../src/pipeline/services/tts";
import { mapEmotionToElevenLabsCue, audioIdentityService } from "../../src/pipeline/services/audio-identity";
import { mediaService, MneValidationResult } from "../../src/pipeline/services/media";
import { dubbingEngine } from "../../src/pipeline/layers/07-dubbing";
import { dubbingEditorService } from "../../src/pipeline/services/dubbingEditorService";
import {
  computeWordErrorRate,
  computeDiarizationAccuracy,
  evaluateSyllableBudgetFit,
  scoreDubbingBenchmarkRun,
  runDubbingBenchmark,
} from "../../src/benchmark/dubbing_live_benchmark";

describe("TruthWorld 5-Pillar Dubbing Upgrade Verification (Zero Credits)", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PILLAR 1: Original Audio Emotion / Prosody Transfer + ElevenLabs v4 Tags
  // ───────────────────────────────────────────────────────────────────────────
  describe("Pillar 1: Emotion, Prosody & ElevenLabs v4 Audio Tag Transfer", () => {
    test("maps vocal emotion & RMS energy to whitelisted ElevenLabs v4 Audio Tags and dynamic stability", () => {
      // A whisper needs measured evidence (delivery-tag-guard.ts, 2026-11-24): no pitch, voiced share < 0.2.
      const whisperCue = mapEmotionToElevenLabsCue("whispers", -34, undefined, undefined, { f0Hz: null, voicedShare: 0.08 });
      expect(whisperCue.emotionTag).toBe("whispers");
      expect(mapEmotionToElevenLabsCue("whispers", -34).emotionTag).toBe("soft");
      expect(whisperCue.stabilityOverride).toBeLessThanOrEqual(0.36);

      const shoutCue = mapEmotionToElevenLabsCue(undefined, -9);
      expect(shoutCue.emotionTag).toBe("shouts");
      expect(shoutCue.stabilityOverride).toBeLessThanOrEqual(0.30);

      const calmCue = mapEmotionToElevenLabsCue("calm", -22);
      expect(calmCue.emotionTag).toBe("calm");
      expect(calmCue.stabilityOverride).toBeGreaterThanOrEqual(0.58);
    });

    test("sanitizeTextForElevenLabsV4 preserves valid [audio tags], injects missing cue, and strips noise brackets", () => {
      const sanitized = sanitizeTextForElevenLabsV4(
        "[whispers] Listen carefully (music swells) [applause] to this [excited] secret.",
        "whispers"
      );
      expect(sanitized).toContain("[whispers]");
      expect(sanitized).toContain("[excited]");
      expect(sanitized).not.toContain("(music swells)");
      expect(sanitized).not.toContain("[applause]");

      const injected = sanitizeTextForElevenLabsV4("We did it!", "laughs");
      expect(injected).toBe("[laughs] We did it!");
    });

    test("stripAudioTagsForSubtitles removes all inline performance tags cleanly for captions", () => {
      const caption = stripAudioTagsForSubtitles("[whispers] Never reveal [laughs] the passphrase.");
      expect(caption).toBe("Never reveal the passphrase.");
    });

    test("applyPronunciationGlossary replaces terms with phonetic spelling before synthesis", () => {
      const out = applyPronunciationGlossary("TruthWorld dubs natively on TruthWorld.", [
        { id: "r1", term: "TruthWorld", replacement: "Trooth-Wurld" },
      ]);
      expect(out).toBe("Trooth-Wurld dubs natively on Trooth-Wurld.");
    });

    test("ElevenLabs v4 payload forwards dynamic stability and preserved [tag] while omitting style & speed", async () => {
      const postSpy = jest.spyOn(axios, "post").mockResolvedValueOnce({
        data: Buffer.from("fake-mp3-v4-emotional"),
      } as any);

      const service = new ElevenLabsTTSService("test-key-v4");
      const tts = new TTSService(undefined, service);

      const result = await tts.synthesize({
        jobId: "job_p1_v4",
        language: "en",
        text: "TruthWorld rocks!",
        preferVoiceCloning: true,
        stability: 0.31,
        similarityBoost: 0.89,
        emotionTag: "excited",
        pronunciationGlossary: [{ id: "g1", term: "TruthWorld", replacement: "Trooth-Wurld" }],
      });

      expect(result.audioUrl).toContain("job_p1_v4/en");
      expect(postSpy).toHaveBeenCalledTimes(1);
      const body = postSpy.mock.calls[0][1] as any;
      expect(body.model_id).toBe("eleven_v4");
      expect(body.text).toBe("[excited] Trooth-Wurld rocks!");
      expect(body.voice_settings.stability).toBe(0.31);
      expect(body.voice_settings.similarity_boost).toBe(0.89);
      expect(body.voice_settings.style).toBeUndefined();
      expect(body.voice_settings.speed).toBeUndefined();

      postSpy.mockRestore();
    });

    test("Telugu payload sends language_code 'te' and lifts low stability to the 0.5 dubbing floor", async () => {
      const postSpy = jest.spyOn(axios, "post").mockResolvedValueOnce({
        data: Buffer.from("fake-mp3-v4-telugu"),
      } as any);

      const service = new ElevenLabsTTSService("test-key-v4");
      const tts = new TTSService(undefined, service);

      await tts.synthesize({
        jobId: "job_p1_v4_te",
        language: "te",
        text: "చింతించకండి. మిమ్మల్ని ఇక్కడ జాగ్రత్తగా చూసుకుంటాం.",
        stability: 0.25,
        similarityBoost: 0.85,
      });

      const body = postSpy.mock.calls[0][1] as any;
      expect(body.language_code).toBe("te");
      expect(body.voice_settings.stability).toBe(0.5);
      postSpy.mockRestore();
    });

    test("romanized Telugu is rejected before ElevenLabs is called", async () => {
      const postSpy = jest.spyOn(axios, "post");
      const tts = new TTSService(undefined, new ElevenLabsTTSService("test-key-v4"));

      await expect(
        tts.synthesize({ jobId: "job_p1_v4_te_rom", language: "te", text: "Chintinchakandi. Mimmalni ikkada chusukuntam." })
      ).rejects.toThrow(/native script/);
      expect(postSpy).not.toHaveBeenCalled();
      postSpy.mockRestore();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PILLAR 2: Hardened M&E Isolation + Explicit Degraded Flagging
  // ───────────────────────────────────────────────────────────────────────────
  describe("Pillar 2: Hardened Neural M&E Isolation & Explicit Degraded Flagging", () => {
    test("ignores Demucs ffmpeg_crossover_fallback masking and flags DSP fallback explicitly as degraded", async () => {
      const jobId = "job_mne_degraded_check";
      const origUrl = `gs://${admin.storage().bucket().name}/audio/${jobId}/source.mp3`;

      // Seed fake Demucs worker response returning degraded crossover
      const postSpy = jest.spyOn(axios, "post").mockResolvedValueOnce({
        data: {
          status: "degraded",
          mneUrl: `gs://${admin.storage().bucket().name}/audio/${jobId}/remote_crossover.mp3`,
          engine: "ffmpeg_crossover_fallback",
          validationStatus: "degraded",
          degraded: true,
        },
      } as any);

      const prevDemuxUrl = PIPELINE_CONFIG.DEMUX_SERVICE_URL;
      (PIPELINE_CONFIG as any).DEMUX_SERVICE_URL = "https://demux.truthworld.internal";
      const prevWorkerToken = process.env.DEMUX_WORKER_TOKEN;
      process.env.DEMUX_WORKER_TOKEN = "test-worker-token-0123456789abcdef0123456789"; // the worker requires it
      try {
        const detailed = await mediaService.extractMneStemDetailed(jobId, origUrl);

        expect(detailed.degraded).toBe(true);
        expect(detailed.source).toBe("dsp_fallback");
        expect(detailed.issues.length).toBeGreaterThan(0);
      } finally {
        (PIPELINE_CONFIG as any).DEMUX_SERVICE_URL = prevDemuxUrl;
        if (prevWorkerToken === undefined) delete process.env.DEMUX_WORKER_TOKEN; else process.env.DEMUX_WORKER_TOKEN = prevWorkerToken;
        postSpy.mockRestore();
      }
    });

    test("validateMneStem enforces degraded status when source is dsp_fallback even if duration matches", async () => {
      const validation: MneValidationResult = await mediaService.validateMneStem(
        "job_val_dsp",
        "gs://truthworld-test-safe.appspot.com/missing_file.mp3",
        60,
        "dsp_fallback",
        { expectedSourceDegraded: true }
      );
      expect(validation.source).toBe("dsp_fallback");
      expect(["degraded", "failed"]).toContain(validation.validationStatus);
      expect(validation.issues.length).toBeGreaterThan(0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PILLAR 3: Distributed Long-Form 15-Minute Reel Orchestration
  // ───────────────────────────────────────────────────────────────────────────
  describe("Pillar 3: Long-Form Distributed 15-Min Reel Orchestration", () => {
    test("processDubbingReel synthesizes per-reel segments and atomically dispatches assembly on final reel", async () => {
      const jobId = "job_movie_90m";
      const jobRef = testFirestore.collection("video_jobs").doc(jobId);

      // Seed 2 reels for a long-form feature
      await jobRef.set({
        jobId,
        videoId: "11111111-1111-4111-8111-111111111111",
        userId: "creator_1",
        videoUrl: "https://example.com/movie.mp4",
      });

      await jobRef.collection("reel_orchestration").doc("meta").set({
        jobId,
        videoId: "11111111-1111-4111-8111-111111111111",
        userId: "creator_1",
        videoUrl: "https://example.com/movie.mp4",
        sourceLanguage: "en",
        languages: ["te"],
        totalReels: 2,
        totalDurationMs: 1800000,
        mneStemUrl: null,
        executionPlan: {
          generateDubbing: true,
          dubbingTier: "audio_track",
          genLangSubs: false,
        },
        voiceMapping: { speaker_0: "ErXwobaYiN019PkySvjV" },
        speakerProfiles: [{ speakerId: "speaker_0", gender: "male", pitchBand: "mid", energy: "medium" }],
        status: "processing",
        completedReelsCount: 1,
        assemblyDispatched: false,
      });

      // Mark Reel 0 already completed
      await jobRef.collection("reels").doc("reel_0").set({
        reelIndex: 0,
        status: "completed",
        dialogueReelUrls: { te: "gs://bucket/reel_0.mp3" },
      });
      await jobRef.collection("reels").doc("reel_1").set({
        reelIndex: 1,
        status: "queued",
        dialogueReelUrls: {},
      });

      // Spy on TTS synthesis, stitching, and Pub/Sub publish (zero real network!)
      const parallelSpy = jest
        .spyOn(dubbingEngine as any, "parallelTTSWithCache")
        .mockResolvedValueOnce({
          urls: ["gs://bucket/seg_r1_0.mp3"],
          failedSegments: [],
          totalSegments: 1,
          successfulSegments: 1,
        });
      const mergeSpy = jest
        .spyOn(mediaService, "mergeAudioChunks")
        .mockResolvedValueOnce("gs://bucket/reel_1.mp3");
      const pubSpy = jest
        .spyOn((dubbingEngine as any).distribution, "publish")
        .mockResolvedValueOnce(undefined);

      await dubbingEngine.processDubbingReel({
        jobId,
        videoId: "11111111-1111-4111-8111-111111111111",
        userId: "creator_1",
        reelIndex: 1,
        totalReels: 2,
        startMs: 900000,
        endMs: 1800000,
        durationMs: 900000,
        languages: ["te"],
        sourceLanguage: "en",
        dubbingTier: "audio_track",
        preferVoiceCloning: true,
        segmentsByLanguage: {
          te: [
            {
              index: 100,
              start: 905000,
              end: 909000,
              originalText: "Final act begins.",
              translatedText: "[serious] చివరి భాగం ప్రారంభమైంది.",
              speaker: "speaker_0",
              emotionTag: "serious",
            },
          ],
        },
        idempotencyKey: `${jobId}_reel_1`,
      });

      // Verify reel 1 stitched with local relative offset (5000ms..9000ms) and padded to 900000ms
      expect(mergeSpy).toHaveBeenCalledWith(
        `${jobId}_reel_1`,
        ["gs://bucket/seg_r1_0.mp3"],
        "te",
        expect.objectContaining({
          totalDurationMs: 900000,
          segments: [expect.objectContaining({ start: 5000, end: 9000 })],
        })
      );

      // Verify final reel triggered dubbing-reel-assemble transactionally
      expect(pubSpy).toHaveBeenCalledWith(
        "dubbing-reel-assemble",
        expect.objectContaining({
          eventType: "dubbing-reel-assemble",
          jobId,
        })
      );

      const metaAfter = (await jobRef.collection("reel_orchestration").doc("meta").get()).data();
      expect(metaAfter?.assemblyDispatched).toBe(true);
      expect(metaAfter?.completedReelsCount).toBe(2);

      parallelSpy.mockRestore();
      mergeSpy.mockRestore();
      pubSpy.mockRestore();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PILLAR 4: Interactive Creator Dubbing Editor
  // ───────────────────────────────────────────────────────────────────────────
  describe("Pillar 4: Interactive Creator Dubbing Editor Backend Flow", () => {
    test("supports manifest retrieval, glossary saving, single-line re-synthesis, and track remastering", async () => {
      const jobId = "job_editor_1";
      const videoId = "22222222-2222-4222-8222-222222222222";
      const uid = "creator_editor_uid";

      await testFirestore.collection("videos").doc(videoId).set({
        id: videoId,
        userId: uid,
        dubbingManifests: { te: { jobId } },
      });

      await testFirestore.collection("video_jobs").doc(jobId).set({
        jobId,
        videoId,
        userId: uid,
        videoUrl: "gs://bucket/video.mp4",
      });

      await testFirestore
        .collection("video_jobs")
        .doc(jobId)
        .collection("dubbing_manifests")
        .doc("te")
        .set({
          jobId,
          videoId,
          userId: uid,
          language: "te",
          sourceLanguage: "en",
          totalDurationMs: 6000,
          mneStemUrl: "gs://bucket/mne.mp3",
          masterAudioUrl: "https://storage.googleapis.com/bucket/master.mp3",
          pronunciationGlossary: [],
          segments: [
            {
              index: 0,
              startMs: 500,
              endMs: 3500,
              speaker: "speaker_0",
              originalText: "TruthWorld is live.",
              translatedText: "TruthWorld లైవ్‌లో ఉంది.",
              voiceId: "ErXwobaYiN019PkySvjV",
              synthesizedAudioUrl: "gs://bucket/seg0.mp3",
            },
          ],
          version: 1,
          updatedAt: Date.now(),
        });

      // 1. Glossary save
      const glossRes = await dubbingEditorService.savePronunciationGlossary({
        jobId,
        language: "te",
        uid,
        rules: [{ id: "g1", term: "TruthWorld", replacement: "ట్రూత్ వరల్డ్" }],
      });
      expect(glossRes.savedCount).toBe(1);
      expect(glossRes.version).toBe(2);

      // 2. Single-line resynthesis
      const synthSpy = jest
        .spyOn(TTSService.prototype, "synthesize")
        .mockResolvedValueOnce({
          jobId,
          language: "te",
          audioUrl: "https://storage.googleapis.com/bucket/seg0_v2.mp3",
          duration: 2.5,
          format: "mp3",
          provider: "elevenlabs",
          voiceName: "ErXwobaYiN019PkySvjV",
        });
      const subSpy = jest
        .spyOn(mediaService, "generateAllSubtitles")
        .mockResolvedValueOnce({
          srtUrl: "gs://bucket/te_v2.srt",
          vttUrl: "gs://bucket/te_v2.vtt",
          jsonUrl: "gs://bucket/te_v2.json",
        });

      const editRes = await dubbingEditorService.updateSegmentAndResynthesize({
        jobId,
        language: "te",
        segmentIndex: 0,
        uid,
        editedText: "TruthWorld ఇప్పుడు లైవ్‌లో ఉంది!",
        emotionTag: "excited",
        stabilityOverride: 0.35,
      });

      expect(editRes.segment.translatedText).toContain("[excited]");
      expect(editRes.version).toBe(3);
      expect(subSpy).toHaveBeenCalledWith(
        jobId,
        [expect.objectContaining({ text: "TruthWorld ఇప్పుడు లైవ్‌లో ఉంది!" })],
        "te"
      );

      // 3. Unauthorized user blocked
      await expect(
        dubbingEditorService.getManifest({ jobId, language: "te", uid: "intruder_uid" })
      ).rejects.toThrow("permission");

      // 4. Full remaster
      const mergeSpy = jest
        .spyOn(mediaService, "mergeAudioChunks")
        .mockResolvedValueOnce("gs://bucket/dialogue_v4.mp3");
      const mixSpy = jest
        .spyOn(mediaService, "mixDubWithMne")
        .mockResolvedValueOnce("https://storage.googleapis.com/bucket/master_v4.mp3");
      const remuxSpy = jest
        .spyOn(mediaService, "mergeAudioToVideo")
        .mockResolvedValueOnce("https://storage.googleapis.com/bucket/video_v4.mp4");
      const signSpy = jest
        .spyOn(audioIdentityService, "getAccessibleUrl")
        .mockImplementation(async (url: string) => `${url}?signed=1`);

      const remasterRes = await dubbingEditorService.remasterTrack({
        jobId,
        language: "te",
        uid,
      });

      expect(remasterRes.version).toBe(4);
      expect(remasterRes.masterAudioUrl).toBe("https://storage.googleapis.com/bucket/master_v4.mp3?signed=1");
      const updatedVideo = (await testFirestore.collection("videos").doc(videoId).get()).data();
      const teTrack = updatedVideo?.audioTracks?.te;
      expect(typeof teTrack === "object" ? teTrack.audioUrl : teTrack).toBe("https://storage.googleapis.com/bucket/master_v4.mp3");

      synthSpy.mockRestore();
      subSpy.mockRestore();
      mergeSpy.mockRestore();
      mixSpy.mockRestore();
      remuxSpy.mockRestore();
      signSpy.mockRestore();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // PILLAR 5: Live Quality Benchmark Harness (--dry-run Zero Credit Execution)
  // ───────────────────────────────────────────────────────────────────────────
  describe("Pillar 5: Quality Benchmark Harness & Scorecard", () => {
    test("calculates accurate Levenshtein WER, diarization accuracy, syllable compliance, and scorecard", () => {
      expect(computeWordErrorRate("hello world today", "hello world today")).toBe(0);
      expect(computeWordErrorRate("hello world today foo", "hello duck today")).toBe(0.5);
      expect(computeDiarizationAccuracy(["A", "B", "A", "A"], ["A", "B", "B", "A"])).toBe(0.75);
      expect(
        evaluateSyllableBudgetFit([
          { durationSec: 3.0, text: "[excited] Welcome back friends" },
        ])
      ).toBe(1);

      const degradedScore = scoreDubbingBenchmarkRun({
        mode: "dry_run",
        sourceLanguage: "en",
        targetLanguage: "te",
        sttWerRatio: 0.02,
        diarizationAccuracyRatio: 0.95,
        mneSource: "dsp_fallback",
        mneValidationStatus: "degraded",
        syllableBudgetComplianceRatio: 1.0,
        emotionTagPreservationRatio: 1.0,
        subtitleTagLeakCount: 0,
        durationDriftMs: 25,
        elevenLabsCharsBilled: 0,
        wallLatencyMs: 250,
      });
      expect(degradedScore.verdict).toBe("DEGRADED");
    });

    test("executes --dry-run benchmark end-to-end with local FFmpeg and zero API credits", async () => {
      const scorecard = await runDubbingBenchmark(["--dry-run", "--source=en", "--target=te"]);
      expect(scorecard.mode).toBe("dry_run");
      expect(scorecard.verdict).toBe("CERTIFIED_DRY_RUN");
      expect(scorecard.metrics.estimatedCostUsd).toBe(0);
      expect(scorecard.metrics.subtitleTagLeakCount).toBe(0);
      expect(scorecard.overallScore10).toBeGreaterThanOrEqual(8.5);
    }, 30000);
  });
});
