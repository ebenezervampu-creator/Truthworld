import * as fs from "fs";
import * as path from "path";
import { computeStudioJobUpdate, toDirectHttpUrl } from "../../src/dubbing/studio-job-sync";

describe("Dubbing Studio job sync (computeStudioJobUpdate)", () => {
  const baseStudioJob = {
    id: "dub_dubjob_123_1000",
    pipelineJobId: "dubjob_123",
    mode: "dubbing",
    sourceMediaUrl: "https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/dubbing_uploads%2Fu1%2Fclip.mp4?alt=media",
    targetLanguages: ["te"],
    progressPercent: 10,
    status: "processing",
  };

  it("advances progress through transcription -> diarizing -> translating -> synthesizing -> muxing -> completed", () => {
    const step1 = computeStudioJobUpdate(
      {
        status: "processing",
        stages: {
          transcription: { status: "running", progress: 40 },
          dubbing: { status: "pending", progress: 0 },
        },
      },
      baseStudioJob
    );
    expect(step1.status).toBe("transcribing");
    expect(step1.progressPercent).toBe(20);
    expect(step1.stages.audio_extraction.status).toBe("completed");

    const step2 = computeStudioJobUpdate(
      {
        status: "processing",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "running", progress: 15 },
        },
      },
      { ...baseStudioJob, ...step1 }
    );
    expect(step2.status).toBe("diarizing");
    expect(step2.progressPercent).toBeGreaterThanOrEqual(38);
    expect(step2.stages.transcription.status).toBe("completed");

    const step3 = computeStudioJobUpdate(
      {
        status: "processing",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "running", progress: 65 },
        },
      },
      { ...baseStudioJob, ...step2 }
    );
    expect(step3.status).toBe("synthesizing_speech");
    expect(step3.progressPercent).toBeGreaterThanOrEqual(60);

    const step4 = computeStudioJobUpdate(
      {
        status: "processing",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "running", progress: 94 },
        },
      },
      { ...baseStudioJob, ...step3 }
    );
    expect(step4.status).toBe("muxing_audio");
    expect(step4.progressPercent).toBeGreaterThanOrEqual(88);

    const done = computeStudioJobUpdate(
      {
        status: "completed",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "completed", progress: 100 },
        },
        outputs: {
          dubbedVideos: { te: "gs://truthworld-1.firebasestorage.app/videos/dubjob_123/te-dubbed.mp4" },
          audioTracks: { te: "gs://truthworld-1.firebasestorage.app/audio/dubjob_123/te.mp3" },
          subtitles: { te: "gs://truthworld-1.firebasestorage.app/subtitles/dubjob_123/te.srt" },
        },
      },
      { ...baseStudioJob, ...step4 }
    );
    expect(done.status).toBe("completed");
    expect(done.progressPercent).toBe(100);
    expect(done.exportUrls.dubbedVideoByLanguage.te).toContain("firebasestorage.googleapis.com");
    expect(done.exportUrls.dubbedAudioByLanguage.te).toContain("firebasestorage.googleapis.com");
    expect(done.exportUrls.subtitlesSrt.te).toContain("firebasestorage.googleapis.com");
  });

  it("extracts legacy literal dotted outputs keys and normalizes gs:// URIs", () => {
    const res = computeStudioJobUpdate(
      {
        status: "completed",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "completed", progress: 100 },
        },
        "outputs.dubbedVideos.te": "gs://truthworld-1.firebasestorage.app/videos/dubjob_123/te-dubbed.mp4",
        "outputs.audioTracks.te": "gs://truthworld-1.firebasestorage.app/audio/dubjob_123/te/master.mp3",
        "outputs.dialogueTracks.te": "gs://truthworld-1.firebasestorage.app/audio/dubjob_123/te/stitched.mp3",
        "outputs.translations.te": "gs://truthworld-1.firebasestorage.app/translations/dubjob_123/translation_te.json",
        "outputs.subtitles.te": "gs://truthworld-1.firebasestorage.app/subtitles/dubjob_123/te.srt",
        "outputs.stems.vocals": "gs://truthworld-1.firebasestorage.app/audio/dubjob_123/vocals_demucs.mp3",
        "outputs.stems.mne": "gs://truthworld-1.firebasestorage.app/audio/dubjob_123/m_and_e.mp3",
        "outputs.dubbingReportUrl": "gs://truthworld-1.firebasestorage.app/dubbing/dubjob_123/report.json",
      },
      baseStudioJob
    );
    expect(res.exportUrls.dubbedVideoByLanguage.te).toContain("firebasestorage.googleapis.com");
    expect(res.exportUrls.dubbedAudioByLanguage.te).toContain("firebasestorage.googleapis.com");
    expect(res.exportUrls.dialogueAudioByLanguage.te).toContain("firebasestorage.googleapis.com");
    expect(res.exportUrls.translationJsonByLanguage.te).toContain("firebasestorage.googleapis.com");
    expect(res.exportUrls.vocalsStemMp3).toContain("firebasestorage.googleapis.com");
    expect(res.exportUrls.backgroundStemMp3).toContain("firebasestorage.googleapis.com");
    expect(res.exportUrls.reportJson).toContain("firebasestorage.googleapis.com");
    expect(res.exportUrls.subtitlesSrt.te).toContain("firebasestorage.googleapis.com");
  });

  it("never marks dubbing completed prematurely when video_jobs.status is 'published'", () => {
    const mid = computeStudioJobUpdate(
      {
        status: "published",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "pending", progress: 0 },
        },
      },
      baseStudioJob
    );
    expect(mid.status).toBe("translating");
    expect(mid.progressPercent).toBe(35);
    expect(mid.exportUrls).toBeUndefined();
  });

  it("tracks subtitles_only mode via stages.subtitles and excludes dubbed videos", () => {
    const subJob = { ...baseStudioJob, mode: "subtitles_only" };
    const mid = computeStudioJobUpdate(
      {
        status: "processing",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "skipped", progress: 100 },
          subtitles: { status: "running", progress: 50 },
        },
      },
      subJob
    );
    expect(mid.status).toBe("generating_subtitles");
    expect(mid.progressPercent).toBe(65);

    const done = computeStudioJobUpdate(
      {
        status: "processing",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "skipped", progress: 100 },
          subtitles: { status: "completed", progress: 100 },
        },
        outputs: {
          subtitles: { te: "gs://truthworld-1.firebasestorage.app/subtitles/dubjob_123/te.srt" },
        },
      },
      subJob
    );
    expect(done.status).toBe("completed");
    expect(done.progressPercent).toBe(100);
    expect(done.exportUrls.subtitlesSrt.te).toContain("firebasestorage.googleapis.com");
  });

  it("transitions to failed with error message when transcription or dubbing fails", () => {
    const failed = computeStudioJobUpdate(
      {
        status: "processing",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "failed", error: "We couldn't finish the Telugu dub." },
        },
      },
      baseStudioJob
    );
    expect(failed.status).toBe("failed");
    expect(failed.error).toBe("We couldn't finish the Telugu dub.");
  });

  it("rejects original upload URL from dubbedVideoByLanguage", () => {
    const done = computeStudioJobUpdate(
      {
        status: "completed",
        videoUrl: baseStudioJob.sourceMediaUrl,
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "completed", progress: 100 },
        },
        outputs: {
          dubbedVideos: { te: baseStudioJob.sourceMediaUrl },
          audioTracks: { te: "https://storage.googleapis.com/truthworld-1.firebasestorage.app/audio/dubjob_123/te.mp3" },
        },
      },
      baseStudioJob
    );
    expect(done.exportUrls.dubbedVideoByLanguage.te).toBeUndefined();
    expect(done.exportUrls.dubbedAudioByLanguage.te).toContain("te.mp3");
  });

  it("converts gs:// storage paths to HTTPS URLs synchronously", () => {
    expect(toDirectHttpUrl("gs://truthworld-1.firebasestorage.app/videos/dubjob_1/te-dubbed.mp4")).toBe(
      "https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/videos%2Fdubjob_1%2Fte-dubbed.mp4?alt=media"
    );
  });

  it("merges late-arriving dubbedVideos into existing exportUrls instead of leaving dubbedVideoByLanguage empty", () => {
    const existingStudioJob = {
      ...baseStudioJob,
      status: "completed",
      progressPercent: 100,
      exportUrls: {
        dubbedVideoByLanguage: {},
        dubbedAudioByLanguage: {
          te: "https://storage.googleapis.com/truthworld-1.firebasestorage.app/audio/dubjob_123/te.mp3",
        },
        subtitlesSrt: {
          te: "https://storage.googleapis.com/truthworld-1.firebasestorage.app/subtitles/dubjob_123/te.srt",
        },
        subtitlesVtt: {},
      },
    };

    const updated = computeStudioJobUpdate(
      {
        status: "completed",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "completed", progress: 100 },
        },
        outputs: {
          dubbedVideos: {
            te: "gs://truthworld-1.firebasestorage.app/videos/dubjob_123/te-dubbed.mp4",
          },
          audioTracks: {
            te: "gs://truthworld-1.firebasestorage.app/audio/dubjob_123/te.mp3",
          },
        },
      },
      existingStudioJob
    );

    expect(updated.exportUrls).toBeDefined();
    expect(updated.exportUrls.dubbedVideoByLanguage.te).toContain("te-dubbed.mp4");
    expect(updated.exportUrls.dubbedVideoMp4).toContain("te-dubbed.mp4");
    expect(updated.exportUrls.dubbedAudioByLanguage.te).toContain("audio/dubjob_123/te.mp3");
  });

  it("reports failed instead of completed when stages.dubbing fails even if video_jobs.status is completed", () => {
    const failed = computeStudioJobUpdate(
      {
        status: "completed",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "failed", error: "Telugu dubbing failed." },
          subtitles: { status: "completed", progress: 100 },
        },
      },
      baseStudioJob
    );
    expect(failed.status).toBe("failed");
    expect(failed.error).toBe("Telugu dubbing failed.");
  });
});

