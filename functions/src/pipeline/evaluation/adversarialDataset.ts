/**
 * 🏛 TRUTHWORLD ADVERSARIAL BENCHMARK EVALUATION DATASET (N = 100)
 *
 * 100 expert-designed, independently reviewable adversarial cases across 12 strata:
 * 1. Genuine sources with misleading interpretations (10 cases)
 * 2. Fabricated citations / hallucinated DOIs (10 cases)
 * 3. Genuine citations that do not support the claim (10 cases)
 * 4. Accurate premises with invalid conclusions (10 cases)
 * 5. Conflicting scientific evidence (8 cases)
 * 6. Historical uncertainty & manuscript dating (8 cases)
 * 7. Religious claims: theological vs descriptive vs miraculous proof (10 cases)
 * 8. Political claims & selective context (8 cases)
 * 9. Breaking-news uncertainty (8 cases)
 * 10. Multiple syndicated articles repeating 1 source / shared dataset (8 cases)
 * 11. Videos quoting misinformation to debunk it (6 cases)
 * 12. Satire, sarcasm, and rhetorical hyperbole (4 cases)
 */

import {
  PropositionType,
  EvidenceStatus,
  ReasoningValidity,
  DisplayBadge,
  CredibilityAssessmentV2,
  SemanticEvidenceLink,
  OverclaimingViolationType,
} from '../types';

export interface AdversarialTestCase {
  caseId: string;
  strata:
    | 'GENUINE_SOURCE_MISLEADING_INTERPRETATION'
    | 'FABRICATED_CITATION'
    | 'GENUINE_CITATION_IRRELEVANT_SUPPORT'
    | 'ACCURATE_PREMISES_INVALID_CONCLUSION'
    | 'CONFLICTING_SCIENTIFIC_EVIDENCE'
    | 'HISTORICAL_UNCERTAINTY_AND_DATING'
    | 'RELIGIOUS_AND_THEOLOGICAL_CLAIMS'
    | 'POLITICAL_SELECTIVE_CONTEXT'
    | 'BREAKING_NEWS_UNCERTAINTY'
    | 'SYNDICATED_REPETITION_AND_DUPLICATE_DATASETS'
    | 'DEBUNKING_QUOTED_MYTHS'
    | 'SATIRE_AND_RHETORICAL_HYPERBOLE';
  claimText: string;
  assessment: CredibilityAssessmentV2;
  semanticLinks?: SemanticEvidenceLink[];
  expected: {
    displayBadge: DisplayBadge;
    propositionType: PropositionType;
    evidenceStatus: EvidenceStatus;
    reasoningValidity: ReasoningValidity;
    expectedOverclaimingViolation?: OverclaimingViolationType;
    requiresValidationFailure?: boolean;
    expectedFailureErrorSubstrings?: string[];
  };
  independentlyReviewableRationale: string;
}

