import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { ClaimNature, FramingStyle, RichSource } from '../../src/pipeline/types';

describe('Unit: Faith Claims & Evidence Architecture (Anti-Bias & Epistemic Fairness)', () => {
  const verificationService = new ClaimVerificationService('test-key', 0.6);

  describe('Pillar A: Replace Ambiguous Credibility Rating with Evidence Categories', () => {
    it('sets rating to null for faith claims, eliminating misleading numerical scores like 5/10', async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      verifications: [
                        {
                          claimId: 'claim_jesus_water',
                          claim: 'Jesus walked on water',
                          claimType: 'RELIGIOUS_CLAIM',
                          nature: 'SUPERNATURAL_CLAIM',
                          label: 'FAITH-BASED CLAIM',
                          evidenceLevel: 'NONE',
                          confidence: 0.95,
                          freshness: 'Timeless',
                          summary: 'This event is documented as a miracle narrative across Christian Gospels. No independent contemporary extra-biblical records exist.',
                          evidenceAssessment: {
                            scripturalSupport: 'DOCUMENTED',
                            independentHistoricalCorroboration: 'NOT_ESTABLISHED',
                            empiricalVerification: 'NOT_ESTABLISHED',
                          },
                          beliefAssessment: 'A recognized Christian belief / theological tradition',
                          misinformationVerdict: 'NOT_ESTABLISHED_AS_MISINFORMATION',
                          confidenceMeaning: 'Measures confidence in the categorization of the claim and evidentiary scoping, not the probability that the physical event occurred.',
                          framingAssessment: 'The assertion that proof exists is ambiguous. If referring to scriptural testimony, canonical text exists; if referring to empirical or scientific proof, that assertion is not established by the supplied sources.',
                          epistemicLimitations: [
                            'This assessment evaluates the available evidence, not the validity of Christian faith or personal religious belief.',
                          ],
                          sources: [
                            {
                              title: 'Bible Gateway — Gospel of Matthew (Matthew 14:22-33)',
                              url: 'https://www.biblegateway.com/passage/?search=Matthew%2014%3A22-33',
                              snippet: 'Jesus went out to them, walking on the lake.',
                              sourceType: 'scripture',
                              whatItSupports: 'Documents that the event is described in canonical Christian scripture',
                              whatItDoesNotEstablish: 'Does not provide independent contemporary extra-biblical physical corroboration',
                              sourceRole: 'primary_scripture',
                            },
                          ],
                        },
                      ],
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

      const results = await verificationService.verifyClaimBatch(
        [
          {
            claimId: 'claim_jesus_water',
            text: 'Jesus walked on water',
            nature: ClaimNature.BELIEF,
            framing: FramingStyle.BALANCED,
            confidence: 0.95,
            importance: 0.8,
            chunkIndex: 0,
            start: 0,
            end: 20,
          },
        ],
        'Religion',
        {
          groundingMode: 'never',
          forcePro: false,
          minSourcesRequired: 1,
          sourceDiversityRequired: false,
        }
      );

      expect(results.length).toBe(1);
      const verified = results[0];

      // Verification: Rating is null (no 5/10 scalar rating on faith)
      expect(verified.rating).toBeNull();
      expect(verified.status).toBe('faith_based_claim');

      // Verification: Explicit Evidence Assessment categories
      expect(verified.evidenceAssessment).toBeDefined();
      expect(verified.evidenceAssessment?.scripturalSupport).toBe('DOCUMENTED');
      expect(verified.evidenceAssessment?.independentHistoricalCorroboration).toBe('NOT_ESTABLISHED');
      expect(verified.evidenceAssessment?.empiricalVerification).toBe('NOT_ESTABLISHED');

      // Verification: Never labeled as misinformation
      expect(verified.misinformationVerdict).toBe('NOT_ESTABLISHED_AS_MISINFORMATION');
      expect(verified.beliefAssessment).toContain('Christian');

      // Verification: Defined Confidence Meaning
      expect(verified.confidenceMeaning).toBeDefined();
      expect(verified.confidenceMeaning).toContain('categorization');

      // Verification: Separate Framing Assessment & Epistemic Limitations
      expect(verified.framingAssessment).toBeDefined();
      expect(verified.framingAssessment).toContain('ambiguous');
      expect(verified.epistemicLimitations).toBeDefined();
      expect(verified.epistemicLimitations?.[0]).toContain('validity of Christian faith');
    });
  });

  describe('Pillar B: Refine Framing Violations (Proof Assertions vs Scriptural Citations)', () => {
    it('does NOT flag legitimate scriptural attributions as framing violations', () => {
      const scripturalClaims = [
        {
          text: 'Jesus walked on water, according to the Bible',
          nature: ClaimNature.BELIEF,
          framing: FramingStyle.ABSOLUTE,
          confidence: 0.95,
          importance: 0.8,
          chunkIndex: 0,
          start: 0,
          end: 45,
        },
        {
          text: 'Christians believe Jesus walked on the Sea of Galilee',
          nature: ClaimNature.BELIEF,
          framing: FramingStyle.ABSOLUTE,
          confidence: 0.95,
          importance: 0.8,
          chunkIndex: 0,
          start: 0,
          end: 50,
        },
        {
          text: 'The Gospel of Matthew describes Jesus walking on water',
          nature: ClaimNature.BELIEF,
          framing: FramingStyle.ABSOLUTE,
          confidence: 0.95,
          importance: 0.8,
          chunkIndex: 0,
          start: 0,
          end: 52,
        },
      ];

      const { toVerify, opinions } = verificationService.classifyClaims(scripturalClaims);
      const allClassified = [...toVerify, ...opinions];

      for (const item of allClassified) {
        expect(item.isFramingViolation).toBe(false);
        expect(item.framingViolationDetail).toBeUndefined();
      }
    });

    it('specifically flags unsupported assertions about empirical proofs as framing violations', () => {
      const proofClaims = [
        {
          text: 'Jesus walked on water, it has proofs',
          nature: ClaimNature.BELIEF,
          framing: FramingStyle.ABSOLUTE,
          confidence: 0.95,
          importance: 0.8,
          chunkIndex: 0,
          start: 0,
          end: 35,
        },
        {
          text: 'Scientific experiments have proved that Jesus walked on water',
          nature: ClaimNature.BELIEF,
          framing: FramingStyle.ABSOLUTE,
          confidence: 0.95,
          importance: 0.8,
          chunkIndex: 0,
          start: 0,
          end: 60,
        },
      ];

      const { toVerify, opinions } = verificationService.classifyClaims(proofClaims);
      const allClassified = [...toVerify, ...opinions];

      for (const item of allClassified) {
        expect(item.isFramingViolation).toBe(true);
        expect(item.framingViolationDetail).toBeDefined();
        expect(item.framingViolationDetail?.violationType).toBe('UNSUPPORTED_PROOF_ASSERTION');
        expect(item.framingViolationDetail?.assertedEvidenceQuality).toContain('Empirical/scientific proof');
      }
    });
  });

  describe('Pillar C: Transparent Source Scoping (What Sources Support vs Cannot Establish)', () => {
    it('populates source transparency fields for scripture and scholarly sources', async () => {
      const mockGenerateContent = jest.fn().mockResolvedValue({
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      verifications: [
                        {
                          claimId: 'claim_sources_test',
                          claim: 'Jesus walked on water',
                          claimType: 'RELIGIOUS_CLAIM',
                          nature: 'SUPERNATURAL_CLAIM',
                          label: 'FAITH-BASED CLAIM',
                          evidenceLevel: 'NONE',
                          confidence: 0.95,
                          freshness: 'Timeless',
                          summary: 'Documented Gospel narrative.',
                          sources: [
                            {
                              title: 'Gospel of Matthew (Matthew 14:22-33)',
                              url: 'https://www.biblegateway.com/passage/?search=Matthew%2014%3A22-33',
                              snippet: 'Shortly before dawn Jesus went out to them, walking on the lake.',
                              sourceType: 'scripture',
                              whatItSupports: 'The event is described in Christian scripture',
                              whatItDoesNotEstablish: 'Independent confirmation of the physical event',
                              sourceRole: 'primary_scripture',
                            },
                            {
                              title: 'Encyclopaedia Britannica — The Miracles of Jesus',
                              url: 'https://www.britannica.com/biography/Jesus/The-miracles',
                              snippet: 'Miracle stories in the Gospels reflect early church theological traditions.',
                              sourceType: 'encyclopedia',
                              whatItSupports: 'Historical and theological context for Gospel miracle narratives',
                              whatItDoesNotEstablish: 'A definitive scientific determination that the miracle did or did not occur',
                              sourceRole: 'scholarly_reference',
                            },
                          ],
                        },
                      ],
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

      const results = await verificationService.verifyClaimBatch(
        [
          {
            claimId: 'claim_sources_test',
            text: 'Jesus walked on water',
            nature: ClaimNature.BELIEF,
            framing: FramingStyle.BALANCED,
            confidence: 0.95,
            importance: 0.8,
            chunkIndex: 0,
            start: 0,
            end: 20,
          },
        ],
        'Religion',
        {
          groundingMode: 'never',
          forcePro: false,
          minSourcesRequired: 1,
          sourceDiversityRequired: false,
        }
      );

      const verified = results[0];
      expect(verified.richSources).toBeDefined();
      expect(verified.richSources?.length).toBe(2);

      const scriptureSource = verified.richSources?.find(s => s.sourceRole === 'primary_scripture');
      expect(scriptureSource).toBeDefined();
      expect(scriptureSource?.whatItSupports).toBe('The event is described in Christian scripture');
      expect(scriptureSource?.whatItDoesNotEstablish).toBe('Independent confirmation of the physical event');

      const scholarlySource = verified.richSources?.find(s => s.sourceRole === 'scholarly_reference');
      expect(scholarlySource).toBeDefined();
      expect(scholarlySource?.whatItSupports).toBe('Historical and theological context for Gospel miracle narratives');
      expect(scholarlySource?.whatItDoesNotEstablish).toBe('A definitive scientific determination that the miracle did or did not occur');
    });
  });

  describe('Pillar D: Empirical Verification & Conspiracy Refutation (Apollo 11 Moon Landing Hoax)', () => {
    it('correctly evaluates empirical conspiracy claim using 4-dimensional epistemic framework', async () => {
      const claimText = 'NASA faked the Apollo 11 Moon landing in 1969. The astronauts never landed on the Moon, and the photographs and videos were staged on Earth.';

      // 1. Classification & Routing Matrix
      const { toVerify, opinions } = verificationService.classifyClaims([
        {
          text: claimText,
          nature: ClaimNature.VERIFIABLE_FACT,
          framing: FramingStyle.ABSOLUTE,
          confidence: 0.98,
          importance: 0.95,
          chunkIndex: 0,
          start: 0,
          end: 140,
        },
      ]);

      expect(toVerify.length).toBe(1);
      expect(opinions.length).toBe(0);
      expect(toVerify[0].nature).toBe(ClaimNature.VERIFIABLE_FACT);

      // 2. Mock Multi-Dimensional Institutional Verification Response
      const mockGenerateContent = jest.fn()
        .mockResolvedValueOnce({
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        verifications: [
                          {
                            claimId: 'claim_apollo_moon_landing',
                            claim: claimText,
                            claimType: 'HISTORICAL_FACT',
                            nature: 'VERIFIABLE_FACT',
                            label: 'FALSE',
                            evidenceLevel: 'CONTRADICTED',
                            rating: 0,
                            confidence: 0.99,
                            freshness: 'Timeless',
                            summary: 'Inaccurate. The assertion that the 1969 Apollo 11 Moon landing was staged on Earth is conclusively refuted by physical retroreflectors continuously measured on the lunar surface, 382 kg of independently verified lunar samples, Cold War tracking telemetry by the Soviet Union, and modern high-resolution orbital imagery.',
                            verifiedFacts: [
                              'Neil Armstrong and Buzz Aldrin landed the Apollo 11 Lunar Module Eagle on the Moon on July 20, 1969, spending 21 hours and 36 minutes on the lunar surface.',
                              'Apollo 11 deployed the Laser Ranging Retroreflector (LRRR) at Tranquility Base, continuously pinged by independent Earth observatories for over 50 years to measure the Earth-Moon distance.',
                              'Apollo missions returned 382 kilograms of lunar samples exhibiting cosmic ray exposure, micrometeorite zap pits, and total absence of hydration that were scientifically impossible to artificially synthesize on Earth in 1969.',
                              'The Soviet Union, the primary geopolitical adversary during the Cold War, tracked Apollo 11 radio signals, Doppler velocity, and telemetry in real time and conceded the American achievement without contesting authenticity.',
                              'The NASA Lunar Reconnaissance Orbiter (LROC) and ISRO Chandrayaan-2 High Resolution Camera have imaged the Apollo 11 landing site from lunar orbit, documenting the descent stage hardware, experiment packages, and dual astronaut foot trails.',
                              'Cinematographic analysis confirms that in 1969, computer-controlled video compositing did not exist, and reproducing parallel solar illumination across acres alongside non-billowing ballistic dust plumes in a total vacuum was technically impossible on Earth.',
                            ],
                            missingEvidence: [
                              'Zero empirical or documentary evidence has ever substantiated claims that Apollo 11 was staged or filmed in a studio.',
                              'No evidence of terrestrial studio lighting artifacts, atmospheric dust drag, or video splicing exists in primary NASA broadcasts or raw Hasselblad film reels.',
                            ],
                            evidenceAssessment: {
                              scripturalSupport: 'NOT_APPLICABLE',
                              independentHistoricalCorroboration: 'DOCUMENTED',
                              empiricalVerification: 'CONTRADICTED',
                            },
                            misinformationVerdict: 'MISINFORMATION',
                            confidenceMeaning: 'Measures confidence in the physical, historical, and multilateral evidentiary refutation of the claim, based on continuous physical measurements, geochemical verification, and independent Cold War tracking.',
                            framingAssessment: 'The claim asserts empirical and historical fraud contrary to overwhelming physical, geochemical, optical, and multilateral archival documentation. It relies on conspiratorial tropes that mischaracterize camera optics, solar illumination, and vacuum mechanics.',
                            epistemicLimitations: [
                              'Physical retroreflectors and returned regolith provide direct, permanent empirical verification that cannot be falsified by conspiracy allegations.',
                            ],
                            sources: [
                              {
                                title: 'NASA Apollo 11 Mission Report & Lunar Surface Journal',
                                url: 'https://www.nasa.gov/mission_pages/apollo/apollo-11.html',
                                snippet: 'Apollo 11 landed at Tranquility Base on July 20, 1969, deploying the Early Apollo Scientific Experiments Package.',
                                sourceType: 'government',
                                whatItSupports: 'Documents complete primary telemetry, flight trajectory, surface experiment deployments, and voice transcripts',
                                whatItDoesNotEstablish: 'Does not constitute third-party independent verification on its own',
                                sourceRole: 'primary_scripture', // Used generically as primary documentation
                              },
                              {
                                title: 'Soviet Academy of Sciences Space Tracking Telemetry Archives',
                                url: 'https://en.wikipedia.org/wiki/Third-party_evidence_for_Apollo_Moon_Landings#Soviet_Union',
                                snippet: 'Soviet space tracking stations independently tracked Apollo 11 transmissions and Doppler shifts from the Moon.',
                                sourceType: 'archive',
                                whatItSupports: 'Independent verification by the United States primary Cold War rival confirming the spacecraft trajectory and lunar landing in real time',
                                whatItDoesNotEstablish: 'Microscopic petrological confirmation of returned regolith samples',
                                sourceRole: 'independent_corroboration',
                              },
                              {
                                title: 'Lunar Laser Ranging Experiment — APOLLO Project & McDonald Observatory',
                                url: 'https://physics.ucsd.edu/~tmurphy/apollo/apollo.html',
                                snippet: 'Laser pulses bounced off Apollo retroreflectors on the Moon measure the Earth-Moon distance with sub-millimeter precision.',
                                sourceType: 'website',
                                whatItSupports: 'Physical, ongoing empirical proof of human-placed hardware at Tranquility Base',
                                whatItDoesNotEstablish: 'Verification of 1969 television studio transmission protocols',
                                sourceRole: 'scientific_reference',
                              },
                              {
                                title: 'Science — Petrology and Geochemistry of Apollo 11 Lunar Samples',
                                url: 'https://doi.org/10.1126/science.167.3918.447',
                                snippet: 'Lunar rocks exhibit impact craters and noble gas implantation completely devoid of water, distinct from any terrestrial minerals.',
                                sourceType: 'journal',
                                whatItSupports: 'Geochemical and isotopic proof of extraterrestrial lunar origin verified by international laboratories',
                                whatItDoesNotEstablish: 'Real-time telemetry validation during descent',
                                sourceRole: 'scholarly_reference',
                              },
                              {
                                title: 'Lunar Reconnaissance Orbiter Camera (LROC) — Apollo 11 Landing Site Imagery',
                                url: 'https://www.lroc.asu.edu/featured_sites/view_site/apollo-11',
                                snippet: 'High-resolution orbital images show the Apollo 11 descent stage, LR-3 reflector, and astronaut walking paths.',
                                sourceType: 'government',
                                whatItSupports: 'Sub-meter orbital imaging directly showing physical Apollo hardware and foot trails on the Moon',
                                whatItDoesNotEstablish: 'Astronaut psychological reflections or internal audio transcripts',
                                sourceRole: 'independent_corroboration',
                              },
                            ],
                          },
                        ],
                      }),
                    },
                  ],
                },
              },
            ],
          },
        })
        .mockResolvedValueOnce({
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        steelManDefense: 'Conspiracy theorists point to photographic artifacts, lack of background stars, and Cold War propaganda pressure.',
                        inquisitorChallenge: 'Direct physical retroreflectors, geochemical lunar rocks, 400,000 personnel, and independent Soviet tracking decisively refute any hoax hypothesis.',
                        evidentiaryBalance: 'Unanimous multilateral physical, optical, and historical empirical consensus.',
                        detectedFallacies: ['CHERRY_PICKING', 'APPEAL_TO_IGNORANCE'],
                        secondaryVerdict: 'CONFIRMED_FALSE',
                        concursWithPrimary: true,
                        adjudicationRationale: 'The claim of a staged Moon landing is contradicted by overwhelming multilateral physical, geochemical, and historical evidence.',
                        bayesFactor: 0.0001,
                        priorProbability: 0.001,
                        epistemicConfidence: 0.99,
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

      const results = await verificationService.verifyClaimBatch(
        [
          {
            claimId: 'claim_apollo_moon_landing',
            text: claimText,
            nature: ClaimNature.VERIFIABLE_FACT,
            framing: FramingStyle.ABSOLUTE,
            confidence: 0.98,
            importance: 0.95,
            chunkIndex: 0,
            start: 0,
            end: 140,
          },
        ],
        'Science',
        {
          groundingMode: 'never',
          forcePro: false,
          minSourcesRequired: 2,
          sourceDiversityRequired: true,
        }
      );

      expect(results.length).toBe(1);
      const verified = results[0];

      // Verifications:
      expect(verified.status).toBe('false_claim');
      expect(verified.evidenceLevel).toBe('VERY_STRONG');
      expect(verified.evidenceAssessment?.empiricalVerification).toBe('CONTRADICTED');
      expect(verified.evidenceAssessment?.independentHistoricalCorroboration).toBe('DOCUMENTED');
      expect(verified.misinformationVerdict).toBe('MISINFORMATION');
      expect(verified.confidenceMeaning).toContain('refutation of the claim');
      expect(verified.richSources?.length).toBe(5);

      const sovietSource = verified.richSources?.find(s => s.title.includes('Soviet'));
      expect(sovietSource).toBeDefined();
      expect(sovietSource?.whatItSupports).toContain('Cold War rival');

      const laserSource = verified.richSources?.find(s => s.title.includes('Laser'));
      expect(laserSource).toBeDefined();
      expect(laserSource?.whatItSupports).toContain('Physical, ongoing empirical proof');

      const lrocSource = verified.richSources?.find(s => s.title.includes('LROC'));
      expect(lrocSource).toBeDefined();
      expect(lrocSource?.whatItSupports).toContain('Sub-meter orbital imaging');
    });
  });
});
