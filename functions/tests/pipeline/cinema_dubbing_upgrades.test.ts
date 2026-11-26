/**
 * Cinema-Grade Dubbing Architecture Upgrade Tests (Zero Paid Credits)
 *
 * Covers the 5 core architectural upgrades:
 * 1. Multi-stage FFmpeg mastering filter chain & parallel best-of-2 M&E isolation.
 * 2. Multimodal prosody cue mapping (voiceQuality, 6-axis emotionalIntensity, continuous stability).
 * 3. Language-calibrated syllable-budget translation compliance & CJK/Indic/Latin counting.
 * 4. Cross-scene / cross-reel persistent SpeakerVoiceProfile EMA stabilization.
 * 5. DAW timeline ms segment timing persistence & M&E/Dialogue fader gain remastering.
 */

import * as child_process from "child_process";
import axios from "axios";
import { PIPELINE_CONFIG } from "../../src/pipeline/config";

const firestoreStore = new Map<string, any>();

function makeDocRef(docPath: string): any {
  return {
    get: jest.fn(async () => {
      const data = firestoreStore.get(docPath);
      return {
        exists: data !== undefined,
        data: () => data,
      };
    }),
    set: jest.fn(async (payload: any, opts?: { merge?: boolean }) => {
      if (opts?.merge && firestoreStore.has(docPath)) {
        firestoreStore.set(docPath, { ...firestoreStore.get(docPath), ...payload });
      } else {
        firestoreStore.set(docPath, { ...payload });
      }
      return {};
    }),
    update: jest.fn(async (payload: any) => {
      const prev = firestoreStore.get(docPath) || {};
      firestoreStore.set(docPath, { ...prev, ...payload });
      return {};
    }),
    collection: (subCol: string) => makeColRef(`${docPath}/${subCol}`),
  };
}

function makeColRef(colPath: string): any {
  return {
    doc: jest.fn((id: string) => makeDocRef(`${colPath}/${id}`)),
    where: jest.fn(() => ({
      limit: jest.fn(() => ({
        get: jest.fn(async () => ({ empty: true, docs: [] })),
      })),
    })),
  };
}

const mockFileSave = jest.fn().mockResolvedValue(undefined);
const mockFileDownload = jest.fn().mockResolvedValue([Buffer.from("fake-audio-buffer")]);
const mockFileExists = jest.fn().mockResolvedValue([false]);
const mockFileGetMetadata = jest.fn().mockResolvedValue([{ size: 48000, metadata: {} }]);
const mockBucketUpload = jest.fn().mockResolvedValue(undefined);
const mockBucket = {
  name: "truthworld-test-bucket",
  file: jest.fn(() => ({
    save: mockFileSave,
    download: mockFileDownload,
    exists: mockFileExists,
    getMetadata: mockFileGetMetadata,
    getSignedUrl: jest.fn().mockResolvedValue(["https://signed.example.com/audio.mp3"]),
  })),
  upload: mockBucketUpload,
};

jest.mock("firebase-admin", () => {
  const actual = jest.requireActual("firebase-admin");
  const firestoreFn: any = () => ({
    collection: jest.fn((col: string) => makeColRef(col)),
  });
  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => 1700000000000),
  };
  return {
    ...actual,
    storage: () => ({
      bucket: () => mockBucket,
    }),
    firestore: firestoreFn,
  };
});

jest.mock("child_process", () => ({
  ...jest.requireActual("child_process"),
  execFile: jest.fn((_cmd: string, _args: string[], optsOrCb: any, cb?: any) => {
    const callback = typeof optsOrCb === "function" ? optsOrCb : cb;
    if (typeof callback === "function") {
      callback(
        null,
        "",
        "Duration: 00:00:30.00\nStream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s\nmean_volume: -21.5 dB"
      );
    }
  }),
}));

import {
  MediaService,
  buildCinemaMasteringFilterChain,
} from "../../src/pipeline/services/media";
import { mapEmotionToElevenLabsCue } from "../../src/pipeline/services/audio-identity";
import {
  LANG_SYLLABLE_RATIOS,
  countSourceSyllables,
  computeSyllableBudgetCompliance,
} from "../../src/pipeline/services/translation";
import { DubbingEngine } from "../../src/pipeline/layers/07-dubbing";
import { dubbingEditorService } from "../../src/pipeline/services/dubbingEditorService";

