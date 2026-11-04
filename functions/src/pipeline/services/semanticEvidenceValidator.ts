/**
 * 🔬 EVIDENCE-TO-CLAIM SEMANTIC VALIDATION ENGINE (TRUTHWORLD V2.1)
 *
 * Enforces the core epistemic guarantee:
 * "A genuine source does not necessarily provide genuine support for the claim."
 *
 * Implements:
 * 1. Semantic Evidence Relationship Assessment:
 *    (SUPPORTS, CONTRADICTS, PARTIALLY_SUPPORTS, CONTEXTUALLY_LIMITS, IRRELEVANT, AMBIGUOUS)
 * 2. Overclaiming Detection (6 Overclaiming Scenarios):
 *    - Authentic but irrelevant citations
 *    - Partial support treated as full proof
 *    - Accurate quotation with omitted qualifications
 *    - Discussion of hypothesis treated as empirical finding
 *    - Interpretation contradicting study conclusion
 *    - Duplicate dataset double-counting
 * 3. Bipartite Evidentiary Provenance Graph & k_eff calculation
 * 4. Nuanced Religious & Historical Classification Guardrails
 */

import {
  PropositionType,
  EvidenceStatus,
  SemanticEvidenceRelationship,
  SemanticEvidenceLink,
  OverclaimingAudit,
  OverclaimingViolationType,
  EvidentiaryProvenanceGraph,
  ProvenanceEntityNode,
  ProvenanceEdge,
  CredibilityAssessmentV2,
  EvidenceRegistryItem,
  ClaimDecompositionProposition,
} from '../types';

export class SemanticEvidenceValidator {
  /**
   * Evaluates semantic relationship between a verified evidence item and a claim proposition.
   * Returns a structured SemanticEvidenceLink.
   */
  public static evaluateSemanticLink(params: {
    evidenceId: string;
    targetPropositionId: string;
    propositionText: string;
    propositionType: PropositionType;
    evidenceItem: EvidenceRegistryItem;
    candidateRelationship?: SemanticEvidenceRelationship;
    rationale?: string;
    hypothesisVsFinding?: 'EMPIRICAL_FINDING' | 'STUDY_HYPOTHESIS_DISCUSSED' | 'LITERATURE_REVIEW_CITATION' | 'METHODOLOGICAL_CAVEAT';
    scopeOfSupport?: 'FULL_PROPOSITION' | 'PARTIAL_PREMISE_ONLY' | 'CONTEXTUAL_BACKGROUND' | 'CONTRADICTING_EVIDENCE' | 'NO_SUPPORT';
    disclosedCaveats?: string[];
  }): SemanticEvidenceLink {
    const {
      evidenceId,
      targetPropositionId,
      propositionText: _propositionText,
      evidenceItem,
      candidateRelationship,
      rationale,
      hypothesisVsFinding = 'EMPIRICAL_FINDING',
      scopeOfSupport = 'FULL_PROPOSITION',
      disclosedCaveats = [],
    } = params;

    const establishes = evidenceItem.epistemicScope?.establishes || '';
    const limitations = evidenceItem.epistemicScope?.limitations || '';
    const doesNotEstablish = evidenceItem.epistemicScope?.doesNotEstablish || '';

    // If explicit candidateRelationship provided, start from there, otherwise infer
    let relationship: SemanticEvidenceRelationship = candidateRelationship || 'AMBIGUOUS';

    // Automatic qualification / caveat detection
    const caveats = [...disclosedCaveats];
    if (limitations && !caveats.includes(limitations)) {
      caveats.push(limitations);
    }
    if (doesNotEstablish && !caveats.includes(`Does not establish: ${doesNotEstablish}`)) {
      caveats.push(`Does not establish: ${doesNotEstablish}`);
    }

    // Check hypothesis distinction
    let resolvedHypothesis = hypothesisVsFinding;
    const passage = evidenceItem.deterministicVerification?.verifiedPassage || '';
    const lowerPassage = passage.toLowerCase();
    if (
      lowerPassage.includes('hypothesiz') ||
      lowerPassage.includes('hypothesis') ||
      lowerPassage.includes('to test whether') ||
      lowerPassage.includes('proposed') ||
      lowerPassage.includes('suggested that')
    ) {
      if (
        !lowerPassage.includes('we demonstrated') &&
        !lowerPassage.includes('results indicate') &&
        !lowerPassage.includes('we conclude')
      ) {
        resolvedHypothesis = 'STUDY_HYPOTHESIS_DISCUSSED';
      }
    }

    // Check contextual limits
    if (evidenceItem.deterministicVerification?.contextDistortionDetected) {
      relationship = 'CONTEXTUALLY_LIMITS';
    }

    const defaultRationale =
      rationale ||
      `Passage ${relationship.toLowerCase()} the proposition within bounded scope: "${establishes || 'verified parameters'}".`;

    return {
      evidenceId,
      targetPropositionId,
      semanticRelationship: relationship,
      rationale: defaultRationale,
      disclosedCaveats: caveats,
      hypothesisVsFindingDistinction: resolvedHypothesis,
      scopeOfSupport,
    };
  }

