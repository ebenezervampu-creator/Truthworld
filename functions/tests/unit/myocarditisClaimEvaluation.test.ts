import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { SemanticEvidenceValidator } from '../../src/pipeline/services/semanticEvidenceValidator';
import {
  ClaimNature,
  FramingStyle,
  CredibilityAssessmentV2,
  EvidenceRegistryItem,
  ClaimDecompositionProposition,
} from '../../src/pipeline/types';

describe('TruthWorld Credibility System: COVID-19 mRNA Vaccine Myocarditis Compound Claim Evaluation (V2.2)', () => {
  const claimText =
    'COVID-19 mRNA vaccines cause myocarditis, particularly in young males. Several countries have acknowledged this risk, and scientific studies have confirmed an association. However, because the condition is rare and most cases are mild, governments and pharmaceutical companies deliberately concealed the true extent of vaccine-related heart damage. Therefore, COVID-19 vaccines are more dangerous than the disease itself for young men.';

  it('executes atomic decomposition (7 propositions), evaluates concealment as INSUFFICIENT_EVIDENCE, applies epidemiological stratification, and enforces consistent summary scoping', () => {
    // 1. Classification & Routing
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

    // 2. Full Evidence Registry with Complete Inspectable Records & Epidemiological Parameters
    const evidenceRegistry: Record<string, EvidenceRegistryItem> = {
      ev_cdc_mmwr_myocarditis_2021: {
        sourceIdentity: {
          publisher: 'Centers for Disease Control and Prevention (CDC) MMWR',
          url: 'https://www.cdc.gov/mmwr/volumes/70/wr/mm7027e2.htm',
          publicationDate: '2021-07-09',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'CDC_MMWR_VOL70_NO27_2021',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4e5f67890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'Rates of myocarditis/pericarditis were highest among males aged 12-29 years following dose 2 of mRNA COVID-19 vaccine; reporting rates exceeded expected background rates.',
          charStart: 120,
          charEnd: 275,
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
            'Statistically elevated rate of myocarditis/pericarditis in males aged 12–29 following dose 2 of mRNA COVID-19 vaccines',
          doesNotEstablish: 'Net overall excess harm compared to acute SARS-CoV-2 disease',
          limitations: 'Spontaneous reporting surveillance rates subject to underreporting or stimulated reporting bias',
          epidemiologicalParameters: {
            populationStudied: 'United States vaccine recipients (~141 million second doses)',
            ageGroup: '12–29 years (highest concentration 16–19 years)',
            sex: 'Male',
            vaccineProduct: 'BNT162b2 (Pfizer-BioNTech) and mRNA-1273 (Moderna)',
            doseNumber: 'Dose 2 (significantly higher than Dose 1)',
            absoluteRisk: '40.6 to 62.8 cases per million second doses in males aged 12–17 and 18–24',
            relativeRisk: 'Exceeded background rate expectations by factor of 3 to 10 depending on age stratum',
            outcomeDefinition: 'CDC working case definition for probable or confirmed myocarditis',
            followUpDuration: '30-day post-vaccination reporting window',
            confoundingLimitations: 'Passive surveillance lacks universal clinical verification of every mild outpatient event',
          },
        },
      },
      ev_nejm_israeli_cohort_2021: {
        sourceIdentity: {
          publisher: 'New England Journal of Medicine (NEJM)',
          url: 'https://doi.org/10.1056/NEJMoa2109730',
          publicationDate: '2021-10-06',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'DOI_10_1056_NEJMoa2109730',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'b2c3d4e5f6a17890b2c3d4e5f6a17890b2c3d4e5f6a17890b2c3d4e5f6a17890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'Among 2.5 million vaccinated persons, myocarditis was rare and concentrated in young males; the clinical presentation was generally mild with rapid resolution of clinical symptoms in the vast majority of patients.',
          charStart: 45,
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
          establishes:
            'Overall myocarditis incidence is rare (~2.13 cases per 100,000 persons); clinical course is predominantly mild with median 4-day hospital stay',
          doesNotEstablish: 'Absence of rare severe cases or universal long-term myocardial scar absence',
          limitations: 'Integrated health record population data from single national healthcare system',
          epidemiologicalParameters: {
            populationStudied: 'Clalit Health Services Israeli population (N = 2,558,421 vaccinated individuals)',
            ageGroup: 'All age groups, with peak incidence in males aged 16–29 years (10.7 per 100,000)',
            sex: 'Male (91% of cases)',
            vaccineProduct: 'BNT162b2 (Pfizer-BioNTech)',
            doseNumber: 'Dose 2 (76% of myocarditis events occurred within 3–5 days of dose 2)',
            absoluteRisk: '2.13 cases per 100,000 vaccinated overall; 10.69 per 100,000 in males aged 16–29',
            relativeRisk: 'Risk difference: 1.76 cases per 100,000 persons',
            outcomeDefinition: 'Brighton Collaboration criteria confirmed by cardiologist adjudication and troponin elevation',
            followUpDuration: 'Mean clinical follow-up 83 days',
            confoundingLimitations: 'Conducted during early Alpha/Delta variant period under universal single-payer tracking',
          },
        },
      },
      ev_fda_ema_regulatory_timeline: {
        sourceIdentity: {
          publisher: 'U.S. Food and Drug Administration (FDA) & European Medicines Agency (EMA)',
          url: 'https://www.fda.gov/news-events/press-announcements/fda-regulators-add-warning-regarding-myocarditis',
          publicationDate: '2021-06-25',
          sourceClassification: 'REGULATORY_RECORD',
          primaryArtifactId: 'FDA_REGULATORY_ACTION_JUNE2021',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'c3d4e5f6a1b27890c3d4e5f6a1b27890c3d4e5f6a1b27890c3d4e5f6a1b27890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'FDA and EMA updated Fact Sheets for healthcare providers and vaccine recipients in June 2021 to include a warning regarding myocarditis and pericarditis following public ACIP/PRAC review sessions.',
          charStart: 10,
          charEnd: 205,
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
            'Proactive public disclosure of the myocarditis signal, open Advisory Committee hearings, and official warning label additions within weeks of signal detection in spring 2021',
          doesNotEstablish: 'Complete proof that no internal draft communications were ever withheld anywhere',
          limitations: 'Official administrative regulatory dockets and press records',
          epidemiologicalParameters: {
            populationStudied: 'Global vaccine recipient surveillance',
            ageGroup: 'Adolescent and adult indications',
            sex: 'All sexes',
            vaccineProduct: 'Comirnaty (Pfizer) and Spikevax (Moderna)',
            doseNumber: 'Dose 1 and Dose 2',
            outcomeDefinition: 'Acute inflammatory perimyocardial syndrome warning text',
            confoundingLimitations: 'Regulatory communication timing reflects speed of safety signal confirmation',
          },
        },
      },
      ev_comparative_benefit_risk_nejm: {
        sourceIdentity: {
          publisher: 'New England Journal of Medicine & CDC ACIP',
          url: 'https://doi.org/10.1056/NEJMoa2110475',
          publicationDate: '2021-08-25',
          sourceClassification: 'PRIMARY',
          primaryArtifactId: 'DOI_10_1056_NEJMoa2110475',
        },
        deterministicVerification: {
          fetchStatus: 'HTTP_200_OK',
          snapshotSha256: 'd4e5f6a1b2c37890d4e5f6a1b2c37890d4e5f6a1b2c37890d4e5f6a1b2c37890',
          retrievedAtUtc: '2026-11-03T00:00:00Z',
          verifiedPassage:
            'SARS-CoV-2 infection was associated with substantially higher risk of myocarditis (risk ratio 18.28) and severe cardiovascular injury than mRNA vaccination (risk ratio 3.24); vaccination prevented far more hospitalizations, intensive care admissions, and deaths than associated adverse events.',
          charStart: 80,
          charEnd: 360,
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
            'Direct SARS-CoV-2 viral infection produces acute myocardial and systemic endothelial injury at substantially higher rates than vaccination across matched cohorts',
          doesNotEstablish: 'Zero incidence of post-vaccination adverse events',
          limitations: 'Observational matched cohort design with potential unmeasured test-seeking behavior',
          epidemiologicalParameters: {
            populationStudied: 'Matched cohort of 884,828 vaccinated persons vs 884,828 unvaccinated infected controls',
            ageGroup: '16 years and older',
            sex: 'All sexes, with subgroup analyses for males',
            vaccineProduct: 'BNT162b2',
            doseNumber: 'Complete two-dose primary series',
            absoluteRisk:
              'Infection excess myocarditis: 11.0 events per 100,000 persons; Vaccine excess myocarditis: 2.7 events per 100,000 persons',
            relativeRisk:
              'Infection myocarditis Risk Ratio: 18.28 (95% CI 3.95–25.12); Vaccination myocarditis Risk Ratio: 3.24 (95% CI 1.55–5.42)',
            outcomeDefinition: 'Hospital-diagnosed acute myocarditis, arrhythmia, acute kidney injury, pulmonary embolism, pericarditis',
            followUpDuration: '42 days post-exposure',
            confoundingLimitations: 'Risk of infection depends on circulating viral prevalence; variant virulence differs over time',
          },
        },
      },
    };

    // 3. OBJECTIVE 1: Atomic Claim Decomposition into 7 Granular Propositions
    const claimDecomposition: ClaimDecompositionProposition[] = [
      {
        propositionId: 'prop_myo_1',
        role: 'PREMISE',
        text: 'COVID-19 mRNA vaccines cause an elevated risk of myocarditis.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_cdc_mmwr_myocarditis_2021', 'ev_nejm_israeli_cohort_2021'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'prop_myo_2',
        role: 'PREMISE',
        text: 'The elevated risk of myocarditis is concentrated particularly in young males.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_cdc_mmwr_myocarditis_2021', 'ev_nejm_israeli_cohort_2021'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'prop_myo_3',
        role: 'PREMISE',
        text: 'The reporting rate of myocarditis is significantly higher after the second dose than the first dose.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_cdc_mmwr_myocarditis_2021', 'ev_nejm_israeli_cohort_2021'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'prop_myo_4',
        role: 'PREMISE',
        text: 'Multiple countries and scientific studies officially acknowledged and confirmed this association.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_fda_ema_regulatory_timeline', 'ev_cdc_mmwr_myocarditis_2021'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 2,
      },
      {
        propositionId: 'prop_myo_5',
        role: 'PREMISE',
        text: 'Post-vaccine myocarditis is rare, and most clinical cases present as mild with rapid symptom resolution.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        assessment: 'SUPPORTED',
        supportingEvidenceIds: ['ev_nejm_israeli_cohort_2021'],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 1,
      },
      {
        propositionId: 'prop_myo_6',
        role: 'PREMISE',
        text: 'Governments and pharmaceutical companies deliberately concealed the true extent of vaccine-related heart damage.',
        propositionType: 'CAUSAL_CLAIM',
        // OBJECTIVE 2: Intent & Concealment must be INSUFFICIENT_EVIDENCE rather than CONTRADICTED
        assessment: 'INSUFFICIENT_EVIDENCE',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: [],
        independentPrimarySourceCount: 0,
      },
      {
        propositionId: 'prop_myo_7',
        role: 'CONCLUSION',
        text: 'Therefore, COVID-19 vaccines are more dangerous than the disease itself for young men.',
        propositionType: 'CAUSAL_INFERENCE',
        // OBJECTIVE 3: Refuted by comparative benefit-risk matched cohort epidemiology
        assessment: 'CONTRADICTED',
        supportingEvidenceIds: [],
        contradictingEvidenceIds: ['ev_comparative_benefit_risk_nejm'],
        independentPrimarySourceCount: 1,
      },
    ];

    // 4. OBJECTIVE 2: Intent & Concealment Engine Evaluation
    const concealmentResult = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: claimDecomposition[5].text,
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: true,
    });
    expect(concealmentResult.assessment).toBe('INSUFFICIENT_EVIDENCE');
    expect(concealmentResult.distinctionCategory).toBe('INSUFFICIENT_EVIDENCE_OF_INTENT');

    // 5. Semantic Links Construction
    const semanticLinks = [
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_cdc_mmwr_myocarditis_2021',
        targetPropositionId: 'prop_myo_1',
        propositionText: claimDecomposition[0].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_cdc_mmwr_myocarditis_2021'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_cdc_mmwr_myocarditis_2021',
        targetPropositionId: 'prop_myo_2',
        propositionText: claimDecomposition[1].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_cdc_mmwr_myocarditis_2021'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_cdc_mmwr_myocarditis_2021',
        targetPropositionId: 'prop_myo_3',
        propositionText: claimDecomposition[2].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_cdc_mmwr_myocarditis_2021'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_fda_ema_regulatory_timeline',
        targetPropositionId: 'prop_myo_4',
        propositionText: claimDecomposition[3].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_fda_ema_regulatory_timeline'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_nejm_israeli_cohort_2021',
        targetPropositionId: 'prop_myo_5',
        propositionText: claimDecomposition[4].text,
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: evidenceRegistry['ev_nejm_israeli_cohort_2021'],
        candidateRelationship: 'SUPPORTS',
        scopeOfSupport: 'FULL_PROPOSITION',
      }),
      SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_comparative_benefit_risk_nejm',
        targetPropositionId: 'prop_myo_7',
        propositionText: claimDecomposition[6].text,
        propositionType: 'CAUSAL_INFERENCE',
        evidenceItem: evidenceRegistry['ev_comparative_benefit_risk_nejm'],
        candidateRelationship: 'CONTRADICTS',
        scopeOfSupport: 'CONTRADICTING_EVIDENCE',
      }),
    ];

    // 6. Provenance Graph Construction ($k_eff calculation)
    const provenanceGraph = SemanticEvidenceValidator.constructProvenanceGraph({
      evidenceRegistry,
      datasets: [
        { datasetId: 'CDC_MMWR_VOL70_NO27_2021', name: 'CDC VAERS & V-safe Surveillance' },
        { datasetId: 'DOI_10_1056_NEJMoa2109730', name: 'Clalit Health Services Israeli Cohort' },
        { datasetId: 'FDA_REGULATORY_ACTION_JUNE2021', name: 'FDA/EMA Advisory Meeting Records' },
        { datasetId: 'DOI_10_1056_NEJMoa2110475', name: 'Comparative Cohort Benefit-Risk Database' },
      ],
    });

    // 7. OBJECTIVE 5: Explicit Summary Field Scoping & Consistency Engine
    const scoping = SemanticEvidenceValidator.computeScopingSummary({
      propositions: claimDecomposition,
      links: semanticLinks,
      k_eff: provenanceGraph.effectiveIndependentSourcesCount,
    });

    expect(scoping.semanticEvidenceLevel).toBe('MIXED_EVIDENCE');
    expect(scoping.semanticEvidenceScope).toBe('INDIVIDUAL_EVIDENCE_LINKS');
    expect(scoping.sourceCountScope).toBe('ENTIRE_ASSESSMENT');
    expect(scoping.effectiveIndependentSourcesCount).toBe(4);

    const assessment: CredibilityAssessmentV2 = {
      assessmentId: 'asmt_covid_mrna_myocarditis_v2_2',
      schemaVersion: '2.0.0',
      assessmentVersion: 2,
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
        premisesVerifiedAccurate: ['prop_myo_1', 'prop_myo_2', 'prop_myo_3', 'prop_myo_4', 'prop_myo_5'],
        conclusionFollowsDeductively: false,
        conclusionFollowsInductively: false,
        evaluatedAlternativeExplanations: [
          {
            explanation:
              'Direct SARS-CoV-2 viral infection produces acute endothelial and myocardial injury at substantially higher rates than vaccination across matched cohorts (11.0 excess events per 100k vs 2.7 per 100k).',
            supportingEvidenceIds: ['ev_comparative_benefit_risk_nejm'],
          },
          {
            explanation:
              'Vaccine safety signal was identified by early warning systems and publicly presented at open Advisory Committee meetings in June 2021; public disclosure refutes total communication blackout, but absence of evidence for concealment cannot substantiate intentional cover-up.',
            supportingEvidenceIds: ['ev_fda_ema_regulatory_timeline'],
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
          'Subclinical myocarditis incidence detected solely via cardiac troponin I biomarkers without overt symptoms.',
          'Long-term outcome data beyond 2 years for adolescents recovering from acute vaccine-associated perimyocarditis.',
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

    // 8. Pre-Commit Database Constraint Validation
    const validation = DeterministicVerifierService.validateAssessmentV2(assessment);
    expect(validation.isValid).toBe(true);
    expect(validation.errors).toEqual([]);

    // 9. Display Badge Check
    const derivedBadge = DeterministicVerifierService.deriveDisplayBadge(
      assessment.classification.propositionType,
      assessment.classification.evidenceStatus,
      assessment.classification.reasoningValidity,
      assessment.semanticValidation?.overclaimingAudit
    );
    expect(derivedBadge).toBe('MISLEADING_INFERENCE');

    console.log('\n--- TRUTHWORLD V2.2 RE-RUN RESULT ---');
    console.log(JSON.stringify(assessment, null, 2));
  });
});
