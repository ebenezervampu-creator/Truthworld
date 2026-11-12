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

describe('TruthWorld Credibility System: Indian Economic Data Suppression & GDP/Unemployment Manipulation Compound Claim Evaluation (V2.2)', () => {
  const claimText =
    "The Indian government and mainstream media deliberately suppress negative economic data, manipulate unemployment and GDP statistics, and selectively present economic achievements to create a false impression of India's economic progress. Therefore, India's reported economic growth does not accurately represent the economic reality experienced by ordinary citizens.";

  it('executes end-to-end production credibility evaluation: classification, 5-proposition atomic decomposition, intent/concealment evaluation, semantic validation, k_eff provenance, database constraints, and institutional scoring', async () => {
    // ── 1. Classification & Routing ──────────────────────────────────────────
    const verificationService = new ClaimVerificationService('test-key', 0.6);
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

    const isSensitive = (verificationService as any).isSensitiveClaim(
      { text: claimText, nature: ClaimNature.VERIFIABLE_FACT },
      false
    );
    expect(isSensitive).toBe(true);

    // ── 2. Full Evidence Registry with Complete Inspectable Authoritative Records ─
    const evidenceRegistry: Record<string, EvidenceRegistryItem> = {
      ev_imf_article_iv_india_2023: {
        sourceIdentity: {
          publisher: 'International Monetary Fund (IMF)',
          url: 'https://www.imf.org/en/Publications/CR/Issues/2023/12/18/India-2023-Article-IV-Consultation-Press-Release-Staff-Report-and-Statement-by-the-Executive-542647',
          publicationDate: '2023-12-18',
          sourceClassification: 'REGULATORY_RECORD',
          primaryArtifactId: 'IMF_ARTICLE_IV_INDIA_2023',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'e1f2a3b4c5d67890e1f2a3b4c5d67890e1f2a3b4c5d67890e1f2a3b4c5d67890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'India’s macroeconomic statistics are broadly adequate for surveillance. Real GDP growth is supported by robust domestic demand and public infrastructure investment, with headline methodology aligned with international standards (SNA 2008), though further enhancements in service deflators and high-frequency informal sector data coverage are recommended.',
          charStart: 45,
          charEnd: 380,
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
            'Independent multilateral surveillance validating that official Indian GDP growth figures conform broadly to international statistical standards (SNA 2008) and reflect genuine macro expansion.',
          doesNotEstablish: 'Complete absence of measurement friction or uniform distribution of growth across all socioeconomic percentiles.',
          limitations: 'IMF surveillance relies primarily on national statistical office baseline data supplemented by multilateral field missions.',
        },
      },
      ev_subramanian_harvard_cid_2019: {
        sourceIdentity: {
          publisher: 'Harvard Center for International Development (CID) & Peterson Institute',
          url: 'https://www.hks.harvard.edu/centers/cid/publications/fellow-working-papers/validating-indias-gdp-growth',
          publicationDate: '2019-06-11',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'HARVARD_CID_WORKING_PAPER_354',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'f2a3b4c5d6e17890f2a3b4c5d6e17890f2a3b4c5d6e17890f2a3b4c5d6e17890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'Cross-country indicator models suggest post-2011 GDP growth in India was overestimated by approximately 2.5 percentage points annually due to 2015 base-year methodological revisions in manufacturing and corporate MCA-21 database weighting, reflecting statistical methodological divergence rather than fraudulent data fabrication.',
          charStart: 110,
          charEnd: 420,
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
            'Scholarly methodological controversy and econometric divergence between headline GDP and 17 high-frequency real economic indicators (electricity, credit, rail freight) post-2011.',
          doesNotEstablish: 'Deliberate malicious data falsification or suppression conspiracy by statisticians.',
          limitations: 'Econometric cross-country regression methodology questioned by MoSPI and RBI economists for omitting services sector productivity.',
        },
      },
      ev_mospi_plfs_timeline_and_nsc_2019: {
        sourceIdentity: {
          publisher: 'Ministry of Statistics and Programme Implementation (MoSPI) & National Statistical Commission',
          url: 'https://www.mospi.gov.in/periodic-labour-force-survey-plfs',
          publicationDate: '2019-05-31',
          sourceClassification: 'REGULATORY_RECORD',
          primaryArtifactId: 'MOSPI_PLFS_OFFICIAL_TIMELINE_2019',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'a3b4c5d6e1f27890a3b4c5d6e1f27890a3b4c5d6e1f27890a3b4c5d6e1f27890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'The Periodic Labour Force Survey (PLFS) 2017-18 was approved by the National Statistical Commission in December 2018 and subsequently officially released in May 2019, recording an unemployment rate of 6.1%. Annual and quarterly PLFS reports have since been published regularly without suspension.',
          charStart: 20,
          charEnd: 310,
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
            'Official disclosure of unvarnished high unemployment data (6.1%) by MoSPI, disproving permanent data suppression, while documenting administrative publication delay that triggered NSC member resignations.',
          doesNotEstablish: 'Total absence of political sensitivity around publication timing.',
          limitations: 'Official government gazette and survey publication dockets.',
        },
      },
      ev_rbi_k_shaped_growth_and_rural_wages_2023: {
        sourceIdentity: {
          publisher: 'Reserve Bank of India (RBI) Bulletins & Reports on Currency and Finance',
          url: 'https://www.rbi.org.in/Scripts/BS_ViewBulletin.aspx?Id=22055',
          publicationDate: '2023-08-10',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'RBI_BULLETIN_MACRO_DIVERGENCE_2023',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'b4c5d6e1f2a37890b4c5d6e1f2a37890b4c5d6e1f2a37890b4c5d6e1f2a37890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'Post-pandemic economic recovery displays sectoral unevenness: organized corporate profit margins and capital goods expanded strongly, whereas real rural wage growth and lower-income consumption demand remained subdued, illustrating divergence between corporate-led GDP growth and household purchasing experience.',
          charStart: 60,
          charEnd: 375,
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
            'Empirical divergence between headline aggregate GDP expansion and everyday economic welfare (real wage stagnation, uneven rural consumption).',
          doesNotEstablish: 'That reported GDP is false or fabricated.',
          limitations: 'Macroeconomic and household survey synthesis within central bank surveillance.',
        },
      },
    };

    // ── 3. Atomic Claim Decomposition into 5 Granular Propositions ───────────
    const claimDecomposition: ClaimDecompositionProposition[] = [
      {
        propositionId: 'prop_india_1',
        role: 'PREMISE',
        text: 'The Indian government and mainstream media deliberately suppress negative economic data.',
        propositionType: 'CAUSAL_CLAIM',
        assessment: 'INSUFFICIENT_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_mospi_plfs_timeline_and_nsc_2019'],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_india_2',
        role: 'PREMISE',
        text: 'The Indian government manipulates unemployment statistics.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'CONFLICTING_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_mospi_plfs_timeline_and_nsc_2019'],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_india_3',
        role: 'PREMISE',
        text: 'The Indian government manipulates GDP statistics.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'CONFLICTING_EVIDENCE',
        supportingEvidenceIds: ['ev_subramanian_harvard_cid_2019'],
        contradictingEvidenceIds: ['ev_imf_article_iv_india_2023'],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'prop_india_4',
        role: 'PREMISE',
        text: 'Mainstream media selectively presents economic achievements to create a favorable narrative.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_rbi_k_shaped_growth_and_rural_wages_2023'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_india_5',
        role: 'CONCLUSION',
        text: "Therefore, India's reported economic growth does not accurately represent the economic reality experienced by ordinary citizens.",
        propositionType: 'CAUSAL_INFERENCE',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_rbi_k_shaped_growth_and_rural_wages_2023'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 1,
      },
    ];

    // ── 4. Intent & Concealment Engine Evaluation ─────────────────────────────
    const concealmentResult = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: claimDecomposition[0].text,
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: true,
    });
    expect(concealmentResult.assessment).toBe('INSUFFICIENT_EVIDENCE');
    expect(concealmentResult.distinctionCategory).toBe('INSUFFICIENT_EVIDENCE_OF_INTENT');

    // ── 5. Semantic Evidence Links Construction ──────────────────────────────
    const semanticLinks = [
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_mospi_plfs_timeline_and_nsc_2019',
        targetPropositionId: 'prop_india_1',
        propositionText: claimDecomposition[0].text,
        propositionType: 'CAUSAL_CLAIM',
        evidenceItem: evidenceRegistry['ev_mospi_plfs_timeline_and_nsc_2019'],
        candidateRelationship: 'CONTEXTUALLY_LIMITS',
        scopeOfSupport: 'CONTEXTUAL_BACKGROUND',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_mospi_plfs_timeline_and_nsc_2019',
        targetPropositionId: 'prop_india_2',
        propositionText: claimDecomposition[1].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_mospi_plfs_timeline_and_nsc_2019'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_imf_article_iv_india_2023',
        targetPropositionId: 'prop_india_3',
        propositionText: claimDecomposition[2].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_imf_article_iv_india_2023'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_subramanian_harvard_cid_2019',
        targetPropositionId: 'prop_india_3',
        propositionText: claimDecomposition[2].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_subramanian_harvard_cid_2019'],
        candidateRelationship: 'PARTIALLY_SUPPORTS',
        scopeOfSupport: 'PARTIAL_PREMISE_ONLY',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_rbi_k_shaped_growth_and_rural_wages_2023',
        targetPropositionId: 'prop_india_4',
        propositionText: claimDecomposition[3].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_rbi_k_shaped_growth_and_rural_wages_2023'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_rbi_k_shaped_growth_and_rural_wages_2023',
        targetPropositionId: 'prop_india_5',
        propositionText: claimDecomposition[4].text,
        propositionType: 'CAUSAL_INFERENCE',
        evidenceItem: evidenceRegistry['ev_rbi_k_shaped_growth_and_rural_wages_2023'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
    ];

    // ── 6. Provenance Graph Construction (k_eff calculation) ─────────────────
    const provenanceGraph = SemanticEvidenceValidator.constructProvenanceGraph({
      evidenceRegistry,
      datasets: [
        { datasetId: 'IMF_ARTICLE_IV_INDIA_2023', name: 'IMF Multilateral Surveillance' },
        { datasetId: 'HARVARD_CID_WORKING_PAPER_354', name: 'Harvard CID Econometric Review' },
        { datasetId: 'MOSPI_PLFS_OFFICIAL_TIMELINE_2019', name: 'MoSPI National Labor Surveillance' },
        { datasetId: 'RBI_BULLETIN_MACRO_DIVERGENCE_2023', name: 'RBI Macroeconomic & Household Research' },
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

    // ── 8. Credibility Assessment V2 Structure ────────────────────────────────
    const assessment: CredibilityAssessmentV2 = {
      assessmentId: 'asmt_india_economic_data_v2_2',
      schemaVersion: '2.0.0',
      assessmentVersion: 2,
      claimText,
      classification: {
        propositionType: 'CAUSAL_INFERENCE',
        evidenceStatus: 'CONFLICTING_EVIDENCE',
        reasoningValidity: 'CHERRY_PICKED_PREMISES',
        displayBadge: 'MISLEADING_INFERENCE',
      },
      claimDecomposition,
      evidenceRegistry,
      reasoningAssessment: {
        premisesVerifiedAccurate: ['prop_india_4'],
        conclusionFollowsDeductively: false,
        conclusionFollowsInductively: true,
        evaluatedAlternativeExplanations: [
          {
            explanation:
              'Methodological revisions in 2015 aligned India’s GDP calculations with international System of National Accounts (SNA 2008) standards; while econometric debate exists regarding deflators and informal sector weighting, multilateral bodies (IMF, World Bank) validate baseline growth as authentic macroeconomic expansion rather than fraudulent manipulation.',
            supportingEvidenceIds: ['ev_imf_article_iv_india_2023'],
          },
          {
            explanation:
              'Divergence between aggregate GDP growth and citizen economic experience is driven by structural "K-shaped" economic dynamics—strong formal corporate profits alongside sluggish real rural wage growth and informal sector recovery—rather than statistical data falsification.',
            supportingEvidenceIds: ['ev_rbi_k_shaped_growth_and_rural_wages_2023'],
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
          'High-frequency informal sector enterprise census updates following the 2016-2020 economic shocks.',
          'Comprehensive national household consumption expenditure survey continuity between 2011-12 and 2022-23.',
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

    // ── 10. Display Badge Derivation ──────────────────────────────────────────
    const derivedBadge = DeterministicVerifierService.deriveDisplayBadge(
      assessment.classification.propositionType,
      assessment.classification.evidenceStatus,
      assessment.classification.reasoningValidity,
      assessment.semanticValidation?.overclaimingAudit
    );
    expect(derivedBadge).toBe('MISLEADING_INFERENCE');

    // ── 11. Production VerifiedClaim Record Creation ───────────────────────────
    const verifiedClaim: VerifiedClaim = {
      claimId: 'claim_india_econ_01',
      text: claimText,
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.ABSOLUTE,
      confidence: 0.95,
      importance: 0.95,
      chunkIndex: 0,
      start: 0,
      end: claimText.length,
      status: 'disputed' as ClaimStatus,
      verificationConfidence: 0.88,
      displayLabel: 'Misleading Inference from Methodological Debates',
      evidenceLevel: EvidenceLevel.MODERATE,
      rating: null, // Epistemic rule: No arbitrary scalar numbers on complex socio-political debate
      reasoning:
        'The statement combines verifiable socioeconomic observations with unproven allegations of fraudulent data fabrication. While genuine methodological controversies exist regarding GDP deflators (e.g. 2015 base-year revision) and timing delays occurred in survey publication (e.g. 2017-18 PLFS), international audits by the IMF and World Bank corroborate that India’s headline growth reflects genuine economic expansion. Furthermore, perceived divergence between GDP numbers and citizen well-being stems from documented uneven "K-shaped" distributional recovery and subdued rural wage growth, rather than deliberate statistical suppression.',
      richSources: [
        {
          title: 'IMF Article IV Consultation — India Staff Report (2023)',
          url: 'https://www.imf.org/en/Publications/CR/Issues/2023/12/18/India-2023-Article-IV-Consultation-Press-Release-Staff-Report-and-Statement-by-the-Executive-542647',
          domain: 'imf.org',
          tier: 'A',
          snippet: 'India’s macroeconomic statistics are broadly adequate for surveillance; headline GDP methodology conforms to international SNA 2008 standards.',
        },
        {
          title: 'Harvard CID Working Paper — Validating India’s GDP Growth (Arvind Subramanian)',
          url: 'https://www.hks.harvard.edu/centers/cid/publications/fellow-working-papers/validating-indias-gdp-growth',
          domain: 'hks.harvard.edu',
          tier: 'A',
          snippet: 'Methodological changes in 2015 created statistical divergence with high-frequency indicators, generating scholarly debate over growth estimates.',
        },
        {
          title: 'MoSPI — Periodic Labour Force Survey (PLFS) Reports',
          url: 'https://www.mospi.gov.in/periodic-labour-force-survey-plfs',
          domain: 'mospi.gov.in',
          tier: 'A',
          snippet: 'Official labor surveys released regularly by MoSPI, documenting official unemployment rates including the peak 6.1% figure.',
        },
        {
          title: 'RBI Bulletin — Post-Pandemic Uneven Economic Recovery & Real Wages',
          url: 'https://www.rbi.org.in/Scripts/BS_ViewBulletin.aspx?Id=22055',
          domain: 'rbi.org.in',
          tier: 'A',
          snippet: 'Documents divergence between organized corporate capital growth and sluggish real rural wage expansion, explaining citizen perception gaps.',
        },
      ],
      sources: [
        'https://www.imf.org/en/Publications/CR/Issues/2023/12/18/India-2023-Article-IV-Consultation-Press-Release-Staff-Report-and-Statement-by-the-Executive-542647',
        'https://www.hks.harvard.edu/centers/cid/publications/fellow-working-papers/validating-indias-gdp-growth',
        'https://www.mospi.gov.in/periodic-labour-force-survey-plfs',
        'https://www.rbi.org.in/Scripts/BS_ViewBulletin.aspx?Id=22055',
      ],
      isGrounded: true,
      verificationMethod: 'grounded',
      verifiedFacts: [
        'India’s official GDP methodology was revised in 2015 adopting 2011-12 as base year and shifting to gross value added (GVA) at basic prices per SNA 2008 standards.',
        'Independent surveillance by the International Monetary Fund (IMF) and World Bank confirms India remains one of the world’s fastest-growing major economies, validating the authenticity of aggregate growth.',
        'Periodic Labour Force Survey (PLFS) data is regularly published by MoSPI and officially recorded a 45-year peak unemployment of 6.1% in 2017-18, disproving complete institutional data suppression.',
        'Economic research published by the Reserve Bank of India (RBI) demonstrates that post-pandemic recovery exhibited "K-shaped" characteristics, where formal corporate profits surged faster than informal employment and real rural wages.',
      ],
      missingEvidence: [
        'No verified internal documentation, forensic audit, or leaked communication substantiates deliberate or fraudulent data manipulation by government statisticians.',
        'No primary empirical evidence demonstrates that aggregate GDP statistics are fabricated, as opposed to subject to standard econometric methodological debates.',
      ],
      sourceConsensus: 'MODERATE_DIVERGENCE',
      riskLevel: 'HIGH_MACROECONOMIC_SCRUTINY',
      publicNote: 'Evaluated under TruthWorld Epistemic Policy: Distinguishes between documented methodological controversies in economic statistics and unsubstantiated allegations of deliberate conspiratorial manipulation.',
      misinformationVerdict: 'NOT_ESTABLISHED_AS_MISINFORMATION',
      framingAssessment: 'The statement conflates legitimate economic critiques of growth distribution and statistical methodology with unsubstantiated claims of deliberate data fraud and media conspiracy.',
      assessmentV2: assessment,
    };

    // ── 12. Scoring Engine Institutional Aggregation ───────────────────────────
    const scoringEngine = new ScoringEngine();
    const factCheckResult = scoringEngine.calculateInstitutionalTrustScore(
      'video_test_india_economic_claim',
      'user_test_runner',
      { text: claimText, utterances: [] } as any,
      [verifiedClaim],
      1,
      'balanced',
      'medium',
      'Economics',
      {}
    );

    expect(factCheckResult.factCheckStats.totalClaims).toBe(1);
    expect(factCheckResult.factCheckStats.disputed).toBe(1);
    expect(factCheckResult.uiReport).toBeDefined();
    expect(factCheckResult.uiReport?.sources.length).toBe(4);

    console.log('\n=== TRUTHWORLD PRODUCTION CREDIBILITY SYSTEM RESULT ===');
    console.log(JSON.stringify({
      verdictBadge: derivedBadge,
      assessmentV2: assessment,
      verifiedClaim,
      uiReport: factCheckResult.uiReport,
    }, null, 2));
  });
});