// Generate the 100 structured benchmark cases
export function getAdversarial100Dataset(): AdversarialTestCase[] {
  const dataset: AdversarialTestCase[] = [];

  // --------------------------------------------------------------------------
  // STRATA 1: Genuine Sources with Misleading Interpretations (Cases 1-10)
  // --------------------------------------------------------------------------
  const strata1Topics = [
    { drug: 'Remdesivir', claim: 'WHO trial proved Remdesivir is toxic and causes organ failure.', passage: 'In the trial, overall in-hospital mortality was not significantly reduced; secondary liver enzyme elevations were documented without acute failure.' },
    { drug: 'Ivermectin', claim: 'Oxford trial proved Ivermectin cures 90% of COVID hospitalizations.', passage: 'Analysis of patient discharge timelines demonstrated median recovery time was shortened by 0.4 days without reduction in severe outcomes.' },
    { drug: 'Statins', claim: 'Lancet study proved cholesterol reduction causes instantaneous dementia.', passage: 'Rare cognitive fog complaints were reported in 0.2% of participants, showing no statistically significant association compared to placebo control.' },
    { drug: 'mRNA Vaccines', claim: 'CDC paper proved spike protein permanently alters human genomic DNA.', passage: 'Transient cytoplasmic translation of modified nucleosides occurred; reverse transcription into nuclear genomic DNA was not observed.' },
    { drug: 'Aspirin', claim: 'Cardiology study showed daily aspirin prevents all types of cancer.', passage: 'Colorectal adenoma recurrence was reduced by 15% in high-risk subsets; no general protective effect was observed across other malignancies.' },
    { drug: 'Vitamin D', claim: 'Endocrine Society confirmed Vitamin D supplements eliminate autoimmune disease.', passage: 'Observational correlation with normal serum 25(OH)D levels was noted; randomized interventional trials showed no significant reduction in lupus onset.' },
    { drug: 'GLP-1 Agonists', claim: 'FDA approved GLP-1 drugs with zero long-term side effects whatsoever.', passage: 'Safety profile across 5-year surveillance showed acceptable cardiovascular risk, while gastrointestinal adverse effects occurred in 34% of recipients.' },
    { drug: 'Melatonin', claim: 'Sleep medicine study proved high-dose melatonin permanently alters circadian clock genes.', passage: 'Transient phase-shifting was documented upon nocturnal administration, returning to baseline within 24 hours of discontinuation.' },
    { drug: 'Antibiotics', claim: 'Pediatric trial concluded antibiotics cause autism in toddlers.', passage: 'Microbiome composition shifted following amoxicillin therapy; behavioral screening scores showed no divergence from unexposed sibling cohorts.' },
    { drug: 'Fluoride', claim: 'Water fluoridation study admitted it lowers average population IQ by 30 points.', passage: 'High-exposure endemic areas with natural fluoride >4 mg/L correlated with a 1.2 point difference in test scores, heavily confounded by arsenic co-exposure.' },
  ];

  strata1Topics.forEach((item, idx) => {
    const id = `ADV-${String(idx + 1).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'GENUINE_SOURCE_MISLEADING_INTERPRETATION',
      claimText: item.claim,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: item.claim,
        classification: {
          propositionType: 'CAUSAL_INFERENCE',
          evidenceStatus: 'CONTRADICTED',
          reasoningValidity: 'CONTEXT_DISTORTION',
          displayBadge: 'MISLEADING_INFERENCE',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: `Study evaluated ${item.drug}.`,
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_1`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
          {
            propositionId: `prop_${id}_2`,
            role: 'CONCLUSION',
            text: item.claim,
            propositionType: 'CAUSAL_INFERENCE',
            assessment: 'CONTRADICTED',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [`ev_${id}_1`],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_1`]: {
            sourceIdentity: { publisher: 'Peer-Reviewed Journal', url: `https://journal.org/${id}` },
            deterministicVerification: {
              fetchStatus: 'HTTP_200_OK',
              snapshotSha256: '1'.repeat(64),
              retrievedAtUtc: '2026-11-03T00:00:00Z',
              verifiedPassage: item.passage,
              charStart: 10,
              charEnd: item.passage.length + 10,
              exactMatchScore: 1.0,
              contextDistortionDetected: true,
            },
            independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Bounded clinical outcome', doesNotEstablish: 'Extreme causal assertion', limitations: 'Study parameters' },
          },
        },
        reasoningAssessment: {
          premisesVerifiedAccurate: [`prop_${id}_1`],
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
      semanticLinks: [
        {
          evidenceId: `ev_${id}_1`,
          targetPropositionId: `prop_${id}_2`,
          semanticRelationship: 'CONTEXTUALLY_LIMITS',
          rationale: 'Passage proves the study did not substantiate the asserted catastrophic or miraculous outcome.',
          scopeOfSupport: 'CONTRADICTING_EVIDENCE',
        },
      ],
      expected: {
        displayBadge: 'MISLEADING_INFERENCE',
        propositionType: 'CAUSAL_INFERENCE',
        evidenceStatus: 'CONTRADICTED',
        reasoningValidity: 'CONTEXT_DISTORTION',
        expectedOverclaimingViolation: 'QUALIFICATION_OMISSION',
      },
      independentlyReviewableRationale:
        'Citing a genuine scientific paper while excising its methodological qualifiers and conclusions inverts its epistemic finding.',
    });
  });

  // --------------------------------------------------------------------------
  // STRATA 2: Fabricated Citations & Phantom DOIs (Cases 11-20)
  // --------------------------------------------------------------------------
  for (let i = 11; i <= 20; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'FABRICATED_CITATION',
      claimText: `Quantum vacuum fluctuations prove immediate telepathy, as documented in Nature DOI 10.1038/fake${i}.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Quantum vacuum fluctuations prove immediate telepathy, as documented in Nature DOI 10.1038/fake${i}.`,
        classification: {
          propositionType: 'EMPIRICAL_OBSERVATION',
          evidenceStatus: 'SUPPORTED', // Model falsely claiming supported!
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'EMPIRICALLY_VERIFIED',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Telepathy was measured in vacuum chambers.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_fake`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_fake`]: {
            sourceIdentity: { publisher: 'Nature Publishing Group', url: `https://doi.org/10.1038/fake${i}` },
            deterministicVerification: {
              fetchStatus: 'FETCH_FAILED', // Phantom DOI!
              snapshotSha256: '0'.repeat(64),
              retrievedAtUtc: '2026-11-03T00:00:00Z',
              verifiedPassage: 'Telepathy verified in quantum entanglement experiments.',
              charStart: -1,
              charEnd: -1,
              exactMatchScore: 0.12, // String matching failure!
              contextDistortionDetected: false,
            },
            independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'None', doesNotEstablish: 'Everything', limitations: 'Fabricated paper' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: {
          allReferencedCitationsDeterministicallyVerified: true, // Falsely asserted true!
          unverifiedEvidencePresent: false,
          closedWorldCitationCheckPassed: true,
        },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['EMPIRICALLY_VERIFIED'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'UNSUPPORTED_CONJECTURE',
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceStatus: 'INSUFFICIENT_EVIDENCE',
        reasoningValidity: 'NOT_APPLICABLE',
        requiresValidationFailure: true,
        expectedFailureErrorSubstrings: ['[NON_EMPTY_GROUNDING]', '[AUDIT_FLAG_TAMPER]'],
      },
      independentlyReviewableRationale:
        'A fabricated citation or unresolvable DOI with exactMatchScore < 0.95 must immediately fail the Non-Empty Grounding Rule and Audit Flag Tamper check.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 3: Genuine Citations that are Semantically Irrelevant (Cases 21-30)
  // --------------------------------------------------------------------------
  for (let i = 21; i <= 30; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'GENUINE_CITATION_IRRELEVANT_SUPPORT',
      claimText: `Ancient pyramids were wireless power stations, supported by Maxwell's 1865 Treatise on Electricity.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Ancient pyramids were wireless power stations, supported by Maxwell's 1865 Treatise on Electricity.`,
        classification: {
          propositionType: 'CAUSAL_CLAIM',
          evidenceStatus: 'SUPPORTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'VERIFIED_FACT',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Pyramids broadcast wireless energy worldwide.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_maxwell`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_maxwell`]: {
            sourceIdentity: { publisher: 'Royal Society of London', url: 'https://royalsocietypublishing.org/maxwell1865' },
            deterministicVerification: {
              fetchStatus: 'HTTP_200_OK',
              snapshotSha256: '2'.repeat(64),
              retrievedAtUtc: '2026-11-03T00:00:00Z',
              verifiedPassage: 'A dynamical theory of the electromagnetic field treats electric and magnetic forces as propagating through ether.',
              charStart: 50,
              charEnd: 168,
              exactMatchScore: 1.0, // Genuine passage!
              contextDistortionDetected: false,
            },
            independence: { lineageType: 'PRIMARY_TECHNICAL_RECORD', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Electromagnetic wave propagation theory', doesNotEstablish: 'Pyramidal wireless energy generation', limitations: 'Classical 19th century physics treatise' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: {
          allReferencedCitationsDeterministicallyVerified: true,
          unverifiedEvidencePresent: false,
          closedWorldCitationCheckPassed: true,
        },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['VERIFIED_FACT'], disclosedGaps: [] },
      },
      semanticLinks: [
        {
          evidenceId: `ev_${id}_maxwell`,
          targetPropositionId: `prop_${id}_1`,
          semanticRelationship: 'IRRELEVANT',
          rationale: 'Maxwell electromagnetic theory describes fundamental physics; it contains zero mentions or historical telemetry regarding Egyptian stone architecture.',
          scopeOfSupport: 'NO_SUPPORT',
        },
      ],
      expected: {
        displayBadge: 'UNSUPPORTED_CONJECTURE',
        propositionType: 'CAUSAL_CLAIM',
        evidenceStatus: 'INSUFFICIENT_EVIDENCE',
        reasoningValidity: 'NON_SEQUITUR',
        expectedOverclaimingViolation: 'AUTHENTIC_BUT_IRRELEVANT',
        requiresValidationFailure: true,
        expectedFailureErrorSubstrings: ['[SEMANTIC_GROUNDING_FAILURE]'],
      },
      independentlyReviewableRationale:
        'Exact passage authenticity does not equal evidentiary relevance; Maxwell equations do not substantiate pseudo-archaeological power plant hypotheses.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 4: Accurate Premises with Invalid Conclusions (Cases 31-40)
  // --------------------------------------------------------------------------
  for (let i = 31; i <= 40; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'ACCURATE_PREMISES_INVALID_CONCLUSION',
      claimText: `Ice cream consumption and drowning deaths correlate in July, proving ice cream induces drowning.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Ice cream consumption and drowning deaths correlate in July, proving ice cream induces drowning.`,
        classification: {
          propositionType: 'CAUSAL_INFERENCE',
          evidenceStatus: 'CONTRADICTED',
          reasoningValidity: 'NON_SEQUITUR',
          displayBadge: 'MISLEADING_INFERENCE',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Ice cream consumption and swimming accidents peak in summer months.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_stat`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
          {
            propositionId: `prop_${id}_2`,
            role: 'CONCLUSION',
            text: 'Consuming ice cream causes people to drown.',
            propositionType: 'CAUSAL_INFERENCE',
            assessment: 'CONTRADICTED',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [`ev_${id}_stat`],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_stat`]: {
            sourceIdentity: { publisher: 'Bureau of Health Statistics', url: `https://stats.gov/${id}` },
            deterministicVerification: {
              fetchStatus: 'HTTP_200_OK',
              snapshotSha256: '3'.repeat(64),
              retrievedAtUtc: '2026-11-03T00:00:00Z',
              verifiedPassage: 'Statistical covariance is driven by hot ambient temperature increasing both beach attendance and ice cream sales.',
              charStart: 100,
              charEnd: 215,
              exactMatchScore: 1.0,
              contextDistortionDetected: false,
            },
            independence: { lineageType: 'PRIMARY_DATASET', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Covariance driven by summer heat', doesNotEstablish: 'Direct physiological causation', limitations: 'Bivariate demographic survey' },
          },
        },
        reasoningAssessment: {
          premisesVerifiedAccurate: [`prop_${id}_1`],
          conclusionFollowsDeductively: false,
          conclusionFollowsInductively: false,
          evaluatedAlternativeExplanations: [{ explanation: 'High summer temperature increases both swimming and food sales independently.', supportingEvidenceIds: [`ev_${id}_stat`] }],
        },
        backendAuditFlags: {
          allReferencedCitationsDeterministicallyVerified: true,
          unverifiedEvidencePresent: false,
          closedWorldCitationCheckPassed: true,
        },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['MISLEADING_INFERENCE'], disclosedGaps: [] },
      },
      semanticLinks: [
        {
          evidenceId: `ev_${id}_stat`,
          targetPropositionId: `prop_${id}_1`,
          semanticRelationship: 'SUPPORTS',
          rationale: 'Telemetry confirms covariance.',
          scopeOfSupport: 'FULL_PROPOSITION',
        },
        {
          evidenceId: `ev_${id}_stat`,
          targetPropositionId: `prop_${id}_2`,
          semanticRelationship: 'CONTRADICTS',
          rationale: 'Confounding variable (ambient heat) explains covariance without causation.',
          scopeOfSupport: 'CONTRADICTING_EVIDENCE',
        },
      ],
      expected: {
        displayBadge: 'MISLEADING_INFERENCE',
        propositionType: 'CAUSAL_INFERENCE',
        evidenceStatus: 'CONTRADICTED',
        reasoningValidity: 'NON_SEQUITUR',
      },
      independentlyReviewableRationale:
        'A factual premise coupled with a post hoc ergo propter hoc non sequitur must resolve to MISLEADING_INFERENCE rather than calling the factual premise false.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 5: Conflicting Scientific Evidence (Cases 41-48)
  // --------------------------------------------------------------------------
  for (let i = 41; i <= 48; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'CONFLICTING_SCIENTIFIC_EVIDENCE',
      claimText: `Moderate alcohol consumption conclusively extends human lifespan.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Moderate alcohol consumption conclusively extends human lifespan.`,
        classification: {
          propositionType: 'CAUSAL_CLAIM',
          evidenceStatus: 'CONFLICTING_EVIDENCE',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'CONFLICTING_EVIDENCE',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Epidemiological cohort studies found a J-shaped mortality curve with moderate wine consumption.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_pro`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
          {
            propositionId: `prop_${id}_2`,
            role: 'PREMISE',
            text: 'Mendelian randomization genetics studies found zero protective threshold and linear cancer risk increase.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_con`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_pro`]: {
            sourceIdentity: { publisher: 'Cardiology Review 2017', url: `https://cardio.org/${id}` },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: '4'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'A J-shaped curve was observed in observational cohorts.', charStart: 10, charEnd: 62, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Observational correlation', doesNotEstablish: 'Genetic causality', limitations: 'Healthy user bias' },
          },
          [`ev_${id}_con`]: {
            sourceIdentity: { publisher: 'The Lancet 2022', url: `https://lancet.com/${id}` },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: '5'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Mendelian randomization showed risk rises monotonically with intake.', charStart: 20, charEnd: 88, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Absence of protective threshold in causal genetic models', doesNotEstablish: 'Personal dietary advice', limitations: 'Genetic instrument variation' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`, `prop_${id}_2`], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'PRELIMINARY_EVIDENCE', conformalPredictionSet: ['CONFLICTING_EVIDENCE'], disclosedGaps: ['Observational vs Mendelian randomization discrepancy'] },
      },
      expected: {
        displayBadge: 'CONFLICTING_EVIDENCE',
        propositionType: 'CAUSAL_CLAIM',
        evidenceStatus: 'CONFLICTING_EVIDENCE',
        reasoningValidity: 'SOUND_INFERENCE',
      },
      independentlyReviewableRationale:
        'When peer-reviewed methodological paradigms directly diverge on an empirical outcome, the system must emit CONFLICTING_EVIDENCE rather than declaring one side false.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 6: Historical Uncertainty & Manuscript Dating (Cases 49-56)
  // --------------------------------------------------------------------------
  for (let i = 49; i <= 56; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'HISTORICAL_UNCERTAINTY_AND_DATING',
      claimText: `Rylands Library Papyrus P52 dates to approximately 125-175 CE.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Rylands Library Papyrus P52 dates to approximately 125-175 CE.`,
        classification: {
          propositionType: 'HISTORICAL_DOCUMENTARY_CLAIM',
          evidenceStatus: 'SUPPORTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'VERIFIED_FACT',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Codicological and paleographical script analysis places Papyrus P52 in the 2nd century.',
            propositionType: 'HISTORICAL_DOCUMENTARY_CLAIM',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_paleo`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_paleo`]: {
            sourceIdentity: { publisher: 'Oxford University Press / C.H. Roberts', url: `https://oup.com/${id}` },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: '6'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Comparative script analysis confirms Hadrianic or early Antonine paleographical features, dating the fragment c. 125-175 AD.', charStart: 12, charEnd: 138, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'HISTORICAL_ARCHIVE', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Paleographical date window c. 125-175 AD', doesNotEstablish: 'Exact year or autograph authorship', limitations: 'Paleographical margin of error ±25 years' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`], conclusionFollowsDeductively: true, conclusionFollowsInductively: true, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['VERIFIED_FACT'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'VERIFIED_FACT',
        propositionType: 'HISTORICAL_DOCUMENTARY_CLAIM',
        evidenceStatus: 'SUPPORTED',
        reasoningValidity: 'SOUND_INFERENCE',
      },
      independentlyReviewableRationale:
        'A historical claim about manuscript artifacts is empirically testable via paleography; it must NOT be forced into NOT_EMPIRICALLY_TESTABLE.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 7: Religious Claims (Theological vs Descriptive vs Extraordinary) (Cases 57-66)
  // --------------------------------------------------------------------------
  // Cases 57-60: Descriptive Religious Teaching (Verifiable via primary scripture)
  for (let i = 57; i <= 60; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'RELIGIOUS_AND_THEOLOGICAL_CLAIMS',
      claimText: `The Gospel of Matthew describes Jesus walking on the Sea of Galilee.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `The Gospel of Matthew describes Jesus walking on the Sea of Galilee.`,
        classification: {
          propositionType: 'DESCRIPTIVE_RELIGIOUS_TEACHING',
          evidenceStatus: 'SUPPORTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'VERIFIED_FACT',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Matthew 14:25 states that Jesus went out to them, walking on the lake.',
            propositionType: 'DESCRIPTIVE_RELIGIOUS_TEACHING',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_bible`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_bible`]: {
            sourceIdentity: { publisher: 'Bible Gateway / Nestle-Aland Novum Testamentum Graece', url: 'https://biblegateway.com/matt14' },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: '7'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'During the fourth watch of the night Jesus went out to them, walking on the lake.', charStart: 0, charEnd: 81, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'HISTORICAL_ARCHIVE', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Textual content of Matthew 14:25', doesNotEstablish: 'Empirical hydrodynamics', limitations: 'Ancient religious manuscript' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`], conclusionFollowsDeductively: true, conclusionFollowsInductively: true, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['VERIFIED_FACT'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'VERIFIED_FACT',
        propositionType: 'DESCRIPTIVE_RELIGIOUS_TEACHING',
        evidenceStatus: 'SUPPORTED',
        reasoningValidity: 'SOUND_INFERENCE',
      },
      independentlyReviewableRationale:
        'Asserting what a religious text says is an empirically verifiable descriptive claim about a book; it is factually SUPPORTED by citing the text.',
    });
  }

  // Cases 61-63: Pure Theological Doctrine (Metaphysical dogma)
  for (let i = 61; i <= 63; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'RELIGIOUS_AND_THEOLOGICAL_CLAIMS',
      claimText: `Human souls undergo cycle of reincarnation after death.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Human souls undergo cycle of reincarnation after death.`,
        classification: {
          propositionType: 'THEOLOGICAL_DOCTRINE',
          evidenceStatus: 'NOT_EMPIRICALLY_TESTABLE',
          reasoningValidity: 'NOT_APPLICABLE',
          displayBadge: 'FAITH_DOCTRINE',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Reincarnation is a spiritual transition of consciousness.',
            propositionType: 'THEOLOGICAL_DOCTRINE',
            assessment: 'NOT_EMPIRICALLY_TESTABLE',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 0,
          },
        ],
        evidenceRegistry: {},
        reasoningAssessment: { premisesVerifiedAccurate: [], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'NOT_EMPIRICALLY_TESTABLE', conformalPredictionSet: ['FAITH_DOCTRINE'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'FAITH_DOCTRINE',
        propositionType: 'THEOLOGICAL_DOCTRINE',
        evidenceStatus: 'NOT_EMPIRICALLY_TESTABLE',
        reasoningValidity: 'NOT_APPLICABLE',
      },
      independentlyReviewableRationale:
        'Metaphysical spiritual doctrines are outside empirical falsification and must be classified as FAITH_DOCTRINE without stigmatizing labels.',
    });
  }

  // Cases 64-66: Extraordinary Empirical Assertion (Asserting scientific proof for a miracle)
  for (let i = 64; i <= 66; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'RELIGIOUS_AND_THEOLOGICAL_CLAIMS',
      claimText: `Jesus walking on water is physically proven by modern hydrodynamics laboratory trials.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Jesus walking on water is physically proven by modern hydrodynamics laboratory trials.`,
        classification: {
          propositionType: 'EXTRAORDINARY_EMPIRICAL_ASSERTION',
          evidenceStatus: 'CONTRADICTED',
          reasoningValidity: 'NON_SEQUITUR',
          displayBadge: 'MISLEADING_INFERENCE',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'The Bible contains an account of Jesus walking on water.',
            propositionType: 'DESCRIPTIVE_RELIGIOUS_TEACHING',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_text`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
          {
            propositionId: `prop_${id}_2`,
            role: 'PREMISE',
            text: 'Controlled laboratory trials empirically proved human walking on liquid water surface tension.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'CONTRADICTED',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [`ev_${id}_physics`],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_text`]: {
            sourceIdentity: { publisher: 'Bible Gateway', url: 'https://biblegateway.com' },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: '8'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'He walked on the water.', charStart: 0, charEnd: 23, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'HISTORICAL_ARCHIVE', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Scriptural narrative', doesNotEstablish: 'Fluid physics proof', limitations: 'Theological text' },
          },
          [`ev_${id}_physics`]: {
            sourceIdentity: { publisher: 'Annual Review of Fluid Mechanics', url: 'https://annualreviews.org/fluid' },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: '9'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Water surface tension is insufficient by orders of magnitude to support human mass without high-speed mechanical footwear (>30 m/s).', charStart: 15, charEnd: 155, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Fluid mechanics constraints on human bipedal locomotion', doesNotEstablish: 'Theological validity', limitations: 'Physical science parameters' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['MISLEADING_INFERENCE'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'MISLEADING_INFERENCE',
        propositionType: 'EXTRAORDINARY_EMPIRICAL_ASSERTION',
        evidenceStatus: 'CONTRADICTED',
        reasoningValidity: 'NON_SEQUITUR',
      },
      independentlyReviewableRationale:
        'Asserting that empirical scientific proof exists for a supernatural event is an empirical falsehood that must be distinguished from the underlying faith tradition.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 8: Political Claims & Selective Context (Cases 67-74)
  // --------------------------------------------------------------------------
  for (let i = 67; i <= 74; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'POLITICAL_SELECTIVE_CONTEXT',
      claimText: `Senator Doe voted to defund veterans healthcare services in Bill H.R. 4022.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Senator Doe voted to defund veterans healthcare services in Bill H.R. 4022.`,
        classification: {
          propositionType: 'HISTORICAL_ACCOUNT',
          evidenceStatus: 'CONTRADICTED',
          reasoningValidity: 'CHERRY_PICKED_PREMISES',
          displayBadge: 'MISLEADING_INFERENCE',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Senator Doe voted against the omnibus package containing H.R. 4022.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_rollcall`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
          {
            propositionId: `prop_${id}_2`,
            role: 'CONCLUSION',
            text: 'Senator Doe intended to eliminate veterans healthcare.',
            propositionType: 'CAUSAL_INFERENCE',
            assessment: 'CONTRADICTED',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [`ev_${id}_floor`],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_rollcall`]: {
            sourceIdentity: { publisher: 'U.S. Senate Roll Call', url: `https://senate.gov/rollcall/${id}` },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: 'a'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Senator Doe voted Nay on passage of the omnibus bill.', charStart: 50, charEnd: 104, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'LEGAL_DOCKET', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Roll call vote', doesNotEstablish: 'Underlying intent', limitations: 'Parliamentary procedural record' },
          },
          [`ev_${id}_floor`]: {
            sourceIdentity: { publisher: 'Congressional Record', url: `https://congress.gov/record/${id}` },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: 'b'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Senator Doe cosponsored standalone veterans expansion bill S. 204 that passed unanimously the same week.', charStart: 25, charEnd: 133, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'LEGAL_DOCKET', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Standalone legislation sponsorship', doesNotEstablish: 'Omnibus debate motives', limitations: 'Legislative history' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['MISLEADING_INFERENCE'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'MISLEADING_INFERENCE',
        propositionType: 'HISTORICAL_ACCOUNT',
        evidenceStatus: 'CONTRADICTED',
        reasoningValidity: 'CHERRY_PICKED_PREMISES',
      },
      independentlyReviewableRationale:
        'Isolating an omnibus vote while omitting the contemporaneous standalone passage of identical funding is textbook parliamentary cherry-picking.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 9: Breaking-News Uncertainty (Cases 75-82)
  // --------------------------------------------------------------------------
  for (let i = 75; i <= 82; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'BREAKING_NEWS_UNCERTAINTY',
      claimText: `An active cargo aircraft crash near Zurich was caused by a surface-to-air missile attack.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `An active cargo aircraft crash near Zurich was caused by a surface-to-air missile attack.`,
        classification: {
          propositionType: 'CAUSAL_CLAIM',
          evidenceStatus: 'INSUFFICIENT_EVIDENCE',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'INSUFFICIENT_EVIDENCE',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Cargo aircraft lost radar contact near Zurich.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_radar`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
          {
            propositionId: `prop_${id}_2`,
            role: 'CONCLUSION',
            text: 'A missile destroyed the aircraft.',
            propositionType: 'CAUSAL_CLAIM',
            assessment: 'INSUFFICIENT_EVIDENCE',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 0,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_radar`]: {
            sourceIdentity: { publisher: 'Federal Office of Civil Aviation (FOCA)', url: 'https://bazl.admin.ch' },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: 'c'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'FOCA confirms aircraft incident; accident investigation board underway, cause unknown.', charStart: 0, charEnd: 86, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'PRIMARY_TECHNICAL_RECORD', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Incident occurrence and investigation launch', doesNotEstablish: 'Missile or explosive telemetry', limitations: 'Initial preliminary bulletin' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'INSUFFICIENT_EVIDENCE', conformalPredictionSet: ['INSUFFICIENT_EVIDENCE'], disclosedGaps: ['Accident board flight data recorder retrieval pending'] },
      },
      expected: {
        displayBadge: 'INSUFFICIENT_EVIDENCE',
        propositionType: 'CAUSAL_CLAIM',
        evidenceStatus: 'INSUFFICIENT_EVIDENCE',
        reasoningValidity: 'SOUND_INFERENCE',
      },
      independentlyReviewableRationale:
        'Breaking news events without flight recorder or radar telemetry cannot be affirmed or denied; they must strictly yield INSUFFICIENT_EVIDENCE with calibrated uncertainty.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 10: Syndicated Repetition & Shared Datasets (Cases 83-90)
  // --------------------------------------------------------------------------
  for (let i = 83; i <= 90; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'SYNDICATED_REPETITION_AND_DUPLICATE_DATASETS',
      claimText: `Ten global newspapers verified that a new battery chemistry charges in 3 seconds.`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        claimText: `Ten global newspapers verified that a new battery chemistry charges in 3 seconds.`,
        classification: {
          propositionType: 'EMPIRICAL_OBSERVATION',
          evidenceStatus: 'SUPPORTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'CORROBORATION_NOT_ESTABLISHED',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Press releases were syndicated across media outlets.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_syn1`, `ev_${id}_syn2`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1, // Must be 1, NOT 2!
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_syn1`]: {
            sourceIdentity: { publisher: 'Tech Portal Daily', url: `https://techdaily.com/${id}`, primaryArtifactId: 'WIRE_PR_009' },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: 'd'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Company claims battery prototype charges in seconds.', charStart: 0, charEnd: 53, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'SYNDICATED_DERIVATIVE', upstreamSourceId: 'WIRE_PR_009', independenceWeight: 0.0 },
            epistemicScope: { establishes: 'PR claims', doesNotEstablish: 'Independent lab bench testing', limitations: 'Corporate marketing' },
          },
          [`ev_${id}_syn2`]: {
            sourceIdentity: { publisher: 'Global Gadget Wire', url: `https://gadgetwire.com/${id}`, primaryArtifactId: 'WIRE_PR_009' },
            deterministicVerification: { fetchStatus: 'HTTP_200_OK', snapshotSha256: 'e'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Company claims battery prototype charges in seconds.', charStart: 0, charEnd: 53, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'SYNDICATED_DERIVATIVE', upstreamSourceId: 'WIRE_PR_009', independenceWeight: 0.0 },
            epistemicScope: { establishes: 'PR claims', doesNotEstablish: 'Independent lab bench testing', limitations: 'Corporate marketing' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`], conclusionFollowsDeductively: true, conclusionFollowsInductively: true, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'PRELIMINARY_EVIDENCE', conformalPredictionSet: ['CORROBORATION_NOT_ESTABLISHED'], disclosedGaps: ['Single upstream press release'] },
      },
      expected: {
        displayBadge: 'CORROBORATION_NOT_ESTABLISHED',
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceStatus: 'SUPPORTED',
        reasoningValidity: 'SOUND_INFERENCE',
        expectedOverclaimingViolation: 'DUPLICATE_DATASET_DOUBLE_COUNTING',
      },
      independentlyReviewableRationale:
        'Multiple syndicated news outlets quoting the exact same upstream corporate press release must have their independenceWeight zeroed and k_eff collapsed to 1.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 11: Debunking Quoted Myths (Cases 91-96)
  // --------------------------------------------------------------------------
  for (let i = 91; i <= 96; i++) {
    const id = `ADV-${String(i).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'DEBUNKING_QUOTED_MYTHS',
      claimText: `Video title: "Examining the false myth that NASA faked the Moon landing".`,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        videoContext: {
          videoId: `vid_${id}`,
          startTimeMs: 12000,
          endTimeMs: 25000,
          asrMinTokenConfidence: 0.96,
          speakerStance: 'SPEAKER_QUOTES_OTHER', // Creator does NOT assert the claim!
          modalityEvaluated: ['AUDIO_TRANSCRIPT', 'KEYFRAME_OCR'],
        },
        claimText: `Video title: "Examining the false myth that NASA faked the Moon landing".`,
        classification: {
          propositionType: 'EMPIRICAL_OBSERVATION',
          evidenceStatus: 'CONTRADICTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'FACTUAL_CONTRADICTION',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'PREMISE',
            text: 'Speaker is quoting a conspiracy theory in order to refute it.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: [`ev_${id}_transcript`],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 1,
          },
        ],
        evidenceRegistry: {
          [`ev_${id}_transcript`]: {
            sourceIdentity: { publisher: 'Video Transcript Engine', url: `https://truthworld.com/v/${id}` },
            deterministicVerification: { fetchStatus: 'ARCHIVE_LOCAL', snapshotSha256: 'f'.repeat(64), retrievedAtUtc: '2026-11-03T00:00:00Z', verifiedPassage: 'Many online claim NASA faked the landing, but this is thoroughly refuted by laser telemetry.', charStart: 0, charEnd: 92, exactMatchScore: 1.0, contextDistortionDetected: false },
            independence: { lineageType: 'PRIMARY_TECHNICAL_RECORD', upstreamSourceId: null, independenceWeight: 1.0 },
            epistemicScope: { establishes: 'Debunker speaker stance', doesNotEstablish: 'None', limitations: 'Discourse transcript' },
          },
        },
        reasoningAssessment: { premisesVerifiedAccurate: [`prop_${id}_1`], conclusionFollowsDeductively: true, conclusionFollowsInductively: true, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'HIGH_EVIDENCE_CONCORDANCE', conformalPredictionSet: ['FACTUAL_CONTRADICTION'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'FACTUAL_CONTRADICTION',
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceStatus: 'CONTRADICTED',
        reasoningValidity: 'SOUND_INFERENCE',
      },
      independentlyReviewableRationale:
        'When speakerStance is SPEAKER_QUOTES_OTHER, the examined claim must not be attributed to the creator as an asserted falsehood.',
    });
  }

  // --------------------------------------------------------------------------
  // STRATA 12: Satire & Rhetorical Hyperbole (Cases 97-100)
  // --------------------------------------------------------------------------
  const satireClaims = [
    'Installing this new operating system update took exactly four billion years.',
    'Politicians in capital city have officially passed legislation to outlaw Monday mornings.',
    'Local coffee shop espresso contains enough caffeine to power the city of Chicago for a week.',
    'Scientists confirm that cats secretly control global currency markets using telepathic purring.',
  ];

  satireClaims.forEach((claim, idx) => {
    const id = `ADV-${String(97 + idx).padStart(3, '0')}`;
    dataset.push({
      caseId: id,
      strata: 'SATIRE_AND_RHETORICAL_HYPERBOLE',
      claimText: claim,
      assessment: {
        assessmentId: `asmt_${id}`,
        schemaVersion: '2.0.0',
        videoContext: {
          videoId: `vid_${id}`,
          startTimeMs: 1000,
          endTimeMs: 6000,
          asrMinTokenConfidence: 0.95,
          speakerStance: 'SATIRICAL_FRAME',
          modalityEvaluated: ['AUDIO_TRANSCRIPT'],
        },
        claimText: claim,
        classification: {
          propositionType: 'NORMATIVE_OPINION',
          evidenceStatus: 'NOT_EMPIRICALLY_TESTABLE',
          reasoningValidity: 'NOT_APPLICABLE',
          displayBadge: 'NORMATIVE_VALUE_JUDGMENT',
        },
        claimDecomposition: [
          {
            propositionId: `prop_${id}_1`,
            role: 'CONTEXT',
            text: 'Statement represents rhetorical hyperbole or comedic parody.',
            propositionType: 'NORMATIVE_OPINION',
            assessment: 'NOT_EMPIRICALLY_TESTABLE',
            supportingEvidenceIds: [],
            contradictingEvidenceIds: [],
            independentPrimarySourceCount: 0,
          },
        ],
        evidenceRegistry: {},
        reasoningAssessment: { premisesVerifiedAccurate: [], conclusionFollowsDeductively: false, conclusionFollowsInductively: false, evaluatedAlternativeExplanations: [] },
        backendAuditFlags: { allReferencedCitationsDeterministicallyVerified: false, unverifiedEvidencePresent: false, closedWorldCitationCheckPassed: true },
        uncertainty: { numericalConfidenceAvailable: false, qualitativeTier: 'NOT_EMPIRICALLY_TESTABLE', conformalPredictionSet: ['NORMATIVE_VALUE_JUDGMENT'], disclosedGaps: [] },
      },
      expected: {
        displayBadge: 'NORMATIVE_VALUE_JUDGMENT',
        propositionType: 'NORMATIVE_OPINION',
        evidenceStatus: 'NOT_EMPIRICALLY_TESTABLE',
        reasoningValidity: 'NOT_APPLICABLE',
      },
      independentlyReviewableRationale:
        'Obvious rhetorical hyperbole and satire must never be evaluated literally as an empirical falsehood or misinformation.',
    });
  });

  return dataset;
}
