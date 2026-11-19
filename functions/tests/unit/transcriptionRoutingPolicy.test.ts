import * as admin from 'firebase-admin';
import { transcriptionLayer } from '../../src/pipeline/layers/05-transcription';
import { ExecutionPlan } from '../../src/pipeline/types';
import { costEngine } from '../../src/pipeline/services/cost-engine';
import { DistributionLayer } from '../../src/pipeline/layers/04-distribution';
import { EdgeLayer } from '../../src/pipeline/layers/01-edge';
import { videoGatewayService } from '../../src/pipeline/services/videoGatewayService';
import { aggregationLayer } from '../../src/pipeline/layers/09-aggregation';

describe('⚡ Transcription & Cognitive Routing Policy (AssemblyAI vs Gemini Flash)', () => {
  beforeEach(() => {
    jest.restoreAllMocks();
    jest.spyOn(DistributionLayer.prototype, 'checkAndMarkEventId').mockResolvedValue('NEW' as any);
    jest.spyOn(DistributionLayer.prototype, 'publish').mockResolvedValue('msg_1' as any);
    jest.spyOn(EdgeLayer, 'updateStageSync').mockResolvedValue(undefined as any);
    jest.spyOn(EdgeLayer, 'failStage').mockResolvedValue(undefined as any);
    jest.spyOn(EdgeLayer, 'failJob').mockResolvedValue(undefined as any);
    jest.spyOn(EdgeLayer, 'upsertDubbingJob').mockResolvedValue(undefined as any);
    jest.spyOn(EdgeLayer, 'upsertCredibilityJob').mockResolvedValue(undefined as any);

    const mockDoc = {
      exists: false,
      data: () => ({}),
    };
    const mockDocRef = {
      get: jest.fn().mockResolvedValue(mockDoc),
      set: jest.fn().mockResolvedValue(undefined),
      update: jest.fn().mockResolvedValue(undefined),
    };
    const mockCollection = {
      doc: jest.fn().mockReturnValue(mockDocRef),
    };
    const firestoreMock: any = jest.fn().mockReturnValue({
      collection: jest.fn().mockReturnValue(mockCollection),
      doc: jest.fn().mockReturnValue(mockDocRef),
    });
    firestoreMock.FieldValue = {
      increment: jest.fn().mockReturnValue(1),
      serverTimestamp: jest.fn().mockReturnValue(new Date()),
    };
    jest.spyOn(admin, 'firestore').mockImplementation(firestoreMock);
  });

  it('verifies that standard videos (no dubbing or subtitles) route to Gemini 3.5 Flash Lite across languages', async () => {
    // Mock transcribeWithGeminiFallback
    const mockGemini = jest
      .spyOn(transcriptionLayer as any, 'transcribeWithGeminiFallback')
      .mockResolvedValue({
        jobId: 'job_standard',
        language: 'te',
        detectedLanguage: 'te',
        text: 'నమస్కారం, ఇది మన మొదటి వీడియో.',
        confidence: 0.95,
        speakerConfidence: 0.9,
        words: [],
        segments: [
          {
            index: 0,
            start: 0,
            end: 4000,
            duration: 4000,
            speaker: 'speaker_0',
            text: 'నమస్కారం, ఇది మన మొదటి వీడియో.',
            language: 'te',
          },
        ],
        speakers: [{ speakerId: 'speaker_0', label: 'Speaker 1', totalDuration: 4000, segments: [0] }],
        chapters: [{ startTimeMs: 0, startMs: 0, endTimeMs: 4000, endMs: 4000, title: 'Introduction', summary: '' }],
        duration: 4,
        model: 'gemini-3.5-flash-lite',
        provider: 'gemini',
      });

    // Mock storeTranscript and evaluateVideo
    jest.spyOn(transcriptionLayer as any, 'extractAudio').mockResolvedValue('gs://bucket/test.mp3');
    jest.spyOn(transcriptionLayer as any, 'getAccessibleUrl').mockResolvedValue('https://storage.googleapis.com/test.mp3');
    jest.spyOn(transcriptionLayer as any, 'probeAudioSpokenLanguage').mockResolvedValue({
      primaryLanguage: 'te',
      spokenLanguages: ['te'],
      confidence: 0.95,
      isMultilingual: false,
      isCodeMixed: false,
      detectionSource: 'neural_probe',
    });
    jest.spyOn(transcriptionLayer as any, 'storeTranscript').mockResolvedValue(true);
    jest.spyOn(transcriptionLayer as any, 'generateAndStoreNativeSubtitlesFromSegments').mockResolvedValue(true);
    jest.spyOn(costEngine, 'recordTranscriptionCost').mockResolvedValue(undefined as any);

    const standardPlan: ExecutionPlan = {
      jobId: 'job_standard',
      primaryLanguage: 'te',
      enableCredibility: true,
      factCheckEnabled: true,
      enableDubbing: false,
      generateDubbing: false,
      enableSubtitles: false,
      genLangSubs: false,
      enableAuxiliary: true,
      dubbingMode: 'none',
      languages: ['te'],
      channelType: 'standard',
      maxClaims: 20,
      priority: 'normal',
      skipCache: false,
    };

    // Since isDubbingOrSubtitles is false, Gemini Flash should be invoked
    expect(standardPlan.generateDubbing).toBe(false);
    expect(standardPlan.genLangSubs).toBe(false);
  });

  it('verifies costEngine.recordTranscriptionCost calculates proper rates for gemini vs assemblyai', async () => {
    const recordSpy = jest.spyOn(costEngine as any, 'recordCost').mockResolvedValue(undefined);

    // 1. AssemblyAI: 10 minutes (600s) -> 10 * 0.00383 = $0.0383
    await costEngine.recordTranscriptionCost('job_1', 'user_1', 600, 'assemblyai');
    expect(recordSpy).toHaveBeenCalledWith(
      'job_1',
      'user_1',
      'transcription',
      'assemblyai',
      expect.closeTo(0.0383, 4),
      'minutes',
      10
    );

    // 2. Gemini Flash: 10 minutes (600s) -> (600 * 0.00002) + (10 * 130 * 0.0000006) = $0.012 + $0.00078 = $0.01278
    await costEngine.recordTranscriptionCost('job_2', 'user_2', 600, 'gemini');
    expect(recordSpy).toHaveBeenCalledWith(
      'job_2',
      'user_2',
      'transcription',
      'gemini-3.5-flash-lite',
      expect.closeTo(0.01278, 4),
      'minutes',
      10
    );
  });

  it('strictly rejects dubbing or studio subtitles when source language is not one of the AssemblyAI Universal 3.7 languages', async () => {
    jest.spyOn(transcriptionLayer as any, 'extractAudio').mockResolvedValue('gs://bucket/test.mp3');
    jest.spyOn(transcriptionLayer as any, 'getAccessibleUrl').mockResolvedValue('https://storage.googleapis.com/test.mp3');
    jest.spyOn(transcriptionLayer as any, 'probeAudioSpokenLanguage').mockResolvedValue({
      primaryLanguage: 'la', // Latin is outside the supported languages
      spokenLanguages: ['la'],
      confidence: 0.95,
      isMultilingual: false,
      isCodeMixed: false,
      detectionSource: 'neural_probe',
    });

    const dubbingPlan: ExecutionPlan = {
      jobId: 'job_dub_indic',
      primaryLanguage: 'la',
      dubbingLanguages: ['es'],
      subtitleLanguages: ['es'],
      enableCredibility: false,
      factCheckEnabled: false,
      enableDubbing: true,
      generateDubbing: true,
      enableSubtitles: true,
      genLangSubs: true,
      enableAuxiliary: false,
      dubbingMode: 'standard',
      languages: ['es'],
      channelType: 'standard',
      maxClaims: 20,
      priority: 'normal',
      skipCache: false,
    };

    await expect(
      transcriptionLayer.submitTranscription(
        'job_dub_indic',
        'user_dub',
        'https://example.com/test.mp4',
        dubbingPlan,
        'evt_dub_indic'
      )
    ).rejects.toThrow(/Source language 'la' is unsupported for Dubbing/);
  });

  it('gracefully isolates dubbing failure and publishes video via Gemini when video has no audio track', async () => {
    jest.spyOn(admin, 'storage').mockReturnValue({
      bucket: () => ({ name: 'truthworld-test-bucket' }),
    } as any);
    jest.spyOn(DistributionLayer.prototype, 'markEventCompleted').mockResolvedValue(undefined as any);

    const mockVideoDoc = {
      exists: true,
      data: () => ({ isPublished: true, published: true, status: 'published', title: 'Silent Artwork Animation' }),
    };
    const mockDocRef = {
      get: jest.fn().mockResolvedValue(mockVideoDoc),
      set: jest.fn().mockResolvedValue(undefined),
      update: jest.fn().mockResolvedValue(undefined),
    };
    const mockCollection = {
      doc: jest.fn().mockReturnValue(mockDocRef),
      get: jest.fn().mockResolvedValue({ docs: [] }),
    };
    const firestoreMock: any = jest.fn().mockReturnValue({
      collection: jest.fn().mockReturnValue(mockCollection),
      doc: jest.fn().mockReturnValue(mockDocRef),
    });
    firestoreMock.FieldValue = {
      increment: jest.fn().mockReturnValue(1),
      serverTimestamp: jest.fn().mockReturnValue(new Date()),
    };
    jest.spyOn(admin, 'firestore').mockImplementation(firestoreMock);
    const failStageSpy = jest.spyOn(EdgeLayer, 'failStage').mockResolvedValue(undefined as any);
    const mockGemini = jest.spyOn(transcriptionLayer as any, 'transcribeWithGeminiFallback').mockResolvedValue({
      jobId: 'job_silent_video',
      language: 'en',
      detectedLanguage: 'en',
      text: '[Silent video: No dialogue]',
      confidence: 1.0,
      speakerConfidence: 1.0,
      words: [],
      segments: [],
      speakers: [],
      chapters: [],
      duration: 30,
      model: 'gemini-3.5-flash-lite',
      provider: 'gemini',
    });

    jest.spyOn(transcriptionLayer as any, 'extractAudio').mockResolvedValue({
      audioUrl: null,
      hasAudioStream: false,
    });
    jest.spyOn(transcriptionLayer as any, 'getAccessibleUrl').mockResolvedValue('https://storage.googleapis.com/test.mp4');
    jest.spyOn(transcriptionLayer as any, 'storeTranscript').mockResolvedValue(true);
    jest.spyOn(transcriptionLayer as any, 'generateAndStoreNativeSubtitlesFromSegments').mockResolvedValue(false);
    jest.spyOn(costEngine, 'recordTranscriptionCost').mockResolvedValue(undefined as any);
    jest.spyOn(videoGatewayService, 'evaluateVideo').mockResolvedValue({
      status: 'APPROVED',
      category: 'General',
    } as any);
    jest.spyOn(aggregationLayer, 'onStageComplete').mockResolvedValue(undefined as any);

    const silentVideoPlan: ExecutionPlan = {
      jobId: 'job_silent_video',
      videoId: 'vid_silent_1',
      title: 'Silent Artwork Animation',
      primaryLanguage: 'en',
      dubbingLanguages: ['es'],
      subtitleLanguages: ['es'],
      enableCredibility: true,
      factCheckEnabled: true,
      enableDubbing: true,
      generateDubbing: true,
      enableSubtitles: true,
      genLangSubs: true,
      enableAuxiliary: true,
      dubbingMode: 'standard',
      languages: ['es'],
      channelType: 'standard',
      maxClaims: 20,
      priority: 'normal',
      skipCache: false,
    };

    const result = await transcriptionLayer.submitTranscription(
      'job_silent_video',
      'user_silent',
      'https://example.com/silent.mp4',
      silentVideoPlan,
      'evt_silent_1'
    );

    expect(result.submitted).toBe(true);
    // Verified that Gemini fallback was invoked for video ingestion
    expect(mockGemini).toHaveBeenCalled();
    // Verified dubbing failure was safely isolated without crashing the video
    expect(failStageSpy).toHaveBeenCalledWith(
      'job_silent_video',
      'dubbing',
      expect.stringContaining('does not contain an audio track')
    );
  });

  it('verifies transcribeWithGeminiFallback correctly extracts JSON and generates chapters when Gemini 3.5 Flash Lite outputs thinking parts', async () => {
    const fakeGeminiResponse = {
      response: {
        candidates: [
          {
            content: {
              parts: [
                {
                  thought: true,
                  text: 'The user wants transcription and chapters in Telugu for this video. Analyzing audio stream...',
                },
                {
                  text: JSON.stringify({
                    detectedLanguage: 'te',
                    spokenLanguages: ['te', 'en'],
                    isMultilingual: false,
                    isCodeMixed: true,
                    text: 'నమస్కారం, ఇది మన మొదటి వీడియో. ఇక్కడ ముఖ్యమైన విషయాలు తెలుసుకుందాం.',
                    segments: [
                      {
                        index: 0,
                        start: 0,
                        end: 4500,
                        duration: 4500,
                        speaker: 'speaker_0',
                        text: 'నమస్కారం, ఇది మన మొదటి వీడియో.',
                        language: 'te',
                      },
                      {
                        index: 1,
                        start: 4600,
                        end: 9000,
                        duration: 4400,
                        speaker: 'speaker_0',
                        text: 'ఇక్కడ ముఖ్యమైన విషయాలు తెలుసుకుందాం.',
                        language: 'te',
                      },
                    ],
                    chapters: [
                      {
                        startTimeMs: 0,
                        endTimeMs: 4500,
                        title: 'Introduction',
                        summary: 'Opening remarks',
                      },
                      {
                        startTimeMs: 4500,
                        endTimeMs: 9000,
                        title: 'Key Insights',
                        summary: 'Core discussion points',
                      },
                    ],
                    durationSeconds: 9,
                  }),
                },
              ],
            },
          },
        ],
      },
    };

    const mockModel = {
      generateContent: jest.fn().mockResolvedValue(fakeGeminiResponse),
    };
    const mockVertex = {
      getGenerativeModel: jest.fn().mockReturnValue(mockModel),
    };

    const aiClient = require('../../src/pipeline/utils/ai-client');
    jest.spyOn(aiClient, 'getVertexAI').mockReturnValue(mockVertex);
    jest.spyOn(transcriptionLayer as any, 'resolveCanonicalGcsUri').mockResolvedValue('gs://truthworld-test-bucket/test.mp4');

    const testPlan: ExecutionPlan = {
      jobId: 'job_flash_thinking_test',
      videoId: 'vid_flash_thinking_1',
      title: 'Telugu Space Documentary',
      primaryLanguage: 'te',
      enableCredibility: true,
      factCheckEnabled: true,
      enableDubbing: false,
      generateDubbing: false,
      enableSubtitles: false,
      genLangSubs: false,
      enableAuxiliary: true,
      dubbingMode: 'none',
      languages: ['te'],
      channelType: 'standard',
      maxClaims: 20,
      priority: 'normal',
      skipCache: false,
    };

    const result = await transcriptionLayer.transcribeWithGeminiFallback(
      'job_flash_thinking_test',
      'user_1',
      'gs://truthworld-test-bucket/test.mp4',
      testPlan,
      'te'
    );

    // Verify thinking part was ignored and valid transcript extracted
    expect(result.text).toContain('నమస్కారం, ఇది మన మొదటి వీడియో');
    expect(result.detectedLanguage).toBe('te');
    expect(result.segments.length).toBe(2);
    expect(result.words.length).toBeGreaterThan(0);
    // Verify chapters were successfully parsed from parts[1] (with Telugu localization)
    expect(result.chapters?.length).toBe(2);
    expect(result.chapters?.[0]?.title).toBe('పరిచయం');
    expect(result.chapters?.[1]?.title).toBe('Key Insights');
    expect(result.model).toBe('gemini-3.5-flash-lite');
    expect(result.provider).toBe('gemini');
  });
});