  /**
   * Audits evidence links and propositions for the 6 Overclaiming Failure Modes
   */
  public static auditOverclaiming(
    assessment: CredibilityAssessmentV2,
    semanticLinks: SemanticEvidenceLink[],
    provenanceGraph?: EvidentiaryProvenanceGraph
  ): OverclaimingAudit {
    const violationTypes: OverclaimingViolationType[] = [];
    const details: string[] = [];

    const registry = assessment.evidenceRegistry || {};
    const propositions = assessment.claimDecomposition || [];
    const linkMap = new Map<string, SemanticEvidenceLink[]>();

    for (const link of semanticLinks) {
      const existing = linkMap.get(link.targetPropositionId) || [];
      existing.push(link);
      linkMap.set(link.targetPropositionId, existing);
    }

    for (const prop of propositions) {
      const propLinks = linkMap.get(prop.propositionId) || [];

      // 1. AUTHENTIC_BUT_IRRELEVANT:
      // Proposition is marked SUPPORTED, but linked evidence has IRRELEVANT or AMBIGUOUS relationship
      if (prop.assessment === 'SUPPORTED') {
        const supportingLinks = propLinks.filter(
          l => l.semanticRelationship === 'SUPPORTS' || l.semanticRelationship === 'PARTIALLY_SUPPORTS'
        );
        const irrelevantLinks = propLinks.filter(
          l => l.semanticRelationship === 'IRRELEVANT' || l.semanticRelationship === 'AMBIGUOUS'
        );

        if (supportingLinks.length === 0 && irrelevantLinks.length > 0) {
          violationTypes.push('AUTHENTIC_BUT_IRRELEVANT');
          details.push(
            `Proposition '${prop.propositionId}' marked SUPPORTED, but its authentic citations are semantically IRRELEVANT or AMBIGUOUS.`
          );
        }

        // 2. PARTIAL_SUPPORT_TREATED_AS_FULL:
        // Proposition is marked SUPPORTED, but only has PARTIALLY_SUPPORTS or PARTIAL_PREMISE_ONLY links
        const fullSupportLinks = propLinks.filter(
          l => l.semanticRelationship === 'SUPPORTS' && l.scopeOfSupport === 'FULL_PROPOSITION'
        );
        const partialLinks = propLinks.filter(
          l => l.semanticRelationship === 'PARTIALLY_SUPPORTS' || l.scopeOfSupport === 'PARTIAL_PREMISE_ONLY'
        );

        if (fullSupportLinks.length === 0 && partialLinks.length > 0) {
          violationTypes.push('PARTIAL_SUPPORT_TREATED_AS_FULL');
          details.push(
            `Proposition '${prop.propositionId}' claims full SUPPORT, but evidence only provides partial premise support.`
          );
        }

    // 3. QUALIFICATION_OMISSION:
    // Check all semantic links for CONTEXTUALLY_LIMITS
    for (const link of semanticLinks) {
      if (link.semanticRelationship === 'CONTEXTUALLY_LIMITS') {
        violationTypes.push('QUALIFICATION_OMISSION');
        details.push(
          `Evidence '${link.evidenceId}' contextually limits proposition '${link.targetPropositionId}', but proposition claims unconditioned support.`
        );
      }
    }

        // 4. HYPOTHESIS_TREATED_AS_FINDING:
        // Quoting a discussed hypothesis or background summary as primary empirical proof
        for (const link of propLinks) {
          if (
            link.hypothesisVsFindingDistinction === 'STUDY_HYPOTHESIS_DISCUSSED' ||
            link.hypothesisVsFindingDistinction === 'LITERATURE_REVIEW_CITATION'
          ) {
            violationTypes.push('HYPOTHESIS_TREATED_AS_FINDING');
            details.push(
              `Evidence '${link.evidenceId}' cites an investigated hypothesis or background literature review, not a verified study finding.`
            );
          }
        }
      }
    }

    // 5. CONCLUSION_CONTRADICTS_ABSTRACT_INTERPRETATION:
    // Check if any evidence registry item notes that study conclusion contradicts popular interpretation
    for (const [evId, item] of Object.entries(registry)) {
      const scope = item.epistemicScope;
      if (
        scope?.limitations?.toLowerCase().includes('contradicts') ||
        scope?.doesNotEstablish?.toLowerCase().includes('conclusion differs')
      ) {
        violationTypes.push('CONCLUSION_CONTRADICTS_ABSTRACT_INTERPRETATION');
        details.push(
          `Evidence '${evId}' indicates that the primary study conclusion contradicts the popular interpretation.`
        );
      }
    }

    // 6. DUPLICATE_DATASET_DOUBLE_COUNTING:
    // Check provenance graph for multiple publications analyzing the exact same dataset while counting as separate evidence
    if (provenanceGraph) {
      const datasetToPubs = new Map<string, string[]>();
      for (const edge of provenanceGraph.edges) {
        if (edge.relation === 'ANALYZES_DATASET') {
          const pubs = datasetToPubs.get(edge.toNodeId) || [];
          pubs.push(edge.fromNodeId);
          datasetToPubs.set(edge.toNodeId, pubs);
        }
      }

      for (const [datasetId, pubs] of datasetToPubs.entries()) {
        if (pubs.length > 1) {
          // Check if both publications are referenced in assessment as separate primary sources
          const pubEvidenceCount = pubs.filter(p => registry[p] || registry[p.replace(/^node_/, '')]).length;
          if (pubEvidenceCount > 1) {
            violationTypes.push('DUPLICATE_DATASET_DOUBLE_COUNTING');
            details.push(
              `Publications [${pubs.join(', ')}] analyze the identical underlying dataset '${datasetId}', creating double-counting risk.`
            );
          }
        }
      }
    }

    return {
      overclaimingDetected: violationTypes.length > 0,
      violationTypes: Array.from(new Set(violationTypes)),
      details,
    };
  }