describe("Standalone Dubbing Studio pipeline guards", () => {
  it("05-transcription bypasses public-feed MANUAL_REVIEW and copyright hold for standalone dubbing jobs", () => {
    const source = fs.readFileSync(
      path.resolve(__dirname, "../../src/pipeline/layers/05-transcription.ts"),
      "utf8"
    );
    expect(source).toContain("const isStandaloneDubbingJob = !targetVideoId && !isCredibilityRequested && isDubbingOrSubtitles;");
    expect(source).toContain('gatewayDecision.status === "MANUAL_REVIEW" && isStandaloneDubbingJob');
    expect(source).toContain("syncStudioDubbingJobsForPipelineJob");
  });

  it("pipelineTriggers exports onVideoJobWrittenSyncDubbingStudio and allocates 4GiB / 2 vCPU for handleDubbing", () => {
    const triggersSource = fs.readFileSync(
      path.resolve(__dirname, "../../src/pipeline/pipelineTriggers.ts"),
      "utf8"
    );
    expect(triggersSource).toContain("export const onVideoJobWrittenSyncDubbingStudio");
    expect(triggersSource).toMatch(/handleDubbing\s*=\s*onMessagePublished\([\s\S]*?memory:\s*"4GiB"[\s\S]*?cpu:\s*2/);
  });

  it("screenContentAnalyzer falls back on 404 NOT_FOUND and configures thinkingBudget 0", async () => {
    const aiClient = require("../../src/pipeline/utils/ai-client");
    const calls: any[] = [];
    const spy = jest.spyOn(aiClient, "getVertexClient").mockReturnValue({
      models: {
        generateContent: jest.fn(async (req: any) => {
          calls.push(req);
          if (req.model === "gemini-3.5-flash-lite") {
            const err: any = new Error('{"error":{"code":404,"message":"Requested entity was not found.","status":"NOT_FOUND"}}');
            err.status = 404;
            throw err;
          }
          return {
            text: JSON.stringify({
              songs: [],
              on_screen_text: [{ start_seconds: 1, end_seconds: 4, text: "NEWSLAUNDRY", language: "en" }],
            }),
          };
        }),
      },
    });
    try {
      const { getScreenContent } = require("../../src/pipeline/services/screenContentAnalyzer");
      const res = await getScreenContent(
        `screen_test_${Date.now()}`,
        "https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/dubbing_uploads%2Fu1%2Fclip.mp4?alt=media",
        32000
      );
      expect(calls.length).toBeGreaterThanOrEqual(2);
      expect(calls[0].config?.thinkingConfig).toEqual({ thinkingBudget: 0 });
      expect(calls[1].model).toBe("gemini-3.8-flash");
      expect(res.onScreenText).toEqual([{ startMs: 1000, endMs: 4000, text: "NEWSLAUNDRY", language: "en" }]);
    } finally {
      spy.mockRestore();
    }
  });

  it("geminiDubbingEditor defaultGenerate configures bounded thinkingConfig for low latency", async () => {
    const aiClient = require("../../src/pipeline/utils/ai-client");
    const calls: any[] = [];
    const spy = jest.spyOn(aiClient, "getVertexClient").mockReturnValue({
      models: {
        generateContent: jest.fn(async (req: any) => {
          calls.push(req);
          if (String(req.config?.systemInstruction || "").includes("You check ")) {
            return {
              text: JSON.stringify({
                lines: [{ id: "L1", keeps_meaning: true, polarity_flipped: false, numbers_changed: false }],
              }),
            };
          }
          return {
            text: JSON.stringify({ lines: [{ id: "L1", text: "హలో ప్రపంచం" }] }),
          };
        }),
      },
    });
    try {
      const { GeminiDubbingEditor } = require("../../src/pipeline/services/geminiDubbingEditor");
      const editor = new GeminiDubbingEditor();
      await editor.editSegments(
        [{ id: "L1", source: "Hello world", draft: "హలో ప్రపంచం", speaker: "speaker_0", maxSyllables: 20 }],
        {
          jobId: "thinking_test",
          sourceLanguage: "en",
          targetLanguage: "te",
          countSyllables: () => 5,
        }
      );
      expect(calls.length).toBeGreaterThanOrEqual(2);
      expect(calls[0].config?.thinkingConfig?.thinkingLevel).toBe("LOW");
      expect(calls[calls.length - 1].config?.thinkingConfig?.thinkingLevel).toBe("LOW");
    } finally {
      spy.mockRestore();
    }
  });
});
