import { DeterministicRegistryService } from '../../src/pipeline/services/deterministicRegistry';
import { tier0KnowledgeService } from '../../src/pipeline/services/tier0Knowledge';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { sourceTrustService } from '../../src/pipeline/services/sourceTrustService';
import { ScoringEngine } from '../../src/pipeline/services/scoringEngine';
import {
  normalizeClaimText,
  semanticCanonicalizeClaim,
  hashSemanticClaimText,
} from '../../src/pipeline/utils/claim-normalization';
import { ClaimNature, FramingStyle, VerifiedClaim, ClaimStatus, VerificationState } from '../../src/pipeline/types';
import { formatOpinionReasoning } from '../../src/pipeline/utils/opinion-formatting';

describe('Unit: 10-Claim End-to-End Fact-Checking & Credibility Pipeline Verification', () => {
  const verificationService = new ClaimVerificationService('test-api-key', 0.6);
  const scoringEngine = new ScoringEngine();

  const TEN_CLAIMS = [
    {
      id: 'claim_01',
      text: 'The speed of light in a vacuum is 299,792,458 meters per second.',
      domain: 'Physics',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.BALANCED,
      expectedVerdict: 'verified_true',
      expectedTier: 'A',
    },
    {
      id: 'claim_02',
      text: 'Smoking causes lung cancer and heart disease.',
      domain: 'Health',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.BALANCED,
      expectedVerdict: 'verified_true',
      expectedTier: 'A',
    },
    {
      id: 'claim_03',
      text: 'Antibiotics cure the common cold.',
      domain: 'Health',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.ABSOLUTE,
      expectedVerdict: 'false_claim',
      expectedTier: 'A',
    },
    {
      id: 'claim_04',
      text: 'The capital of France is Paris.',
      domain: 'Geography',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.BALANCED,
      expectedVerdict: 'verified_true',
      expectedTier: 'A',
    },
    {
      id: 'claim_05',
      text: 'Apollo 11 landed on the moon in 1969.',
      domain: 'History',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.BALANCED,
      expectedVerdict: 'verified_true',
      expectedTier: 'A',
    },
    {
      id: 'claim_06',
      text: 'The Earth is flat.',
      domain: 'Science',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.ABSOLUTE,
      expectedVerdict: 'false_claim',
      expectedTier: 'A',
    },
    {
      id: 'claim_07',
      text: "Earth's atmosphere is approximately 78% nitrogen and 21% oxygen.",
      domain: 'Earth Science',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.BALANCED,
      expectedVerdict: 'verified_true',
      expectedTier: 'A',
    },
    {
      id: 'claim_08',
      text: 'According to village elder oral tradition and local folklore, chieftain Kael defended the valley in 1640.',
      domain: 'History',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.BALANCED,
      expectedVerdict: 'not_historically_verifiable',
      expectedTier: 'N/A',
    },
    {
      id: 'claim_09',
      text: 'Breaking news: new bioRxiv preprint reports room-temperature ambient pressure superconductivity in compound LK-99B.',
      domain: 'Physics',
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.ASSERTIVE,
      expectedVerdict: 'disputed',
      expectedTier: 'C',
    },
    {
      id: 'claim_10',
      text: 'I personally think jazz is the greatest musical genre ever created.',
      domain: 'Culture',
      nature: ClaimNature.OPINION,
      framing: FramingStyle.ABSOLUTE,
      expectedVerdict: 'opinion_claim',
      expectedTier: 'N/A',
    },
  ];

  it('evaluates all 10 claims with 100% accuracy across all verification layers and aggregates institutional scoring', async () => {
    const verifiedClaims: VerifiedClaim[] = [];

    for (const item of TEN_CLAIMS) {
      const normalized = normalizeClaimText(item.text);
      const canonical = semanticCanonicalizeClaim(item.text);
      const semanticHash = hashSemanticClaimText(item.text);

      expect(normalized.length).toBeGreaterThan(0);
      expect(canonical.length).toBeGreaterThan(0);
      expect(semanticHash).toMatch(/^[a-f0-9]{64}$/);

      const { toVerify, opinions } = verificationService.classifyClaims([
        {
          text: item.text,
          nature: item.nature,
          framing: item.framing,
          confidence: 0.95,
          importance: 0.8,
          chunkIndex: 0,
          start: 0,
          end: 5000,
        },
      ]);

      const isOpinionRouted = opinions.length > 0 && toVerify.length === 0;
      const scarcityCheck = verificationService.detectDigitalArchivalScarcity(item.text, item.domain);
      const frontierCheck = verificationService.detectFrontierOrBreakingEvent(item.text);

      let status: ClaimStatus = 'inconclusive';
      let confidence = 0.0;
      let reasoning = '';
      let sourceTitle = 'N/A';
      let sourceUrl = 'N/A';
      let sourceTier = 'N/A';

      // Tier 2: the deterministic registry rules only on whole sentences it understands,
      // comparing the stated value with the reference value.
      const detMatch = DeterministicRegistryService.resolveDeterministicFact(item.text);
      const t0Match = tier0KnowledgeService.lookupPreIndexedFact(item.text);

      if (isOpinionRouted) {
        status = 'opinion_claim';
        confidence = 1.0;
        reasoning = formatOpinionReasoning(item.text);
      } else if (detMatch) {
        status = detMatch.status;
        confidence = detMatch.confidence;
        reasoning = detMatch.reasoning;
        sourceTitle = detMatch.source;
        sourceUrl = detMatch.url;
        sourceTier = detMatch.tier;
      } else if (t0Match) {
        status = t0Match.status;
        confidence = t0Match.confidence;
        reasoning = t0Match.reasoning;
        sourceTitle = t0Match.source;
        sourceUrl = t0Match.url;
        sourceTier = sourceTrustService.resolveSourceTrust(t0Match.url, item.domain).tier;
      } else if (scarcityCheck.isScarcity) {
        const crossExam = await verificationService.crossExamineClaim(
          item.text,
          'false_claim',
          'No digital web search results found in English repositories',
          [],
          item.domain
        );
        status = crossExam.adjudicatedStatus;
        confidence = 0.85;
        reasoning = crossExam.consensusMetadata.adjudicationRationale || '';
      } else if (frontierCheck.isFrontier) {
        (verificationService as any).genAI = {
          getGenerativeModel: () => ({
            generateContent: async () => ({
              response: {
                candidates: [
                  {
                    content: {
                      parts: [
                        {
                          text: JSON.stringify({
                            secondaryVerdict: 'DISPUTED',
                            concursWithPrimary: false,
                            adjudicationRationale:
                              'Preliminary bioRxiv preprint lacks independent peer-reviewed replication.',
                          }),
                        },
                      ],
                    },
                  },
                ],
              },
            }),
          }),
        };
        const crossExam = await verificationService.crossExamineClaim(
          item.text,
          'verified_true',
          'Preprint uploaded by initial laboratory team',
          [],
          item.domain
        );
        status = crossExam.adjudicatedStatus;
        confidence = 0.80;
        reasoning = crossExam.consensusMetadata.adjudicationRationale || '';
        sourceTitle = 'bioRxiv Preprint Server';
        sourceUrl = 'https://www.biorxiv.org';
        sourceTier = 'C';
      }

      expect(status).toBe(item.expectedVerdict);
      expect(sourceTier).toBe(item.expectedTier);
      expect(confidence).toBeGreaterThanOrEqual(0.8);

      verifiedClaims.push({
        claimId: item.id,
        text: item.text,
        nature: item.nature,
        framing: item.framing,
        confidence: 0.95,
        importance: 0.8,
        chunkIndex: 0,
        start: 0,
        end: 5000,
        status,
        verificationConfidence: confidence,
        reasoning,
        sources: sourceTitle !== 'N/A' ? [sourceTitle] : [],
        richSources:
          sourceUrl !== 'N/A'
            ? [
                {
                  title: sourceTitle,
                  url: sourceUrl,
                  domain: sourceUrl.replace(/^https?:\/\/(www\.)?/, '').split('/')[0],
                  tier: sourceTier as any,
                  snippet: reasoning,
                },
              ]
            : [],
        isGrounded: sourceUrl !== 'N/A',
        isFramingViolation: opinions[0]?.isFramingViolation || toVerify[0]?.isFramingViolation || false,
      });
    }

    const aggregateResult = scoringEngine.calculateInstitutionalTrustScore(
      'video_test_10_claims',
      'user_test_runner',
      { text: TEN_CLAIMS.map((c) => c.text).join(' '), utterances: [] } as any,
      verifiedClaims,
      TEN_CLAIMS.length,
      'balanced',
      'medium',
      'General',
      {}
    );

    expect(aggregateResult.analysisState).toBe(VerificationState.VERIFIED);
    expect(aggregateResult.factCheckStats.totalClaims).toBe(10);
    expect(aggregateResult.factCheckStats.verified_true).toBe(5);
    expect(aggregateResult.factCheckStats.false_claim).toBe(2);
    expect(aggregateResult.factCheckStats.disputed).toBe(1);
    expect(aggregateResult.factCheckStats.religious_belief).toBe(1); // not_historically_verifiable bucket
    expect(aggregateResult.factCheckStats.opinion_claim).toBe(1);
  });

  // The earlier keyword lookup marked these as verified because they mention a known topic.
  // The fast tiers must now leave them to grounded verification (or call out the wrong value).
  it.each([
    ['The capital of India is Kolkata', 'false_claim'],
    ['The capital of Japan is Kyoto', 'false_claim'],
    ['The speed of light in a vacuum is 100 kilometres per hour', 'false_claim'],
    ['The boiling point of water at sea level is 50 degrees', 'false_claim'],
    ['Water boils at 100 degrees on Mount Everest', 'false_claim'],
    ['Apollo 11 landed on the moon in 1972', 'false_claim'],
    ['The United Nations was founded in 1950', 'false_claim'],
    ['Apollo 11 was faked in a studio in 1969', null],
    ['Apollo 11 landed on Mars', null],
    ['Smoking cigarettes prevents heart disease and cancer', null],
    ['The United Nations was founded in 1945 by Hitler', null],
    ['Antibiotics treat bacterial infections that follow the flu', null],
    ['Turmeric does not cure cancer', null],
    ['The flat earth theory is a myth', null],
    ['Earth is a sphere that orbits the planet Mars', null],
    ['DNA is a triple helix', null],
    ['Delhi is the capital of India since 1600', null],
    ['Clinical research proves tobacco smoking causes lung cancer and heart disease.', null],
  ])('fast tiers do not verify "%s" (expected %s)', (text, expected) => {
    const det = DeterministicRegistryService.resolveDeterministicFact(text);
    expect(det?.status ?? null).toBe(expected);
    expect(det?.status).not.toBe('verified_true');
    const t0 = tier0KnowledgeService.lookupPreIndexedFact(text);
    expect(t0?.status).not.toBe('verified_true');
  });
});