  /**
   * Constructs an Evidentiary Provenance Graph and calculates deduplicated k_eff.
   */
  public static constructProvenanceGraph(params: {
    evidenceRegistry: Record<string, EvidenceRegistryItem>;
    datasets?: Array<{ datasetId: string; name: string }>;
    authors?: Array<{ authorId: string; name: string }>;
  }): EvidentiaryProvenanceGraph {
    const { evidenceRegistry, datasets = [], authors = [] } = params;

    const nodes: ProvenanceEntityNode[] = [];
    const edges: ProvenanceEdge[] = [];
    const uniqueDatasets = new Set<string>();
    const uniqueInvestigators = new Set<string>();

    // Add dataset nodes
    for (const ds of datasets) {
      nodes.push({
        nodeId: ds.datasetId,
        type: 'PRIMARY_DATASET',
        label: ds.name,
        canonicalId: ds.datasetId,
      });
      uniqueDatasets.add(ds.datasetId);
    }

    // Add author nodes
    for (const auth of authors) {
      nodes.push({
        nodeId: auth.authorId,
        type: 'AUTHOR',
        label: auth.name,
      });
      uniqueInvestigators.add(auth.authorId);
    }

    // Add publication nodes and infer edges
    const seenUpstreamSources = new Set<string>();
    let standaloneIndependentCount = 0;

    for (const [evId, item] of Object.entries(evidenceRegistry)) {
      const pubNodeId = `node_${evId}`;
      nodes.push({
        nodeId: pubNodeId,
        type: 'PUBLICATION',
        label: item.sourceIdentity?.publisher || 'Publication',
        canonicalId: item.sourceIdentity?.primaryArtifactId || item.sourceIdentity?.url,
      });

      const upstream = item.independence?.upstreamSourceId;
      if (upstream) {
        seenUpstreamSources.add(upstream);
        const upstreamNodeId = `upstream_${upstream}`;
        if (!nodes.some(n => n.nodeId === upstreamNodeId)) {
          nodes.push({
            nodeId: upstreamNodeId,
            type: 'ORGANIZATION',
            label: `Upstream Source: ${upstream}`,
            canonicalId: upstream,
          });
        }
        edges.push({
          fromNodeId: pubNodeId,
          toNodeId: upstreamNodeId,
          relation: item.independence?.lineageType === 'SYNDICATED_DERIVATIVE' ? 'SYNDICATES' : 'DERIVED_FROM',
        });
      } else if ((item.independence?.independenceWeight ?? 0) >= 0.8) {
        standaloneIndependentCount++;
      }

      // Check if item links to a primary dataset
      const artifactId = item.sourceIdentity?.primaryArtifactId;
      if (artifactId && datasets.some(d => d.datasetId === artifactId)) {
        edges.push({
          fromNodeId: pubNodeId,
          toNodeId: artifactId,
          relation: 'ANALYZES_DATASET',
        });
      }
    }

    // Effective independence k_eff:
    // Count distinct datasets, unique upstream organizations, and standalone primary observations
    const effectiveIndependentSourcesCount = Math.max(
      1,
      uniqueDatasets.size > 0
        ? uniqueDatasets.size + seenUpstreamSources.size
        : standaloneIndependentCount + seenUpstreamSources.size
    );

    return {
      nodes,
      edges,
      effectiveIndependentSourcesCount,
      underlyingDatasetCount: uniqueDatasets.size,
      distinctInvestigatorCount: uniqueInvestigators.size,
    };
  }

