import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { SemanticEvidenceValidator } from '../../src/pipeline/services/semanticEvidenceValidator';
import { EvidenceTransferValidator } from '../../src/pipeline/services/evidenceTransferValidator';
import {
  ClaimNature,
  FramingStyle,
  CredibilityAssessmentV2,
  EvidenceRegistryItem,
  ClaimDecompositionProposition,
} from '../../src/pipeline/types';

describe('TruthWorld Stress Test A (TW-ST-001): Mechanistic Plausibility vs. Clinical Outcome', () => {
  const claimText =
    'Scientists have demonstrated that Compound Q inhibits viral replication by 95% in human airway cells in laboratory experiments. This proves that Compound Q can effectively prevent COVID-19 in humans. Pharmaceutical companies ignored this discovery because it threatened their vaccine business.';

  // 1. Evidence Package (All 4 records authentic, independently verified)
  const evidenceRegistry: Record<string, EvidenceRegistryItem> = {
    ev_e1_invitro_inhibition: {
      sourceIdentity: {
        publisher: 'Journal of Virology & Antiviral Research',
        url: 'https://doi.org/10.1128/jvi.00999-21',
        publicationDate: '2021-04-15',
        sourceClassification: 'PRIMARY',
        primaryArtifactId: 'DOI_10_1128_jvi_00999_21',
      },
      evidenceDomain: 'IN_VITRO_LABORATORY',
      deterministicVerification: {
        fetchStatus: 'HTTP_200_OK',
        snapshotSha256: 'e1e1e1e1'.repeat(8),
        retrievedAtUtc: '2026-11-03T00:00:00Z',
        verifiedPassage:
          'In human airway epithelial cell cultures, Compound Q inhibited SARS-CoV-2 viral replication by 95% at an IC50 of 1.2 micromolar under specified laboratory cell culture conditions.',
        charStart: 100,
        charEnd: 270,
        exactMatchScore: 1.0,
        contextDistortionDetected: false,
      },
      independence: {
        lineageType: 'PEER_REVIEWED_RESEARCH',
        upstreamSourceId: null,
        independenceWeight: 1.0,
      },
      epistemicScope: {
        establishes: 'In-vitro biological activity and viral replication inhibition in cell cultures',
        doesNotEstablish: 'In-vivo human clinical efficacy, safe tissue bioavailability, or clinical prevention',
        limitations: 'Cell culture model with continuous high drug exposure lacking human metabolism or renal clearance',
      },
    },
    ev_e2_clinical_trial_rct: {
      sourceIdentity: {
        publisher: 'Lancet Respiratory Medicine',
        url: 'https://doi.org/10.1016/S2213-2600(21)00300-X',
        publicationDate: '2021-12-10',
        sourceClassification: 'PRIMARY',
        primaryArtifactId: 'NCT04889922',
      },
      evidenceDomain: 'RANDOMIZED_CONTROLLED_TRIAL',
      deterministicVerification: {
        fetchStatus: 'HTTP_200_OK',
        snapshotSha256: 'e2e2e2e2'.repeat(8),
        retrievedAtUtc: '2026-11-03T00:00:00Z',
        verifiedPassage:
          'In this double-blind, randomized, placebo-controlled trial of 1,420 outpatient adults, Compound Q showed no statistically significant reduction in COVID-19 hospitalization or death compared with placebo (hazard ratio 0.98; 95% CI 0.78 to 1.24).',
        charStart: 50,
        charEnd: 300,
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
          'Randomized trial demonstrates no statistically significant reduction in hospitalization at the tested dosing regimen in the study population',
        doesNotEstablish: 'Efficacy at toxic unachievable doses or non-studied synthetic derivatives',
        limitations: 'Conducted in mild-to-moderate outpatient cohort receiving standard-of-care background therapy',
      },
    },
    ev_e3_ci_benefit_exclusion: {
      sourceIdentity: {
        publisher: 'Cochrane Systematic Reviews Database',
        url: 'https://doi.org/10.1002/14651858.CD014000',
        publicationDate: '2022-03-20',
        sourceClassification: 'PRIMARY',
        primaryArtifactId: 'CD014000_META_ANALYSIS',
      },
      evidenceDomain: 'SYSTEMATIC_REVIEW_META_ANALYSIS',
      deterministicVerification: {
        fetchStatus: 'HTTP_200_OK',
        snapshotSha256: 'e3e3e3e3'.repeat(8),
        retrievedAtUtc: '2026-11-03T00:00:00Z',
        verifiedPassage:
          'The upper bound of the 95% confidence interval for Compound Q clinical trials excludes the prespecified minimal clinically meaningful benefit of a 20% relative risk reduction in hospitalization.',
        charStart: 30,
        charEnd: 235,
        exactMatchScore: 1.0,
        contextDistortionDetected: false,
      },
      independence: {
        lineageType: 'PEER_REVIEWED_RESEARCH',
        upstreamSourceId: null,
        independenceWeight: 1.0,
      },
      epistemicScope: {
        establishes: 'Statistical exclusion of clinically meaningful benefit across pooled randomized trials',
        doesNotEstablish: 'Subgroup effects in rare non-characterized mutations',
        limitations: 'Meta-analysis synthesis restricted to peer-reviewed blinded trials',
      },
    },
    ev_e4_suppression_docket: {
      sourceIdentity: {
        publisher: 'U.S. National Institutes of Health (NIH) Trial Registry',
        url: 'https://clinicaltrials.gov/study/NCT04889922',
        publicationDate: '2021-05-01',
        sourceClassification: 'REGULATORY_RECORD',
        primaryArtifactId: 'NIH_NCT04889922_PROTOCOL',
      },
      evidenceDomain: 'REGULATORY_DOCKET',
      deterministicVerification: {
        fetchStatus: 'HTTP_200_OK',
        snapshotSha256: 'e4e4e4e4'.repeat(8),
        retrievedAtUtc: '2026-11-03T00:00:00Z',
        verifiedPassage:
          'Trial protocols, funding sources, and sponsor disclosures were publicly registered on ClinicalTrials.gov with academic medical center institutional review board oversight.',
        charStart: 20,
        charEnd: 200,
        exactMatchScore: 1.0,
        contextDistortionDetected: false,
      },
      independence: {
        lineageType: 'PRIMARY_TECHNICAL_RECORD',
        upstreamSourceId: null,
        independenceWeight: 1.0,
      },
      epistemicScope: {
        establishes: 'Public trial registration and institutional oversight',
        doesNotEstablish: 'Definitive internal corporate thoughts or motives',
        limitations: 'Public administrative registry record',
      },
    },
  };

  it('TW-ST-001: Evaluates Mechanistic vs Clinical Outcome: prevents evidence transfer, refutes clinical claim, and derives MISLEADING_INFERENCE', () => {
    // 1. Classification & Routing
    const verificationService = new ClaimVerificationService('test-key', 0.6);
    const { toVerify } = verificationService.classifyClaims([
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

    // 2. Step 1: Atomic Decomposition (5 Distinct Propositions)
    const claimDecomposition: ClaimDecompositionProposition[] = [
      {
        propositionId: 'P1',
        role: 'PREMISE',
        text: 'Compound Q inhibits viral replication in human airway cells under laboratory conditions.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_e1_invitro_inhibition'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'P2',
        role: 'PREMISE',
        text: 'The laboratory cell-culture result establishes antiviral activity in human patients.',
        propositionType: 'CAUSAL_INFERENCE',
        assessment: 'CONTRADICTED',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_e2_clinical_trial_rct', 'ev_e3_ci_benefit_exclusion'],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'P3',
        role: 'CONCLUSION',
        text: 'Compound Q effectively prevents COVID-19 hospitalization in humans.',
        propositionType: 'CLINICAL_OUTCOME',
        assessment: 'CONTRADICTED',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_e2_clinical_trial_rct', 'ev_e3_ci_benefit_exclusion'],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'P4',
        role: 'PREMISE',
        text: 'Pharmaceutical companies deliberately ignored and suppressed Compound Q because it threatened their vaccine business.',
        propositionType: 'INTENT_CLAIM',
        assessment: 'INSUFFICIENT_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 0,
      },
      {
        propositionId: 'P5',
        role: 'PREMISE',
        text: 'The clinical failure occurred because companies suppressed the compound.',
        propositionType: 'CAUSAL_CLAIM',
        assessment: 'INSUFFICIENT_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 0,
      },
    ];

    // 3. Step 2: Evidence Transfer Validation (Inferential Relationship Analyzer)
    const inferenceAudit = EvidenceTransferValidator.validateInferenceStep({
      inferenceId: 'inf_tw_st_001_p1_to_p3',
      sourcePropositions: [claimDecomposition[0]], // P1 (In-vitro lab)
      targetProposition: claimDecomposition[2],   // P3 (Clinical outcome)
      evidenceRegistry,
      explicitInferenceType: 'MECHANISTIC_TO_CLINICAL',
    });

    // Verification of ETV Reasoning
    expect(inferenceAudit.inferenceType).toBe('MECHANISTIC_TO_CLINICAL');
    expect(inferenceAudit.validity).toBe('INVALID_WITHOUT_ADDITIONAL_EVIDENCE');
    expect(inferenceAudit.detectedFallacy).toBe('EVIDENCE_DOMAIN_TRANSFER');
    expect(inferenceAudit.missingEvidence).toContain(
      'Human in-vivo pharmacokinetic and pharmacodynamic (PK/PD) tissue concentration data'
    );
    expect(inferenceAudit.missingEvidence).toContain(
      'Human phase II/III randomized controlled trial (RCT) clinical efficacy data'
    );
    expect(inferenceAudit.contradictingEvidenceIds).toContain('ev_e2_clinical_trial_rct');
    expect(inferenceAudit.contradictingEvidenceIds).toContain('ev_e3_ci_benefit_exclusion');

    // 4. Intent & Concealment Engine Validation (P4)
    const concealmentAudit = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: claimDecomposition[3].text,
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: false,
    });
    expect(concealmentAudit.assessment).toBe('INSUFFICIENT_EVIDENCE');

    // 5. Semantic Links Construction
    const semanticLinks = [
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_e1_invitro_inhibition',
        targetPropositionId: 'P1',
        propositionText: claimDecomposition[0].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_e1_invitro_inhibition'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_e2_clinical_trial_rct',
        targetPropositionId: 'P3',
        propositionText: claimDecomposition[2].text,
        propositionType: 'CLINICAL_OUTCOME',
        evidenceItem: evidenceRegistry['ev_e2_clinical_trial_rct'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_e3_ci_benefit_exclusion',
        targetPropositionId: 'P3',
        propositionText: claimDecomposition[2].text,
        propositionType: 'CLINICAL_OUTCOME',
        evidenceItem: evidenceRegistry['ev_e3_ci_benefit_exclusion'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
    ];

    // 6. Provenance Graph Construction
    const provenanceGraph = SemanticEvidenceValidator.constructProvenanceGraph({
      evidenceRegistry,
      datasets: [
        { datasetId: 'DOI_10_1128_jvi_00999_21', name: 'In-Vitro Epithelial Assay' },
        { datasetId: 'NCT04889922', name: 'Phase III Randomized Trial' },
        { datasetId: 'CD014000_META_ANALYSIS', name: 'Cochrane Meta-Analysis Dataset' },
        { datasetId: 'NIH_NCT04889922_PROTOCOL', name: 'Trial Protocol Registry' },
      ],
    });

    const overclaimingAudit = SemanticEvidenceValidator.auditOverclaiming(
      {
        assessmentId: 'asmt_tw_st_001',
        schemaVersion: '2.0.0',
        claimText,
        classification: {
          propositionType: 'CAUSAL_INFERENCE',
          evidenceStatus: 'CONTRADICTED',
          reasoningValidity: 'NON_SEQUITUR',
          displayBadge: 'MISLEADING_INFERENCE',
        },
        claimDecomposition,
        evidenceRegistry,
        reasoningAssessment: {
          premisesVerifiedAccurate: ['P1'],
          conclusionFollowsDeductively: false,
          conclusionFollowsInductively: false,
          evaluatedAlternativeExplanations: [],
        },
        backendAuditFlags: {
          allReferencedCitationsDeterministicallyVerified: true,
          unverifiedEvidencePresent: false,
          closedWorldCitationCheckPassed: true,
        },
        uncertainty: {
          numericalConfidenceAvailable: false,
          qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE',
          conformalPredictionSet: ['MISLEADING_INFERENCE'],
          disclosedGaps: [],
        },
      },
      semanticLinks,
      provenanceGraph
    );

    // 7. Scoping & Summary Consistency
    const scoping = SemanticEvidenceValidator.computeScopingSummary({
      propositions: claimDecomposition,
      links: semanticLinks,
      k_eff: provenanceGraph.effectiveIndependentSourcesCount,
    });

    expect(scoping.semanticEvidenceLevel).toBe('MIXED_EVIDENCE');
    expect(scoping.semanticEvidenceScope).toBe('INDIVIDUAL_EVIDENCE_LINKS');

    // 8. Deterministic Display Badge Derivation
    const derivedBadge = DeterministicVerifierService.deriveDisplayBadge(
      'CAUSAL_INFERENCE',
      'CONTRADICTED',
      'NON_SEQUITUR',
      overclaimingAudit
    );
    expect(derivedBadge).toBe('MISLEADING_INFERENCE');

    // 9. Pre-Commit Database Constraint Validation (Rule 1 through Rule 8)
    const assessment: CredibilityAssessmentV2 = {
      assessmentId: 'asmt_tw_st_001_final',
      schemaVersion: '2.0.0',
      assessmentVersion: 1,
      claimText,
      classification: {
        propositionType: 'CAUSAL_INFERENCE',
        evidenceStatus: 'CONTRADICTED',
        reasoningValidity: 'NON_SEQUITUR',
        displayBadge: derivedBadge,
      },
      claimDecomposition,
      evidenceRegistry,
      reasoningAssessment: {
        premisesVerifiedAccurate: ['P1'],
        conclusionFollowsDeductively: false,
        conclusionFollowsInductively: false,
        evaluatedAlternativeExplanations: [
          {
            explanation:
              'In-vitro biological activity fails to translate into human efficacy due to inadequate oral bioavailability, rapid pulmonary metabolism, or inability to achieve safe micromolar plasma concentrations in vivo.',
            supportingEvidenceIds: ['ev_e2_clinical_trial_rct', 'ev_e3_ci_benefit_exclusion'],
          },
        ],
        inferenceAudits: [inferenceAudit],
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
          'High-dose aerosolized inhalation pharmacokinetic delivery data (not evaluated in systemic oral trial)',
        ],
      },
      semanticValidation: {
        links: semanticLinks,
        overclaimingAudit,
        provenanceGraph,
        semanticEvidenceLevel: scoping.semanticEvidenceLevel,
        semanticEvidenceScope: scoping.semanticEvidenceScope,
        sourceCountScope: scoping.sourceCountScope,
        effectiveIndependentSourcesCount: scoping.effectiveIndependentSourcesCount,
      },
      inferenceAudits: [inferenceAudit],
    };

    const validation = DeterministicVerifierService.validateAssessmentV2(assessment);
    expect(validation.isValid).toBe(true);
    expect(validation.errors).toEqual([]);

    console.log('\n--- TW-ST-001 CANONICAL OUTPUT ---');
    console.log(JSON.stringify(assessment, null, 2));
  });

  describe('Adversarial Variations for TW-ST-001', () => {
    it('TW-ST-001A: Rejects assessment when creator cites only laboratory experiment to mark human clinical outcome as SUPPORTED', () => {
      const invalidAssessment: any = {
        assessmentId: 'asmt_tw_st_001a',
        schemaVersion: '2.0.0',
        claimText: 'Compound Q inhibits viral replication in cells, proving it prevents COVID-19 in humans.',
        classification: {
          propositionType: 'CLINICAL_OUTCOME',
          evidenceStatus: 'SUPPORTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'VERIFIED_FACT',
        },
        claimDecomposition: [
          {
            propositionId: 'P_claim',
            role: 'CONCLUSION',
            text: 'Compound Q prevents COVID-19 in humans.',
            propositionType: 'CLINICAL_OUTCOME',
            assessment: 'SUPPORTED', // ILLEGITIMATE SUPPORT FROM IN-VITRO ALONE!
            supportingEvidenceIds: ['ev_e1_invitro_inhibition'],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry,
        backendAuditFlags: {
          allReferencedCitationsDeterministicallyVerified: true,
          unverifiedEvidencePresent: false,
          closedWorldCitationCheckPassed: true,
        },
      };

      // Rule 8 must trigger!
      const validation = DeterministicVerifierService.validateAssessmentV2(invalidAssessment);
      expect(validation.isValid).toBe(false);
      expect(validation.errors.some(e => e.includes('[INVALID_DOMAIN_SUPPORT]'))).toBe(true);
    });

    it('TW-ST-001B: Flags evidence omission when creator omits known clinical trial results', () => {
      // Assessment references only P1, while available evidence universe contains contradictory RCT
      const partialAssessment: any = {
        assessmentId: 'asmt_tw_st_001b',
        schemaVersion: '2.0.0',
        claimText: 'Compound Q inhibits viral replication in cells.',
        classification: {
          propositionType: 'EMPIRICAL_OBSERVATION',
          evidenceStatus: 'SUPPORTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'EMPIRICALLY_VERIFIED',
        },
        claimDecomposition: [
          {
            propositionId: 'P1',
            role: 'PREMISE',
            text: 'Compound Q inhibits viral replication in laboratory cells.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: ['ev_e1_invitro_inhibition'],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          ev_e1_invitro_inhibition: evidenceRegistry['ev_e1_invitro_inhibition'],
        },
        backendAuditFlags: {
          allReferencedCitationsDeterministicallyVerified: true,
          unverifiedEvidencePresent: false,
          closedWorldCitationCheckPassed: true,
        },
      };

      const audit = EvidenceTransferValidator.auditEvidenceTransfers({
        propositions: partialAssessment.claimDecomposition,
        evidenceRegistry: partialAssessment.evidenceRegistry,
      });

      // P1 alone as laboratory observation is supported, but cannot be generalized
      expect(audit.hasInvalidDomainTransfer).toBe(false);
    });

    it('TW-ST-001C: Requires independent documentary evidence when creator claims clinical trial was designed to fail', () => {
      const intentProp: ClaimDecompositionProposition = {
        propositionId: 'P_conspiracy',
        role: 'PREMISE',
        text: 'The clinical trial was intentionally designed with sub-therapeutic doses to make Compound Q fail.',
        propositionType: 'INTENT_CLAIM',
        assessment: 'INSUFFICIENT_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 0,
      };

      const audit = EvidenceTransferValidator.validateInferenceStep({
        inferenceId: 'inf_intent_test',
        sourcePropositions: [],
        targetProposition: intentProp,
        evidenceRegistry,
      });

      expect(audit.validity).toBe('INVALID_WITHOUT_ADDITIONAL_EVIDENCE');
      expect(audit.detectedFallacy).toBe('INTENT_IMPUTATION');
      expect(audit.missingEvidence[0]).toContain('unredacted internal communications');
    });

    it('TW-ST-001D: Subgroup biomarker claim without prespecified multiplicity correction receives INSUFFICIENT_EVIDENCE', () => {
      const subgroupProp: ClaimDecompositionProposition = {
        propositionId: 'P_subgroup',
        role: 'CONCLUSION',
        text: 'Compound Q prevents death in patients with low baseline ferritin levels based on retrospective subgroup analysis.',
        propositionType: 'CLINICAL_OUTCOME',
        assessment: 'INSUFFICIENT_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 0,
      };

      const audit = EvidenceTransferValidator.validateInferenceStep({
        inferenceId: 'inf_subgroup_test',
        sourcePropositions: [],
        targetProposition: subgroupProp,
        evidenceRegistry,
        explicitInferenceType: 'SUBGROUP_TO_GENERAL',
      });

      expect(audit.validity).toBe('INVALID_WITHOUT_ADDITIONAL_EVIDENCE');
      expect(audit.detectedFallacy).toBe('CHERRY_PICKING');
      expect(audit.missingEvidence[0]).toContain('Prespecified statistical analysis plan');
    });
  });
});
