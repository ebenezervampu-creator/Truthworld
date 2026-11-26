import { computeStudioJobUpdate } from "../../src/dubbing/studio-job-sync";
import {
  buildDubbingReportPayload,
  buildTranslationArtifactPayload,
} from "../../src/pipeline/services/dubbing-report";

describe("Dubbing Output Artifacts (MP4, Master MP3, Dialogue MP3, Stems, Translation JSON, Report JSON)", () => {
  it("builds translation_{lang}.json payload with structured segment fields", () => {
    const payload = buildTranslationArtifactPayload({
      jobId: "job_te_1",
      videoId: "vid_123",
      sourceLanguage: "en",
      targetLanguage: "te",
      segments: [
        {
          index: 0,
          start: 0,
          end: 2500,
          speaker: "speaker_0",
          originalText: "Hello everyone",
          translatedText: "అందరికీ నమస్కారం",
          subtitleText: "అందరికీ నమస్కారం",
          emotionTag: "neutral",
        },
      ],
      generatedAt: "2026-11-26T00:00:00.000Z",
    });

    expect(payload.jobId).toBe("job_te_1");
    expect(payload.videoId).toBe("vid_123");
    expect(payload.sourceLanguage).toBe("en");
    expect(payload.targetLanguage).toBe("te");
    expect(payload.segmentCount).toBe(1);
    expect(payload.segments[0]).toEqual({
      index: 0,
      startMs: 0,
      endMs: 2500,
      speaker: "speaker_0",
      originalText: "Hello everyone",
      translatedText: "అందరికీ నమస్కారం",
      subtitleText: "అందరికీ నమస్కారం",
      emotionTag: "neutral",
    });
  });

  it("builds report.json payload with stems and per-language output artifacts", () => {
    const report = buildDubbingReportPayload({
      jobId: "job_te_1",
      videoId: "vid_123",
      sourceLanguage: "en",
      targetLanguages: ["te"],
      durationSeconds: 30,
      processingTimeMs: 4200,
      vocalsStemUrl: "gs://bucket/audio/job_te_1/vocals_demucs.mp3",
      backgroundStemUrl: "gs://bucket/audio/job_te_1/m_and_e.mp3",
      separationPath: "demucs",
      results: [
        {
          jobId: "job_te_1",
          language: "te",
          subtitleUrl: "gs://bucket/subtitles/job_te_1/te.srt",
          subtitleFormat: "srt",
          audioUrl: "gs://bucket/audio/job_te_1/te/master.mp3",
          videoUrl: "gs://bucket/videos/job_te_1/te-dubbed.mp4",
          translationUrl: "gs://bucket/translations/job_te_1/translation_te.json",
          segments: 5,
          processingTime: 3900,
          dubOutcome: "delivered",
          stems: {
            dialogue: "gs://bucket/audio/job_te_1/te/stitched.mp3",
            master: "gs://bucket/audio/job_te_1/te/master.mp3",
            vocals: "gs://bucket/audio/job_te_1/vocals_demucs.mp3",
            mne: "gs://bucket/audio/job_te_1/m_and_e.mp3",
          },
        },
      ],
      generatedAtMs: 1700000000000,
    });

    expect(report.stems.vocalsStemUrl).toBe("gs://bucket/audio/job_te_1/vocals_demucs.mp3");
    expect(report.stems.backgroundStemUrl).toBe("gs://bucket/audio/job_te_1/m_and_e.mp3");
    expect(report.stems.separationPath).toBe("demucs");
    expect(report.languages.te.status).toBe("completed");
    expect(report.languages.te.artifacts).toEqual({
      dubbedVideoUrl: "gs://bucket/videos/job_te_1/te-dubbed.mp4",
      masterAudioUrl: "gs://bucket/audio/job_te_1/te/master.mp3",
      dialogueAudioUrl: "gs://bucket/audio/job_te_1/te/stitched.mp3",
      translationUrl: "gs://bucket/translations/job_te_1/translation_te.json",
      subtitleSrtUrl: "gs://bucket/subtitles/job_te_1/te.srt",
      subtitleVttUrl: "gs://bucket/subtitles/job_te_1/te.vtt",
    });
  });

  it("computeStudioJobUpdate propagates all 7 output artifact types into exportUrls", () => {
    const baseStudioJob = {
      id: "dub_job_te_1",
      pipelineJobId: "job_te_1",
      mode: "dubbing",
      sourceMediaUrl: "https://firebasestorage.googleapis.com/v0/b/b1/o/source.mp4?alt=media",
      targetLanguages: ["te"],
      progressPercent: 80,
      status: "muxing_audio",
    };

    const done = computeStudioJobUpdate(
      {
        status: "completed",
        stages: {
          transcription: { status: "completed", progress: 100 },
          dubbing: { status: "completed", progress: 100 },
        },
        outputs: {
          dubbedVideos: { te: "gs://b1/videos/job_te_1/te-dubbed.mp4" },
          audioTracks: { te: "gs://b1/audio/job_te_1/te/master.mp3" },
          dialogueTracks: { te: "gs://b1/audio/job_te_1/te/stitched.mp3" },
          translations: { te: "gs://b1/translations/job_te_1/translation_te.json" },
          subtitles: { te: "gs://b1/subtitles/job_te_1/te.srt" },
          dubbingReportUrl: "gs://b1/dubbing/job_te_1/report.json",
          stems: {
            vocals: "gs://b1/audio/job_te_1/vocals_demucs.mp3",
            background: "gs://b1/audio/job_te_1/m_and_e.mp3",
          },
        },
      },
      baseStudioJob
    );

    expect(done.status).toBe("completed");
    expect(done.exportUrls.dubbedVideoByLanguage.te).toContain("te-dubbed.mp4");
    expect(done.exportUrls.dubbedAudioByLanguage.te).toContain("master.mp3");
    expect(done.exportUrls.dialogueAudioByLanguage.te).toContain("stitched.mp3");
    expect(done.exportUrls.translationJsonByLanguage.te).toContain("translation_te.json");
    expect(done.exportUrls.vocalsStemMp3).toContain("vocals_demucs.mp3");
    expect(done.exportUrls.backgroundStemMp3).toContain("m_and_e.mp3");
    expect(done.exportUrls.reportJson).toContain("report.json");
    expect(done.exportUrls.subtitlesSrt.te).toContain("te.srt");
  });
});