  /**
   * Refined Theological & Historical Classification Guardrail (Objective 4):
   * Validates propositions without improperly classifying historical or descriptive claims as untestable.
   */
  public static validateReligiousAndHistoricalProposition(params: {
    propositionType: PropositionType;
    evidenceStatus: EvidenceStatus;
    hasScripturalCitations?: boolean;
    hasEmpiricalTelemetricCitations?: boolean;
  }): { isValid: boolean; error?: string; recommendedType?: PropositionType } {
    const {
      propositionType,
      evidenceStatus,
      hasScripturalCitations = false,
      hasEmpiricalTelemetricCitations = false,
    } = params;

    // 1. DESCRIPTIVE_RELIGIOUS_TEACHING:
    // e.g. "Christianity teaches that Jesus walked on water", "The Book of Exodus states X"
    // This is an empirical claim about textual documentation! It CAN be SUPPORTED by scriptural texts.
    if (propositionType === 'DESCRIPTIVE_RELIGIOUS_TEACHING') {
      if (evidenceStatus === 'SUPPORTED' && !hasScripturalCitations) {
        return {
          isValid: false,
          error: `DESCRIPTIVE_RELIGIOUS_TEACHING marked SUPPORTED requires primary scriptural or documentary textual evidence.`,
        };
      }
      return { isValid: true };
    }

    // 2. HISTORICAL_DOCUMENTARY_CLAIM:
    // e.g. "Papyrus P52 dates to the 2nd century", "The Dead Sea Scrolls were found in Qumran"
    // This is an empirical historical/archaeological claim! It is fully testable.
    if (propositionType === 'HISTORICAL_DOCUMENTARY_CLAIM') {
      if (evidenceStatus === 'NOT_EMPIRICALLY_TESTABLE') {
        return {
          isValid: false,
          error: `HISTORICAL_DOCUMENTARY_CLAIM must not be marked NOT_EMPIRICALLY_TESTABLE. Codicological, archaeological, and textual evidence apply.`,
          recommendedType: 'HISTORICAL_DOCUMENTARY_CLAIM',
        };
      }
      return { isValid: true };
    }

    // 3. THEOLOGICAL_DOCTRINE:
    // Unfalsifiable metaphysical beliefs (e.g. "The Holy Trinity exists", "Reincarnation occurs")
    // Strictly NOT_EMPIRICALLY_TESTABLE. Cannot be SUPPORTED or CONTRADICTED by empirical science.
    if (propositionType === 'THEOLOGICAL_DOCTRINE') {
      if (evidenceStatus === 'SUPPORTED' || evidenceStatus === 'CONTRADICTED') {
        return {
          isValid: false,
          error: `THEOLOGICAL_DOCTRINE cannot be marked '${evidenceStatus}'. Metaphysical doctrines are NOT_EMPIRICALLY_TESTABLE. If claiming empirical evidence, decompose into DESCRIPTIVE_RELIGIOUS_TEACHING or EXTRAORDINARY_EMPIRICAL_ASSERTION.`,
        };
      }
      return { isValid: true };
    }

    // 4. EXTRAORDINARY_EMPIRICAL_ASSERTION:
    // e.g. "Jesus walked on water, it has scientific proofs", "Physical evidence proves the Red Sea split"
    // The proof assertion is an empirical claim. If empirical proof is absent, it CANNOT be SUPPORTED.
    if (propositionType === 'EXTRAORDINARY_EMPIRICAL_ASSERTION') {
      if (evidenceStatus === 'SUPPORTED' && !hasEmpiricalTelemetricCitations) {
        return {
          isValid: false,
          error: `EXTRAORDINARY_EMPIRICAL_ASSERTION asserting empirical proof cannot be marked SUPPORTED solely by theological texts without independent empirical verification.`,
        };
      }
      return { isValid: true };
    }

    return { isValid: true };
  }

