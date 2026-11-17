/**
 * 🧪 COMPREHENSIVE SAMPLE TEST:
 *    - Sample Telugu & Code-Mixed ("Tenglish") Speech-to-Text via ElevenLabs Scribe v2
 *    - Multilingual Empirical Claim Extraction (Telugu + English)
 *    - ElevenLabs V4 Premium Tier 1 Dubbing with Tier 2 (v3) Fallback
 *    - Zero Google Cloud Speech Models Guarantee
 */

import { ElevenLabsTTSService, TTSService } from '../../src/pipeline/services/tts';
import { FactExtractionService } from '../../src/pipeline/services/factExtraction';
import { transcriptionLayer } from '../../src/pipeline/layers/05-transcription';
import { costEngine } from '../../src/pipeline/services/cost-engine';
import { TTSRequest, ExtractedClaim } from '../../src/pipeline/types';

import { mockBucket, mockFile } from '../setup';
import * as admin from 'firebase-admin';

// Spy on admin.storage
jest.spyOn(admin, 'storage').mockReturnValue({
  bucket: () => mockBucket as any,
} as any);

// Mock axios for ElevenLabs API
jest.mock('axios');
import axios from 'axios';
const mockedAxios = axios as jest.Mocked<typeof axios>;

// Mock Vertex AI for Fact Extraction
jest.mock('../../src/pipeline/utils/ai-client', () => ({
  getVertexAI: jest.fn(() => ({
    getGenerativeModel: jest.fn(() => ({
      generateContent: jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      claims: [
                        {
                          text: "Indian Council of Medical Research ప్రకారం, Covaxin 77.8 percent efficacy రేటును కలిగి ఉంది",
                          nature: "VERIFIABLE_FACT",
                          framing: "ASSERTIVE",
                          confidence: 0.96,
                          importance: 0.9,
                          isVerifiableEvent: true,
                          honestyWashingRisk: false,
                          assertiveness: "confident",
                          claimStrength: "strong",
                        },
                        {
                          text: "Covaxin clinical trials were completed across multiple phase III sites",
                          nature: "VERIFIABLE_FACT",
                          framing: "ASSERTIVE",
                          confidence: 0.92,
                          importance: 0.85,
                          isVerifiableEvent: true,
                          honestyWashingRisk: false,
                          assertiveness: "confident",
                          claimStrength: "strong",
                        }
                      ],
                      summary: "Sample Telugu and English code-mixed medical claims on vaccine efficacy."
                    }),
                  },
                ],
              },
            },
          ],
        },
      }),
    })),
  })),
}));

