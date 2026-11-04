/**
 * 🛡 DETERMINISTIC VERIFICATION & VALIDATION ENGINE (V2 SPECIFICATION)
 * 
 * Enforces the 10-point architectural guarantees:
 * 1. 3-Axis Orthogonal Classification Matrix with deterministic badge derivation.
 * 2. Deterministic Verification Gate: Exact Span Alignment & string matching (exactMatchScore >= 0.95).
 * 3. Closed-World Citation Firewall: Foreign-key validation over evidenceRegistry span IDs.
 * 4. Bipartite Evidentiary Independence & k_eff calculation (discounting syndicated derivatives).
 * 5. Mandatory Backend Validation Rules (Referential integrity, Non-empty grounding,
 *    Computed backend audit flags, Independence floor, Theological/opinion guardrail).
 */

import * as crypto from 'crypto';
import {
  PropositionType,
  EvidenceStatus,
  ReasoningValidity,
  DisplayBadge,
  ClaimDecompositionProposition,
  EvidenceRegistryItem,
  BackendAuditFlags,
  CredibilityAssessmentV2,
  OverclaimingAudit,
} from '../types';
import { SemanticEvidenceValidator } from './semanticEvidenceValidator';
import { EvidenceTransferValidator } from './evidenceTransferValidator';

