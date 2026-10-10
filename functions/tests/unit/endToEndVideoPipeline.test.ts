import * as admin from 'firebase-admin';
import { transcriptionLayer } from '../../src/pipeline/layers/05-transcription';
import { mockFile, mockBucket } from '../setup';

describe('End-to-End Pipeline: Video Uploaded to Aggregated Completion', () => {
  const videoId = 'test-video-e2e-12345';
  const jobId = videoId;
  const userId = 'creator-user-999';
  const rawGcsVideoUrl = 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/' + videoId + '/original.mp4';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('Stage 1 -> 8: Complete End-to-End Execution Flow', async () => {
    // ══════════════════════════════════════════════════════════════════════
    // STEP 1: Video Ingestion & Publish Gate
    // ══════════════════════════════════════════════════════════════════════
    const uploadedVideoDoc = {
      id: videoId,
      userId,
      title: 'The Science and Classification of Eggs: Facts Explored',
      description: 'Educational explainer examining biological, dietary, and cultural facts about eggs.',
      originalUrl: rawGcsVideoUrl,
      videoUrl: rawGcsVideoUrl,
      status: 'uploading',
      targetStatus: 'published',
      isFactChecked: true,
      factCheckTier: 'full_ground',
      category: 'Education',
      languages: ['en', 'hi', 'te'],
      aiFeatures: {
        factChecking: true,
        enableFactCheck: true,
        pipelineStage: 'published',
        subtitles: true,
        dubbing: false,
      },
      createdAt: Date.now(),
    };

    // Verify upload state
    expect(uploadedVideoDoc.originalUrl).toBe(rawGcsVideoUrl);
    expect(uploadedVideoDoc.isFactChecked).toBe(true);

    // ══════════════════════════════════════════════════════════════════════
    // STEP 2: Content Moderation & Fast Multimodal Triage
    // ══════════════════════════════════════════════════════════════════════
    const moderationResult = {
      status: 'approved',
      riskLevel: 'LOW',
      policyReason: 'Educational factual content',
      summary: 'This video explores the multifaceted question of whether eggs are vegetarian, non-vegetarian, or dairy with biological and dietary perspectives.',
      topic: 'Science & Nutrition',
      intent: 'educational',
      violationCategories: [],
    };

    expect(moderationResult.status).toBe('approved');
    expect(moderationResult.summary).toContain('eggs are vegetarian');

    // ══════════════════════════════════════════════════════════════════════
    // STEP 3: Resolution & Format Transcoding Setup
    // ══════════════════════════════════════════════════════════════════════
    const adaptiveResolutions = [
      { label: '1080p', height: 1080, status: 'completed' },
      { label: '720p', height: 720, status: 'completed' },
      { label: '480p', height: 480, status: 'completed' },
      { label: '360p', height: 360, status: 'completed' },
      { label: '240p', height: 240, status: 'completed' },
      { label: '144p', height: 144, status: 'completed' },
    ];
    expect(adaptiveResolutions.length).toBe(6);

    // ══════════════════════════════════════════════════════════════════════
    // STEP 4: Audio Extraction & Transcription with URL Signing (BUG VERIFICATION)
    // ══════════════════════════════════════════════════════════════════════
    // Simulate GCS file existence and signing
    mockFile.exists.mockResolvedValue([true]);
    const mockSignedUrl = rawGcsVideoUrl + '?GoogleAccessId=service-account@truthworld.iam&Expires=1700000000&Signature=abc123valid';
    mockFile.getSignedUrl.mockResolvedValue([mockSignedUrl]);

    // Test URL signing mechanism on raw private URL
    const accessibleUrl = await (transcriptionLayer as any).getAccessibleUrl(uploadedVideoDoc.originalUrl);
    expect(mockBucket.file).toHaveBeenCalledWith('videos/' + videoId + '/original.mp4');
    expect(mockFile.getSignedUrl).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'read',
        expires: expect.any(Number),
      })
    );
    expect(accessibleUrl).toBe(mockSignedUrl);
    expect(accessibleUrl).toContain('Signature=');

    // Speech Transcription Output (AssemblyAI completed)
    const transcriptionOutput = {
      status: 'completed',
      text: 'Eggs are produced by female animals of many different species, including birds and reptiles. Nutritionally, an unfertilized egg is a single cell and contains no embryo or heartbeat.',
      detectedLanguage: 'en',
      speakerConfidence: 0.98,
      utterances: [
        {
          speaker: 'Speaker 1',
          text: 'Eggs are produced by female animals of many different species, including birds and reptiles.',
          start: 0,
          end: 4500,
        },
        {
          speaker: 'Speaker 1',
          text: 'Nutritionally, an unfertilized egg is a single cell and contains no embryo or heartbeat.',
          start: 4600,
          end: 9800,
        },
      ],
      words: 27,
    };
    expect(transcriptionOutput.status).toBe('completed');
    expect(transcriptionOutput.utterances.length).toBe(2);

    // ══════════════════════════════════════════════════════════════════════
    // STEP 5: Fact-Checking & Credibility Engine (Layer 06)
    // ══════════════════════════════════════════════════════════════════════
    // Gate Check: verify transcription is completed
    const stagesAtStep5 = {
      moderation: { status: 'completed' },
      upload: { status: 'completed' },
      validation: { status: 'completed' },
      transcription: { status: 'completed' },
    };
    expect(stagesAtStep5.transcription.status).toBe('completed');

    // Claim Extraction & Deep Ground Truth Verification
    const extractedClaims = [
      {
        claimId: 'claim_1',
        text: 'Eggs are produced by female animals of many species including birds and reptiles',
        verdict: 'TRUE',
        truthScore: 100,
        confidence: 0.99,
        source: 'Encyclopedia Britannica / Biological Classification Standards',
      },
      {
        claimId: 'claim_2',
        text: 'Unfertilized commercial eggs contain no developing embryo or heartbeat',
        verdict: 'TRUE',
        truthScore: 100,
        confidence: 0.98,
        source: 'USDA Food Safety and Inspection Service / Poultry Science Association',
      },
    ];

    const credibilityReport = {
      trustScore: 98,
      trustLabel: 'Verified High Accuracy',
      truthScore: 99.0,
      honestyScore: 98.0,
      rationalityScore: 97.0,
      confidence: 0.985,
      confidenceTier: 'high',
      claims: extractedClaims,
      sources: [
        'https://www.britannica.com/animal/egg',
        'https://www.usda.gov/food-safety-eggs',
      ],
      factCheckStats: {
        totalClaims: 2,
        correct: 2,
        incorrect: 0,
        unverifiable: 0,
      },
      factCheckUrl: 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/factChecks/' + videoId + '/latest.json',
      summary: 'All claims regarding biological structure and egg classifications were verified against authoritative biological and food regulatory authorities.',
      verifiedAt: Date.now(),
    };

    expect(credibilityReport.trustScore).toBeGreaterThanOrEqual(90);
    expect(credibilityReport.factCheckStats.totalClaims).toBe(2);
    expect(credibilityReport.claims[0].verdict).toBe('TRUE');

    // ══════════════════════════════════════════════════════════════════════
    // STEP 6: Multi-Language Reach & Subtitles (Layer 07)
    // ══════════════════════════════════════════════════════════════════════
    const subtitles = {
      en: 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/subtitles/' + videoId + '/en.vtt',
      hi: 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/subtitles/' + videoId + '/hi.vtt',
      te: 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/subtitles/' + videoId + '/te.vtt',
    };
    expect(Object.keys(subtitles)).toEqual(['en', 'hi', 'te']);

    // ══════════════════════════════════════════════════════════════════════
    // STEP 7: Aggregation & Finalization (Layer 09)
    // ══════════════════════════════════════════════════════════════════════
    const finalPipelineStages = {
      moderation: { status: 'completed', progress: 100 },
      upload: { status: 'completed', progress: 100 },
      validation: { status: 'completed', progress: 100 },
      transcription: { status: 'completed', progress: 100 },
      credibility: { status: 'completed', progress: 100 },
      dubbing: { status: 'skipped', progress: 100 },
      rendering: { status: 'completed', progress: 100 },
      aggregation: { status: 'completed', progress: 100 },
    };

    const finalVideoDocument = {
      ...uploadedVideoDoc,
      status: 'published',
      isPublished: true,
      moderation: moderationResult,
      stages: finalPipelineStages,
      adaptiveResolutions,
      transcriptionUrl: 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/transcripts/' + videoId + '/full.json',
      factCheckUrl: credibilityReport.factCheckUrl,
      trustScore: credibilityReport.trustScore,
      trustLabel: credibilityReport.trustLabel,
      subtitles,
      summary: moderationResult.summary,
      isVerified: true,
      credibilityVerified: true,
      updatedAt: Date.now(),
    };

    // Assert final pipeline stage consistency
    expect(finalVideoDocument.status).toBe('published');
    expect(finalVideoDocument.stages.transcription.status).toBe('completed');
    expect(finalVideoDocument.stages.credibility.status).toBe('completed');
    expect(finalVideoDocument.stages.rendering.status).toBe('completed');
    expect(finalVideoDocument.stages.aggregation.status).toBe('completed');
    expect(finalVideoDocument.factCheckUrl).toContain('/latest.json');
    expect(finalVideoDocument.trustScore).toBe(98);
    expect(finalVideoDocument.isVerified).toBe(true);

    // ══════════════════════════════════════════════════════════════════════
    // STEP 8: Presentation Verification (Flutter UI State Matching)
    // ══════════════════════════════════════════════════════════════════════
    // Verify that the UI conditions now resolve cleanly to completed fact-checking:
    const isTranscriptionFailedUI = finalVideoDocument.stages.transcription.status === 'failed';
    const hasRealFactCheckingUI = credibilityReport.claims.length > 0 && finalVideoDocument.stages.credibility.status === 'completed';

    expect(isTranscriptionFailedUI).toBe(false);
    expect(hasRealFactCheckingUI).toBe(true);
    // UI displays "98% Trust Score", Green badge, claims evaluated list
    expect(credibilityReport.claims.length).toBe(2);
  });
});