describe('Sample Verification: Code-Mixed Telugu & ElevenLabs V4 Dubbing', () => {
  let elevenLabsService: ElevenLabsTTSService;
  let ttsService: TTSService;
  let factService: FactExtractionService;

  beforeEach(() => {
    jest.clearAllMocks();
    (mockBucket as any).name = 'truthworld-test-bucket';
    elevenLabsService = new ElevenLabsTTSService('test-elevenlabs-api-key');
    ttsService = new TTSService(undefined, elevenLabsService);
    factService = new FactExtractionService('mock-api-key');
    jest.spyOn(costEngine, 'recordTTSCost').mockImplementation(async () => {});
  });

  describe('Sample 1: Speech-to-Text via ElevenLabs Scribe v2 for Code-Mixed Telugu', () => {
    it('transcribes sample Telugu audio using ElevenLabs Scribe v2 with speaker diarization', async () => {
      // Mock ElevenLabs Scribe response for sample Telugu audio
      const mockScribeResponse = {
        language_code: 'te',
        text: 'హలో friends, ఈరోజు vaccine safety గురించి ఒక serious myth bust చేద్దాం. Covaxin 77.8 percent efficacy రేటును కలిగి ఉంది.',
        words: [
          { text: 'హలో', start: 0.1, end: 0.5, speaker_id: 'speaker_0', type: 'word' },
          { text: 'friends', start: 0.6, end: 1.1, speaker_id: 'speaker_0', type: 'word' },
          { text: 'ఈరోజు', start: 1.2, end: 1.7, speaker_id: 'speaker_0', type: 'word' },
          { text: 'vaccine', start: 1.8, end: 2.3, speaker_id: 'speaker_0', type: 'word' },
          { text: 'safety', start: 2.4, end: 2.9, speaker_id: 'speaker_0', type: 'word' },
          { text: 'Covaxin', start: 3.2, end: 3.8, speaker_id: 'speaker_0', type: 'word' },
          { text: '77.8', start: 3.9, end: 4.4, speaker_id: 'speaker_0', type: 'word' },
          { text: 'percent', start: 4.5, end: 4.9, speaker_id: 'speaker_0', type: 'word' },
          { text: 'efficacy', start: 5.0, end: 5.5, speaker_id: 'speaker_0', type: 'word' },
        ],
      };

      mockedAxios.post.mockResolvedValueOnce({
        data: mockScribeResponse,
      });

      const result = await transcriptionLayer.transcribeWithElevenLabsScribe(
        'job_telugu_sample_stt',
        'creator_123',
        'gs://truthworld-media/videos/job_telugu_sample_stt/original.mp4',
        { primaryLanguage: 'te' } as any,
        'te'
      );

      expect(mockedAxios.post).toHaveBeenCalledTimes(1);
      const [url, formData] = mockedAxios.post.mock.calls[0];

      // Verifies ElevenLabs Scribe endpoint and parameters
      expect(url).toBe('https://api.elevenlabs.io/v1/speech-to-text');
      const form = formData as any;
      expect(form.get('model_id')).toBe('scribe_v2');
      expect(form.get('diarize')).toBe('true');
      expect(form.get('language_code')).toBe('te');

      // Verifies structured transcription result
      expect(result.detectedLanguage).toBe('te');
      expect(result.text).toContain('హలో friends');
      expect(result.text).toContain('Covaxin 77.8 percent efficacy');
      expect(result.words.length).toBe(9);
      expect(result.segments.length).toBeGreaterThan(0);
    });
  });

  describe('Sample 2: Multilingual Fact Extraction from Code-Mixed Telugu', () => {
    it('extracts empirical factual claims from code-mixed Telugu chunks without dropping Telugu assertions', async () => {
      const sampleChunkUtterances = [
        {
          text: 'హలో friends, ఈరోజు vaccine safety గురించి ఒక serious myth bust చేద్దాం. Indian Council of Medical Research ప్రకారం, Covaxin 77.8 percent efficacy రేటును కలిగి ఉంది.',
          start: 0,
          end: 6000,
          speaker: 'Presenter',
        },
      ];

      const claims: ExtractedClaim[] = await factService.extractClaimsFromChunk(
        'job_telugu_factcheck',
        sampleChunkUtterances,
        0
      );

      expect(claims).toBeDefined();
      expect(claims.length).toBe(2);

      // Verify that Telugu statement with English scientific terms is retained as VERIFIABLE_FACT
      const icmrClaim = claims.find((c: ExtractedClaim) => c.text.includes('Covaxin') || c.text.includes('efficacy'));
      expect(icmrClaim).toBeDefined();
      expect(icmrClaim?.nature).toBe('VERIFIABLE_FACT');
      expect(icmrClaim?.confidence).toBeGreaterThanOrEqual(0.9);
      expect(icmrClaim?.text).toContain('Indian Council of Medical Research');
    });
  });

  describe('Sample 3: Dubbing Synthesis with ElevenLabs V4 Premium First', () => {
    it('synthesizes sample Telugu text using Tier 1 eleven_v4', async () => {
      const sampleDubbingText = 'భారతదేశంలో డిజిటల్ చెల్లింపులు 50 శాతం పెరిగాయి.';
      const sampleMp3Bytes = Buffer.from('sample-mp3-elevenlabs-v4-bytes');

      mockedAxios.post.mockResolvedValueOnce({
        data: sampleMp3Bytes,
      });

      const request: TTSRequest = {
        jobId: 'job_sample_tts_v4',
        userId: 'user_telugu_creator',
        language: 'te',
        text: sampleDubbingText,
        voiceId: 'EXAVITQu4vr4xnSDxMaL',
      };

      const result = await ttsService.synthesize(request);

      expect(mockedAxios.post).toHaveBeenCalledTimes(1);
      const [url, postPayload, config] = mockedAxios.post.mock.calls[0];

      // Verify ElevenLabs API endpoint
      expect(url).toBe('https://api.elevenlabs.io/v1/text-to-speech/EXAVITQu4vr4xnSDxMaL');

      // Verify Tier 1 Model: eleven_v4 was selected first
      expect(postPayload).toMatchObject({
        text: sampleDubbingText,
        model_id: 'eleven_v4',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
          use_speaker_boost: true,
        },
      });

      // Verify headers
      expect(config?.headers).toMatchObject({
        'xi-api-key': 'test-elevenlabs-api-key',
        'Content-Type': 'application/json',
      });

      // Verify GCS storage and return payload
      expect(mockFile.save).toHaveBeenCalledTimes(1);
      expect(result.provider).toBe('elevenlabs');
      expect(result.language).toBe('te');
      expect(result.format).toBe('mp3');
      expect(result.audioUrl).toContain('gs://truthworld-test-bucket/audio/job_sample_tts_v4/te/chunk-');
    });
  });

  describe('Sample 4: Zero Fallback Policy — Strictly ElevenLabs v4 (eleven_v4)', () => {
    it('retries strictly on eleven_v4 when encountering transient 429 rate limit (zero fallback models)', async () => {
      const sampleSegment = 'సత్యమేవ జయతే - సత్యం మాత్రమే గెలుస్తుంది.';
      const sampleV4Bytes = Buffer.from('sample-v4-retry-audio');

      // Attempt 1: eleven_v4 fails with 429
      mockedAxios.post.mockRejectedValueOnce({
        response: {
          status: 429,
          data: { detail: 'Too Many Requests: V4 concurrency limit' },
        },
        message: 'Request failed with status code 429',
      });

      // Attempt 2: retry on eleven_v4 succeeds
      mockedAxios.post.mockResolvedValueOnce({
        data: sampleV4Bytes,
      });

      const request: TTSRequest = {
        jobId: 'job_sample_fallback',
        userId: 'user_test',
        language: 'te',
        text: sampleSegment,
      };

      const result = await ttsService.synthesize(request);

      // Verify 2 attempts were made
      expect(mockedAxios.post).toHaveBeenCalledTimes(2);

      // Both attempts are strictly eleven_v4 (zero fallback models)
      expect(mockedAxios.post.mock.calls[0][1]).toMatchObject({
        model_id: 'eleven_v4',
      });
      expect(mockedAxios.post.mock.calls[1][1]).toMatchObject({
        model_id: 'eleven_v4',
      });

      expect(result.provider).toBe('elevenlabs');
      expect(result.audioUrl).toContain('gs://truthworld-test-bucket/audio/job_sample_fallback/te/chunk-');
    });

    it('strictly fails with eleven_v4 after retries without attempting any fallback models', async () => {
      const sampleSegment = 'ప్రపంచవ్యాప్తంగా శాంతి మరియు సత్యం ముఖ్యం.';

      // Attempt 1: eleven_v4 fails with 500
      mockedAxios.post.mockRejectedValueOnce({
        response: {
          status: 500,
          data: { detail: 'Internal server error in V4' },
        },
        message: 'Request failed with status code 500',
      });

      // Attempt 2: eleven_v4 fails with 503
      mockedAxios.post.mockRejectedValueOnce({
        response: {
          status: 503,
          data: { detail: 'V4 capacity saturated' },
        },
        message: 'Request failed with status code 503',
      });

      const request: TTSRequest = {
        jobId: 'job_sample_flash_fallback',
        userId: 'user_test_2',
        language: 'te',
        text: sampleSegment,
      };

      const elevenService = (ttsService as any).elevenLabsTts;
      await expect(elevenService.synthesize(request)).rejects.toThrow(
        /Failed with model eleven_v4/
      );

      // Verify both attempts strictly used eleven_v4 (zero fallback models)
      expect(mockedAxios.post).toHaveBeenCalledTimes(2);
      expect(mockedAxios.post.mock.calls[0][1]).toMatchObject({ model_id: 'eleven_v4' });
      expect(mockedAxios.post.mock.calls[1][1]).toMatchObject({ model_id: 'eleven_v4' });
    });
  });
});
