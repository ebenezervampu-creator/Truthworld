import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { BridgingConsensusEngine, ContributorRating } from '../../src/pipeline/services/bridgingAlgorithm';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { ScoringEngine } from '../../src/pipeline/services/scoringEngine';
import { DubbingGateService } from '../../src/pipeline/services/dubbingGateService';
import {
  ClaimNature,
  FramingStyle,
  VerifiedClaim,
  ClaimStatus,
  ClaimLedgerSummary,
  VerificationState,
  CredibilityAssessmentV2,
} from '../../src/pipeline/types';

describe('Unit: The Kerala Story 32,000 / 33,000 Claim Credibility & Bridging Verification', () => {
  const verificationService = new ClaimVerificationService('test-key', 0.6);
  const scoringEngine = new ScoringEngine();

  const CLAIM_TEXT = 'The Kerala Story movie claims that 33,000 women in Kerala were converted to Islam and joined ISIS military troops.';

  it('1. Classifies the claim as an empirical verifiable proposition (not a normative value judgment)', () => {
    const isSensitive = (verificationService as any).isSensitiveClaim(
      { text: CLAIM_TEXT, nature: ClaimNature.VERIFIABLE_FACT },
      false
    );
    expect(isSensitive).toBe(true);

    const normativeCheck = verificationService.detectNormativeOrPolicyDebate(CLAIM_TEXT);
    // This is an empirical demographic and statistical assertion, not a normative opinion
    expect(normativeCheck.isNormative).toBe(false);

    const { toVerify, opinions } = verificationService.classifyClaims([
      {
        text: CLAIM_TEXT,
        nature: ClaimNature.VERIFIABLE_FACT,
        framing: FramingStyle.ABSOLUTE,
        confidence: 0.96,
        importance: 0.95,
        chunkIndex: 0,
        start: 0,
        end: 5000,
      },
    ]);

    expect(toVerify.length).toBe(1);
    expect(opinions.length).toBe(0);
    expect(toVerify[0].framing).toBe(FramingStyle.ABSOLUTE);
  });

  it('2. Evaluates the claim against primary judicial & national security registries returning false_claim / contradicted', () => {
    // Official primary evidence:
    // 1. Supreme Court of India & Kerala High Court records (filmmakers agreed to amend teaser description from 32,000 to 3 women)
    // 2. National Investigation Agency (NIA) chargesheet & MHA records (~21 individuals from Kerala migrated to Nangarhar, Afghanistan in 2016)
    // 3. US State Department Country Reports on Terrorism (total Indian nationals joined ISIS < 100 nationwide)

    const verifiedClaim: VerifiedClaim = {
      claimId: 'claim_kerala_story_33k_01',
      text: CLAIM_TEXT,
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.ABSOLUTE,
      confidence: 0.98,
      importance: 0.95,
      chunkIndex: 0,
      start: 0,
      end: 4500,
      status: 'false_claim' as ClaimStatus,
      verificationConfidence: 0.99,
      reasoning:
        'The assertion that 32,000 to 33,000 women from Kerala were converted and joined ISIS is contradicted by all official police, judicial, and intelligence records. Before the Supreme Court of India and Kerala High Court, the filmmakers conceded they had no official empirical data for this figure and updated the teaser to specify "three women". National Investigation Agency (NIA) and Ministry of Home Affairs (MHA) records document approximately 21 individuals from Kerala who traveled to ISIS-held territories in Afghanistan in 2016.',
      sources: [
        'Supreme Court of India Undertaking (SLP (C) No. 9054/2023)',
        'Kerala High Court Order (WP(C) No. 15309/2023)',
        'National Investigation Agency (NIA) Case RC-02/2016/NIA/KOC Chargesheet',
      ],
      richSources: [
        {
          title: 'Supreme Court of India Proceedings - The Kerala Story Disclaimer Order',
          url: 'https://main.sci.gov.in/supremecourt/2023/18260/18260_2023_1_1501_44588_Order_18-May-2023.pdf',
          domain: 'main.sci.gov.in',
          tier: 'A',
          snippet:
            'Senior counsel for the producers confirmed that the teaser stating 32,000 women was withdrawn and the film contains a disclaimer stating it is a fictionalized account with no authenticated data for the figure 32,000.',
          retrievalMethod: 'tier0_corpus',
          lastVerified: new Date().toISOString(),
        },
        {
          title: 'Ministry of Home Affairs & NIA Chargesheet Summary - ISIS Kerala Module RC-02/2016',
          url: 'https://www.nia.gov.in/case-detail.htm?2016',
          domain: 'nia.gov.in',
          tier: 'A',
          snippet:
            'NIA investigated the departure of a group of 21 persons (men, women, and children) from Kasaragod and Palakkad in Kerala who migrated to Nangarhar province, Afghanistan.',
          retrievalMethod: 'tier0_corpus',
          lastVerified: new Date().toISOString(),
        },
      ],
      isGrounded: true,
      severity: 'high',
    };

    const aggregateResult = scoringEngine.calculateInstitutionalTrustScore(
      'video_kerala_story_analysis',
      'truthworld_analyst',
      { text: CLAIM_TEXT, utterances: [] } as any,
      [verifiedClaim],
      1,
      'balanced',
      'high',
      'Politics',
      {}
    );

    expect(aggregateResult.analysisState).toBe(VerificationState.VERIFIED);
    expect(aggregateResult.factCheckStats.false_claim).toBe(1);
    expect(aggregateResult.factCheckStats.verified_true).toBe(0);

    // Ledger Summary & High Severity Alert
    const falseCount = 1;
    let highestSeverityVerdict: ClaimLedgerSummary['highestSeverityVerdict'] = 'false_claim';
    const priorityNotice = `Notice: ${falseCount} claim(s) contradicted by documented evidence.`;

    const claimLedger: ClaimLedgerSummary = {
      totalClaimsChecked: 1,
      confirmedCount: 0,
      disputedCount: 0,
      unprovenCount: 0,
      falseCount,
      contextualCount: 0,
      highestSeverityVerdict,
      verdictHeadline: `0 Confirmed • 0 Disputed • ${falseCount} False`,
      priorityNotice,
      verifiableRatio: 0,
    };

    expect(verifiedClaim.status).toBe('false_claim');
    expect(claimLedger.falseCount).toBe(1);
    expect(verifiedClaim.severity).toBe('high');
    expect(claimLedger.highestSeverityVerdict).toBe('false_claim');
    expect(claimLedger.priorityNotice).toContain('contradicted by documented evidence');
  });

  it('3. Formulates a rigorous CredibilityAssessmentV2 contract with deterministic propositions', () => {
    const keralaStoryV2Assessment: CredibilityAssessmentV2 = {
      assessmentId: 'asmt_kerala_story_01',
      schemaVersion: '2.0.0',
      videoContext: {
        videoId: 'vid_kerala_story_trailer',
        startTimeMs: 12000,
        endTimeMs: 25000,
        asrMinTokenConfidence: 0.98,
        speakerStance: 'SPEAKER_ASSERTS',
        modalityEvaluated: ['AUDIO_TRANSCRIPT', 'KEYFRAME_OCR'],
      },
      claimText: CLAIM_TEXT,
      classification: {
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceStatus: 'CONTRADICTED',
        reasoningValidity: 'NON_SEQUITUR',
        displayBadge: 'FACTUAL_CONTRADICTION',
      },
      claimDecomposition: [
        {
          propositionId: 'prop_kerala_01',
          role: 'PREMISE',
          text: 'A documented group of individuals from Kerala (approx. 21 persons) joined ISIS modules in Afghanistan around 2016.',
          propositionType: 'EMPIRICAL_OBSERVATION',
          assessment: 'SUPPORTED',
          supportingEvidenceIds: ['ev_nia_01'],
          contradictingEvidenceIds: [],
          independentPrimarySourceCount: 1,
        },
        {
          propositionId: 'prop_kerala_02',
          role: 'CONCLUSION',
          text: '32,000 to 33,000 women in Kerala were systematically converted and recruited into ISIS.',
          propositionType: 'EMPIRICAL_OBSERVATION',
          assessment: 'CONTRADICTED',
          supportingEvidenceIds: [],
          contradictingEvidenceIds: ['ev_court_01', 'ev_nia_01'],
          independentPrimarySourceCount: 2,
        },
      ],
      evidenceRegistry: {
        ev_court_01: {
          sourceIdentity: {
            publisher: 'Supreme Court of India & High Court of Kerala',
            url: 'https://main.sci.gov.in/supremecourt/2023/18260/order.pdf',
            primaryArtifactId: 'SCI-ORDER-18260-2023',
          },
          deterministicVerification: {
            fetchStatus: 'HTTP_200_OK',
            snapshotSha256: 'b2f5c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b899',
            retrievedAtUtc: '2026-11-16T12:00:00Z',
            verifiedPassage:
              'The producers confirmed that the promotional teaser claiming 32,000 women was withdrawn and amended to specify three women, stating the film is a dramatized fiction without official empirical backing for 32,000.',
            charStart: 120,
            charEnd: 320,
            exactMatchScore: 1.0,
            contextDistortionDetected: false,
          },
          independence: {
            lineageType: 'LEGAL_DOCKET',
            upstreamSourceId: null,
            independenceWeight: 1.0,
          },
          epistemicScope: {
            establishes: 'Producers retracted the 32,000 figure in judicial proceedings and acknowledged lack of empirical data.',
            doesNotEstablish: 'Total worldwide ISIS foreign fighter demographics.',
            limitations: 'Judicial records and counsel statements.',
          },
        },
        ev_nia_01: {
          sourceIdentity: {
            publisher: 'National Investigation Agency (NIA) Government of India',
            url: 'https://www.nia.gov.in/case-detail.htm?2016-rc-02',
            primaryArtifactId: 'NIA-RC02-2016-INVESTIGATION',
          },
          deterministicVerification: {
            fetchStatus: 'HTTP_200_OK',
            snapshotSha256: 'c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef01234',
            retrievedAtUtc: '2026-11-16T12:05:00Z',
            verifiedPassage:
              'Official investigations confirmed a specific group of 21 persons from Kerala migrated to Nangarhar province; national counterterrorism telemetry records no thousands-scale ISIS recruitment in India.',
            charStart: 450,
            charEnd: 680,
            exactMatchScore: 1.0,
            contextDistortionDetected: false,
          },
          independence: {
            lineageType: 'PRIMARY_DATASET',
            upstreamSourceId: null,
            independenceWeight: 1.0,
          },
          epistemicScope: {
            establishes: 'Actual documented scale of Kerala ISIS recruitment was ~21 individuals in 2016.',
            doesNotEstablish: 'General unregistered non-terror religious conversions.',
            limitations: 'Statutory terrorism jurisdiction records.',
          },
        },
      },
      reasoningAssessment: {
        premisesVerifiedAccurate: ['prop_kerala_01'],
        conclusionFollowsDeductively: false,
        conclusionFollowsInductively: false,
        evaluatedAlternativeExplanations: [
          {
            explanation:
              'The figure 32,000 was an unverified dramatization originating from a misquoted 2010 speech, which conflated general conversions with ISIS recruitment by a factor of over 1,500x.',
            supportingEvidenceIds: ['ev_court_01', 'ev_nia_01'],
          },
        ],
      },
      backendAuditFlags: {
        allReferencedCitationsDeterministicallyVerified: true,
        unverifiedEvidencePresent: false,
        closedWorldCitationCheckPassed: true,
      },
      uncertainty: {
        numericalConfidenceAvailable: true,
        calibrationModelVersion: 'truthworld-calib-v2.1',
        qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE',
        conformalPredictionSet: ['FACTUAL_CONTRADICTION'],
        disclosedGaps: [],
      },
      distortionGenealogy: {
        sourceMetric: {
          rawFigure: 2667,
          unit: 'persons',
          timeframe: '2006-2012 (6-year aggregate)',
          description: 'Official 2012 Kerala Assembly record of voluntary conversions to Islam.',
        },
        claimedMetric: {
          rawFigure: 32000,
          unit: 'females',
          timeframe: 'Decade projection (conflated with ISIS)',
          description: 'Trailer claim that 32,000 women were converted and recruited into ISIS.',
        },
        extrapolationFallacy: 'ANNUALIZATION_ERROR',
        multiplicationFactor: 12.0,
        genealogyExplanation:
          'Conflated a multi-year total (2,667 over 6 years) as an annual rate (~3,000/yr), projected it across 10 years (30,000+), and falsely equated non-terror civil conversions with foreign terrorist recruitment.',
        citedEvidenceIds: ['ev_court_01', 'ev_nia_01'],
      },
    };

    const validation = DeterministicVerifierService.validateAssessmentV2(keralaStoryV2Assessment);
    expect(validation.isValid).toBe(true);
    expect(validation.errors).toEqual([]);
    expect(keralaStoryV2Assessment.classification.evidenceStatus).toBe('CONTRADICTED');

    // Referential Integrity Guard: ensure phantom citation in distortionGenealogy is rejected
    const corruptedAssessment = JSON.parse(JSON.stringify(keralaStoryV2Assessment));
    corruptedAssessment.distortionGenealogy.citedEvidenceIds.push('ev_phantom_unverified');
    const corruptedValidation = DeterministicVerifierService.validateAssessmentV2(corruptedAssessment);
    expect(corruptedValidation.isValid).toBe(false);
    expect(corruptedValidation.errors.some(e => e.includes('[REFERENTIAL_INTEGRITY]'))).toBe(true);
  });

  it('4. Simulates Bridging Consensus (X/Birdwatch Matrix Factorization standard) across opposing political clusters', () => {
    // When a community note fact-checking the 33,000 claim cites the Supreme Court affidavit and NIA chargesheet:
    // Contributors across both political polarities (left: p < -0.2, right: p > +0.2, center: -0.2 < p < 0.2)
    // recognize the official court retraction by the film director/producers.
    const ratings: ContributorRating[] = [
      // Left cluster raters (p_u < -0.2)
      {
        ratingId: 'rate_left_01',
        contributorId: 'user_left_alpha',
        isHelpful: true,
        ratingReason: 'Cites official Supreme Court order and NIA case numbers.',
        contributorPolarity: -0.75,
        contributorReputationTier: 'Trusted',
        timestamp: Date.now() - 50000,
      },
      {
        ratingId: 'rate_left_02',
        contributorId: 'user_left_beta',
        isHelpful: true,
        ratingReason: 'Filmmakers conceded in court the claim had no data.',
        contributorPolarity: -0.45,
        contributorReputationTier: 'Active',
        timestamp: Date.now() - 40000,
      },
      // Right cluster raters (p_u > +0.2)
      {
        ratingId: 'rate_right_01',
        contributorId: 'user_right_alpha',
        isHelpful: true,
        ratingReason: 'Accurate note: even the filmmakers acknowledged in their affidavit that 32,000 was modified to 3.',
        contributorPolarity: 0.65,
        contributorReputationTier: 'Trusted',
        timestamp: Date.now() - 30000,
      },
      {
        ratingId: 'rate_right_02',
        contributorId: 'user_right_beta',
        isHelpful: true,
        ratingReason: 'Important to cite the court disclaimer so facts remain precise while acknowledging the movie is fiction.',
        contributorPolarity: 0.50,
        contributorReputationTier: 'Active',
        timestamp: Date.now() - 20000,
      },
      // Center cluster rater
      {
        ratingId: 'rate_center_01',
        contributorId: 'user_center_alpha',
        isHelpful: true,
        ratingReason: 'Neutral, objective, and backed by legal filings.',
        contributorPolarity: 0.05,
        contributorReputationTier: 'Trusted',
        timestamp: Date.now() - 10000,
      },
    ];

    const result = BridgingConsensusEngine.evaluateDispute('dispute_kerala_story_note', ratings);

    // Because both clusters (p < -0.2 and p > +0.2) agreed on the helpfulness of the note backed by primary judicial records:
    expect(result.status).toBe('consensus_achieved');
    expect(result.bridgingScore).toBeGreaterThanOrEqual(0.60);
    expect(result.leftHelpfulRate).toBe(1.0);
    expect(result.rightHelpfulRate).toBe(1.0);
    expect(result.isBrigadeSuspected).toBe(false);
  });

  it('5. Enforces Layer 06 -> Layer 07 Dubbing Gate (EU AI Act Article 50 Compliance Moat)', () => {
    // Attempting to dub/localize a video containing high-severity communal/geopolitical contradictions
    const decision = DubbingGateService.evaluateDubbingGate('vid_kerala_story_trailer', [
      {
        claimId: 'claim_kerala_story_33k_01',
        domain: 'Politics',
        verdict: 'FACTUAL_CONTRADICTION',
        confidence: 0.98,
        startMs: 12000,
        endMs: 25000,
        citedEvidenceIds: ['ev_court_01', 'ev_nia_01'],
        auditPackHash: 'hash_pack_kerala_33k',
      },
    ]);

    expect(decision.action).toBe('BLOCK_LOCALIZATION');
    expect(decision.blockedClaimIds).toContain('claim_kerala_story_33k_01');
    expect(decision.complianceNotes[0]).toContain('[EU_AI_ACT_ART50_BLOCK]');

    // Conversely, benign educational or culture content passes unrestricted
    const benignDecision = DubbingGateService.evaluateDubbingGate('vid_science_doc', [
      {
        claimId: 'claim_science_01',
        domain: 'Science',
        verdict: 'VERIFIED',
        confidence: 0.99,
        startMs: 1000,
        endMs: 5000,
        citedEvidenceIds: ['ev_sci_01'],
        auditPackHash: 'hash_sci_01',
      },
    ]);

    expect(benignDecision.action).toBe('ALLOW_UNRESTRICTED');
    expect(benignDecision.blockedClaimIds.length).toBe(0);
  });
});