describe("Cinema Dubbing Architecture Upgrades", () => {
  const mockedExecFile = child_process.execFile as unknown as jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    firestoreStore.clear();
  });

  describe("1. Cinema Mastering Chain & Parallel Best-of-2 M&E", () => {
    it("builds multi-stage compression, de-essing, ISP limiter (level=0), and linear loudnorm", () => {
      const chain = buildCinemaMasteringFilterChain({
        targetLufs: -16,
        truePeakDb: -2.0,
        loudnessRangeLra: 12,
        deEss: true,
        roomTone: "large-reflective",
      });

      expect(chain).toContain("acompressor=threshold=-24dB:ratio=3");
      expect(chain).toContain("acompressor=threshold=-18dB:ratio=2");
      expect(chain).toContain("equalizer=f=6500");
      expect(chain).toContain("aecho=0.8:0.88:90:0.28");
      expect(chain).toContain("alimiter=level_in=1:level_out=1:limit=0.794:attack=5:release=50:asc=1:level=0");
      expect(chain).toContain("loudnorm=I=-16:TP=-2:LRA=12:linear=true");
    });

    it("applies cinema_netflix mastering profile in MediaService.applyCinemaGradeMastering", async () => {
      const media = new MediaService();
      const outUrl = await media.applyCinemaGradeMastering(
        "job_master_cinema",
        "gs://truthworld-test-bucket/audio/job_master_cinema/te/master.mp3",
        {
          masteringProfile: "cinema_netflix",
          roomTone: "small-room",
        }
      );

      expect(outUrl).toBe("gs://truthworld-test-bucket/audio/job_master_cinema/cinema_master.mp3");
      const ffmpegCall = mockedExecFile.mock.calls.find((c: any[]) => c[1]?.includes("-af"));
      expect(ffmpegCall).toBeDefined();
      const afArg = ffmpegCall![1][ffmpegCall![1].indexOf("-af") + 1];
      expect(afArg).toContain("aecho=0.8:0.88:40:0.18");
      expect(afArg).toContain("loudnorm=I=-24:TP=-1:LRA=14:linear=true");
    });

    it("picks lower-dialogue-bleed stem between parallel Demucs and isolated-vocal subtraction", async () => {
      const media = new MediaService();
      const prevWorkerUrl = (PIPELINE_CONFIG as any).DEMUX_SERVICE_URL;
      (PIPELINE_CONFIG as any).DEMUX_SERVICE_URL = "https://demucs-worker.test.local";
      const prevWorkerToken = process.env.DEMUX_WORKER_TOKEN;
      process.env.DEMUX_WORKER_TOKEN = "test-worker-token-0123456789abcdef0123456789"; // the worker requires it

      try {
        jest.spyOn(axios, "post").mockResolvedValueOnce({
          data: {
            mneUrl: "gs://truthworld-test-bucket/audio/job_par/m_and_e.mp3",
            engine: "demucs_v4_neural",
            degraded: false,
          },
        } as any);

        const validateSpy = jest.spyOn(media, "validateMneStem").mockImplementation(
          async (_jobId, url) => ({
            source: url.includes("_iso") ? "neural_isolation_subtraction" : "neural_demixing",
            fileUrl: url,
            durationSeconds: 30,
            videoDurationSeconds: 30,
            durationMatch: true,
            durationDeltaMs: 0,
            timelineAlignmentMs: 0,
            sampleRate: 44100,
            channels: 2,
            channelLayout: "stereo",
            dialogueBleedDb: url.includes("_iso") ? -36.5 : -24.0,
            // Candidates are ranked by measured voice suppression; an unmeasured stem is never "clean".
            vocalSuppressionDb: url.includes("_iso") ? 30 : 18,
            clippingDetected: false,
            corruptionDetected: false,
            validationStatus: "passed",
            issues: [],
          })
        );

        const best = await media.extractMneStemDetailedParallel(
          "job_par",
          "gs://truthworld-test-bucket/audio/job_par/original.mp3",
          {
            isolatedVocalUrl: "gs://truthworld-test-bucket/audio/job_par/vocals.mp3",
            expectedDurationSeconds: 30,
          }
        );

        expect(validateSpy).toHaveBeenCalledTimes(2);
        expect(best.mneUrl).toBe("gs://truthworld-test-bucket/audio/job_par/m_and_e_iso.mp3");
        expect(best.source).toBe("neural_demixing_best_of_2");
        expect(best.degraded).toBe(false);
      } finally {
        (PIPELINE_CONFIG as any).DEMUX_SERVICE_URL = prevWorkerUrl;
        if (prevWorkerToken === undefined) delete process.env.DEMUX_WORKER_TOKEN; else process.env.DEMUX_WORKER_TOKEN = prevWorkerToken;
      }
    });
  });

  describe("2. Multimodal Prosody Cue Mapping", () => {
    it("modulates stability via voiceQuality and promotes high-intensity 6-axis emotions", () => {
      // A whisper needs measured evidence (delivery-tag-guard.ts, 2026-11-24): no pitch and a
      // measured voiced share below 0.2.
      const breathyWhisper = mapEmotionToElevenLabsCue(
        "whisper",
        -31,
        "breathy",
        { anger: 0.05, sadness: 0.2, joy: 0.05, fear: 0.6, disgust: 0.0, surprise: 0.1 },
        { f0Hz: null, voicedShare: 0.08 }
      );
      expect(breathyWhisper.emotionTag).toBe("whispers");
      expect(breathyWhisper.similarityBoostOverride).toBeGreaterThanOrEqual(0.86);
      // Without any voicing measurement the same line is not whispered.
      const unmeasured = mapEmotionToElevenLabsCue("whisper", -31, "breathy");
      expect(unmeasured.emotionTag).toBe("soft");

      const furiousAutoPromoted = mapEmotionToElevenLabsCue(
        undefined,
        -11,
        "pressed",
        { anger: 0.88, sadness: 0.1, joy: 0.0, fear: 0.1, disgust: 0.3, surprise: 0.2 }
      );
      expect(furiousAutoPromoted.emotionTag).toBe("angry");
      expect(furiousAutoPromoted.stabilityOverride).toBeLessThan(0.45);
    });
  });

  describe("3. Syllable-Budget Translation Ratios & Counting", () => {
    it("provides calibrated expansion ratios and accurately counts English, Telugu, and CJK syllables", () => {
      expect(LANG_SYLLABLE_RATIOS.te).toBeGreaterThan(LANG_SYLLABLE_RATIOS.en);
      expect(LANG_SYLLABLE_RATIOS.zh).toBeLessThan(LANG_SYLLABLE_RATIOS.en);

      expect(countSourceSyllables("[whispers] Hello world", "en")).toBe(3);
      expect(countSourceSyllables("నమస్కారం", "te")).toBeGreaterThanOrEqual(4);
      expect(countSourceSyllables("你好世界", "zh")).toBe(4);
    });

    it("scores 1.0 compliance for concise dubs and penalizes over-budget verbosity", () => {
      const conciseScore = computeSyllableBudgetCompliance(
        "Stay right here and listen carefully.",
        "ఇక్కడే ఉండి జాగ్రత్తగా వినండి.",
        "en",
        "te",
        3000
      );
      expect(conciseScore).toBe(1.0);

      const verboseScore = computeSyllableBudgetCompliance(
        "Stop.",
        "దయచేసి తక్షణమే మీరు చేస్తున్న ఆ పనులన్నింటినీ పూర్తిగా ఆపివేసి ఇక్కడే నిశ్శబ్దంగా నిలబడండి అని కోరుతున్నాను.",
        "en",
        "te",
        1000
      );
      expect(verboseScore).toBeLessThan(0.6);
    });
  });

  describe("4. Persistent SpeakerVoiceProfile EMA Stabilization", () => {
    it("persists and smooths per-speaker baseline pitch, stability, and similarity across scenes", async () => {
      const engine = new DubbingEngine();

      const first = await engine.updateSpeakerVoiceProfile("job_vp", "speaker_0", "te", {
        voiceId: "ErXwobaYiN019PkySvjV",
        pitchSemitones: -1.5,
        energyDb: -18,
        stability: 0.42,
        similarityBoost: 0.86,
        voiceQuality: "modal",
      });
      expect(first?.segmentCount).toBe(1);
      expect(first?.avgPitchSemitones).toBe(-1.5);

      const second = await engine.updateSpeakerVoiceProfile("job_vp", "speaker_0", "te", {
        voiceId: "ErXwobaYiN019PkySvjV",
        pitchSemitones: 0.5,
        energyDb: -14,
        stability: 0.62,
        similarityBoost: 0.88,
        voiceQuality: "pressed",
      });
      expect(second?.segmentCount).toBe(2);
      expect(second?.avgPitchSemitones).toBe(-0.5);

      const loaded = await engine.loadSpeakerVoiceProfile("job_vp", "speaker_0", "te");
      expect(loaded?.segmentCount).toBe(2);
      expect(loaded?.dominantVoiceQuality).toBe("pressed");
    });
  });

  describe("5. DAW Segment Timing & Fader Mixer Persistence", () => {
    it("updates segment startMs/endMs timings and syncs subtitles + manifest version", async () => {
      firestoreStore.set("video_jobs/job_daw", { userId: "creator_1" });
      firestoreStore.set("video_jobs/job_daw/dubbing_manifests/te", {
        jobId: "job_daw",
        videoId: "vid_daw",
        userId: "creator_1",
        language: "te",
        sourceLanguage: "en",
        totalDurationMs: 12000,
        mneStemUrl: "gs://truthworld-test-bucket/audio/job_daw/m_and_e.mp3",
        version: 1,
        segments: [
          {
            index: 0,
            startMs: 500,
            endMs: 2500,
            speaker: "speaker_0",
            originalText: "Hello",
            translatedText: "హలో",
            durationMs: 2000,
            updatedAt: 1,
          },
        ],
      });

      const mediaSpy = jest
        .spyOn(MediaService.prototype, "generateAllSubtitles")
        .mockResolvedValue({
          srtUrl: "gs://truthworld-test-bucket/subtitles/job_daw/te.srt",
          vttUrl: "gs://truthworld-test-bucket/subtitles/job_daw/te.vtt",
        } as any);

      const res = await dubbingEditorService.updateSegmentTimings({
        jobId: "job_daw",
        language: "te",
        uid: "creator_1",
        timings: [{ segmentIndex: 0, startMs: 650, endMs: 2950 }],
      });

      expect(res.updatedCount).toBe(1);
      expect(res.version).toBe(2);
      expect(mediaSpy).toHaveBeenCalledTimes(1);

      const savedManifest = firestoreStore.get("video_jobs/job_daw/dubbing_manifests/te");
      expect(savedManifest.segments[0].startMs).toBe(650);
      expect(savedManifest.segments[0].endMs).toBe(2950);
      expect(savedManifest.segments[0].durationMs).toBe(2300);
    });

    it("forwards DAW M&E and Dialogue fader gains through remasterTrack to mixDubWithMne", async () => {
      firestoreStore.set("video_jobs/job_fader", { userId: "creator_2" });
      firestoreStore.set("video_jobs/job_fader/dubbing_manifests/hi", {
        jobId: "job_fader",
        videoId: "vid_fader",
        userId: "creator_2",
        language: "hi",
        sourceLanguage: "en",
        totalDurationMs: 5000,
        mneStemUrl: "gs://truthworld-test-bucket/audio/job_fader/m_and_e.mp3",
        version: 1,
        segments: [
          {
            index: 0,
            startMs: 200,
            endMs: 4800,
            speaker: "speaker_0",
            originalText: "Welcome",
            translatedText: "स्वागत है",
            synthesizedAudioUrl: "gs://truthworld-test-bucket/tts/job_fader/hi/0.mp3",
            durationMs: 4600,
            updatedAt: 1,
          },
        ],
      });

      jest
        .spyOn(MediaService.prototype, "mergeAudioChunks")
        .mockResolvedValue("gs://truthworld-test-bucket/audio/job_fader/hi/dialogue.mp3");
      const mixSpy = jest
        .spyOn(MediaService.prototype, "mixDubWithMne")
        .mockResolvedValue("gs://truthworld-test-bucket/audio/job_fader/hi/master.mp3");

      const remasterRes = await dubbingEditorService.remasterTrack({
        jobId: "job_fader",
        language: "hi",
        uid: "creator_2",
        mneGain: 0.75,
        dialogueGain: 1.25,
      });

      expect(mixSpy).toHaveBeenCalledWith(
        "job_fader",
        "hi",
        expect.objectContaining({
          mneGain: 0.75,
          dialogueGain: 1.25,
        })
      );
      expect(remasterRes.mneGain).toBe(0.75);
      expect(remasterRes.dialogueGain).toBe(1.25);

      const savedManifest = firestoreStore.get("video_jobs/job_fader/dubbing_manifests/hi");
      expect(savedManifest.mneGain).toBe(0.75);
      expect(savedManifest.dialogueGain).toBe(1.25);
    });
  });
});
