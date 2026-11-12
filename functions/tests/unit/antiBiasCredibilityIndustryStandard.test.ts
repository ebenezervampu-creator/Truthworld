import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { RichSource, ClaimStatus } from '../../src/pipeline/types';
import { PIPELINE_CONFIG } from '../../src/pipeline/config';

describe('Unit: Industry-Standard Anti-Bias & 100% Rational Credibility System', () => {
  const verificationService = new ClaimVerificationService('test-key', 0.6);

  describe('Pillar 1: Humean Normative & Value-Judgment Firewall (Zero Ideological Censorship)', () => {
    it('detects normative statements, ethical positions, and policy trade-offs', () => {
      const claims = [
        'Raising the national minimum wage to $20 is the best economic policy for workers',
        'Capitalism is evil and inevitably concentrates wealth unfairly',
        'Taxation is theft and governments have no right to tax income',
        'Universal basic income is bad for human motivation and dignity',
        'This prime minister ruined the entire country and is the worst leader in history',
      ];

      for (const text of claims) {
        const detection = verificationService.detectNormativeOrPolicyDebate(text);
        expect(detection.isNormative).toBe(true);
        expect(detection.reason).toBeDefined();
      }
    });

    it('returns false for purely empirical testable assertions', () => {
      const empiricalClaims = [
        'The Federal Reserve raised interest rates by 25 basis points in July 2023',
        'Water freezes at 0 degrees Celsius at standard atmospheric pressure',
        'Global crude oil prices averaged $82 per barrel in 2023',
      ];

      for (const text of empiricalClaims) {
        const detection = verificationService.detectNormativeOrPolicyDebate(text);
        expect(detection.isNormative).toBe(false);
      }
    });

    it('blocks normative value judgments from being stamped as false_claim, enforcing contested_interpretation', async () => {
      const normativeClaim = 'Raising corporate tax rates is bad for society and destroys capital investment';
      
      const res = await verificationService.crossExamineClaim(
        normativeClaim,
        'false_claim', // A biased fact-checker or preliminary heuristic tried to mark it false
        'Economic studies from partisan think tank dispute the assertion',
        [],
        'finance'
      );

      // Must be intercepted by the normative firewall
      expect(res.adjudicatedStatus).toBe('contested_interpretation');
      expect(res.consensusMetadata.checked).toBe(true);
      expect(res.consensusMetadata.isNormativeValueJudgment).toBe(true);
      expect(res.publicNote).toContain('Normative / Policy Debate');
      expect(res.publicNote).toContain('Epistemic neutrality');
    });
  });

  describe('Pillar 2: Double-Blind Adjudication & Entity De-Biasing', () => {
    it('neutralizes polarizing political entities, leaders, and media brands into objective variables', () => {
      const trumpClaim = 'Donald Trump announced a new 10% tariff on imported consumer goods';
      const bidenClaim = 'Joe Biden signed executive orders regulating artificial intelligence models';
      const partyClaim = 'The Republican Party and Democratic Party reached a compromise on defense funding';
      const mediaClaim = 'Fox News and MSNBC reported contrasting narratives on the summit';

      const resTrump = verificationService.anonymizeClaimForObjectiveReview(trumpClaim);
      expect(resTrump.wasAnonymized).toBe(true);
      expect(resTrump.anonymizedClaim).toContain('[Political Leader A]');
      expect(resTrump.anonymizedClaim).not.toContain('Donald Trump');

      const resBiden = verificationService.anonymizeClaimForObjectiveReview(bidenClaim);
      expect(resBiden.wasAnonymized).toBe(true);
      expect(resBiden.anonymizedClaim).toContain('[Political Leader A]');
      expect(resBiden.anonymizedClaim).not.toContain('Joe Biden');

      const resParty = verificationService.anonymizeClaimForObjectiveReview(partyClaim);
      expect(resParty.wasAnonymized).toBe(true);
      expect(resParty.anonymizedClaim).toContain('[Party Beta]');
      expect(resParty.anonymizedClaim).toContain('[Party Alpha]');

      const resMedia = verificationService.anonymizeClaimForObjectiveReview(mediaClaim);
      expect(resMedia.wasAnonymized).toBe(true);
      expect(resMedia.anonymizedClaim).toContain('[Media Outlet]');
    });

    it('marks blindReviewApplied: true in consensus metadata when entity anonymization takes place', async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      steelManDefense: 'Empirical economic data shows quarterly trade deficit changes',
                      inquisitorChallenge: 'Import customs tariffs were enacted through executive proclamation',
                      evidentiaryBalance: 'Primary customs agency records verify tariff implementation',
                      secondaryVerdict: 'CONFIRMED_TRUE',
                      concursWithPrimary: true,
                      adjudicationRationale: 'Official federal registry confirms tariff enactment.',
                      epistemicConfidence: 0.95,
                      detectedFallacies: [],
                      bayesFactor: 15.0,
                      priorProbability: 0.5,
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
        'Donald Trump signed executive tariffs on foreign aluminum in 2018',
        'verified_true',
        'Federal Register confirms presidential proclamation',
        [],
        'politics'
      );

      expect(res.consensusMetadata.checked).toBe(true);
      expect(res.consensusMetadata.blindReviewApplied).toBe(true);
      expect(res.consensusMetadata.epistemicConfidence).toBe(0.95);
    });
  });

  describe('Pillar 3: Multilateral War & Geopolitical Observation Protocol', () => {
    it('detects active military strikes, casualty claims, and territorial assertions', () => {
      const warClaims = [
        'Defense ministry claims 450 enemy troops killed in overnight missile strike',
        'Artillery strike destroyed insurgent stronghold near the border',
        'Drone attack targeted electrical infrastructure during the military counter-offensive',
      ];

      for (const text of warClaims) {
        const detection = verificationService.detectGeopoliticalOrWarClaim(text, 'war');
        expect(detection.isWarClaim).toBe(true);
        expect(detection.reason).toBeDefined();
      }
    });

    it('de-escalates unilateral belligerent claims to disputed when independent multilateral telemetry is absent', async () => {
      const unilateralStrikeClaim = 'Military command confirms 300 enemy combatants neutralized in morning airstrike';

      const unilateralSources: RichSource[] = [
        {
          title: 'State Ministry of Defense Press Release',
          url: 'https://state-defense-agency.mil/briefing',
          tier: 'D',
          snippet: 'Official military announcement of enemy casualty count',
        },
      ];

      const res = await verificationService.crossExamineClaim(
        unilateralStrikeClaim,
        'false_claim', // Primary flagged it as false because enemy state disputed it
        'Enemy state media claimed zero casualties',
        unilateralSources,
        'war'
      );

      // Must be de-escalated to disputed under multilateral observation protocol
      expect(res.adjudicatedStatus).toBe('disputed');
      expect(res.consensusMetadata.isMultilateralWarObservation).toBe(true);
      expect(res.publicNote).toContain('Geopolitical / War Observation Protocol');
      expect(res.publicNote).toContain('independent multilateral observation');
    });

    it('allows cross-examination verification when multilateral telemetry (e.g. UN, IAEA, Satellite) is present', async () => {
      const verifiedNuclearClaim = 'IAEA monitors confirm nuclear facility cooling systems were undamaged during shelling';

      const multilateralSources: RichSource[] = [
        {
          title: 'IAEA Director General Statement on Facility Integrity',
          url: 'https://iaea.org/press/monitoring-report-2024',
          tier: 'A',
          snippet: 'On-site inspectors verified physical cooling tower integrity intact.',
        },
        {
          title: 'Maxar Satellite High-Resolution Thermal Telemetry',
          url: 'https://maxar.com/imagery-telemetry-2024',
          tier: 'B',
          snippet: 'Orbital multispectral imagery corroborates normal thermal dissipation.',
        },
      ];

      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      steelManDefense: 'On-site multilateral inspectors and orbital imaging verify facility integrity',
                      inquisitorChallenge: 'Initial artillery reports caused telemetry alerts',
                      evidentiaryBalance: 'Unanimous multilateral IAEA inspector presence outweighs media fog-of-war',
                      secondaryVerdict: 'CONFIRMED_TRUE',
                      concursWithPrimary: true,
                      adjudicationRationale: 'Authoritative multilateral inspection confirms cooling systems undamaged.',
                      epistemicConfidence: 0.98,
                      detectedFallacies: [],
                      bayesFactor: 50.0,
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
        verifiedNuclearClaim,
        'verified_true',
        'IAEA and satellite data confirm',
        multilateralSources,
        'war'
      );

      expect(res.adjudicatedStatus).toBe('verified_true');
      expect(res.consensusMetadata.agreed).toBe(true);
      expect(res.consensusMetadata.epistemicConfidence).toBe(0.98);
    });
  });

  describe('Pillar 4: Formal Fallacy & Cognitive Bias Auditing (100% Rationality)', () => {
    it('captures detected formal fallacies, Bayes factor, and calibrated epistemic confidence', async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      steelManDefense: 'Correlative surveys observe higher happiness scores among pet owners',
                      inquisitorChallenge: 'Survey did not control for household income or baseline health',
                      evidentiaryBalance: 'Conflating correlation with direct causation without clinical control',
                      detectedFallacies: ['POST_HOC', 'CHERRY_PICKING'],
                      secondaryVerdict: 'DISPUTED',
                      concursWithPrimary: false,
                      adjudicationRationale: 'Post-hoc causal fallacy: longitudinal clinical controls do not demonstrate direct causation.',
                      bayesFactor: 0.85,
                      priorProbability: 0.5,
                      epistemicConfidence: 0.72,
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
        'Adopting a dog directly causes a 30% reduction in cardiovascular disease mortality',
        'false_claim',
        'Observational study lacked multi-center randomized controls',
        [],
        'health'
      );

      expect(res.adjudicatedStatus).toBe('disputed');
      expect(res.consensusMetadata.checked).toBe(true);
      expect(res.consensusMetadata.detectedFallacies).toEqual(['POST_HOC', 'CHERRY_PICKING']);
      expect(res.consensusMetadata.bayesFactor).toBe(0.85);
      expect(res.consensusMetadata.priorProbability).toBe(0.5);
      expect(res.consensusMetadata.epistemicConfidence).toBe(0.72);
      expect(res.publicNote).toContain('Multi-model cross-examination revealed conflicting evidence');
    });
  });

  describe('Pillar 5: Cost-Effective Selective Escalation (The 95/5 Pareto Efficiency Rule)', () => {
    it('skips secondary cross-examination entirely for routine uncontroversial claims ($0 cost)', async () => {
      const simpleFact = 'Mount Everest is the highest mountain peak above sea level on Earth';
      
      const res = await verificationService.crossExamineClaim(
        simpleFact,
        'verified_true',
        'Geodetic surveys confirm elevation',
        [],
        'geography'
      );

      // Should be zero model calls, checked: false, agreed: true
      expect(res.consensusMetadata.checked).toBe(false);
      expect(res.consensusMetadata.agreed).toBe(true);
      expect(res.adjudicatedStatus).toBe('verified_true');
    });

    it('triggers Gemini 2.5 Flash reasoning model when domain is sensitive (health, finance, war)', async () => {
      let requestedModel = '';
      (verificationService as any).genAI = {
        getGenerativeModel: jest.fn().mockImplementation((config: any) => {
          requestedModel = config.model;
          return {
            generateContent: jest.fn().mockResolvedValue({
              response: {
                candidates: [
                  {
                    content: {
                      parts: [
                        {
                          text: JSON.stringify({
                            steelManDefense: 'Charitable defense',
                            inquisitorChallenge: 'Red team challenge',
                            evidentiaryBalance: 'Balanced weighing',
                            secondaryVerdict: 'CONFIRMED_FALSE',
                            concursWithPrimary: true,
                            adjudicationRationale: 'Consensus refutation',
                            epistemicConfidence: 0.99,
                          }),
                        },
                      ],
                    },
                  },
                ],
              },
            }),
          };
        }),
      };

      await verificationService.crossExamineClaim(
        'Injecting household disinfectants destroys respiratory viruses safely',
        'false_claim',
        'Toxic substance contraindicated by all medical authorities',
        [],
        'health'
      );

      // Verify that reasoning model (gemini-2.5-flash) was requested
      expect(requestedModel).toBe(PIPELINE_CONFIG.GEMINI_MODELS?.reasoning || 'gemini-2.5-flash');
    });
  });
});