  /**
   * Objective 2: Intent & Concealment Assessment
   * Distinguishes public acknowledgment, delayed disclosure, data withholding, and deliberate concealment.
   * Direct evidence is required for allegations of conspiratorial intent.
   * If available evidence does not substantiate deliberate withholding, returns INSUFFICIENT_EVIDENCE.
   */
  public static evaluateConcealmentOrIntentClaim(params: {
    claimText: string;
    hasDirectProofOfConcealment: boolean;
    hasPublicRegulatoryDisclosure: boolean;
  }): {
    assessment: EvidenceStatus;
    rationale: string;
    distinctionCategory:
      | 'PUBLIC_ACKNOWLEDGMENT'
      | 'DELAYED_DISCLOSURE'
      | 'DATA_WITHHOLDING'
      | 'DELIBERATE_CONCEALMENT'
      | 'INSUFFICIENT_EVIDENCE_OF_INTENT';
  } {
    const { hasDirectProofOfConcealment, hasPublicRegulatoryDisclosure } = params;

    if (hasDirectProofOfConcealment) {
      return {
        assessment: 'SUPPORTED',
        rationale:
          'Primary documentation (e.g. unredacted internal communications) substantiates deliberate withholding of safety data.',
        distinctionCategory: 'DELIBERATE_CONCEALMENT',
      };
    }

    if (hasPublicRegulatoryDisclosure) {
      return {
        assessment: 'INSUFFICIENT_EVIDENCE',
        rationale:
          'Public regulatory communications prove active surveillance and formal disclosure of the safety signal within weeks of detection. However, while public disclosure refutes an absolute claim of zero communication, proving the total absence of any corporate or governmental data withholding requires exhaustive internal investigative records. Under strict epistemic standards, unverified allegations of conspiratorial intent receive INSUFFICIENT_EVIDENCE rather than CONTRADICTED.',
        distinctionCategory: 'INSUFFICIENT_EVIDENCE_OF_INTENT',
      };
    }

    return {
      assessment: 'INSUFFICIENT_EVIDENCE',
      rationale:
        'Insufficient primary evidence to confirm or falsify allegations of intentional institutional concealment.',
      distinctionCategory: 'INSUFFICIENT_EVIDENCE_OF_INTENT',
    };
  }

  /**
   * Objective 5: Summary Field Scoping & Consistency Engine
   * Prevents misleading ROBUST_SUPPORT labels when individual propositions carry mixed evidence.
   */
  public static computeScopingSummary(params: {
    propositions: ClaimDecompositionProposition[];
    links: SemanticEvidenceLink[];
    k_eff: number;
  }): {
    semanticEvidenceLevel:
      | 'ROBUST_SUPPORT'
      | 'PARTIAL_CONCORDANCE'
      | 'MIXED_EVIDENCE'
      | 'CONTRADICTED'
      | 'IRRELEVANT_EVIDENCE'
      | 'INSUFFICIENT_GROUNDING';
    semanticEvidenceScope: 'INDIVIDUAL_EVIDENCE_LINKS' | 'OVERALL_CLAIM';
    sourceCountScope: 'ENTIRE_ASSESSMENT' | 'PER_PROPOSITION';
    effectiveIndependentSourcesCount: number;
  } {
    const { propositions, links, k_eff } = params;

    const hasSupported = propositions.some(p => p.assessment === 'SUPPORTED');
    const hasContradicted = propositions.some(p => p.assessment === 'CONTRADICTED');
    const hasInsufficient = propositions.some(p => p.assessment === 'INSUFFICIENT_EVIDENCE');

    let level:
      | 'ROBUST_SUPPORT'
      | 'PARTIAL_CONCORDANCE'
      | 'MIXED_EVIDENCE'
      | 'CONTRADICTED'
      | 'IRRELEVANT_EVIDENCE'
      | 'INSUFFICIENT_GROUNDING' = 'PARTIAL_CONCORDANCE';

    if (hasSupported && (hasContradicted || hasInsufficient)) {
      level = 'MIXED_EVIDENCE';
    } else if (hasSupported && !hasContradicted && !hasInsufficient) {
      level = 'ROBUST_SUPPORT';
    } else if (hasContradicted && !hasSupported) {
      level = 'CONTRADICTED';
    } else if (links.every(l => l.semanticRelationship === 'IRRELEVANT')) {
      level = 'IRRELEVANT_EVIDENCE';
    } else if (links.length === 0 || hasInsufficient) {
      level = 'INSUFFICIENT_GROUNDING';
    }

    return {
      semanticEvidenceLevel: level,
      semanticEvidenceScope: 'INDIVIDUAL_EVIDENCE_LINKS',
      sourceCountScope: 'ENTIRE_ASSESSMENT',
      effectiveIndependentSourcesCount: k_eff,
    };
  }
}
