import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { UrlVerificationService } from '../../src/pipeline/services/urlVerificationService';
import {
  ClaimNature,
  EvidenceCatalog,
  FramingStyle,
  EvidenceLevel,
  EvidenceToClaimTraceability,
} from '../../src/pipeline/types';
import { useCiteByIdMode } from "../helpers/citeByIdMode";

// The stance step is a model call; these suites use a fixed judgment (see helper).
jest.mock("../../src/pipeline/services/stanceClassifier", () => jest.requireActual("../helpers/citeByIdMode").fixedStanceModule);

function createClosedWorldService(
  claimText: string,
  items: Array<{
    evidenceId: string;
    title: string;
    url: string;
    domain: string;
    publisher: string;
    snippet: string;
    tier?: 'A' | 'B' | 'C' | 'D' | 'E';
  }>
): ClaimVerificationService {
  const candidatesById: EvidenceCatalog['candidatesById'] = {};
  const orderedCandidates = items.map((item) => {
    const candidate = {
      evidenceId: item.evidenceId,
      title: item.title,
      url: item.url,
      canonicalUrl: item.url,
      domain: item.domain,
      publisher: item.publisher,
      snippet: item.snippet,
      tier: item.tier || 'A',
      retrievalProvider: 'PubMed',
      retrievalMethod: 'test_fixture',
      verification: {
        status: 'VERIFIED' as const,
        originalUrl: item.url,
        canonicalUrl: item.url,
        domain: item.domain,
        httpStatus: 200,
        redirectHops: 0,
        isSoft404: false,
        verifiedAtUtc: '2026-11-11T00:00:00.000Z',
        verifierMethod: 'http_get' as const,
        fetchStatus: 'HTTP_200_OK' as const,
      },
    };
    candidatesById[item.evidenceId] = candidate;
    return candidate;
  });

  const catalog: EvidenceCatalog = {
    claimText,
    normalizedQueries: [claimText],
    candidatesById,
    orderedCandidates,
    rejectedCandidates: [],
    verifiedAcademicMetadata: [],
    retrievedAtUtc: '2026-11-11T00:00:00.000Z',
  };

  const urlVerifier = new UrlVerificationService({
    dnsLookup: async () => [{ address: '93.184.216.34', family: 4 }],
    useFirestoreCache: false,
    transport: async () => ({
      statusCode: 200,
      headers: { 'content-type': 'text/html' },
      bodyText: '<html><head><title>Verified</title></head><body>Verified evidence body</body></html>',
    }),
  });

  return new ClaimVerificationService('test-key', 0.6, {
    urlVerifier,
    evidenceRetrieval: {
      buildEvidenceCatalogForClaim: jest.fn().mockResolvedValue(catalog),
    } as any,
  });
}

