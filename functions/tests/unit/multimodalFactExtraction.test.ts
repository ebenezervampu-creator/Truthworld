import { FactExtractionService } from '../../src/pipeline/services/factExtraction';
import { normalizeToGcsUri } from '../../src/pipeline/utils/ai-utils';
import { transcriptionLayer } from '../../src/pipeline/layers/05-transcription';

jest.mock('../../src/pipeline/utils/ai-client', () => ({
  getVertexAI: jest.fn(() => ({
    getGenerativeModel: jest.fn(() => ({
      generateContent: jest.fn().mockImplementation((req: any) => {
        // Multi-modal media extraction mock or Google Speech mock
        return Promise.resolve({
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        detectedLanguage: 'te',
                        domain: 'Science',
                        stance: 'Explanatory',
                        cautionLevel: 'low',
                        isLaunchNews: false,
                        primaryIntent: 'educational',
                        isSensitive: false,
                        summary: 'Scientific analysis of solar eclipses explained in Telugu.',
                        text: 'సూర్య గ్రహణం సమయంలో చంద్రుడు భూమికి సూర్యునికి మధ్య వస్తాడు. అలెగ్జాండర్ ఫ్లెమింగ్ 1928 లో పెన్సిలిన్ కనుగొన్నారు.',
                        segments: [
                          {
                            index: 0,
                            start: 0,
                            end: 8000,
                            duration: 8000,
                            speaker: 'speaker_0',
                            text: 'సూర్య గ్రహణం సమయంలో చంద్రుడు భూమికి సూర్యునికి మధ్య వస్తాడు',
                          },
                          {
                            index: 1,
                            start: 8000,
                            end: 16000,
                            duration: 8000,
                            speaker: 'speaker_0',
                            text: 'అలెగ్జాండర్ ఫ్లెమింగ్ 1928 లో పెన్సిలిన్ కనుగొన్నారు',
                          }
                        ],
                        claims: [
                          {
                            text: 'సూర్య గ్రహణం సమయంలో చంద్రుడు భూమికి సూర్యునికి మధ్య వస్తాడు',
                            nature: 'VERIFIABLE_FACT',
                            framing: 'ASSERTIVE',
                            confidence: 0.98,
                            importance: 0.9,
                            isVerifiableEvent: true,
                            honestyWashingRisk: false,
                            assertiveness: 'confident',
                            claimStrength: 'strong',
                            start: 5000,
                            end: 12000,
                            speaker: 'Presenter'
                          },
                          {
                            text: 'Alexander Fleming discovered penicillin in 1928',
                            nature: 'VERIFIABLE_FACT',
                            framing: 'ASSERTIVE',
                            confidence: 0.99,
                            importance: 0.85,
                            isVerifiableEvent: true,
                            honestyWashingRisk: false,
                            assertiveness: 'confident',
                            claimStrength: 'strong',
                            start: 15000,
                            end: 22000,
                            speaker: 'Presenter'
                          }
                        ]
                      }),
                    },
                  ],
                },
              },
            ],
          },
        });
      }),
    })),
  })),
}));

describe('Multimodal Fact Extraction & Speech-to-Text Language Routing', () => {
  describe('normalizeToGcsUri URL normalizer', () => {
    it('preserves native gs:// URIs', () => {
      const uri = 'gs://truthworld-bucket/videos/test-123/original.mp4';
      expect(normalizeToGcsUri(uri)).toBe(uri);
    });

    it('converts Firebase Storage HTTPS download URLs to gs:// URIs', () => {
      const fbUrl = 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/videos%2Fjob-456%2Foriginal.mp4?alt=media&token=xyz';
      expect(normalizeToGcsUri(fbUrl)).toBe('gs://truthworld.appspot.com/videos/job-456/original.mp4');
    });

    it('converts Google Cloud Storage HTTPS URLs to gs:// URIs', () => {
      const gcsUrl = 'https://storage.googleapis.com/truthworld-media/videos/job-789/original.mp4';
      expect(normalizeToGcsUri(gcsUrl)).toBe('gs://truthworld-media/videos/job-789/original.mp4');
    });

    it('converts relative video paths to canonical bucket gs:// URIs', () => {
      const relPath = 'videos/job-101/original.mp4';
      const result = normalizeToGcsUri(relPath);
      expect(result).toMatch(/^gs:\/\/[^/]+\/videos\/job-101\/original\.mp4$/);
    });
  });

  describe('FactExtractionService.extractClaimsFromMedia', () => {
    it('extracts empirical claims directly from GCS media without requiring AssemblyAI transcripts', async () => {
      const service = new FactExtractionService('mock-api-key');
      const result = await service.extractClaimsFromMedia(
        'job_test_001',
        'gs://truthworld-media/videos/job_test_001/original.mp4',
        'video/mp4',
        'Solar Eclipse Facts in Telugu'
      );

      expect(result).toBeDefined();
      expect(result.claims.length).toBe(2);
      expect(result.claims[0].text).toContain('సూర్య గ్రహణం');
      expect(result.claims[0].nature).toBe('VERIFIABLE_FACT');
      expect(result.claims[1].text).toContain('Alexander Fleming');
      expect(result.domainInfo.detectedLanguage).toBe('te');
      expect(result.domainInfo.domain).toBe('Science');
      expect(result.summary).toContain('Telugu');
    });
  });

  describe('Google Cloud Speech-to-Text for non-Universal Pro languages', () => {
    it('uses Google Cloud Speech-to-Text for languages without Universal Pro in AssemblyAI (e.g. Telugu)', async () => {
      const result = await transcriptionLayer.transcribeWithGoogleSpeech(
        'job_telugu_stt',
        'user_test_1',
        'gs://truthworld-media/videos/job_telugu_stt/original.mp4',
        { primaryLanguage: 'te' } as any,
        'te'
      );

      expect(result).toBeDefined();
      expect(result.detectedLanguage).toBe('te');
      expect(result.text).toContain('సూర్య గ్రహణం');
      expect(result.segments.length).toBeGreaterThan(0);
      expect(result.segments[0].words.length).toBeGreaterThan(0);
    });
  });
});
