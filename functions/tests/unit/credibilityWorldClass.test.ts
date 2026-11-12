import { BridgingConsensusEngine, ContributorRating } from '../../src/pipeline/services/bridgingAlgorithm';
import { Tier0KnowledgeService, tier0KnowledgeService } from '../../src/pipeline/services/tier0Knowledge';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';

describe('Unit: World-Class Credibility Architecture', () => {
  describe('Milestone 1 & 4: Tier-0 Pre-Indexed High-Velocity Knowledge Base', () => {
    it('synchronously resolves universal physical constants without live search latency', () => {
      const matchSpeedOfLight = tier0KnowledgeService.lookupPreIndexedFact('The speed of light in a vacuum is 299,792,458 meters per second');
      expect(matchSpeedOfLight).not.toBeNull();
      expect(matchSpeedOfLight?.matched).toBe(true);
      expect(matchSpeedOfLight?.status).toBe('verified_true');
      expect(matchSpeedOfLight?.domain).toBe('nist.gov');
      expect(matchSpeedOfLight?.confidence).toBeGreaterThanOrEqual(0.95);

      const matchWater = tier0KnowledgeService.lookupPreIndexedFact('Pure water freezes at 0 degrees and boils at 100 degrees Celsius');
      expect(matchWater).not.toBeNull();
      expect(matchWater?.matched).toBe(true);
      expect(matchWater?.status).toBe('verified_true');
    });

    it('synchronously resolves established medical & health consensus', () => {
      const matchVaccines = tier0KnowledgeService.lookupPreIndexedFact('Vaccines work by stimulating the immune system to produce antibodies');
      expect(matchVaccines).not.toBeNull();
      expect(matchVaccines?.matched).toBe(true);
      expect(matchVaccines?.status).toBe('verified_true');
      expect(matchVaccines?.domain).toBe('who.int');

      const matchSmoking = tier0KnowledgeService.lookupPreIndexedFact('Clinical research proves smoking causes lung cancer');
      expect(matchSmoking).not.toBeNull();
      expect(matchSmoking?.matched).toBe(true);
      expect(matchSmoking?.status).toBe('verified_true');
      expect(matchSmoking?.domain).toBe('cdc.gov');

      const matchAntibioticsViral = tier0KnowledgeService.lookupPreIndexedFact('Antibiotics are effective against viral infections and the common cold');
      expect(matchAntibioticsViral).not.toBeNull();
      expect(matchAntibioticsViral?.matched).toBe(true);
      expect(matchAntibioticsViral?.status).toBe('false_claim');
    });

    it('returns null for localized, contested, or novel claims to enforce full pipeline verification', () => {
      const novelClaim = 'The local county approved a 50 million dollar municipal stadium in May 2026';
      const match = tier0KnowledgeService.lookupPreIndexedFact(novelClaim);
      expect(match).toBeNull();
    });
  });

  describe('Milestone 3: Sparse-Graph Cold Start in Bridging Consensus', () => {
    it('achieves provisional consensus with N=2 trusted raters with unanimous positive consensus', () => {
      const ratings: ContributorRating[] = [
        {
          ratingId: 'r1',
          contributorId: 'u1',
          isHelpful: true,
          contributorPolarity: -0.4,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 30000,
        },
        {
          ratingId: 'r2',
          contributorId: 'u2',
          isHelpful: true,
          contributorPolarity: 0.5,
          contributorReputationTier: 'Active',
          timestamp: Date.now() - 20000,
        },
      ];

      const result = BridgingConsensusEngine.evaluateDispute('disp_cold_1', ratings);
      expect(result.status).toBe('consensus_achieved');
      expect(result.isProvisional).toBe(true);
      expect(result.totalRatings).toBe(2);
      expect(result.confidenceScore).toBeGreaterThan(0.2);
    });

    it('achieves provisional rejection when N=2 trusted raters unanimously reject dispute', () => {
      const ratings: ContributorRating[] = [
        {
          ratingId: 'r1',
          contributorId: 'u1',
          isHelpful: false,
          contributorPolarity: -0.3,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 30000,
        },
        {
          ratingId: 'r2',
          contributorId: 'u2',
          isHelpful: false,
          contributorPolarity: 0.4,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 20000,
        },
      ];

      const result = BridgingConsensusEngine.evaluateDispute('disp_cold_2', ratings);
      expect(result.status).toBe('rejected_polarized');
      expect(result.isProvisional).toBe(true);
      expect(result.totalRatings).toBe(2);
    });

    it('holds status as pending_ratings when cold-start raters are unverified or split', () => {
      const splitRatings: ContributorRating[] = [
        {
          ratingId: 'r1',
          contributorId: 'u1',
          isHelpful: true,
          contributorPolarity: -0.5,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 30000,
        },
        {
          ratingId: 'r2',
          contributorId: 'u2',
          isHelpful: false,
          contributorPolarity: 0.5,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 20000,
        },
      ];

      const splitResult = BridgingConsensusEngine.evaluateDispute('disp_cold_split', splitRatings);
      expect(splitResult.status).toBe('pending_ratings');
      expect(splitResult.isProvisional).toBe(false);

      const unverifiedRatings: ContributorRating[] = [
        {
          ratingId: 'r3',
          contributorId: 'u3',
          isHelpful: true,
          contributorPolarity: -0.1,
          contributorReputationTier: 'Unverified',
          timestamp: Date.now() - 30000,
        },
        {
          ratingId: 'r4',
          contributorId: 'u4',
          isHelpful: true,
          contributorPolarity: 0.1,
          contributorReputationTier: 'New',
          timestamp: Date.now() - 20000,
        },
      ];

      const unverifiedResult = BridgingConsensusEngine.evaluateDispute('disp_cold_unverified', unverifiedRatings);
      expect(unverifiedResult.status).toBe('pending_ratings');
    });

    it('executes full harmonic bridging when N >= 5', () => {
      const matureRatings: ContributorRating[] = [
        {
          ratingId: 'r1',
          contributorId: 'u1',
          isHelpful: true,
          contributorPolarity: -0.7,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 60000,
        },
        {
          ratingId: 'r2',
          contributorId: 'u2',
          isHelpful: true,
          contributorPolarity: -0.4,
          contributorReputationTier: 'Active',
          timestamp: Date.now() - 50000,
        },
        {
          ratingId: 'r3',
          contributorId: 'u3',
          isHelpful: true,
          contributorPolarity: 0.0,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 40000,
        },
        {
          ratingId: 'r4',
          contributorId: 'u4',
          isHelpful: true,
          contributorPolarity: 0.5,
          contributorReputationTier: 'Active',
          timestamp: Date.now() - 30000,
        },
        {
          ratingId: 'r5',
          contributorId: 'u5',
          isHelpful: true,
          contributorPolarity: 0.8,
          contributorReputationTier: 'Trusted',
          timestamp: Date.now() - 20000,
        },
      ];

      const matureResult = BridgingConsensusEngine.evaluateDispute('disp_mature', matureRatings);
      expect(matureResult.status).toBe('consensus_achieved');
      expect(matureResult.isProvisional).toBe(false);
      expect(matureResult.bridgingScore).toBeGreaterThanOrEqual(0.60);
      expect(matureResult.perspectiveDivergence).toBeGreaterThan(0.5);
    });
  });

  describe('Milestone 2: Multi-Model Cross-Examination Engine', () => {
    const verificationService = new ClaimVerificationService('test-api-key');

    it('skips redundant cross-examination on low-stakes non-sensitive claims', async () => {
      const res = await verificationService.crossExamineClaim(
        'The movie was released in 1999',
        'verified_true',
        'IMDb and film registries corroborate release date',
        [],
        'entertainment'
      );

      expect(res.consensusMetadata.checked).toBe(false);
      expect(res.consensusMetadata.agreed).toBe(true);
      expect(res.adjudicatedStatus).toBe('verified_true');
    });

    it('de-escalates high-severity claims to disputed when secondary model detects conflict', async () => {
      // Mock genAI model generateContent
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      secondaryVerdict: 'DISPUTED',
                      concursWithPrimary: false,
                      adjudicationRationale: 'Multiple peer-reviewed studies show nuanced conflicting outcomes rather than absolute falsehood.',
                    }),
                  },
                ],
              },
            },
          ],
        },
      });

      (verificationService as any).genAI = {
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: mockGenerateContent,
        }),
      };

      const res = await verificationService.crossExamineClaim(
        'New diet protocol reduces metabolic disorder risk by 40%',
        'false_claim',
        'Single clinical trial was underpowered',
        [],
        'health'
      );

      expect(res.consensusMetadata.checked).toBe(true);
      expect(res.consensusMetadata.agreed).toBe(false);
      expect(res.adjudicatedStatus).toBe('disputed');
      expect(res.publicNote).toContain('Multi-model cross-examination revealed conflicting evidence');
    });

    it('confirms primary verdict when secondary model concurs', async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      secondaryVerdict: 'CONFIRMED_FALSE',
                      concursWithPrimary: true,
                      adjudicationRationale: 'Comprehensive consensus across WHO and CDC confirms this assertion is false.',
                    }),
                  },
                ],
              },
            },
          ],
        },
      });

      (verificationService as any).genAI = {
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: mockGenerateContent,
        }),
      };

      const res = await verificationService.crossExamineClaim(
        'Consuming bleach cures viral respiratory infections',
        'false_claim',
        'Toxic substance contraindicated by all medical health authorities',
        [],
        'health'
      );

      expect(res.consensusMetadata.checked).toBe(true);
      expect(res.consensusMetadata.agreed).toBe(true);
      expect(res.adjudicatedStatus).toBe('false_claim');
      expect(res.consensusMetadata.secondaryVerdict).toBe('CONFIRMED_FALSE');
    });
  });

  describe('Area 1: Digital & Archival Availability Bias Guard', () => {
    const verificationService = new ClaimVerificationService('test-api-key');

    it('identifies unindexed regional, oral history, and vernacular folklore claims', () => {
      const oralClaim = 'According to village elder oral tradition and local folklore, the shrine was protected during the flood';
      const res = verificationService.detectDigitalArchivalScarcity(oralClaim);
      expect(res.isScarcity).toBe(true);
      expect(res.reason).toContain('oral');

      const nonScarcityClaim = 'Federal Reserve raised benchmark interest rates by 25 basis points in 2023';
      const nonRes = verificationService.detectDigitalArchivalScarcity(nonScarcityClaim);
      expect(nonRes.isScarcity).toBe(false);
    });

    it('de-escalates unindexed oral history from false_claim to not_historically_verifiable to prevent digital availability bias', async () => {
      const oralClaim = 'Local tribal lore and folk songs state that chieftain Kael defended the valley in 1640';
      const res = await verificationService.crossExamineClaim(
        oralClaim,
        'false_claim',
        'No digital web search results found on Google or Wikipedia',
        [], // Zero hard counter-proof
        'history'
      );

      expect(res.adjudicatedStatus).toBe('not_historically_verifiable');
      expect(res.publicNote).toContain('Digital Archival Scarcity');
      expect(res.consensusMetadata.checked).toBe(true);
      expect(res.consensusMetadata.agreed).toBe(false);
    });
  });

  describe('Area 2: Emerging Science & Frontier Events (Epistemic Humility)', () => {
    const verificationService = new ClaimVerificationService('test-api-key');

    it('detects preprints, early Phase 1 trials, and breaking news signals', () => {
      const preprintClaim = 'Breaking news: new bioRxiv preprint reports in vitro efficacy of novel compound XYZ-99';
      const res = verificationService.detectFrontierOrBreakingEvent(preprintClaim);
      expect(res.isFrontier).toBe(true);
      expect(res.reason).toBeDefined();

      const establishedClaim = 'Water molecules consist of two hydrogen atoms and one oxygen atom';
      const nonRes = verificationService.detectFrontierOrBreakingEvent(establishedClaim);
      expect(nonRes.isFrontier).toBe(false);
    });

    it('enforces epistemic humility on developing frontier science, de-escalating to disputed', async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      secondaryVerdict: 'DISPUTED',
                      concursWithPrimary: false,
                      adjudicationRationale: 'Preprint results are preliminary and not yet peer-reviewed across multi-center cohorts.',
                    }),
                  },
                ],
              },
            },
          ],
        },
      });

      (verificationService as any).genAI = {
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: mockGenerateContent,
        }),
      };

      const frontierClaim = 'New Phase 1 trial preprint claims room-temperature ambient pressure superconductivity';
      const res = await verificationService.crossExamineClaim(
        frontierClaim,
        'verified_true',
        'Authors published laboratory preprint yesterday',
        [],
        'physics'
      );

      expect(res.adjudicatedStatus).toBe('disputed');
      expect(res.publicNote).toContain('Frontier / Breaking Event');
      expect(res.publicNote).toContain('epistemic humility');
    });

    it('preserves verified_true on breaking news events when supported by 2+ Tier A/B accredited sources', async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      secondaryVerdict: 'CONFIRMED_TRUE',
                      concursWithPrimary: true,
                      adjudicationRationale: 'Multiple accredited regional news outlets confirm police and hospital records.',
                    }),
                  },
                ],
              },
            },
          ],
        },
      });

      (verificationService as any).genAI = {
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: mockGenerateContent,
        }),
      };

      const breakingClaim = 'Breaking news: 15-year-old girl attacked with chainsaw in classroom';
      const sources: any[] = [
        {
          title: 'The Statesman - Andhra school chainsaw attack',
          url: 'https://thestatesman.com/article1',
          tier: 'B',
        },
        {
          title: 'The Hans India - Chainsaw attack on girl in AP classroom',
          url: 'https://thehansindia.com/article2',
          tier: 'B',
        },
      ];

      const res = await verificationService.crossExamineClaim(
        breakingClaim,
        'verified_true',
        'Corroborated by police statements and regional news coverage',
        sources,
        'news'
      );

      expect(res.adjudicatedStatus).toBe('verified_true');
      expect(res.consensusMetadata.agreed).toBe(true);
    });
  });

  describe('Area 3: Human Ombudsman Governance (Quorum & Cryptographic Audit Chain)', () => {
    it('computes cryptographic SHA-256 tamper-evident hash chaining and validates integrity', async () => {
      const { appealsDeskService } = await import('../../src/pipeline/services/appealsDeskService');

      // Test cryptographic hashing logic through class private accessor or validation
      const genesis = (appealsDeskService as any).computeAuditHash({
        previousHash: '0000000000000000000000000000000000000000000000000000000000000000',
        targetId: 'vid_test_1',
        action: 'appeal_submitted',
        performerId: 'user_123',
        timestamp: 1000000,
        payload: JSON.stringify({ appealStatus: 'submitted' }),
        rationale: 'Valid context provided',
      });

      expect(genesis).toMatch(/^[a-f0-9]{64}$/);

      const block2 = (appealsDeskService as any).computeAuditHash({
        previousHash: genesis,
        targetId: 'vid_test_1',
        action: 'appeal_first_review_recorded',
        performerId: 'ombudsman_1',
        timestamp: 1000100,
        payload: JSON.stringify({ interimStatus: 'under_secondary_review' }),
        rationale: 'Evidence verified',
      });

      expect(block2).toMatch(/^[a-f0-9]{64}$/);
      expect(block2).not.toBe(genesis);
    });
  });

  describe('Area 4: Clear 10-Year-Old Friendly Response Sanitizer & Cross-Lingual Grounding', () => {
    const verificationService = new ClaimVerificationService('test-api-key');

    it('cleans conversational first-person AI memories and archive jargon into simple everyday language', () => {
      const rawReasoning = "I looked through all my stories and general knowledge, but I couldn't find any common or famous story about a girl named Gopika being hurt with a chainsaw in a classroom. It's not something lots of people know about from my memory.";
      const cleaned = verificationService.sanitizeInstitutionalReasoning(rawReasoning, '15-year-old Gopika was attacked', 'inconclusive');
      
      expect(cleaned).not.toContain('from my memory');
      expect(cleaned).not.toContain('all my stories');
      expect(cleaned).not.toContain("I couldn't find");
      expect(cleaned.toLowerCase()).not.toContain('this claim');
      expect(cleaned.toLowerCase()).not.toContain('internal data');
      expect(cleaned).toContain('No trusted news reports or official records have been found yet to back this up.');
    });

    it('strips forbidden phrases ("this claim", "from internal data", "indexed institutional public archives")', () => {
      const archiveMsg = 'Authoritative corroboration could not be recovered from indexed institutional public archives.';
      const cleanedArchive = verificationService.sanitizeInstitutionalReasoning(archiveMsg, 'Some medical statement', 'inconclusive');
      expect(cleanedArchive).toBe('No clear outside sources or news reports were found to back this up yet.');
      expect(cleanedArchive.toLowerCase()).not.toContain('archives');

      const metaMsg = 'Based on internal data, this claim is not backed by studies, and no proof for this claim was published.';
      const cleanedMeta = verificationService.sanitizeInstitutionalReasoning(metaMsg, 'Some medical statement', 'inconclusive');
      expect(cleanedMeta.toLowerCase()).not.toContain('internal data');
      expect(cleanedMeta.toLowerCase()).not.toContain('this claim');
      expect(cleanedMeta).toContain('It is not backed by studies');
    });

    it('provides clear, simple confirmation when verified text was only AI memory chatter', () => {
      const rawReasoning = "from my memory I found some bits.";
      const cleaned = verificationService.sanitizeInstitutionalReasoning(rawReasoning, '15-year-old Gopika was attacked', 'verified_true');
      
      expect(cleaned).toContain('Official reports and trusted news stories back this up.');
    });
  });
});