describe('Unit: Evidence-to-Claim Traceability & Mixed-Evidence Decomposition Architecture', () => {
  useCiteByIdMode();
  const verificationService = new ClaimVerificationService('test-key', 0.6);

  it('decomposes mixed-evidence claim, verifies observable premises, refutes invalid inference, and constructs full traceability manifest', async () => {
    const claimText =
      "Apollo 11 photographs contain no visible stars. The American flag appears to wave, and the astronauts' shadows point in different directions. Therefore, the Moon landing was filmed in a Hollywood studio.";

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
        end: claimText.length,
      },
    ]);

    expect(toVerify.length).toBe(1);
    expect(opinions.length).toBe(0);

    // 2. Structured Traceability Manifest
    const mockTraceability: EvidenceToClaimTraceability = {
      isCompoundClaim: true,
      components: [
        {
          componentId: 'comp_stars',
          statement: 'Apollo 11 photographs contain no visible stars.',
          type: 'PREMISE_OBSERVATION',
          factualAccuracy: 'ACCURATE_OBSERVATION',
          inferentialValidity: 'NOT_APPLICABLE',
          explanation:
            'Photographs taken during the lunar surface EVA indeed do not display background stars. This is caused by camera exposure settings (1/250s at f/8 to f/11) calibrated for bright daytime lunar regolith under direct solar illumination (~1360 W/m²). Faint stars (magnitude +1 to +6) require multi-second exposures that would completely overexpose the foreground.',
          detectedFallacy: 'NONE',
          evidenceIds: ['ev_hasselblad_specs', 'ev_optical_albedo'],
        },
        {
          componentId: 'comp_flag',
          statement: 'The American flag appears to wave.',
          type: 'PREMISE_OBSERVATION',
          factualAccuracy: 'ACCURATE_OBSERVATION',
          inferentialValidity: 'NOT_APPLICABLE',
          explanation:
            'The flag displays permanent ripples and motion during deployment. The horizontal telescoping crossbar jammed and failed to fully extend, leaving intentional folds in the nylon fabric. As astronauts twisted the mast into dense regolith, angular momentum propagated through the cloth like an undamped pendulum in a vacuum with zero atmospheric drag. Once astronauts released the mast, stationary time-lapse footage confirms the cloth remained completely motionless.',
          detectedFallacy: 'NONE',
          evidenceIds: ['ev_flag_deployment_report', 'ev_vacuum_pendulum_physics'],
        },
        {
          componentId: 'comp_shadows',
          statement: "The astronauts' shadows point in different directions.",
          type: 'PREMISE_OBSERVATION',
          factualAccuracy: 'ACCURATE_OBSERVATION',
          inferentialValidity: 'NOT_APPLICABLE',
          explanation:
            'Shadows in certain 2D photographs appear non-parallel. Parallel sunlight projected across uneven 3D lunar topography (craters, mounds, depressions) appears to converge or diverge when rendered in 2D perspective foreshortening. Identical optical shadow behavior is observed on uneven terrestrial terrain with a single distant light source.',
          detectedFallacy: 'NONE',
          evidenceIds: ['ev_photogrammetry_shadows'],
        },
        {
          componentId: 'comp_studio_conclusion',
          statement: 'Therefore, the Moon landing was filmed in a Hollywood studio.',
          type: 'INFERENTIAL_CONCLUSION',
          factualAccuracy: 'INACCURATE_OBSERVATION',
          inferentialValidity: 'INVALID_NON_SEQUITUR',
          explanation:
            'The conclusion does not follow from the premises (non sequitur). The observed phenomena are fully explained by camera exposure, vacuum physics, and perspective geometry under a single solar light source. Terrestrial studio lighting with multiple spotlights would produce multiple divergent shadows with multiple distinct penumbras per object, which are completely absent in all Apollo photographs.',
          detectedFallacy: 'NON_SEQUITUR',
          evidenceIds: ['ev_cinematography_refutation', 'ev_soviet_tracking'],
        },
      ],
      evidenceTraces: [
        {
          evidenceId: 'ev_hasselblad_specs',
          componentId: 'comp_stars',
          sourceTitle: 'NASA Apollo Lunar Surface Journal — Hasselblad 500EL Camera Technical Data',
          sourceUrl: 'https://www.hq.nasa.gov/alsj/alsj-HA500EL.html',
          retrievalTimestamp: 1730584800000,
          sourceType: 'archive',
          provenance: {
            originAgencyOrAuthor: 'NASA Manned Spacecraft Center / Hasselblad AB',
            isIndependentOfSubject: false,
            independenceValidation: 'Primary technical documentation of flight camera optics and film sensitivities.',
          },
          exactPassage:
            'Cameras utilized 70mm Kodak Ektachrome film exposed at 1/250 second, with apertures between f/5.6 and f/11 under full lunar daylight.',
          claimComponentAddressed: 'Apollo 11 photographs contain no visible stars.',
          relationship: 'EXPLAINS_OBSERVATION',
          verificationStatus: 'VERIFIED_OBSERVATION',
          knownLimitations: [
            'Documents camera settings; does not directly measure stellar background photon counts.',
          ],
        },
        {
          evidenceId: 'ev_flag_deployment_report',
          componentId: 'comp_flag',
          sourceTitle: 'Where No Flag Has Gone Before: Political and Technical History of the Apollo Lunar Flag',
          sourceUrl: 'https://www.hq.nasa.gov/office/pao/History/flag/flag.html',
          retrievalTimestamp: 1730584800000,
          sourceType: 'government',
          provenance: {
            originAgencyOrAuthor: 'NASA History Office / Anne M. Platoff',
            isIndependentOfSubject: false,
            independenceValidation: 'Official historical analysis of lunar flag hardware engineering and assembly.',
          },
          exactPassage:
            'The horizontal rod did not fully extend, causing the flag to remain wrinkled. Rotation of the pole imparted inertia to the fabric which moved freely in the vacuum before coming to rest.',
          claimComponentAddressed: 'The American flag appears to wave.',
          relationship: 'EXPLAINS_OBSERVATION',
          verificationStatus: 'VERIFIED_OBSERVATION',
          knownLimitations: [
            'Describes Apollo 11 hardware specifically; other missions used modified rod latches.',
          ],
        },
        {
          evidenceId: 'ev_photogrammetry_shadows',
          componentId: 'comp_shadows',
          sourceTitle: 'Journal of Photogrammetric Engineering & Remote Sensing — Shadows on Non-Planar Surfaces',
          sourceUrl: 'https://doi.org/10.14358/PERS.71.6.721',
          retrievalTimestamp: 1730584800000,
          sourceType: 'journal',
          provenance: {
            originAgencyOrAuthor: 'American Society for Photogrammetry and Remote Sensing',
            isIndependentOfSubject: true,
            independenceValidation: 'Peer-reviewed academic photogrammetry journal independent of space agencies.',
          },
          exactPassage:
            'Parallel incident rays from a single collimated source appear non-parallel when projected across undulating topographic relief and viewed through wide-angle lens perspective projection.',
          claimComponentAddressed: "The astronauts' shadows point in different directions.",
          relationship: 'EXPLAINS_OBSERVATION',
          verificationStatus: 'VERIFIED_OBSERVATION',
          knownLimitations: [
            'Applies geometric optics principles; requires precise digital elevation models for site-specific verification.',
          ],
        },
        {
          evidenceId: 'ev_cinematography_refutation',
          componentId: 'comp_studio_conclusion',
          sourceTitle: 'British Film Institute — Did Stanley Kubrick Fake the Moon Landings? Photographic Analysis',
          sourceUrl: 'https://www.bfi.org.uk/features/apollo-moon-landing-conspiracy-kubrick',
          retrievalTimestamp: 1730584800000,
          sourceType: 'academic_press',
          provenance: {
            originAgencyOrAuthor: 'Howard Berry / University of Hertfordshire Film Studies',
            isIndependentOfSubject: true,
            independenceValidation: 'Independent cinematic technology and film archiving research.',
          },
          exactPassage:
            'In 1969, computer graphics did not exist. Reproducing the lighting would require massive spotlight rigs that inevitably produce multiple diverging shadows and penumbras, none of which appear in the footage.',
          claimComponentAddressed: 'Therefore, the Moon landing was filmed in a Hollywood studio.',
          relationship: 'CONTRADICTS',
          verificationStatus: 'INVALID_INFERENCE',
          knownLimitations: [
            'Evaluates commercial 1969 film and television hardware; does not analyze classified military optical capabilities.',
          ],
        },
        {
          evidenceId: 'ev_soviet_tracking',
          componentId: 'comp_studio_conclusion',
          sourceTitle: 'Soviet Space Tracking Telemetry Archives (Evpatoria Deep Space Communication Complex)',
          sourceUrl: 'https://en.wikipedia.org/wiki/Third-party_evidence_for_Apollo_Moon_Landings#Soviet_Union',
          retrievalTimestamp: 1730584800000,
          sourceType: 'archive',
          provenance: {
            originAgencyOrAuthor: 'Soviet Academy of Sciences / USSR Ministry of Defense',
            isIndependentOfSubject: true,
            independenceValidation: 'Primary geopolitical Cold War adversary with direct operational motive to expose fraud.',
          },
          exactPassage:
            'Soviet tracking stations received Apollo 11 audio and television signals directly from the Moon, confirming lunar origin and trajectory.',
          claimComponentAddressed: 'Therefore, the Moon landing was filmed in a Hollywood studio.',
          relationship: 'CONTRADICTS',
          verificationStatus: 'CONTRADICTED_OBSERVATION',
          knownLimitations: [
            'Tracks radio-frequency direction of arrival and Doppler shift; does not independently inspect television studio production.',
          ],
        },
      ],
      inferentialBridgeSummary:
        'The claim presents three factually accurate visual observations (absence of stars in fast daytime exposures, wrinkled fabric motion during manual insertion, and perspective convergence of shadows on uneven slopes). However, the inferential bridge to a Hollywood studio hoax is a formal non sequitur. Each observation is fully explained by photographic optics, vacuum mechanics, and surface geometry under a single distant solar source.',
      overallSynthesis: {
        premisesVerdict: 'ALL_PREMISES_OBSERVABLE',
        conclusionVerdict: 'CONCLUSION_UNSUPPORTED_BY_PREMISES',
        finalAdjudication:
          'Misleading Inference: The photographic premises reflect authentic visual phenomena, but they fail to support the conclusion of a staged hoax. Optical physics and independent telemetry refute studio fabrication.',
      },
    };

    // 3. Mock Gemini Verification & Dialectical Cross-Examination
    const mockGenerateContent = jest
      .fn()
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
                          claimId: 'claim_mixed_apollo_hoax',
                          claim: claimText,
                          claimType: 'HISTORICAL_FACT',
                          nature: 'VERIFIABLE_FACT',
                          label: 'MISLEADING INFERENCE',
                          evidenceLevel: 'CONTRADICTED',
                          rating: null,
                          confidence: 0.96,
                          freshness: 'Timeless',
                          summary:
                            'Misleading Inference from Observable Facts. The statement accurately notes three visual features of Apollo 11 photography: stars are not visible in daylight exposures, the flag exhibits wrinkles and pendulum motion during insertion, and shadows appear non-parallel on 2D slopes. However, the conclusion that the mission was filmed in a studio is an invalid inference (non sequitur). Optical exposure calibration, vacuum mechanics, and 3D surface topography explain all three observations without requiring or supporting a hoax.',
                          verifiedFacts: [
                            'Apollo 11 Hasselblad photographs were exposed at 1/250s at f/8 to f/11 for bright daytime lunar regolith; faint stars are below the exposure threshold.',
                            'The flag rippled during deployment due to an unextended horizontal crossbar and rotational inertia in a vacuum without atmospheric drag.',
                            'Shadows cast across uneven 3D topography appear non-parallel when projected into 2D perspective foreshortening.',
                            'Independent radio and telemetry tracking by the Soviet Union confirmed signals originated from the lunar surface, not a terrestrial studio.',
                          ],
                          missingEvidence: [
                            'Zero empirical documentation, studio lighting artifacts, multiple penumbras, or production records substantiate the Hollywood studio allegation.',
                          ],
                          evidenceAssessment: {
                            scripturalSupport: 'NOT_APPLICABLE',
                            independentHistoricalCorroboration: 'DOCUMENTED',
                            empiricalVerification: 'CONTRADICTED',
                          },
                          misinformationVerdict: 'MISINFORMATION',
                          confidenceMeaning:
                            'Measures confidence in the decomposition of the claim into verifiable premises, optical explanation of observations, and refutation of the inferential leap.',
                          framingAssessment:
                            'The claim utilizes true visual anomalies as premises to advance an unsupported conspiratorial conclusion (fallacy of the undistributed middle / non sequitur).',
                          epistemicLimitations: [
                            'Optical explanations account for all photographic features; documentary records confirm deployment and trajectory.',
                          ],
                          evidenceTraceability: mockTraceability,
                          citedEvidenceIds: ['E1'],
                          sources: [
                            {
                              title: 'NASA Apollo Lunar Surface Journal — Hasselblad Camera Optics',
                              url: 'https://www.hq.nasa.gov/alsj/alsj-HA500EL.html',
                              snippet: 'Cameras utilized 70mm film exposed at 1/250s under full lunar daylight.',
                              sourceType: 'government',
                              whatItSupports: 'Documents exposure parameters explaining why stars do not appear in daytime photographs',
                              whatItDoesNotEstablish: 'Does not provide independent non-NASA verification',
                              sourceRole: 'primary_documentation',
                            },
                            {
                              title: 'British Film Institute — Cinematic Analysis of Apollo Footage',
                              url: 'https://www.bfi.org.uk/features/apollo-moon-landing-conspiracy-kubrick',
                              snippet: 'Recreating lighting across acres in 1969 would require spotlight arrays producing multiple distinct shadows.',
                              sourceType: 'academic_press',
                              whatItSupports: 'Demonstrates photographic impossibility of 1969 studio multi-spotlight staging without multiple penumbras',
                              whatItDoesNotEstablish: 'Does not inspect spacecraft telemetry',
                              sourceRole: 'scholarly_reference',
                            },
                            {
                              title: 'Soviet Academy of Sciences Deep Space Tracking Telemetry Archives',
                              url: 'https://en.wikipedia.org/wiki/Third-party_evidence_for_Apollo_Moon_Landings#Soviet_Union',
                              snippet: 'Soviet stations tracked Apollo 11 television and radio transmissions directly from the Moon in real time.',
                              sourceType: 'archive',
                              whatItSupports: 'Independent verification by Cold War adversary that transmissions originated from lunar distance',
                              whatItDoesNotEstablish: 'Does not analyze camera focal length or shutter speeds',
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
                      steelManDefense:
                        'The claimant correctly observes real photographic features (lack of stars, fluttering flag appearance, converging shadows) that appear counterintuitive to viewers unfamiliar with vacuum mechanics or daylight exposure.',
                      inquisitorChallenge:
                        'The inferential leap from optical anomalies to a Hollywood studio is a formal non sequitur. Camera optics, vacuum dynamics, single-source solar lighting, and Soviet tracking definitively refute the staging conclusion.',
                      evidentiaryBalance:
                        'Premises are factually observable; conclusion is completely unsupported and contradicted by physical and historical records.',
                      detectedFallacies: ['NON_SEQUITUR', 'APPEAL_TO_IGNORANCE', 'CHERRY_PICKING'],
                      secondaryVerdict: 'CONFIRMED_FALSE',
                      concursWithPrimary: true,
                      adjudicationRationale:
                        'The claim correctly identifies observable photographic phenomena but draws an invalid and contradicted conclusion of studio staging.',
                      bayesFactor: 0.0001,
                      priorProbability: 0.001,
                      epistemicConfidence: 0.98,
                    }),
                  },
                ],
              },
            },
          ],
        },
      });

    const cwService = createClosedWorldService(claimText, [
      {
        evidenceId: 'E1',
        title: 'NASA Apollo Lunar Surface Journal — Hasselblad Camera Optics',
        url: 'https://www.hq.nasa.gov/alsj/alsj-HA500EL.html',
        domain: 'hq.nasa.gov',
        publisher: 'NASA',
        snippet: 'Cameras utilized 70mm Kodak Ektachrome film exposed at 1/250s under full lunar daylight Apollo 11.',
        tier: 'A',
      },
      {
        evidenceId: 'E2',
        title: 'British Film Institute — Cinematic Analysis of Apollo Footage',
        url: 'https://www.bfi.org.uk/features/apollo-moon-landing-conspiracy-kubrick',
        domain: 'bfi.org.uk',
        publisher: 'British Film Institute',
        snippet: 'Recreating lighting in 1969 Hollywood studio would require spotlight arrays producing multiple distinct shadows.',
        tier: 'B',
      },
      {
        evidenceId: 'E3',
        title: 'Soviet Academy of Sciences Deep Space Tracking Telemetry Archives',
        url: 'https://en.wikipedia.org/wiki/Third-party_evidence_for_Apollo_Moon_Landings#Soviet_Union',
        domain: 'en.wikipedia.org',
        publisher: 'Wikipedia / Soviet Archives',
        snippet: 'Soviet tracking stations tracked Apollo 11 television and radio transmissions directly from the Moon.',
        tier: 'B',
      },
      {
        evidenceId: 'E4',
        title: 'Where No Flag Has Gone Before: Political and Technical History of the Apollo Lunar Flag',
        url: 'https://www.hq.nasa.gov/office/pao/History/flag/flag.html',
        domain: 'hq.nasa.gov',
        publisher: 'NASA History Office',
        snippet: 'The horizontal rod did not fully extend causing the American flag to ripple in lunar vacuum.',
        tier: 'A',
      },
      {
        evidenceId: 'E5',
        title: 'Journal of Photogrammetric Engineering & Remote Sensing — Shadows on Non-Planar Surfaces',
        url: 'https://doi.org/10.14358/PERS.71.6.721',
        domain: 'doi.org',
        publisher: 'ASPRS',
        snippet: 'Parallel sunlight shadows appear non-parallel across uneven 3D lunar topography.',
        tier: 'A',
      },
    ]);

    (cwService as any).genAI = {
      getGenerativeModel: jest.fn().mockReturnValue({
        generateContent: mockGenerateContent,
      }),
    };

    const results = await cwService.verifyClaimBatch(
      [
        {
          claimId: 'claim_mixed_apollo_hoax',
          text: claimText,
          nature: ClaimNature.VERIFIABLE_FACT,
          framing: FramingStyle.ABSOLUTE,
          confidence: 0.98,
          importance: 0.95,
          chunkIndex: 0,
          start: 0,
          end: claimText.length,
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

    // 4. Validate Evidence-to-Claim Traceability
    expect(verified.evidenceTraceability).toBeDefined();
    const trace = verified.evidenceTraceability!;

    expect(trace.isCompoundClaim).toBe(true);
    expect(trace.components.length).toBe(4);

    // Verify Component 1 (Stars): Premise is factually accurate observation
    const compStars = trace.components.find((c) => c.componentId === 'comp_stars');
    expect(compStars).toBeDefined();
    expect(compStars?.type).toBe('PREMISE_OBSERVATION');
    expect(compStars?.factualAccuracy).toBe('ACCURATE_OBSERVATION');
    expect(compStars?.explanation).toContain('exposure settings');

    // Verify Component 2 (Flag): Premise is factually accurate observation
    const compFlag = trace.components.find((c) => c.componentId === 'comp_flag');
    expect(compFlag).toBeDefined();
    expect(compFlag?.type).toBe('PREMISE_OBSERVATION');
    expect(compFlag?.factualAccuracy).toBe('ACCURATE_OBSERVATION');
    expect(compFlag?.explanation).toContain('telescoping crossbar jammed');

    // Verify Component 3 (Shadows): Premise is factually accurate observation
    const compShadows = trace.components.find((c) => c.componentId === 'comp_shadows');
    expect(compShadows).toBeDefined();
    expect(compShadows?.type).toBe('PREMISE_OBSERVATION');
    expect(compShadows?.factualAccuracy).toBe('ACCURATE_OBSERVATION');
    expect(compShadows?.explanation).toContain('uneven 3D lunar topography');

    // Verify Component 4 (Conclusion): Invalid Non Sequitur
    const compConclusion = trace.components.find((c) => c.componentId === 'comp_studio_conclusion');
    expect(compConclusion).toBeDefined();
    expect(compConclusion?.type).toBe('INFERENTIAL_CONCLUSION');
    expect(compConclusion?.inferentialValidity).toBe('INVALID_NON_SEQUITUR');
    expect(compConclusion?.detectedFallacy).toBe('NON_SEQUITUR');

    // 5. Verify Traceability Items & Provenance
    expect(trace.evidenceTraces.length).toBe(5);

    const sovietEvidence = trace.evidenceTraces.find((e) => e.evidenceId === 'ev_soviet_tracking');
    expect(sovietEvidence).toBeDefined();
    expect(sovietEvidence?.provenance.isIndependentOfSubject).toBe(true);
    expect(sovietEvidence?.provenance.independenceValidation).toContain('Cold War adversary');

    const photogrammetryEvidence = trace.evidenceTraces.find((e) => e.evidenceId === 'ev_photogrammetry_shadows');
    expect(photogrammetryEvidence).toBeDefined();
    expect(photogrammetryEvidence?.provenance.isIndependentOfSubject).toBe(true);
    expect(photogrammetryEvidence?.relationship).toBe('EXPLAINS_OBSERVATION');

    // 6. Verify Synthesis: Preserves distinction between true observations and invalid conclusion
    expect(trace.overallSynthesis.premisesVerdict).toBe('ALL_PREMISES_OBSERVABLE');
    expect(trace.overallSynthesis.conclusionVerdict).toBe('CONCLUSION_UNSUPPORTED_BY_PREMISES');

    // 7. Verify Status & Confidence
    expect(verified.status).toBe('misleading');
    expect(verified.confidenceMeaning).toContain('decomposition of the claim into verifiable premises');
    expect(verified.misinformationVerdict).toBe('MISINFORMATION');
  });

  it('evaluates adversarial selective context-omission claim: verifies document retrieval, passage location, surrounding context comparison, and flags quote-mining manipulation', async () => {
    const claimText =
      "NASA's own documentation proves that the Apollo 11 photographs were staged. Here is a genuine NASA document, but I have quoted it out of context and omitted the paragraph that explains the camera exposure settings.";

    // 1. Classification & Routing Matrix
    const { toVerify } = verificationService.classifyClaims([
      {
        text: claimText,
        nature: ClaimNature.VERIFIABLE_FACT,
        framing: FramingStyle.MANIPULATIVE,
        confidence: 0.98,
        importance: 0.95,
        chunkIndex: 0,
        start: 0,
        end: claimText.length,
      },
    ]);

    expect(toVerify.length).toBe(1);

    // 2. Structured Traceability with Automated Passage Verification & Context Omission
    const mockTraceability: EvidenceToClaimTraceability = {
      isCompoundClaim: true,
      components: [
        {
          componentId: 'comp_authentic_source',
          statement: "The cited text originates from genuine NASA Apollo 11 documentation.",
          type: 'PREMISE_OBSERVATION',
          factualAccuracy: 'ACCURATE_OBSERVATION',
          inferentialValidity: 'NOT_APPLICABLE',
          explanation:
            'The quotation is authentic and matches official NASA Apollo 11 mission documentation.',
          detectedFallacy: 'NONE',
          evidenceIds: ['ev_nasa_doc_match'],
        },
        {
          componentId: 'comp_omitted_context',
          statement: 'Crucial surrounding paragraphs explaining camera exposure settings were deliberately omitted.',
          type: 'PREMISE_OBSERVATION',
          factualAccuracy: 'ACCURATE_OBSERVATION',
          inferentialValidity: 'NOT_APPLICABLE',
          explanation:
            'The source document contains an adjacent qualifying paragraph detailing 1/250s shutter speed and f/8-f/11 apertures under 13,000 foot-candles of daylight, explaining why background stars do not appear. Omitting this passage distorts the evidentiary meaning of the document.',
          detectedFallacy: 'CHERRY_PICKING',
          evidenceIds: ['ev_nasa_surrounding_context'],
        },
        {
          componentId: 'comp_staged_allegation',
          statement: "NASA's documentation proves that the Apollo 11 photographs were staged.",
          type: 'INFERENTIAL_CONCLUSION',
          factualAccuracy: 'INACCURATE_OBSERVATION',
          inferentialValidity: 'INVALID_NON_SEQUITUR',
          explanation:
            'The document does not prove staging. When the omitted paragraph explaining camera exposure calibration is restored, the document describes standard photographic optics under solar illumination, directly refuting the staging inference.',
          detectedFallacy: 'NON_SEQUITUR',
          evidenceIds: ['ev_nasa_surrounding_context'],
        },
      ],
      evidenceTraces: [
        {
          evidenceId: 'ev_nasa_doc_match',
          componentId: 'comp_authentic_source',
          sourceTitle: 'NASA Apollo 11 Preliminary Science Report (NASA SP-214)',
          sourceUrl: 'https://www.hq.nasa.gov/alsj/a11/as11psr.pdf',
          retrievalTimestamp: 1730585000000,
          sourceType: 'government',
          provenance: {
            originAgencyOrAuthor: 'NASA Manned Spacecraft Center',
            isIndependentOfSubject: false,
            independenceValidation: 'Primary agency technical report documenting mission observations.',
          },
          sourceIndependence: {
            publisherIndependentOfSubject: false,
            underlyingDataIndependentOfSubject: false,
            analysisIndependentlyConducted: false,
            corroborationType: 'subject_self_reporting',
          },
          automatedVerification: {
            urlResolved: true,
            passageLocated: true,
            passageMatchesSource: true,
            supportsClaimComponent: true,
            verificationMethod: 'retrieved_text_and_passage_match',
            lastVerifiedAt: '2026-11-02T22:15:00Z',
            locatedContextSnippet: 'The blackness of the lunar sky provided a high-contrast background for lunar surface operations.',
            omittedContextDetected: false,
          },
          exactPassage: 'The blackness of the lunar sky provided a high-contrast background for lunar surface operations.',
          claimComponentAddressed: 'The cited text originates from genuine NASA Apollo 11 documentation.',
          relationship: 'SUPPORTS',
          verificationStatus: 'VERIFIED_OBSERVATION',
          knownLimitations: [
            'Confirms textual authenticity of the quoted excerpt only; does not validate the secondary user interpretation.',
          ],
        },
        {
          evidenceId: 'ev_nasa_surrounding_context',
          componentId: 'comp_omitted_context',
          sourceTitle: 'NASA Apollo 11 Preliminary Science Report (NASA SP-214) — Photographic Equipment and Results',
          sourceUrl: 'https://www.hq.nasa.gov/alsj/a11/as11psr.pdf#page=45',
          retrievalTimestamp: 1730585000000,
          sourceType: 'government',
          provenance: {
            originAgencyOrAuthor: 'NASA Manned Spacecraft Center / Photographic Technology Laboratory',
            isIndependentOfSubject: false,
            independenceValidation: 'Primary technical documentation detailing camera calibration parameters.',
          },
          sourceIndependence: {
            publisherIndependentOfSubject: false,
            underlyingDataIndependentOfSubject: false,
            analysisIndependentlyConducted: false,
            corroborationType: 'subject_self_reporting',
          },
          automatedVerification: {
            urlResolved: true,
            passageLocated: true,
            passageMatchesSource: true,
            supportsClaimComponent: true,
            verificationMethod: 'retrieved_text_and_passage_match',
            lastVerifiedAt: '2026-11-02T22:15:00Z',
            locatedContextSnippet: 'Because the surface scenes were in full sunlight (approximately 13 000 ft-c), exposure times of 1/250 sec at f/5.6 to f/11 were required. Under these daytime exposure conditions, light from background stars is insufficient to expose the film.',
            omittedContextDetected: true,
            omittedContextExplanation: 'Crucial qualifying paragraph immediately following the quoted sentence was omitted. It explains that 1/250s daylight exposure prevents faint stellar light from registering, refuting the claim that absent stars indicate studio staging.',
          },
          exactPassage: 'Because the surface scenes were in full sunlight (approximately 13 000 ft-c), exposure times of 1/250 sec at f/5.6 to f/11 were required. Under these daytime exposure conditions, light from background stars is insufficient to expose the film.',
          claimComponentAddressed: 'Crucial surrounding paragraphs explaining camera exposure settings were deliberately omitted.',
          relationship: 'CONTRADICTS',
          verificationStatus: 'VERIFIED_OBSERVATION',
          knownLimitations: [
            'Documents the authentic surrounding textual context of the cited report.',
          ],
        },
      ],
      inferentialBridgeSummary:
        'The speaker presents a genuine quotation from authentic NASA documentation but commits quote mining by omitting the explanatory paragraph immediately adjacent to it. The omitted text specifies that daytime camera exposure (1/250 sec at f/5.6–f/11 under 13,000 ft-c solar lux) accounts for the lack of background stars. Restoring the context refutes the allegation of staging.',
      overallSynthesis: {
        premisesVerdict: 'MIXED_PREMISES',
        conclusionVerdict: 'CONCLUSION_UNSUPPORTED_BY_PREMISES',
        finalAdjudication:
          'Misleading (Context Omission): An authentic document was cited, but essential qualifying context was omitted to fabricate an unsupported conclusion. The document refutes rather than proves staging.',
      },
    };

    // 3. Mock Model Verification with Automated Verification & Calibrated Confidence
    const mockGenerateContent = jest
      .fn()
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
                          claimId: 'claim_adversarial_context_omission',
                          claim: claimText,
                          claimType: 'HISTORICAL_FACT',
                          nature: 'VERIFIABLE_FACT',
                          label: 'MISLEADING',
                          evidenceLevel: 'CONTRADICTED',
                          rating: null,
                          confidence: null,
                          calibratedConfidence: {
                            claimDecomposition: 0.98,
                            premiseAssessment: 0.96,
                            sourceVerification: 0.94,
                            inferenceAssessment: 0.97,
                            overallVerdict: 0.96,
                          },
                          freshness: 'Timeless',
                          summary:
                            'Misleading (Context Omission). The user correctly cites words from genuine NASA documentation, but commits quote mining by omitting the immediately adjacent paragraph that details camera exposure settings (1/250 sec at f/5.6–f/11 under 13,000 foot-candles of daylight). When the full document context is restored, NASA documentation explains standard photographic physics under solar illumination and does not support or prove a staged landing.',
                          verifiedFacts: [
                            'The cited document is authentic NASA Apollo 11 documentation (NASA SP-214).',
                            'The quotation selectively extracts a description while omitting the adjacent paragraph explaining camera shutter speeds and solar lux.',
                            'Restoring the omitted context demonstrates that the document explains daylight exposure thresholds, directly contradicting the staging allegation.',
                          ],
                          missingEvidence: [
                            'Zero empirical documentation or authentic archival records substantiate that NASA documentation admits or proves a staged landing.',
                          ],
                          evidenceAssessment: {
                            scripturalSupport: 'NOT_APPLICABLE',
                            independentHistoricalCorroboration: 'DOCUMENTED',
                            empiricalVerification: 'CONTRADICTED',
                          },
                          misinformationVerdict: 'MISINFORMATION',
                          confidenceMeaning:
                            'Measures confidence in automated document text matching, detection of selective paragraph omission, and contextual contradiction of the staging inference.',
                          framingAssessment:
                            'Adversarial quote-mining and selective omission manipulation. A genuine document citation is presented without its surrounding qualifying paragraph to deceive the audience.',
                          epistemicLimitations: [
                            'Direct text comparison with the original document confirms exact wording and reveals the omitted qualifying context.',
                          ],
                          evidenceTraceability: mockTraceability,
                          citedEvidenceIds: ['E1'],
                          sources: [
                            {
                              title: 'NASA Apollo 11 Preliminary Science Report (NASA SP-214)',
                              url: 'https://www.hq.nasa.gov/alsj/a11/as11psr.pdf',
                              snippet: 'Exposure times of 1/250 sec at f/5.6 to f/11 were required under full sunlight.',
                              sourceType: 'government',
                              whatItSupports: 'Authentic primary documentation explaining camera exposure parameters',
                              whatItDoesNotEstablish: 'Does not support the staging conclusion',
                              sourceRole: 'primary_documentation',
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
                      steelManDefense:
                        'The user correctly located and quoted language from an authentic NASA report.',
                      inquisitorChallenge:
                        'The quotation selectively excises the explanatory paragraph explaining exposure times, reversing the evidentiary meaning of the document.',
                      evidentiaryBalance:
                        'Authentic document confirmed, but context omission decisively refutes the claim that the document proves staging.',
                      detectedFallacies: ['CHERRY_PICKING', 'FALLACY_OF_EXCLUSION', 'NON_SEQUITUR'],
                      secondaryVerdict: 'CONFIRMED_FALSE',
                      concursWithPrimary: true,
                      adjudicationRationale:
                        'Selective omission manipulation confirmed against original document text. The document does not prove staging.',
                      bayesFactor: 0.0001,
                      priorProbability: 0.001,
                      epistemicConfidence: 0.96,
                    }),
                  },
                ],
              },
            },
          ],
        },
      });

    const cwService = createClosedWorldService(claimText, [
      {
        evidenceId: 'E1',
        title: 'NASA Apollo 11 Preliminary Science Report (NASA SP-214)',
        url: 'https://www.hq.nasa.gov/alsj/a11/as11psr.pdf',
        domain: 'hq.nasa.gov',
        publisher: 'NASA Manned Spacecraft Center',
        snippet: 'Exposure times of 1/250 sec at f/5.6 to f/11 were required under full sunlight; Apollo 11 photographs camera optics.',
        tier: 'A',
      },
    ]);

    (cwService as any).genAI = {
      getGenerativeModel: jest.fn().mockReturnValue({
        generateContent: mockGenerateContent,
      }),
    };

    const results = await cwService.verifyClaimBatch(
      [
        {
          claimId: 'claim_adversarial_context_omission',
          text: claimText,
          nature: ClaimNature.VERIFIABLE_FACT,
          framing: FramingStyle.MANIPULATIVE,
          confidence: 0.98,
          importance: 0.95,
          chunkIndex: 0,
          start: 0,
          end: claimText.length,
        },
      ],
      'Science',
      {
        groundingMode: 'never',
        forcePro: false,
        minSourcesRequired: 1,
        sourceDiversityRequired: false,
      }
    );

    expect(results.length).toBe(1);
    const verified = results[0];

    // 4. Validate Context Omission Detection & Automated Verification
    expect(verified.evidenceTraceability).toBeDefined();
    const trace = verified.evidenceTraceability!;

    const omittedEvidence = trace.evidenceTraces.find(
      (e) => e.evidenceId === 'ev_nasa_surrounding_context'
    );
    expect(omittedEvidence).toBeDefined();
    expect(omittedEvidence?.automatedVerification?.omittedContextDetected).toBe(true);
    expect(omittedEvidence?.automatedVerification?.omittedContextExplanation).toContain(
      'Crucial qualifying paragraph immediately following the quoted sentence was omitted'
    );
    expect(omittedEvidence?.automatedVerification?.urlResolved).toBe(true);
    expect(omittedEvidence?.automatedVerification?.passageLocated).toBe(true);

    // 5. Validate Multi-Dimensional Source Independence Matrix
    expect(omittedEvidence?.sourceIndependence).toBeDefined();
    expect(omittedEvidence?.sourceIndependence?.publisherIndependentOfSubject).toBe(false);
    expect(omittedEvidence?.sourceIndependence?.corroborationType).toBe('subject_self_reporting');

    // 6. Validate Calibrated Confidence Breakdown
    expect(verified.calibratedConfidence).toBeDefined();
    expect(verified.calibratedConfidence?.claimDecomposition).toBeGreaterThanOrEqual(0.95);
    expect(verified.calibratedConfidence?.sourceVerification).toBeGreaterThanOrEqual(0.9);
    expect(verified.calibratedConfidence?.inferenceAssessment).toBeGreaterThanOrEqual(0.95);

    // 7. Validate Status & Verdict
    expect(verified.status).toBe('misleading');
    expect(verified.misinformationVerdict).toBe('MISINFORMATION');
    expect(verified.reasoning).toContain('Context Omission');
  });
});
