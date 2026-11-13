import { videoGatewayService } from '../../src/pipeline/services/videoGatewayService';
import { contentModerationService } from '../../src/pipeline/services/contentModerationService';
import { ExecutionPlan } from '../../src/pipeline/types';
import * as admin from 'firebase-admin';

jest.mock('../../src/pipeline/utils/ai-client', () => ({
  getVertexAI: jest.fn(() => ({
    getGenerativeModel: jest.fn(() => ({
      generateContent: jest.fn().mockImplementation((prompt: string) => {
        if (typeof prompt === 'string' && prompt.includes('INAPPROPRIATE_PROFANITY_TEST')) {
          return Promise.resolve({
            response: {
              candidates: [
                {
                  content: {
                    parts: [
                      {
                        text: JSON.stringify({
                          status: 'REJECTED',
                          rejectionReason: 'Contains severe profanity and inappropriate content.',
                          violatingPolicies: ['PROFANITY', 'HARASSMENT'],
                          summary: '',
                        }),
                      },
                    ],
                  },
                },
              ],
            },
          });
        }

        return Promise.resolve({
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        detectedLanguage: 'en',
                        status: 'APPROVED',
                        confidence: 0.95,
                        category: 'Science',
                        tags: ['education', 'science'],
                        summary: 'Google Cloud Vertex AI verified video content.',
                        violatingPolicies: [],
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

describe('Google Cloud Content Moderation (Decoupled from AssemblyAI Transcript)', () => {
  const dummyPlan: ExecutionPlan = {
    jobId: 'job_gcp_mod_1',
    videoId: 'video_gcp_mod_1',
    title: 'Exploring Deep Space Phenomena',
    description: 'An educational exploration of black holes and cosmology.',
    category: 'Science',
    tags: ['space', 'cosmology'],
    languages: ['en'],
    primaryLanguage: 'en',
    enableCredibility: false,
    factCheckEnabled: false,
    enableDubbing: false,
    enableSubtitles: false,
    enableAuxiliary: false,
    dubbingMode: 'none',
    generateDubbing: false,
    genLangSubs: false,
    channelType: 'standard',
    maxClaims: 10,
    priority: 'normal',
    skipCache: false,
  };

  it('1. Moderates video using Google Cloud tools without requiring an AssemblyAI transcript', async () => {
    // Empty transcript should NOT be sent to MANUAL_REVIEW
    const decision = await videoGatewayService.evaluateVideo(
      'job_no_transcript',
      '', // No transcript from AssemblyAI
      [],
      dummyPlan,
      'en'
    );

    expect(decision.status).toBe('APPROVED');
    expect(decision.category).toBe('Science');
    expect(decision.summary).toBeDefined();
    expect(decision.violatingPolicies).toHaveLength(0);
  });

  it('2. Correctly flags inappropriate video content without transcript dependency', async () => {
    const badPlan: ExecutionPlan = {
      ...dummyPlan,
      title: 'INAPPROPRIATE_PROFANITY_TEST title',
    };

    const decision = await videoGatewayService.evaluateVideo(
      'job_bad_video',
      '',
      [],
      badPlan,
      'en'
    );

    expect(decision.status).toBe('REJECTED');
    expect(decision.rejectionReason).toContain('profanity');
    expect(decision.violatingPolicies).toContain('PROFANITY');
  });

  it('3. Reuses existing Google Cloud Content Moderation approval from Firestore directly', async () => {
    const mockDocId = 'video_pre_moderated_gcp';
    const mockVideoDoc = {
      exists: true,
      data: () => ({
        title: 'Already Moderated Video',
        moderation: {
          status: 'approved',
          confidenceScore: 0.98,
          checkedAt: 1700000000000,
          summary: 'Pre-approved by Google Cloud Content Moderation Service via GCS URI.',
          category: 'Technology',
          model: 'gemini-2.5-flash',
        },
      }),
    };

    jest.spyOn(admin.firestore(), 'collection').mockReturnValue({
      doc: jest.fn().mockReturnValue({
        get: jest.fn().mockResolvedValue(mockVideoDoc),
      }),
    } as any);

    const plan: ExecutionPlan = {
      ...dummyPlan,
      videoId: mockDocId,
    };

    const decision = await videoGatewayService.evaluateVideo(
      'job_pre_moderated',
      '',
      [],
      plan,
      'en'
    );

    expect(decision.status).toBe('APPROVED');
    expect(decision.confidence).toBe(0.98);
    expect(decision.category).toBe('Technology');
    expect(decision.summary).toContain('Pre-approved by Google Cloud Content Moderation Service');
  });

  it('4. Approves family-friendly comedy sketches and arranged marriage content without false positive rejection', () => {
    const rawResult: any = {
      approved: false, // Model outputted false by mistake despite finding zero violations
      policyAction: 'allow',
      topic: 'ai and arranged marriage comedy',
      intent: 'entertainment',
      riskLevel: 'safe',
      confidenceScore: 0.95,
      policyReason: 'The video is a comedic narrative about arranged marriage and AI, delivered in a family-friendly manner without any violations of community guidelines.',
      explanation: 'The video tells a humorous story about a man using AI for arranged marriage, ultimately learning the importance of honesty and personal responsibility, with clean delivery.',
      violationCategories: [],
      summary: 'A funny story about AI and arranged marriage.',
      category: 'Comedy',
      detectedLanguage: 'te',
    };

    const decision = (contentModerationService as any).applyReviewPolicy(rawResult);
    expect(decision.approved).toBe(true);
    expect(decision.policyAction).toBe('allow');
  });

  it('5. Protects safe comedy videos even if model outputs policyAction: "reject" but risk is safe and 0 violation categories', () => {
    const rawContradiction: any = {
      approved: false,
      policyAction: 'reject', // Contradictory rejection output by model
      topic: 'ai and arranged marriage comedy',
      intent: 'entertainment',
      riskLevel: 'safe',
      confidenceScore: 0.95,
      policyReason: 'The video is a comedic narrative about arranged marriage and AI, delivered in a family-friendly manner without any violations of community guidelines.',
      explanation: 'The video tells a humorous story about a man using AI for arranged marriage, ultimately learning the importance of honesty and personal responsibility, with clean delivery.',
      violationCategories: [],
      summary: 'A funny story about AI and arranged marriage.',
      category: 'Comedy',
      detectedLanguage: 'te',
    };

    const decision = (contentModerationService as any).applyReviewPolicy(rawContradiction);
    expect(decision.approved).toBe(true);
    expect(decision.policyAction).toBe('allow');
  });

  it('6. Strictly REJECTS intense romantic/lustful content even if disguised under clean metadata and entertainment intent', () => {
    const lustfulVideo: any = {
      approved: false,
      policyAction: 'reject',
      topic: 'romance',
      intent: 'entertainment',
      riskLevel: 'high',
      confidenceScore: 0.92,
      policyReason: 'Visual frames show passionate deep kissing, sensual caressing on bed, and intimate physical contact violating family-friendly standards.',
      explanation: 'Intense romantic/lustful physical intimacy exceeds family-friendly decorum guidelines.',
      violationCategories: ['romantic_content'],
      summary: 'A romantic video featuring intimate physical scenes.',
      category: 'Entertainment',
      detectedLanguage: 'en',
    };

    const decision = (contentModerationService as any).applyReviewPolicy(lustfulVideo);
    expect(decision.approved).toBe(false);
    expect(decision.policyAction).toBe('reject');
  });

  it('7. Overrides and REJECTS romantic/sexual content even if model erroneously returned policyAction: "allow"', () => {
    const contradictoryLust: any = {
      approved: true,
      policyAction: 'allow', // Contradictory allow from model
      topic: 'romantic_drama',
      intent: 'entertainment',
      riskLevel: 'high',
      confidenceScore: 0.88,
      policyReason: 'Contains bedroom romance and passionate kissing.',
      explanation: 'Romantic clip from movie with physical intimacy.',
      violationCategories: ['romantic_content'],
      summary: 'Couple romance clip.',
      category: 'Entertainment',
      detectedLanguage: 'en',
    };

    const decision = (contentModerationService as any).applyReviewPolicy(contradictoryLust);
    expect(decision.approved).toBe(false);
    expect(['reject', 'manual_review']).toContain(decision.policyAction);
  });

  it('8. Enforces fail-closed: holds video in manual_review if moderation times out', async () => {
    const mockTimeoutModel = {
      generateContent: jest.fn().mockImplementation(() => {
        return new Promise((_, reject) => {
          setTimeout(() => reject(new Error('MODERATION_TIMEOUT')), 10);
        });
      }),
    };

    const service = contentModerationService as any;
    jest.spyOn(service, 'vertexAI', 'get').mockReturnValue({
      getGenerativeModel: jest.fn(() => mockTimeoutModel),
    });

    const result = await contentModerationService.moderate(
      'gs://truthworld-1.firebasestorage.app/videos/test_vid/original.mp4',
      'video/mp4',
      { title: 'My Love Story', description: 'Clean description', tags: ['love'] }
    );

    expect(result.approved).toBe(false);
    expect(result.policyAction).toBe('manual_review');
    expect(result.violationCategories).toContain('timeout_held_for_review');
  });

  it('9. Never allows video when policyReason reveals sensual/lustful intimacy despite clean metadata and allow action', () => {
    const sneakyLust: any = {
      approved: true,
      policyAction: 'allow',
      topic: 'love_story',
      intent: 'entertainment',
      riskLevel: 'low',
      confidenceScore: 0.65,
      policyReason: 'Couple shows passionate kissing and sensual bedroom intimacy in the video.',
      explanation: 'Delivery has romantic moments.',
      violationCategories: [],
      summary: 'Love story video.',
      category: 'Entertainment',
      detectedLanguage: 'en',
    };

    const decision = (contentModerationService as any).applyReviewPolicy(sneakyLust);
    expect(decision.approved).toBe(false);
    expect(decision.policyAction).toBe('manual_review');
  });
});
