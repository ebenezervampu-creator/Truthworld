import { videoGatewayService, estimateEnglishPercentage } from '../../src/pipeline/services/videoGatewayService';
import { EdgeLayer } from '../../src/pipeline/layers/01-edge';
import { ExecutionPlan } from '../../src/pipeline/types';

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
                      detectedLanguage: 'en',
                      englishPercentage: 95,
                      status: 'APPROVED',
                      violatingPolicies: [],
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

describe('Language Enforcement (Phase 1: 90% Primary English / 10% Secondary Allowance)', () => {
  const dummyExecutionPlan: ExecutionPlan = {
    jobId: 'job_test_lang_123',
    videoId: 'video_test_lang_123',
    languages: ['en'],
    primaryLanguage: 'en',
    enablePath1: false,
    enablePath2: false,
    enableTruthEngine: false,
    enableReachEngine: false,
    enableAuxiliary: false,
    dubbingMode: 'none',
    generateDubbing: false,
    genLangSubs: false,
    channelType: 'standard',
    maxClaims: 10,
    priority: 'normal',
    skipCache: false,
  };

  describe('VideoGatewayService Spoken Language Policy (90/10 Rule)', () => {
    it('1. Strictly REJECTS Telugu ("te") videos immediately with UNSUPPORTED_LANGUAGE policy', async () => {
      const decision = await videoGatewayService.evaluateVideo(
        'job_telugu_1',
        'నమస్కారం, ఇది తెలుగు వీడియో వివరణ.',
        [],
        dummyExecutionPlan,
        'te' // Telugu detected
      );

      expect(decision.status).toBe('REJECTED');
      expect(decision.rejectionReason).toContain('Truthworld currently only supports English channels and content');
      expect(decision.rejectionReason).toContain('TE');
      expect(decision.violatingPolicies).toContain('UNSUPPORTED_LANGUAGE');
    });

    it('2. Strictly REJECTS Telugu when passed as full name ("telugu" or "Telugu")', async () => {
      const decision = await videoGatewayService.evaluateVideo(
        'job_telugu_2',
        'తెలుగు వార్తలు మరియు సమాచారం.',
        [],
        dummyExecutionPlan,
        'Telugu'
      );

      expect(decision.status).toBe('REJECTED');
      expect(decision.rejectionReason).toContain('Truthworld currently only supports English channels and content');
      expect(decision.violatingPolicies).toContain('UNSUPPORTED_LANGUAGE');
    });

    it('3. Strictly REJECTS Hindi ("hi"), Spanish ("es"), and other non-English languages when < 90% English', async () => {
      for (const lang of ['hi', 'es', 'fr', 'ta', 'kn', 'bn']) {
        const decision = await videoGatewayService.evaluateVideo(
          `job_${lang}`,
          'Non-English video sample transcript',
          [],
          dummyExecutionPlan,
          lang
        );

        expect(decision.status).toBe('REJECTED');
        expect(decision.violatingPolicies).toContain('UNSUPPORTED_LANGUAGE');
      }
    });

    it('4. Rejects when executionPlan primaryLanguage is Telugu even if detectedLanguage is undefined', async () => {
      const teluguPlan: ExecutionPlan = {
        ...dummyExecutionPlan,
        primaryLanguage: 'te',
      };

      const decision = await videoGatewayService.evaluateVideo(
        'job_telugu_plan',
        'Telugu audio transcription content',
        [],
        teluguPlan
      );

      expect(decision.status).toBe('REJECTED');
      expect(decision.violatingPolicies).toContain('UNSUPPORTED_LANGUAGE');
    });

    it('5. ALLOWS Ground News English videos (>90% English) that include short <=10% Hindi or Telugu street interviews', async () => {
      const groundNewsTranscript =
        'Hello everyone and welcome back to our ground news report from New Delhi. ' +
        'Today we are investigating the impact of the new solar grid infrastructure on local shopkeepers and daily commuters across the city. ' +
        'We spoke with a resident at the market who told us in Hindi: "यह बिजली बहुत अच्छी है" ' +
        'which means this new power system is working very well for their small business. ' +
        'Let us now examine the official energy ministry data and see how grid stability has improved over the last six months.';

      const pct = estimateEnglishPercentage(groundNewsTranscript, 'en');
      expect(pct).toBeGreaterThanOrEqual(90);

      const decision = await videoGatewayService.evaluateVideo(
        'job_ground_news_en_hi',
        groundNewsTranscript,
        [],
        dummyExecutionPlan,
        'en'
      );

      expect(decision.status).toBe('APPROVED');
      expect(decision.violatingPolicies).not.toContain('UNSUPPORTED_LANGUAGE');
    });

    it('6. REJECTS mixed videos where non-English exceeds 10% (e.g., 50% English / 50% Telugu)', async () => {
      const halfTeluguTranscript =
        'Hello everyone welcome to our video today we are talking about news. ' +
        'ఈరోజు మనం హైదరాబాద్ లోని కొత్త మెట్రో రైలు గురించి మాట్లాడుకుంటున్నాము మరియు ప్రజల అభిప్రాయాలు తెలుసుకుంటున్నాము.';

      const pct = estimateEnglishPercentage(halfTeluguTranscript, 'en');
      expect(pct).toBeLessThan(90);

      const decision = await videoGatewayService.evaluateVideo(
        'job_half_telugu',
        halfTeluguTranscript,
        [],
        dummyExecutionPlan,
        'en'
      );

      expect(decision.status).toBe('REJECTED');
      expect(decision.violatingPolicies).toContain('UNSUPPORTED_LANGUAGE');
    });
  });

  describe('EdgeLayer Video Submission Gate', () => {
    const edgeLayer = new EdgeLayer();

    beforeAll(() => {
      jest.spyOn(edgeLayer as any, 'persistJobAsync').mockImplementation(() => {});
      jest.spyOn((edgeLayer as any).distribution, 'publish').mockResolvedValue('mock-msg-id');
    });

    it('7. Strictly rejects video submission if primaryLanguage is Telugu ("te")', async () => {
      const res = await edgeLayer.submitVideo(
        'user_123',
        'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/v1/original.mp4',
        'sample_telugu.mp4',
        {
          primaryLanguage: 'te',
          channelType: 'standard',
        }
      );

      expect(res.status).toBe('rejected');
      expect(res.message).toContain('Truthworld currently only supports English content');
    });

    it('8. Accepts video submission when primaryLanguage is English ("en")', async () => {
      const res = await edgeLayer.submitVideo(
        'user_123',
        'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/v1/original.mp4',
        'sample_english.mp4',
        {
          primaryLanguage: 'en',
          channelType: 'standard',
        }
      );

      expect(res.status).toBe('accepted');
      expect(res.jobId).toBeDefined();
    });
  });
});