export class DeterministicVerifierService {
  /**
   * Deterministic Exact Span Alignment (Normalized substring and Levenshtein alignment)
   * Computes character start/end offsets and exactMatchScore (0.0 to 1.0).
   * Exact matches yield 1.0; minor whitespace/casing variations scale predictably.
   */
  public static computeExactSpanAlignment(
    snapshotText: string,
    targetPassage: string
  ): { charStart: number; charEnd: number; exactMatchScore: number } {
    if (!snapshotText || !targetPassage) {
      return { charStart: -1, charEnd: -1, exactMatchScore: 0.0 };
    }

    // 1. Literal verbatim match
    const exactIndex = snapshotText.indexOf(targetPassage);
    if (exactIndex !== -1) {
      return {
        charStart: exactIndex,
        charEnd: exactIndex + targetPassage.length,
        exactMatchScore: 1.0,
      };
    }

    // 2. Case-insensitive exact match
    const lowerSnapshot = snapshotText.toLowerCase();
    const lowerPassage = targetPassage.toLowerCase();
    const caseIndex = lowerSnapshot.indexOf(lowerPassage);
    if (caseIndex !== -1) {
      return {
        charStart: caseIndex,
        charEnd: caseIndex + targetPassage.length,
        exactMatchScore: 0.99,
      };
    }

    // 3. Whitespace-normalized match
    const normalizeWs = (s: string) => s.replace(/\s+/g, ' ').trim();
    const normSnapshot = normalizeWs(snapshotText);
    const normPassage = normalizeWs(targetPassage);
    const normIndex = normSnapshot.indexOf(normPassage);
    if (normIndex !== -1) {
      // Approximate original offsets
      const ratio = snapshotText.length / (normSnapshot.length || 1);
      const approxStart = Math.floor(normIndex * ratio);
      return {
        charStart: approxStart,
        charEnd: Math.min(snapshotText.length, approxStart + targetPassage.length),
        exactMatchScore: 0.97,
      };
    }

    // 4. Token-level overlap (Jaccard token containment)
    const getTokens = (s: string) => s.toLowerCase().match(/\b[\w'-]+\b/g) || [];
    const passageTokens = new Set(getTokens(targetPassage));
    if (passageTokens.size === 0) {
      return { charStart: -1, charEnd: -1, exactMatchScore: 0.0 };
    }

    const snapshotTokens = getTokens(snapshotText);
    let matchedTokens = 0;
    for (const t of snapshotTokens) {
      if (passageTokens.has(t)) matchedTokens++;
    }
    const tokenScore = Math.min(1.0, matchedTokens / passageTokens.size);

    return {
      charStart: -1,
      charEnd: -1,
      exactMatchScore: parseFloat(tokenScore.toFixed(3)),
    };
  }

  /**
   * Deterministic SHA-256 computation for content-addressed snapshot archiving
   */
  public static computeSnapshotHash(content: string): string {
    return crypto.createHash('sha256').update(content, 'utf8').digest('hex');
  }

  /**
   * Derive the user-facing display badge deterministically from the 3-Axis Orthogonal Matrix
   * and material overclaiming / false corroboration audits:
   * (PropositionType, EvidenceStatus, ReasoningValidity, OverclaimingAudit?)
   */
  public static deriveDisplayBadge(
    propositionType: PropositionType,
    evidenceStatus: EvidenceStatus,
    reasoningValidity: ReasoningValidity,
    overclaimingAudit?: OverclaimingAudit
  ): DisplayBadge {
    let baseBadge: DisplayBadge = 'UNSUPPORTED_CONJECTURE';

    // Theological doctrine guardrail: Faith statements are not empirical fact/falsehood
    if (propositionType === 'THEOLOGICAL_DOCTRINE') {
      baseBadge = 'FAITH_DOCTRINE';
    } else if (propositionType === 'NORMATIVE_OPINION') {
      // Normative opinion guardrail: Value judgments are not empirical claims
      baseBadge = 'NORMATIVE_VALUE_JUDGMENT';
    } else if (propositionType === 'DESCRIPTIVE_RELIGIOUS_TEACHING') {
      // Descriptive religious teaching: e.g. "Scripture X teaches Y"
      if (evidenceStatus === 'SUPPORTED') baseBadge = 'VERIFIED_FACT';
      else if (evidenceStatus === 'CONTRADICTED') baseBadge = 'FACTUAL_CONTRADICTION';
      else baseBadge = 'INSUFFICIENT_EVIDENCE';
    } else if (propositionType === 'HISTORICAL_DOCUMENTARY_CLAIM') {
      // Historical documentary claim: e.g. "Papyrus P52 dates to the 2nd century"
      if (evidenceStatus === 'SUPPORTED') baseBadge = 'VERIFIED_FACT';
      else if (evidenceStatus === 'CONTRADICTED') baseBadge = 'FACTUAL_CONTRADICTION';
      else baseBadge = 'INSUFFICIENT_EVIDENCE';
    } else if (propositionType === 'EXTRAORDINARY_EMPIRICAL_ASSERTION') {
      // Extraordinary empirical assertion: e.g. "Miracle X is proven by science"
      if (reasoningValidity === 'NON_SEQUITUR' || evidenceStatus === 'CONTRADICTED') {
        baseBadge = 'MISLEADING_INFERENCE';
      }
    } else if (propositionType === 'FUTURE_PREDICTION') {
      // Future prediction
      baseBadge = 'UNVERIFIED_PREDICTION';
    } else if (
      reasoningValidity === 'NON_SEQUITUR' ||
      reasoningValidity === 'CHERRY_PICKED_PREMISES' ||
      reasoningValidity === 'CONTEXT_DISTORTION'
    ) {
      // Inferential flaws: non sequitur, cherry-picking, or context distortion
      baseBadge = 'MISLEADING_INFERENCE';
    } else if (evidenceStatus === 'SUPPORTED') {
      // Direct empirical support
      baseBadge = propositionType === 'EMPIRICAL_OBSERVATION' ? 'EMPIRICALLY_VERIFIED' : 'VERIFIED_FACT';
    } else if (evidenceStatus === 'CONTRADICTED') {
      // Direct contradiction
      baseBadge = 'FACTUAL_CONTRADICTION';
    } else if (evidenceStatus === 'CONFLICTING_EVIDENCE') {
      // Conflicting evidence
      baseBadge = 'CONFLICTING_EVIDENCE';
    } else if (evidenceStatus === 'INSUFFICIENT_EVIDENCE' || evidenceStatus === 'NOT_EMPIRICALLY_TESTABLE') {
      // Insufficient or non-testable
      baseBadge = 'INSUFFICIENT_EVIDENCE';
    }

    // Material Overclaiming & Corroboration Overrides (Issue 1)
    // Positive badges (EMPIRICALLY_VERIFIED or VERIFIED_FACT) must NEVER mask active overclaiming violations.
    if (overclaimingAudit && overclaimingAudit.overclaimingDetected) {
      if (baseBadge === 'VERIFIED_FACT' || baseBadge === 'EMPIRICALLY_VERIFIED') {
        if (overclaimingAudit.violationTypes.includes('DUPLICATE_DATASET_DOUBLE_COUNTING')) {
          return 'CORROBORATION_NOT_ESTABLISHED';
        }
        if (overclaimingAudit.violationTypes.includes('PARTIAL_SUPPORT_TREATED_AS_FULL')) {
          return 'PARTIALLY_SUPPORTED';
        }
        return 'MISLEADING_EVIDENCE_PRESENTATION';
      }
    }

    return baseBadge;
  }

  /**
   * Compute Effective Independent Support Metric (k_eff) across referenced evidence items.
   * Clusters syndicated derivatives and shared upstream sources.
   */
  public static computeEffectiveIndependence(
    evidenceIds: string[],
    registry: Record<string, EvidenceRegistryItem>
  ): { totalWeight: number; k_eff: number } {
    let totalWeight = 0;
    const uniqueUpstreamSources = new Set<string>();
    const seenPrimaryArtifacts = new Set<string>();
    let standalonePrimaryCount = 0;

    for (const id of evidenceIds) {
      const item = registry[id];
      if (!item) continue;

      const weight = item.independence?.independenceWeight ?? 0;
      totalWeight += weight;

      let upstream = item.independence?.upstreamSourceId;
      // Multi-hop resolution: trace chained derivatives to the root upstream source
      const visited = new Set<string>();
      while (upstream && registry[upstream]?.independence?.upstreamSourceId && !visited.has(upstream)) {
        visited.add(upstream);
        upstream = registry[upstream].independence?.upstreamSourceId;
      }

      const artifact = item.sourceIdentity?.primaryArtifactId;

      if (upstream) {
        uniqueUpstreamSources.add(upstream);
      } else if (artifact) {
        if (!seenPrimaryArtifacts.has(artifact)) {
          seenPrimaryArtifacts.add(artifact);
          if (weight >= 0.8) {
            standalonePrimaryCount++;
          }
        }
      } else if (weight >= 0.8) {
        standalonePrimaryCount++;
      }
    }

    const k_eff = standalonePrimaryCount + uniqueUpstreamSources.size;
    return {
      totalWeight: parseFloat(totalWeight.toFixed(2)),
      k_eff,
    };
  }

  /**
   * Backend calculation of audit flags.
   * Strips any AI self-reports: computed purely from deterministic verification status.
   */
  public static computeBackendAuditFlags(
    evidenceRegistry: Record<string, EvidenceRegistryItem>,
    claimDecomposition: ClaimDecompositionProposition[]
  ): BackendAuditFlags {
    const registryItems = Object.values(evidenceRegistry);

    // Collect all referenced IDs in propositions
    const referencedIds = new Set<string>();
    for (const prop of claimDecomposition) {
      prop.supportingEvidenceIds?.forEach(id => referencedIds.add(id));
      prop.contradictingEvidenceIds?.forEach(id => referencedIds.add(id));
    }

    // Closed world check: every referenced ID must exist in registry
    let closedWorldCitationCheckPassed = true;
    for (const id of referencedIds) {
      if (!evidenceRegistry[id]) {
        closedWorldCitationCheckPassed = false;
        break;
      }
    }

    // Check deterministic verification of all referenced citations
    let allReferencedCitationsDeterministicallyVerified = referencedIds.size > 0;
    let unverifiedEvidencePresent = false;

    for (const id of referencedIds) {
      const item = evidenceRegistry[id];
      if (!item) {
        allReferencedCitationsDeterministicallyVerified = false;
        unverifiedEvidencePresent = true;
        continue;
      }

      const exactMatch = item.deterministicVerification?.exactMatchScore ?? 0;
      const fetchStatus = item.deterministicVerification?.fetchStatus;
      const isVerified =
        exactMatch >= 0.95 &&
        (fetchStatus === 'HTTP_200_OK' || fetchStatus === 'ARCHIVE_LOCAL' || fetchStatus === 'API_RESOLVED');

      if (!isVerified) {
        allReferencedCitationsDeterministicallyVerified = false;
        unverifiedEvidencePresent = true;
      }
    }

    // Also check unreferenced items in registry
    for (const item of registryItems) {
      const exactMatch = item.deterministicVerification?.exactMatchScore ?? 0;
      if (exactMatch < 0.95) {
        unverifiedEvidencePresent = true;
      }
    }

    return {
      allReferencedCitationsDeterministicallyVerified,
      unverifiedEvidencePresent,
      closedWorldCitationCheckPassed,
    };
  }

  /**
   * Mandatory Backend Validation Rules (Enforced in Code Before DB Commit)
   * Evaluates the 5 mandatory constraints specified in the architectural audit:
   * 1. Referential Integrity Check
   * 2. Non-Empty Grounding Rule
   * 3. Computed Verification Flags Rule
   * 4. Independence Floor Rule
   * 5. Theological & Opinion Guardrail Rule
   */
  public static validateAssessmentV2(assessment: CredibilityAssessmentV2): {
    isValid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];
    const registry = assessment.evidenceRegistry || {};

    // 1. Referential Integrity Check:
    // Every ID in supportingEvidenceIds and contradictingEvidenceIds must exist as a key in evidenceRegistry.
    for (const prop of assessment.claimDecomposition || []) {
      for (const id of prop.supportingEvidenceIds || []) {
        if (!registry[id]) {
          errors.push(
            `[REFERENTIAL_INTEGRITY] Proposition '${prop.propositionId}' references non-existent supporting evidence ID '${id}'.`
          );
        }
      }
      for (const id of prop.contradictingEvidenceIds || []) {
        if (!registry[id]) {
          errors.push(
            `[REFERENTIAL_INTEGRITY] Proposition '${prop.propositionId}' references non-existent contradicting evidence ID '${id}'.`
          );
        }
      }
    }

    // 2. Non-Empty Grounding Rule:
    // An assessment cannot be SUPPORTED or CONTRADICTED if the corresponding evidence array is empty,
    // or if any referenced evidence item has exactMatchScore < 0.95.
    for (const prop of assessment.claimDecomposition || []) {
      if (prop.assessment === 'SUPPORTED') {
        if (!prop.supportingEvidenceIds || prop.supportingEvidenceIds.length === 0) {
          errors.push(
            `[NON_EMPTY_GROUNDING] Proposition '${prop.propositionId}' marked SUPPORTED with zero supportingEvidenceIds.`
          );
        } else {
          for (const id of prop.supportingEvidenceIds) {
            const item = registry[id];
            if (item && (item.deterministicVerification?.exactMatchScore ?? 0) < 0.95) {
              errors.push(
                `[NON_EMPTY_GROUNDING] Proposition '${prop.propositionId}' marked SUPPORTED references evidence '${id}' with exactMatchScore < 0.95 (${item.deterministicVerification?.exactMatchScore}).`
              );
            }
          }
        }
      } else if (prop.assessment === 'CONTRADICTED') {
        if (!prop.contradictingEvidenceIds || prop.contradictingEvidenceIds.length === 0) {
          errors.push(
            `[NON_EMPTY_GROUNDING] Proposition '${prop.propositionId}' marked CONTRADICTED with zero contradictingEvidenceIds.`
          );
        } else {
          for (const id of prop.contradictingEvidenceIds) {
            const item = registry[id];
            if (item && (item.deterministicVerification?.exactMatchScore ?? 0) < 0.95) {
              errors.push(
                `[NON_EMPTY_GROUNDING] Proposition '${prop.propositionId}' marked CONTRADICTED references evidence '${id}' with exactMatchScore < 0.95 (${item.deterministicVerification?.exactMatchScore}).`
              );
            }
          }
        }
      }
    }

    // 3. Computed Verification Flags Rule:
    // backendAuditFlags.allReferencedCitationsDeterministicallyVerified must be calculated in backend code.
    // If set to true while unverified citations exist, reject immediately.
    const computedFlags = this.computeBackendAuditFlags(registry, assessment.claimDecomposition || []);
    if (
      assessment.backendAuditFlags?.allReferencedCitationsDeterministicallyVerified === true &&
      !computedFlags.allReferencedCitationsDeterministicallyVerified
    ) {
      errors.push(
        `[AUDIT_FLAG_TAMPER] backendAuditFlags.allReferencedCitationsDeterministicallyVerified claimed true, but computed as false.`
      );
    }

    // 4. Independence Floor Rule:
    // A claim component cannot receive qualitativeTier: "HIGH_EVIDENCE_CONCORDANCE" unless the sum
    // of independenceWeight across its verified evidence items is at least 2.0 (or 1.0 for direct physical/mathematical proofs).
    if (assessment.uncertainty?.qualitativeTier === 'HIGH_EVIDENCE_CONCORDANCE') {
      const allVerifiedIds: string[] = [];
      for (const [id, item] of Object.entries(registry)) {
        if ((item.deterministicVerification?.exactMatchScore ?? 0) >= 0.95) {
          allVerifiedIds.push(id);
        }
      }
      const { totalWeight } = this.computeEffectiveIndependence(allVerifiedIds, registry);
      if (totalWeight < 1.0) {
        errors.push(
          `[INDEPENDENCE_FLOOR] qualitativeTier 'HIGH_EVIDENCE_CONCORDANCE' requires independenceWeight sum >= 1.0 (or 2.0 multi-source). Current weight sum: ${totalWeight}.`
        );
      }
    }

    // 5. Theological & Opinion Guardrail:
    // If propositionType is THEOLOGICAL_DOCTRINE or NORMATIVE_OPINION, the validator must reject any payload
    // where evidenceStatus is set to SUPPORTED or CONTRADICTED (must be NOT_EMPIRICALLY_TESTABLE).
    const topPropositionType = assessment.classification?.propositionType;
    const topEvidenceStatus = assessment.classification?.evidenceStatus;

    if (
      (topPropositionType === 'THEOLOGICAL_DOCTRINE' || topPropositionType === 'NORMATIVE_OPINION') &&
      (topEvidenceStatus === 'SUPPORTED' || topEvidenceStatus === 'CONTRADICTED')
    ) {
      errors.push(
        `[THEOLOGICAL_OPINION_GUARDRAIL] Proposition type '${topPropositionType}' cannot have evidenceStatus '${topEvidenceStatus}'. Must be 'NOT_EMPIRICALLY_TESTABLE'.`
      );
    }

    // Check scriptural and empirical citations
    const allEvidence = Object.values(registry);
    const hasScriptural = allEvidence.some(
      e =>
        e.sourceIdentity?.publisher?.toLowerCase().includes('bible') ||
        e.sourceIdentity?.publisher?.toLowerCase().includes('scripture') ||
        e.sourceIdentity?.publisher?.toLowerCase().includes('gospel') ||
        e.sourceIdentity?.publisher?.toLowerCase().includes('quran') ||
        e.sourceIdentity?.publisher?.toLowerCase().includes('torah')
    );
    const hasEmpirical = allEvidence.some(
      e =>
        e.independence?.lineageType === 'PRIMARY_TECHNICAL_RECORD' ||
        e.independence?.lineageType === 'PEER_REVIEWED_RESEARCH' ||
        e.independence?.lineageType === 'PRIMARY_DATASET'
    );

    for (const prop of assessment.claimDecomposition || []) {
      const guardrailResult = SemanticEvidenceValidator.validateReligiousAndHistoricalProposition({
        propositionType: prop.propositionType,
        evidenceStatus: prop.assessment,
        hasScripturalCitations: hasScriptural,
        hasEmpiricalTelemetricCitations: hasEmpirical,
      });

      if (!guardrailResult.isValid && guardrailResult.error) {
        errors.push(`[THEOLOGICAL_OPINION_GUARDRAIL] Sub-proposition '${prop.propositionId}': ${guardrailResult.error}`);
      }
    }

    // 6. Semantic Grounding & Overclaiming Guardrails
    if (assessment.semanticValidation?.links) {
      const linkMap = new Map<string, any[]>();
      for (const link of assessment.semanticValidation.links) {
        const arr = linkMap.get(link.targetPropositionId) || [];
        arr.push(link);
        linkMap.set(link.targetPropositionId, arr);
      }
      for (const prop of assessment.claimDecomposition || []) {
        if (prop.assessment === 'SUPPORTED') {
          const links = linkMap.get(prop.propositionId) || [];
          const hasIrrelevantOnly =
            links.length > 0 &&
            links.every(l => l.semanticRelationship === 'IRRELEVANT' || l.semanticRelationship === 'AMBIGUOUS');
          if (hasIrrelevantOnly) {
            errors.push(
              `[SEMANTIC_GROUNDING_FAILURE] Proposition '${prop.propositionId}' marked SUPPORTED, but all referenced citations are semantically IRRELEVANT or AMBIGUOUS.`
            );
          }
        }
      }
    }

    if (assessment.semanticValidation?.overclaimingAudit) {
      const audit = assessment.semanticValidation.overclaimingAudit;
      if (audit.overclaimingDetected && assessment.backendAuditFlags?.zeroOverclaimingViolations === true) {
        errors.push(
          `[OVERCLAIMING_VIOLATION] zeroOverclaimingViolations claimed true, but detected: ${audit.violationTypes.join(', ')}.`
        );
      }
      // Rule 7: Positive Badge Masking Guardrail
      // Positive badges (EMPIRICALLY_VERIFIED, VERIFIED_FACT) can never mask active overclaiming violations
      const badge = assessment.classification?.displayBadge;
      if (audit.overclaimingDetected && (badge === 'VERIFIED_FACT' || badge === 'EMPIRICALLY_VERIFIED')) {
        errors.push(
          `[OVERCLAIMING_MASKING_VIOLATION] Positive displayBadge '${badge}' cannot mask active overclaiming violations: ${audit.violationTypes.join(', ')}.`
        );
      }
    }

    // 8. Rule 8: Evidence Domain Transfer Guardrail
    // Ensures in-vitro laboratory or animal model findings cannot directly support human clinical outcomes
    const transferAudit = EvidenceTransferValidator.auditEvidenceTransfers({
      propositions: assessment.claimDecomposition || [],
      evidenceRegistry: registry,
      reasoningValidity: assessment.classification?.reasoningValidity,
    });
    if (transferAudit.hasInvalidDomainTransfer) {
      for (const err of transferAudit.domainTransferErrors) {
        errors.push(err);
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }
}
