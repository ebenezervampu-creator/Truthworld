import { SemanticEvidenceValidator } from '../../src/pipeline/services/semanticEvidenceValidator';
import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import {
  CredibilityAssessmentV2,
  EvidenceRegistryItem,
  SemanticEvidenceLink,
} from '../../src/pipeline/types';

describe('Unit: Semantic Evidence Validation & Overclaiming Prevention', () => {
  // Base test registry item
  const mockEvidenceItem: EvidenceRegistryItem = {
    sourceIdentity: {
      publisher: 'The New England Journal of Medicine',
      url: 'https://nejm.org/doi/10.1056/NEJMoa12345',
      primaryArtifactId: 'NEJM-2024-TREATMENT-TRIAL',
    },
    deterministicVerification: {
      fetchStatus: 'HTTP_200_OK',
      snapshotSha256: 'a'.repeat(64),
      retrievedAtUtc: '2026-11-03T00:00:00Z',
      verifiedPassage:
        'In the primary cohort, symptom severity decreased by 40% (p = 0.34, not statistically significant compared to placebo).',
      charStart: 120,
      charEnd: 240,
      exactMatchScore: 1.0,
      contextDistortionDetected: false,
    },
    independence: {
      lineageType: 'PEER_REVIEWED_RESEARCH',
      upstreamSourceId: null,
      independenceWeight: 1.0,
    },
    epistemicScope: {
      establishes: 'A 40% numerical symptom reduction was observed without statistical significance.',
      doesNotEstablish: 'Efficacy superior to placebo.',
      limitations: 'Underpowered cohort; p = 0.34.',
    },
  };

  describe('Objective 1: Semantic Evidence Relationship Assessment', () => {
    it('evaluates semantic links with explicit relationships and disclosed caveats', () => {
      const link = SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_001',
        targetPropositionId: 'prop_001',
        propositionText: 'Treatment shows statistically significant cure rate.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: mockEvidenceItem,
        candidateRelationship: 'CONTRADICTS',
        rationale: 'The trial explicitly reports p = 0.34, disproving statistical significance.',
      });

      expect(link.semanticRelationship).toBe('CONTRADICTS');
      expect(link.evidenceId).toBe('ev_001');
      expect(link.disclosedCaveats?.length).toBeGreaterThan(0);
      expect(link.disclosedCaveats?.some(c => c.includes('p = 0.34'))).toBe(true);
    });

    it('automatically flags CONTEXTUALLY_LIMITS when contextDistortionDetected is true', () => {
      const distortedItem: EvidenceRegistryItem = JSON.parse(JSON.stringify(mockEvidenceItem));
      distortedItem.deterministicVerification.contextDistortionDetected = true;

      const link = SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_002',
        targetPropositionId: 'prop_002',
        propositionText: 'The treatment reduced symptoms by 40%.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: distortedItem,
      });

      expect(link.semanticRelationship).toBe('CONTEXTUALLY_LIMITS');
    });

    it('identifies STUDY_HYPOTHESIS_DISCUSSED from text formulation', () => {
      const hypothesisItem: EvidenceRegistryItem = JSON.parse(JSON.stringify(mockEvidenceItem));
      hypothesisItem.deterministicVerification.verifiedPassage =
        'Previous authors hypothesized that cellular metabolism accelerates under prolonged cold exposure; however, experimental measurements failed to verify this.';

      const link = SemanticEvidenceValidator.evaluateSemanticLink({
        evidenceId: 'ev_003',
        targetPropositionId: 'prop_003',
        propositionText: 'Cold exposure accelerates human metabolism.',
        propositionType: 'EMPIRICAL_OBSERVATION',
        evidenceItem: hypothesisItem,
      });

      expect(link.hypothesisVsFindingDistinction).toBe('STUDY_HYPOTHESIS_DISCUSSED');
    });
  });

  describe('Objective 2: Prevention of Evidence Overclaiming (6 Scenarios)', () => {
    it('Scenario 1: detects AUTHENTIC_BUT_IRRELEVANT when genuine citation has IRRELEVANT relationship', () => {
      const assessment: any = {
        evidenceRegistry: { ev_optics: mockEvidenceItem },
        claimDecomposition: [
          {
            propositionId: 'prop_propulsion',
            role: 'PREMISE',
            text: 'Saturn V used an unproven ion propulsion engine in 1969.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED', // Claiming supported!
            supportingEvidenceIds: ['ev_optics'],
            contradictingEvidenceIds: [],
          },
        ],
      };

      const semanticLinks: SemanticEvidenceLink[] = [
        {
          evidenceId: 'ev_optics',
          targetPropositionId: 'prop_propulsion',
          semanticRelationship: 'IRRELEVANT',
          rationale: 'Citation describes camera lens optical coatings, which is completely irrelevant to rocket propulsion.',
          scopeOfSupport: 'NO_SUPPORT',
        },
      ];

      const audit = SemanticEvidenceValidator.auditOverclaiming(assessment, semanticLinks);
      expect(audit.overclaimingDetected).toBe(true);
      expect(audit.violationTypes).toContain('AUTHENTIC_BUT_IRRELEVANT');
    });

    it('Scenario 2: detects PARTIAL_SUPPORT_TREATED_AS_FULL when evidence only supports a partial premise', () => {
      const assessment: any = {
        evidenceRegistry: { ev_meeting: mockEvidenceItem },
        claimDecomposition: [
          {
            propositionId: 'prop_conspiracy',
            role: 'PREMISE',
            text: 'Officials met in Geneva and agreed to falsify economic data.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED', // Claiming full support!
            supportingEvidenceIds: ['ev_meeting'],
            contradictingEvidenceIds: [],
          },
        ],
      };

      const semanticLinks: SemanticEvidenceLink[] = [
        {
          evidenceId: 'ev_meeting',
          targetPropositionId: 'prop_conspiracy',
          semanticRelationship: 'PARTIALLY_SUPPORTS',
          rationale: 'The minutes confirm that the officials met in Geneva, but do not support the assertion of falsifying data.',
          scopeOfSupport: 'PARTIAL_PREMISE_ONLY',
        },
      ];

      const audit = SemanticEvidenceValidator.auditOverclaiming(assessment, semanticLinks);
      expect(audit.overclaimingDetected).toBe(true);
      expect(audit.violationTypes).toContain('PARTIAL_SUPPORT_TREATED_AS_FULL');
    });

    it('Scenario 3: detects QUALIFICATION_OMISSION when passage caveat is ignored', () => {
      const assessment: any = {
        evidenceRegistry: { ev_trial: mockEvidenceItem },
        claimDecomposition: [
          {
            propositionId: 'prop_cure',
            role: 'PREMISE',
            text: 'The drug cures 40% of patients unconditionally.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: ['ev_trial'],
            contradictingEvidenceIds: [],
          },
        ],
      };

      const semanticLinks: SemanticEvidenceLink[] = [
        {
          evidenceId: 'ev_trial',
          targetPropositionId: 'prop_cure',
          semanticRelationship: 'CONTEXTUALLY_LIMITS',
          rationale: 'Passage omitted the statistical non-significance (p = 0.34).',
          scopeOfSupport: 'FULL_PROPOSITION',
        },
      ];

      const audit = SemanticEvidenceValidator.auditOverclaiming(assessment, semanticLinks);
      expect(audit.overclaimingDetected).toBe(true);
      expect(audit.violationTypes).toContain('QUALIFICATION_OMISSION');
    });

    it('Scenario 4: detects HYPOTHESIS_TREATED_AS_FINDING when study hypothesis is cited as empirical proof', () => {
      const assessment: any = {
        evidenceRegistry: { ev_hypo: mockEvidenceItem },
        claimDecomposition: [
          {
            propositionId: 'prop_hypo',
            role: 'PREMISE',
            text: 'Cold exposure accelerates human metabolic rate.',
            propositionType: 'EMPIRICAL_OBSERVATION',
            assessment: 'SUPPORTED',
            supportingEvidenceIds: ['ev_hypo'],
            contradictingEvidenceIds: [],
          },
        ],
      };

      const semanticLinks: SemanticEvidenceLink[] = [
        {
          evidenceId: 'ev_hypo',
          targetPropositionId: 'prop_hypo',
          semanticRelationship: 'SUPPORTS',
          rationale: 'Paper discusses the hypothesis in Section 1.',
          hypothesisVsFindingDistinction: 'STUDY_HYPOTHESIS_DISCUSSED',
          scopeOfSupport: 'FULL_PROPOSITION',
        },
      ];

      const audit = SemanticEvidenceValidator.auditOverclaiming(assessment, semanticLinks);
      expect(audit.overclaimingDetected).toBe(true);
      expect(audit.violationTypes).toContain('HYPOTHESIS_TREATED_AS_FINDING');
    });

    it('Scenario 5: detects CONCLUSION_CONTRADICTS_ABSTRACT_INTERPRETATION when paper conclusion differs', () => {
      const contradictingItem: EvidenceRegistryItem = JSON.parse(JSON.stringify(mockEvidenceItem));
      contradictingItem.epistemicScope.limitations =
        'Trial concluded overall mortality was unaffected; contradicts preliminary abstract interpretation.';

      const assessment: any = {
        evidenceRegistry: { ev_contra: contradictingItem },
        claimDecomposition: [],
      };

      const audit = SemanticEvidenceValidator.auditOverclaiming(assessment, []);
      expect(audit.overclaimingDetected).toBe(true);
      expect(audit.violationTypes).toContain('CONCLUSION_CONTRADICTS_ABSTRACT_INTERPRETATION');
    });

    it('Scenario 6: detects DUPLICATE_DATASET_DOUBLE_COUNTING when multiple publications cite the same clinical trial ID', () => {
      const pub1: EvidenceRegistryItem = {
        ...mockEvidenceItem,
        sourceIdentity: { publisher: 'Journal A', url: 'https://a.org', primaryArtifactId: 'NCT01234567' },
      };
      const pub2: EvidenceRegistryItem = {
        ...mockEvidenceItem,
        sourceIdentity: { publisher: 'Journal B', url: 'https://b.org', primaryArtifactId: 'NCT01234567' },
      };

      const assessment: any = {
        evidenceRegistry: { ev_pub1: pub1, ev_pub2: pub2 },
        claimDecomposition: [],
      };

      const provenanceGraph = SemanticEvidenceValidator.constructProvenanceGraph({
        evidenceRegistry: assessment.evidenceRegistry,
        datasets: [{ datasetId: 'NCT01234567', name: 'Phase III Multi-Center Trial' }],
      });

      const audit = SemanticEvidenceValidator.auditOverclaiming(assessment, [], provenanceGraph);
      expect(audit.overclaimingDetected).toBe(true);
      expect(audit.violationTypes).toContain('DUPLICATE_DATASET_DOUBLE_COUNTING');
      // k_eff should collapse to 1 dataset
      expect(provenanceGraph.effectiveIndependentSourcesCount).toBe(1);
    });
  });

  describe('Objective 3: Bipartite Evidentiary Graph & Source Independence ($k_eff)', () => {
    it('collapses 5 syndicated news reprints into k_eff = 1', () => {
      const registry: Record<string, EvidenceRegistryItem> = {};
      for (let i = 1; i <= 5; i++) {
        registry[`ev_${i}`] = {
          sourceIdentity: { publisher: `News Outlet ${i}`, url: `https://news${i}.com` },
          deterministicVerification: { ...mockEvidenceItem.deterministicVerification },
          independence: {
            lineageType: 'SYNDICATED_DERIVATIVE',
            upstreamSourceId: 'REUTERS_WIRE_881',
            independenceWeight: 0.0,
          },
          epistemicScope: { ...mockEvidenceItem.epistemicScope },
        };
      }

      const graph = SemanticEvidenceValidator.constructProvenanceGraph({ evidenceRegistry: registry });
      expect(graph.effectiveIndependentSourcesCount).toBe(1);
    });

    it('prevents double-counting duplicate datasets in computeEffectiveIndependence', () => {
      const registry: Record<string, EvidenceRegistryItem> = {
        ev_study_1: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Study Alpha', url: 'https://alpha.org', primaryArtifactId: 'DATASET_APOLLO_TELEMETRY' },
          independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
        },
        ev_study_2: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Study Beta', url: 'https://beta.org', primaryArtifactId: 'DATASET_APOLLO_TELEMETRY' }, // Duplicate dataset!
          independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
        },
      };

      const { k_eff, totalWeight } = DeterministicVerifierService.computeEffectiveIndependence(
        ['ev_study_1', 'ev_study_2'],
        registry
      );

      // Even though there are 2 studies, they share DATASET_APOLLO_TELEMETRY, so k_eff = 1
      expect(k_eff).toBe(1);
      expect(totalWeight).toBe(2.0);
    });
  });

  describe('Objective 4: Refined Religious & Historical Classification Guardrails', () => {
    it('permits DESCRIPTIVE_RELIGIOUS_TEACHING to be SUPPORTED when backed by scriptural text citations', () => {
      const result = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'DESCRIPTIVE_RELIGIOUS_TEACHING',
        evidenceStatus: 'SUPPORTED',
        hasScripturalCitations: true,
      });

      expect(result.isValid).toBe(true);
    });

    it('rejects DESCRIPTIVE_RELIGIOUS_TEACHING marked SUPPORTED without documentary scripture citations', () => {
      const result = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'DESCRIPTIVE_RELIGIOUS_TEACHING',
        evidenceStatus: 'SUPPORTED',
        hasScripturalCitations: false,
      });

      expect(result.isValid).toBe(false);
      expect(result.error).toContain('primary scriptural or documentary textual evidence');
    });

    it('permits HISTORICAL_DOCUMENTARY_CLAIM to be empirically evaluated as SUPPORTED or CONTRADICTED', () => {
      const supportResult = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'HISTORICAL_DOCUMENTARY_CLAIM',
        evidenceStatus: 'SUPPORTED',
      });
      expect(supportResult.isValid).toBe(true);

      const contradictResult = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'HISTORICAL_DOCUMENTARY_CLAIM',
        evidenceStatus: 'CONTRADICTED',
      });
      expect(contradictResult.isValid).toBe(true);
    });

    it('rejects HISTORICAL_DOCUMENTARY_CLAIM if forced into NOT_EMPIRICALLY_TESTABLE', () => {
      const result = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'HISTORICAL_DOCUMENTARY_CLAIM',
        evidenceStatus: 'NOT_EMPIRICALLY_TESTABLE',
      });

      expect(result.isValid).toBe(false);
      expect(result.error).toContain('must not be marked NOT_EMPIRICALLY_TESTABLE');
    });

    it('strictly forces THEOLOGICAL_DOCTRINE into NOT_EMPIRICALLY_TESTABLE', () => {
      const supportedResult = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'THEOLOGICAL_DOCTRINE',
        evidenceStatus: 'SUPPORTED',
      });
      expect(supportedResult.isValid).toBe(false);

      const untestableResult = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'THEOLOGICAL_DOCTRINE',
        evidenceStatus: 'NOT_EMPIRICALLY_TESTABLE',
      });
      expect(untestableResult.isValid).toBe(true);
    });

    it('rejects EXTRAORDINARY_EMPIRICAL_ASSERTION claiming scientific proof without empirical verification', () => {
      const result = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: 'EXTRAORDINARY_EMPIRICAL_ASSERTION',
        evidenceStatus: 'SUPPORTED',
        hasEmpiricalTelemetricCitations: false, // Only scripture, no physical science
      });

      expect(result.isValid).toBe(false);
      expect(result.error).toContain('independent empirical verification');
    });
  });

  describe('V2.1 Hardening: Complex Provenance Graphs & Overclaiming Badge Overrides (Issues 1 & 3)', () => {
    it('Scenario 1: collapses 5 newspapers reporting same government press release to k_eff = 1', () => {
      const registry: Record<string, EvidenceRegistryItem> = {};
      for (let i = 1; i <= 5; i++) {
        registry[`ev_news_${i}`] = {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: `Daily Tribune ${i}`, url: `https://tribune${i}.com` },
          independence: {
            lineageType: 'SYNDICATED_DERIVATIVE',
            upstreamSourceId: 'GOV_PRESS_RELEASE_2026',
            independenceWeight: 0.0,
          },
        };
      }

      const { k_eff } = DeterministicVerifierService.computeEffectiveIndependence(
        Object.keys(registry),
        registry
      );
      expect(k_eff).toBe(1);
    });

    it('Scenario 2: collapses 3 papers using the same underlying clinical trial dataset to k_eff = 1', () => {
      const registry: Record<string, EvidenceRegistryItem> = {
        paper_1: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Journal of Medicine', url: 'https://nejm.org/1', primaryArtifactId: 'NCT99887766' },
          independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
        },
        paper_2: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Lancet Oncology', url: 'https://thelancet.com/2', primaryArtifactId: 'NCT99887766' },
          independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
        },
        paper_3: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'BMJ Global', url: 'https://bmj.com/3', primaryArtifactId: 'NCT99887766' },
          independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
        },
      };

      const { k_eff } = DeterministicVerifierService.computeEffectiveIndependence(
        ['paper_1', 'paper_2', 'paper_3'],
        registry
      );
      expect(k_eff).toBe(1);
    });

    it('Scenario 3: assigns k_eff = 2 to two independent researchers using distinct datasets', () => {
      const registry: Record<string, EvidenceRegistryItem> = {
        study_us: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'CDC Telemetry', url: 'https://cdc.gov/data', primaryArtifactId: 'DATASET_US_COHORT' },
          independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
        },
        study_eu: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'ECDC Bulletin', url: 'https://ecdc.europa.eu', primaryArtifactId: 'DATASET_EU_COHORT' },
          independence: { lineageType: 'PEER_REVIEWED_RESEARCH', upstreamSourceId: null, independenceWeight: 1.0 },
        },
      };

      const { k_eff } = DeterministicVerifierService.computeEffectiveIndependence(
        ['study_us', 'study_eu'],
        registry
      );
      expect(k_eff).toBe(2);
    });

    it('Scenario 4: hybrid investigative report + syndicated citation collapses correctly', () => {
      const registry: Record<string, EvidenceRegistryItem> = {
        investigative: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'ProPublica Investigative Team', url: 'https://propublica.org/investigation' },
          independence: { lineageType: 'PRIMARY_TECHNICAL_RECORD', upstreamSourceId: null, independenceWeight: 1.0 },
        },
        syndicated_wire: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Local Gazette', url: 'https://localgazette.com/wire' },
          independence: { lineageType: 'SYNDICATED_DERIVATIVE', upstreamSourceId: 'AP_WIRE_SUMMARY', independenceWeight: 0.0 },
        },
      };

      const { k_eff } = DeterministicVerifierService.computeEffectiveIndependence(
        ['investigative', 'syndicated_wire'],
        registry
      );
      // 1 standalone primary + 1 upstream wire source = 2 distinct streams of reporting
      expect(k_eff).toBe(2);
    });

    it('Scenario 5: resolves multi-hop derivative chains (A cites B, B cites C) to single root upstream source', () => {
      const registry: Record<string, EvidenceRegistryItem> = {
        node_c_root: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Primary Gov Whitepaper', url: 'https://gov.whitepaper.org' },
          independence: { lineageType: 'PRIMARY_TECHNICAL_RECORD', upstreamSourceId: null, independenceWeight: 1.0 },
        },
        node_b_wire: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Wire Service', url: 'https://wire.com/news' },
          independence: { lineageType: 'SYNDICATED_DERIVATIVE', upstreamSourceId: 'node_c_root', independenceWeight: 0.0 },
        },
        node_a_blog: {
          ...mockEvidenceItem,
          sourceIdentity: { publisher: 'Tech Blog', url: 'https://techblog.com/post' },
          independence: { lineageType: 'SYNDICATED_DERIVATIVE', upstreamSourceId: 'node_b_wire', independenceWeight: 0.0 }, // Cites B, which cites C
        },
      };

      const { k_eff } = DeterministicVerifierService.computeEffectiveIndependence(
        ['node_a_blog', 'node_b_wire'],
        registry
      );
      // Both resolve to node_c_root, so k_eff = 1
      expect(k_eff).toBe(1);
    });

    it('Issue 1: deriveDisplayBadge overrides positive badges when overclaiming violations are present', () => {
      // 1. Duplicate dataset violation overrides EMPIRICALLY_VERIFIED to CORROBORATION_NOT_ESTABLISHED
      const duplicateAudit: any = {
        overclaimingDetected: true,
        violationTypes: ['DUPLICATE_DATASET_DOUBLE_COUNTING'],
      };
      const badge1 = DeterministicVerifierService.deriveDisplayBadge(
        'EMPIRICAL_OBSERVATION',
        'SUPPORTED',
        'SOUND_INFERENCE',
        duplicateAudit
      );
      expect(badge1).toBe('CORROBORATION_NOT_ESTABLISHED');

      // 2. Partial support treated as full overrides to PARTIALLY_SUPPORTED
      const partialAudit: any = {
        overclaimingDetected: true,
        violationTypes: ['PARTIAL_SUPPORT_TREATED_AS_FULL'],
      };
      const badge2 = DeterministicVerifierService.deriveDisplayBadge(
        'EMPIRICAL_OBSERVATION',
        'SUPPORTED',
        'SOUND_INFERENCE',
        partialAudit
      );
      expect(badge2).toBe('PARTIALLY_SUPPORTED');

      // 3. Authentic but irrelevant overrides to MISLEADING_EVIDENCE_PRESENTATION
      const irrelevantAudit: any = {
        overclaimingDetected: true,
        violationTypes: ['AUTHENTIC_BUT_IRRELEVANT'],
      };
      const badge3 = DeterministicVerifierService.deriveDisplayBadge(
        'EMPIRICAL_OBSERVATION',
        'SUPPORTED',
        'SOUND_INFERENCE',
        irrelevantAudit
      );
      expect(badge3).toBe('MISLEADING_EVIDENCE_PRESENTATION');
    });

    it('Rule 7 Guardrail: validateAssessmentV2 rejects positive badge when overclaiming violation is active', () => {
      const assessment: any = {
        assessmentId: 'asmt_test_masking',
        schemaVersion: '2.0.0',
        claimText: 'Test claim with masked overclaiming',
        classification: {
          propositionType: 'EMPIRICAL_OBSERVATION',
          evidenceStatus: 'SUPPORTED',
          reasoningValidity: 'SOUND_INFERENCE',
          displayBadge: 'EMPIRICALLY_VERIFIED', // Masking violation!
        },
        claimDecomposition: [],
        evidenceRegistry: {},
        semanticValidation: {
          overclaimingAudit: {
            overclaimingDetected: true,
            violationTypes: ['DUPLICATE_DATASET_DOUBLE_COUNTING'],
            details: ['Double counted identical press release'],
          },
        },
      };

      const result = DeterministicVerifierService.validateAssessmentV2(assessment);
      expect(result.isValid).toBe(false);
      expect(result.errors.some(e => e.includes('[OVERCLAIMING_MASKING_VIOLATION]'))).toBe(true);
    });
  });
});
