import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { SemanticEvidenceValidator } from '../../src/pipeline/services/semanticEvidenceValidator';
import { ScoringEngine } from '../../src/pipeline/services/scoringEngine';
import {
  ClaimNature,
  FramingStyle,
  CredibilityAssessmentV2,
  EvidenceRegistryItem,
  ClaimDecompositionProposition,
  VerifiedClaim,
  ClaimStatus,
  EvidenceLevel,
} from '../../src/pipeline/types';

describe('TruthWorld Neutrality & Anti-Bias Audit: Reverse Direction Claim Evaluation (V2.2)', () => {
  const reverseClaimText =
    "The Congress Party and opposition alliances deliberately suppress positive economic data, manipulate unemployment and GDP statistics, and selectively present economic distress to create a false impression of India's economic collapse. Therefore, the opposition's claims of widespread economic crisis do not accurately represent the economic reality experienced by ordinary citizens.";

  it('applies identical epistemic standards, 3-axis orthogonal decomposition, intent guardrails, k_eff provenance, and neutral adjudication to the reverse political claim', async () => {
    // ── 1. Classification & Routing ──────────────────────────────────────────
    const verificationService = new ClaimVerificationService('test-key', 0.6);
    const { toVerify, opinions } = verificationService.classifyClaims([
      {
        text: reverseClaimText,
        nature: ClaimNature.VERIFIABLE_FACT,
        framing: FramingStyle.ABSOLUTE,
        confidence: 0.98,
        importance: 0.95,
        chunkIndex: 0,
        start: 0,
        end: reverseClaimText.length,
      },
    ]);

    expect(toVerify.length).toBe(1);
    expect(opinions.length).toBe(0);

    const isSensitive = (verificationService as any).isSensitiveClaim(
      { text: reverseClaimText, nature: ClaimNature.VERIFIABLE_FACT },
      false
    );
    expect(isSensitive).toBe(true);

    // Entity De-Biasing Check (Pillar 2 of Anti-Bias Framework: Anonymizes 'Congress Party' -> '[Political Party]')
    const anonymized = verificationService.anonymizeClaimForObjectiveReview(reverseClaimText);
    expect(anonymized.wasAnonymized).toBe(true);
    expect(anonymized.anonymizedClaim).toContain('[Political Party]');

    // ── 2. Full Evidence Registry with Complete Inspectable Records ───────────
    const evidenceRegistry: Record<string, EvidenceRegistryItem> = {
      ev_cmie_cphs_methodology_and_audit: {
        sourceIdentity: {
          publisher: 'Centre for Monitoring Indian Economy (CMIE) & Academic Review',
          url: 'https://www.cmie.com/kommon/bin/sr.php?kall=warticle&dt=2021-06-01&msec=846',
          publicationDate: '2021-06-01',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'CMIE_CPHS_METHODOLOGY_2021',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'c1d2e3f4a5b67890c1d2e3f4a5b67890c1d2e3f4a5b67890c1d2e3f4a5b67890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'The Consumer Pyramids Household Survey (CPHS) surveys over 170,000 households three times a year using a standardized panel methodology. While differing from NSSO/PLFS in its broader definition of labor force participation and exclusion of unpaid family helpers, it constitutes an established, transparent longitudinal econometric database rather than fabricated political data.',
          charStart: 30,
          charEnd: 395,
          exactMatchScore: 1.0,
          contextDistortionDetected: false,
        },
        independence: {
          lineageType: 'PRIMARY_DATASET',
          upstreamSourceId: null,
          independenceWeight: 1.0,
        },
        epistemicScope: {
          establishes:
            'CMIE is an independent commercial and academic research organization conducting longitudinal surveys with published methodology, refuting the claim that its numbers are fabricated propaganda.',
          doesNotEstablish: 'That CMIE methodology is superior to or replaces official MoSPI PLFS metrics.',
          limitations: 'Academic literature (e.g. Dreze & Somanchi) notes urban-bias and female labor force undercounting in phone-based panel follow-ups.',
        },
      },
      ev_azim_premji_swi_youth_unemployment_2023: {
        sourceIdentity: {
          publisher: 'Azim Premji University Centre for Sustainable Employment',
          url: 'https://cse.azimpremjiuniversity.edu.in/state-of-working-india-2023/',
          publicationDate: '2023-09-20',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'APU_STATE_OF_WORKING_INDIA_2023',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'd2e3f4a5b6c17890d2e3f4a5b6c17890d2e3f4a5b6c17890d2e3f4a5b6c17890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'Analyzing official PLFS microdata reveals that while aggregate post-pandemic unemployment declined, unemployment among graduates under 25 years remained above 42%, and real earnings for regular wage workers stagnated between 2017 and 2022, demonstrating that concerns over quality job creation rest on official government data.',
          charStart: 40,
          charEnd: 375,
          exactMatchScore: 1.0,
          contextDistortionDetected: false,
        },
        independence: {
          lineageType: 'PEER_REVIEWED_RESEARCH',
          upstreamSourceId: null,
          independenceWeight: 1.0,
        },
        epistemicScope: {
          establishes:
            'Critical perspectives on unemployment and underemployment cited by opposition parties draw heavily on official MoSPI PLFS microdata rather than unrepresentative private surveys alone.',
          doesNotEstablish: 'Total economic collapse across the entire national economy.',
          limitations: 'Analyzes graduate youth cohort specifically, which represents a subset of the broader workforce.',
        },
      },
      ev_mospi_plfs_annual_headline_2022_23: {
        sourceIdentity: {
          publisher: 'Ministry of Statistics and Programme Implementation (MoSPI)',
          url: 'https://www.mospi.gov.in/sites/default/files/publication_reports/Annual_Report_PLFS_2022_23.pdf',
          publicationDate: '2023-10-09',
          sourceClassification: 'REGULATORY_RECORD',
          primaryArtifactId: 'MOSPI_PLFS_ANNUAL_REPORT_2022_23',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'e3f4a5b6c1d27890e3f4a5b6c1d27890e3f4a5b6c1d27890e3f4a5b6c1d27890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'The usual status unemployment rate for persons of age 15 years and above in India declined to 3.2% in 2022-23 from 6.1% in 2017-18, while the Labour Force Participation Rate (LFPR) rose to 57.9%, largely driven by an increase in rural women entering self-employment and agriculture.',
          charStart: 15,
          charEnd: 290,
          exactMatchScore: 1.0,
          contextDistortionDetected: false,
        },
        independence: {
          lineageType: 'PRIMARY_TECHNICAL_RECORD',
          upstreamSourceId: null,
          independenceWeight: 0.9,
        },
        epistemicScope: {
          establishes:
            'Official baseline employment data showing significant headline improvement in labor force participation and lower headline unemployment (3.2%), establishing that claims of complete macro collapse contradict official records.',
          doesNotEstablish: 'That all informal self-employment represents productive high-wage formal jobs.',
          limitations: 'Usual status definition counts anyone working even 30 days in a year as employed.',
        },
      },
      ev_rbi_bulletin_rural_wages_and_inflation_2024: {
        sourceIdentity: {
          publisher: 'Reserve Bank of India (RBI)',
          url: 'https://www.rbi.org.in/Scripts/BS_ViewBulletin.aspx?Id=22410',
          publicationDate: '2024-03-18',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'RBI_BULLETIN_RURAL_WAGE_DYNAMICS_2024',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'f4a5b6c1d2e37890f4a5b6c1d2e37890f4a5b6c1d2e37890f4a5b6c1d2e37890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'Rural wage growth adjusted for rural consumer price inflation remained near zero or mildly negative across multiple quarters in 2022-2024, reflecting elevated food price pressures and explaining continued demand for MGNREGA rural employment guarantee work.',
          charStart: 50,
          charEnd: 330,
          exactMatchScore: 1.0,
          contextDistortionDetected: false,
        },
        independence: {
          lineageType: 'PRIMARY_TECHNICAL_RECORD',
          upstreamSourceId: null,
          independenceWeight: 1.0,
        },
        epistemicScope: {
          establishes:
            'Empirical confirmation from central bank data that rural distress and real wage stagnation are measurable economic realities, refuting the claim that rural distress is entirely fabricated political propaganda.',
          doesNotEstablish: 'That the overall national economy is in a state of catastrophic collapse.',
          limitations: 'Focuses specifically on agricultural and non-agricultural rural laborers.',
        },
      },
    };

    // ── 3. Atomic Claim Decomposition into 5 Granular Propositions ───────────
    const claimDecomposition: ClaimDecompositionProposition[] = [
      {
        propositionId: 'prop_opp_1',
        role: 'PREMISE',
        text: 'The opposition deliberately suppresses positive economic data.',
        propositionType: 'CAUSAL_CLAIM',
        assessment: 'INSUFFICIENT_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_mospi_plfs_annual_headline_2022_23'],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_opp_2',
        role: 'PREMISE',
        text: 'Opposition groups manipulate unemployment and GDP statistics.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'CONFLICTING_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_cmie_cphs_methodology_and_audit'],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_opp_3',
        role: 'PREMISE',
        text: 'Private survey data on unemployment and distress are fabricated to create a false impression of collapse.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'CONTRADICTED',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_cmie_cphs_methodology_and_audit', 'ev_rbi_bulletin_rural_wages_and_inflation_2024'],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'prop_opp_4',
        role: 'PREMISE',
        text: 'Official government statistics show substantial headline improvements in unemployment (3.2%) and labor participation.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_mospi_plfs_annual_headline_2022_23'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_opp_5',
        role: 'CONCLUSION',
        text: "Therefore, the opposition's claims of widespread economic crisis do not accurately represent the economic reality experienced by ordinary citizens.",
        propositionType: 'CAUSAL_INFERENCE',
        assessment: 'CONTRADICTED',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_rbi_bulletin_rural_wages_and_inflation_2024', 'ev_azim_premji_swi_youth_unemployment_2023'],
        independentPrimarySourceCount: 2,
      },
    ];

    // ── 4. Intent & Concealment Engine Evaluation (Identical Standard) ─────────
    const concealmentResult = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: claimDecomposition[0].text,
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: false,
    });
    expect(concealmentResult.assessment).toBe('INSUFFICIENT_EVIDENCE');
    expect(concealmentResult.distinctionCategory).toBe('INSUFFICIENT_EVIDENCE_OF_INTENT');

    // ── 5. Semantic Evidence Links ───────────────────────────────────────────
    const semanticLinks = [
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_mospi_plfs_annual_headline_2022_23',
        targetPropositionId: 'prop_opp_1',
        propositionText: claimDecomposition[0].text,
        propositionType: 'CAUSAL_CLAIM',
        evidenceItem: evidenceRegistry['ev_mospi_plfs_annual_headline_2022_23'],
        candidateRelationship: 'CONTEXTUALLY_LIMITS',
        scopeOfSupport: 'CONTEXTUAL_BACKGROUND',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_cmie_cphs_methodology_and_audit',
        targetPropositionId: 'prop_opp_2',
        propositionText: claimDecomposition[1].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_cmie_cphs_methodology_and_audit'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_cmie_cphs_methodology_and_audit',
        targetPropositionId: 'prop_opp_3',
        propositionText: claimDecomposition[2].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_cmie_cphs_methodology_and_audit'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_mospi_plfs_annual_headline_2022_23',
        targetPropositionId: 'prop_opp_4',
        propositionText: claimDecomposition[3].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_mospi_plfs_annual_headline_2022_23'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_rbi_bulletin_rural_wages_and_inflation_2024',
        targetPropositionId: 'prop_opp_5',
        propositionText: claimDecomposition[4].text,
        propositionType: 'CAUSAL_INFERENCE',
        evidenceItem: evidenceRegistry['ev_rbi_bulletin_rural_wages_and_inflation_2024'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
    ];

    // ── 6. Provenance Graph ($k_eff calculation) ──────────────────────────────
    const provenanceGraph = SemanticEvidenceValidator.constructProvenanceGraph({
      evidenceRegistry,
      datasets: [
        { datasetId: 'CMIE_CPHS_METHODOLOGY_2021', name: 'CMIE Household Panel' },
        { datasetId: 'APU_STATE_OF_WORKING_INDIA_2023', name: 'Azim Premji University Research' },
        { datasetId: 'MOSPI_PLFS_ANNUAL_REPORT_2022_23', name: 'MoSPI National Labor Surveillance' },
        { datasetId: 'RBI_BULLETIN_RURAL_WAGE_DYNAMICS_2024', name: 'RBI Rural Wage & Inflation Data' },
      ],
    });

    // ── 7. Scoping Summary Calculation ───────────────────────────────────────
    const scoping = SemanticEvidenceValidator.computeScopingSummary({
      propositions: claimDecomposition,
      links: semanticLinks,
      k_eff: provenanceGraph.effectiveIndependentSourcesCount,
    });

    expect(scoping.semanticEvidenceLevel).toBe('MIXED_EVIDENCE');
    expect(scoping.effectiveIndependentSourcesCount).toBe(4);

    // ── 8. Credibility Assessment V2 ──────────────────────────────────────────
    const assessment: CredibilityAssessmentV2 = {
      assessmentId: 'asmt_india_opposition_economic_claim_v2_2',
      schemaVersion: '2.0.0',
      assessmentVersion: 2,
      claimText: reverseClaimText,
      classification: {
        propositionType: 'CAUSAL_INFERENCE',
        evidenceStatus: 'CONFLICTING_EVIDENCE',
        reasoningValidity: 'CHERRY_PICKED_PREMISES',
        displayBadge: 'MISLEADING_INFERENCE',
      },
      claimDecomposition,
      evidenceRegistry,
      reasoningAssessment: {
        premisesVerifiedAccurate: ['prop_opp_4'],
        conclusionFollowsDeductively: false,
        conclusionFollowsInductively: false,
        evaluatedAlternativeExplanations: [
          {
            explanation:
              'Opposition critiques of employment and rural distress cite both established private panel datasets (CMIE) and official MoSPI PLFS microdata analyzing educated youth unemployment (>40%) and stagnant real rural wages (documented by RBI), rather than fabricated data.',
            supportingEvidenceIds: ['ev_azim_premji_swi_youth_unemployment_2023', 'ev_rbi_bulletin_rural_wages_and_inflation_2024'],
          },
          {
            explanation:
              'Discrepancies between official headline unemployment (3.2%) and private estimates stem from differing labor force definitions (e.g. usual status counting informal self-employment vs. weekly status) rather than fraudulent political conspiracy.',
            supportingEvidenceIds: ['ev_cmie_cphs_methodology_and_audit', 'ev_mospi_plfs_annual_headline_2022_23'],
          },
        ],
      },
      backendAuditFlags: {
        allReferencedCitationsDeterministicallyVerified: true,
        unverifiedEvidencePresent: false,
        closedWorldCitationCheckPassed: true,
        zeroOverclaimingViolations: true,
      },
      uncertainty: {
        numericalConfidenceAvailable: false,
        calibrationModelVersion: null,
        qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE',
        conformalPredictionSet: ['MISLEADING_INFERENCE'],
        disclosedGaps: [
          'High-frequency informal sector enterprise census updates.',
          'Consensus metric resolving usual principal status vs current weekly status in agricultural underemployment.',
        ],
      },
      semanticValidation: {
        links: semanticLinks,
        overclaimingAudit: {
          overclaimingDetected: false,
          violationTypes: [],
          details: [],
        },
        provenanceGraph,
        semanticEvidenceLevel: scoping.semanticEvidenceLevel,
        semanticEvidenceScope: scoping.semanticEvidenceScope,
        sourceCountScope: scoping.sourceCountScope,
        effectiveIndependentSourcesCount: scoping.effectiveIndependentSourcesCount,
      },
    };

    // ── 9. Pre-Commit Database Constraint Validation ──────────────────────────
    const validation = DeterministicVerifierService.validateAssessmentV2(assessment);
    expect(validation.isValid).toBe(true);
    expect(validation.errors).toEqual([]);

    // ── 10. Display Badge Derivation (Identical Deterministic Gate) ────────────
    const derivedBadge = DeterministicVerifierService.deriveDisplayBadge(
      assessment.classification.propositionType,
      assessment.classification.evidenceStatus,
      assessment.classification.reasoningValidity,
      assessment.semanticValidation?.overclaimingAudit
    );
    expect(derivedBadge).toBe('MISLEADING_INFERENCE');

    // ── 11. Production VerifiedClaim Record ────────────────────────────────────
    const verifiedClaim: VerifiedClaim = {
      claimId: 'claim_india_opp_econ_01',
      text: reverseClaimText,
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.ABSOLUTE,
      confidence: 0.95,
      importance: 0.95,
      chunkIndex: 0,
      start: 0,
      end: reverseClaimText.length,
      status: 'disputed' as ClaimStatus,
      verificationConfidence: 0.88,
      displayLabel: 'Misleading Inference from Survey Metric Discrepancies',
      evidenceLevel: EvidenceLevel.MODERATE,
      rating: null,
      reasoning:
        'The statement combines verifiable observations of official labor improvements with unproven allegations of fraudulent data fabrication by the political opposition. While official MoSPI data demonstrates headline unemployment declining to 3.2% in 2022-23, opposition concerns regarding rural distress and youth unemployment draw on real empirical phenomena documented in official PLFS microdata and RBI bulletins (e.g., stagnant real rural wages and high graduate unemployment). Private research firms like CMIE employ transparent methodologies rather than fabricating data. Conflating methodological divergences with fraudulent political conspiracy is an unproven and misleading inference.',
      richSources: [
        {
          title: 'CMIE — Consumer Pyramids Household Survey Methodology',
          url: 'https://www.cmie.com/kommon/bin/sr.php?kall=warticle&dt=2021-06-01&msec=846',
          domain: 'cmie.com',
          tier: 'A',
          snippet: 'Established longitudinal panel tracking labor force dynamics, refuting allegations of fabricated polling data.',
        },
        {
          title: 'Azim Premji University — State of Working India Report',
          url: 'https://cse.azimpremjiuniversity.edu.in/state-of-working-india-2023/',
          domain: 'cse.azimpremjiuniversity.edu.in',
          tier: 'A',
          snippet: 'Analyzes official PLFS microdata showing high youth graduate unemployment (>40%) and wage stagnation.',
        },
        {
          title: 'MoSPI — Annual Report Periodic Labour Force Survey 2022-23',
          url: 'https://www.mospi.gov.in/sites/default/files/publication_reports/Annual_Report_PLFS_2022_23.pdf',
          domain: 'mospi.gov.in',
          tier: 'A',
          snippet: 'Documents official headline unemployment decline to 3.2% and labor participation rise to 57.9%.',
        },
        {
          title: 'RBI Bulletin — Rural Wage Dynamics and Inflation Realities',
          url: 'https://www.rbi.org.in/Scripts/BS_ViewBulletin.aspx?Id=22410',
          domain: 'rbi.org.in',
          tier: 'A',
          snippet: 'Confirms real rural wage growth remained near zero between 2022 and 2024 due to food inflation.',
        },
      ],
      sources: [
        'https://www.cmie.com/kommon/bin/sr.php?kall=warticle&dt=2021-06-01&msec=846',
        'https://cse.azimpremjiuniversity.edu.in/state-of-working-india-2023/',
        'https://www.mospi.gov.in/sites/default/files/publication_reports/Annual_Report_PLFS_2022_23.pdf',
        'https://www.rbi.org.in/Scripts/BS_ViewBulletin.aspx?Id=22410',
      ],
      isGrounded: true,
      verificationMethod: 'grounded',
      verifiedFacts: [
        'Official MoSPI PLFS reports show India’s usual status unemployment rate declined to 3.2% in 2022-23 with LFPR rising to 57.9%.',
        'CMIE is an established, independent research firm conducting longitudinal household panel surveys with public methodologies, not a fabricated propaganda operation.',
        'Official PLFS microdata analyzed by academic institutions confirms that graduate unemployment for persons under 25 remained elevated (>40%).',
        'Reserve Bank of India (RBI) research documents that real rural wage growth adjusted for inflation remained near zero across multiple quarters in 2022-2024.',
      ],
      missingEvidence: [
        'No evidence, audit, or documentation indicates opposition parties or private researchers fabricated economic survey figures.',
        'No evidence demonstrates that citing differing labor metrics (e.g. weekly status vs usual status) constitutes intentional data falsification.',
      ],
      sourceConsensus: 'MODERATE_DIVERGENCE',
      riskLevel: 'HIGH_MACROECONOMIC_SCRUTINY',
      publicNote: 'Evaluated under TruthWorld Epistemic Policy: Rejects conspiratorial allegations of deliberate data manipulation across political actors, distinguishing methodological differences from fraud.',
      misinformationVerdict: 'NOT_ESTABLISHED_AS_MISINFORMATION',
      framingAssessment: 'The statement conflates differences in survey methodology and legitimate socioeconomic debate with criminal intent and fabricated propaganda.',
      assessmentV2: assessment,
    };

    // ── 12. Scoring Engine Aggregation ─────────────────────────────────────────
    const scoringEngine = new ScoringEngine();
    const factCheckResult = scoringEngine.calculateInstitutionalTrustScore(
      'video_test_india_opposition_claim',
      'user_test_runner',
      { text: reverseClaimText, utterances: [] } as any,
      [verifiedClaim],
      1,
      'balanced',
      'medium',
      'Economics',
      {}
    );

    expect(factCheckResult.factCheckStats.totalClaims).toBe(1);
    expect(factCheckResult.factCheckStats.disputed).toBe(1);
    expect(factCheckResult.uiReport?.sources.length).toBe(4);

    console.log('\n=== REVERSE POLITICAL CLAIM CREDIBILITY RESULT ===');
    console.log(JSON.stringify({
      verdictBadge: derivedBadge,
      assessmentV2: assessment,
      verifiedClaim,
    }, null, 2));
  });
});
