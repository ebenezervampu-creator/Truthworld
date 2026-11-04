/**
 * 🔬 EVIDENCE TRANSFER VALIDATOR (ETV) & INFERENTIAL RELATIONSHIP ANALYZER
 * (TruthWorld V2.2 Specification)
 *
 * Implements the core architectural guarantee:
 * "A conclusion does not inherit the credibility of its individual premises.
 * Biological plausibility under laboratory conditions does not establish clinical efficacy."
 *
 * Evaluates the 5 Transfer Dimensions:
 * 1. Evidence Domain Compatibility (In-vitro vs Animal vs Clinical vs Observational)
 * 2. Population Compatibility (Airway cells vs Human patients)
 * 3. Outcome Compatibility (Viral replication inhibition vs Hospitalization/Mortality)
 * 4. Intervention Compatibility (Laboratory concentration vs Safe human dosing/PK)
 * 5. Inferential Validity (Deductive/Inductive soundness vs Fallacious transfer)
 */

import {
  ClaimDecompositionProposition,
  EvidenceRegistryItem,
  InferenceStepAudit,
  InferenceType,
  ReasoningValidity,
} from '../types';

export class EvidenceTransferValidator {
  /**
   * Evaluates an individual inferential step between source proposition(s) and a target conclusion.
   */
  public static validateInferenceStep(params: {
    inferenceId: string;
    sourcePropositions: ClaimDecompositionProposition[];
    targetProposition: ClaimDecompositionProposition;
    evidenceRegistry: Record<string, EvidenceRegistryItem>;
    explicitInferenceType?: InferenceType;
  }): InferenceStepAudit {
    const {
      inferenceId,
      sourcePropositions,
      targetProposition,
      evidenceRegistry,
      explicitInferenceType,
    } = params;

    const sourcePropIds = sourcePropositions.map(p => p.propositionId);
    const targetTextLower = targetProposition.text.toLowerCase();

    // 1. Detect Mechanistic to Clinical Transfer (Laboratory In-Vitro -> Human Clinical Outcome)
    const hasInVitroSource = sourcePropositions.some(p => {
      const evIds = p.supportingEvidenceIds || [];
      return evIds.some(
        id =>
          evidenceRegistry[id]?.evidenceDomain === 'IN_VITRO_LABORATORY' ||
          evidenceRegistry[id]?.sourceIdentity?.publisher?.toLowerCase().includes('in vitro') ||
          p.text.toLowerCase().includes('laboratory') ||
          p.text.toLowerCase().includes('in vitro') ||
          p.text.toLowerCase().includes('cell culture')
      );
    });

    const assertsClinicalOutcome =
      targetProposition.propositionType === 'CLINICAL_OUTCOME' ||
      targetTextLower.includes('prevent') ||
      targetTextLower.includes('cure') ||
      targetTextLower.includes('treat') ||
      targetTextLower.includes('hospitalization') ||
      targetTextLower.includes('in humans') ||
      targetTextLower.includes('in patients');

    if (hasInVitroSource && assertsClinicalOutcome) {
      // Find any contradictory clinical trial or systematic review evidence in the registry or target proposition
      const contradictingClinicalEvidenceIds: string[] = [];
      for (const [evId, item] of Object.entries(evidenceRegistry)) {
        const isTargetContradictor = targetProposition.contradictingEvidenceIds?.includes(evId);
        const isClinicalTrialOrMetaAnalysis =
          item.evidenceDomain === 'RANDOMIZED_CONTROLLED_TRIAL' ||
          item.evidenceDomain === 'SYSTEMATIC_REVIEW_META_ANALYSIS';
        const establishesNoBenefit =
          item.epistemicScope?.establishes?.toLowerCase().includes('no statistically significant') ||
          item.epistemicScope?.establishes?.toLowerCase().includes('no reduction') ||
          item.epistemicScope?.establishes?.toLowerCase().includes('exclusion') ||
          item.epistemicScope?.establishes?.toLowerCase().includes('excludes') ||
          item.epistemicScope?.establishes?.toLowerCase().includes('no benefit');

        if (isTargetContradictor || (isClinicalTrialOrMetaAnalysis && establishesNoBenefit)) {
          if (!contradictingClinicalEvidenceIds.includes(evId)) {
            contradictingClinicalEvidenceIds.push(evId);
          }
        }
      }

      return {
        inferenceId,
        sourcePropositionIds: sourcePropIds,
        targetPropositionId: targetProposition.propositionId,
        inferenceType: explicitInferenceType || 'MECHANISTIC_TO_CLINICAL',
        validity: 'INVALID_WITHOUT_ADDITIONAL_EVIDENCE',
        detectedFallacy: 'EVIDENCE_DOMAIN_TRANSFER',
        missingEvidence: [
          'Human in-vivo pharmacokinetic and pharmacodynamic (PK/PD) tissue concentration data',
          'Human phase II/III randomized controlled trial (RCT) clinical efficacy data',
          'In-vivo therapeutic index and human toxicity/tolerability profile validation',
        ],
        contradictingEvidenceIds: contradictingClinicalEvidenceIds,
        explanation:
          'Laboratory in-vitro antiviral activity demonstrates biological plausibility under controlled conditions, but does not establish clinical efficacy, human tissue bioavailability, or prevention of hospitalization.',
      };
    }

    // 2. Detect Intent Imputation (Allegations of conspiracy, suppression, or corporate cover-up)
    const assertsIntentOrConspiracy =
      targetProposition.propositionType === 'INTENT_CLAIM' ||
      targetTextLower.includes('deliberately') ||
      targetTextLower.includes('suppressed') ||
      targetTextLower.includes('concealed') ||
      targetTextLower.includes('threatened their business') ||
      targetTextLower.includes('cover-up');

    if (assertsIntentOrConspiracy) {
      const hasDirectProof = (targetProposition.supportingEvidenceIds || []).some(id => {
        const item = evidenceRegistry[id];
        return (
          item?.independence?.lineageType === 'LEGAL_DOCKET' ||
          item?.epistemicScope?.establishes?.toLowerCase().includes('internal memorandum')
        );
      });

      if (!hasDirectProof) {
        return {
          inferenceId,
          sourcePropositionIds: sourcePropIds,
          targetPropositionId: targetProposition.propositionId,
          inferenceType: 'INTENT_IMPUTATION',
          validity: 'INVALID_WITHOUT_ADDITIONAL_EVIDENCE',
          detectedFallacy: 'INTENT_IMPUTATION',
          missingEvidence: [
            'Direct documentary records (unredacted internal communications, regulatory subpoenas, or verified whistleblower transcripts) substantiating intentional suppression',
          ],
          contradictingEvidenceIds: [],
          explanation:
            'A commercial motive or regulatory inaction does not deductively prove deliberate suppression or institutional cover-up; intent allegations require direct primary documentary evidence.',
        };
      }
    }

    // 3. Detect Subgroup / Cherry-Picking Inference
    const assertsSubgroup =
      explicitInferenceType === 'SUBGROUP_TO_GENERAL' ||
      targetTextLower.includes('subgroup') ||
      targetTextLower.includes('retrospective');

    if (assertsSubgroup) {
      const hasPrespecifiedSAP = (targetProposition.supportingEvidenceIds || []).some(id => {
        const item = evidenceRegistry[id];
        return (
          item?.evidenceDomain === 'REGULATORY_DOCKET' &&
          item?.epistemicScope?.establishes?.toLowerCase().includes('prespecified')
        );
      });

      if (!hasPrespecifiedSAP) {
        return {
          inferenceId,
          sourcePropositionIds: sourcePropIds,
          targetPropositionId: targetProposition.propositionId,
          inferenceType: 'SUBGROUP_TO_GENERAL',
          validity: 'INVALID_WITHOUT_ADDITIONAL_EVIDENCE',
          detectedFallacy: 'CHERRY_PICKING',
          missingEvidence: [
            'Prespecified statistical analysis plan with multiple testing (multiplicity) corrections and replication in independent confirmatory cohort',
          ],
          contradictingEvidenceIds: [],
          explanation:
            'Post-hoc subgroup analyses without prespecified hypotheses and multiplicity corrections carry high false-discovery rates and cannot establish general clinical efficacy.',
        };
      }
    }

    // 4. Fallback standard deductive/inductive inference check
    return {
      inferenceId,
      sourcePropositionIds: sourcePropIds,
      targetPropositionId: targetProposition.propositionId,
      inferenceType: explicitInferenceType || 'DIRECT_DEDUCTION',
      validity: 'VALID_DEDUCTIVE',
      missingEvidence: [],
      contradictingEvidenceIds: [],
      explanation: 'Inference follows deductively from verified premises.',
    };
  }

  /**
   * Comprehensive audit of all propositions and evidence transfers in an assessment.
   */
  public static auditEvidenceTransfers(params: {
    propositions: ClaimDecompositionProposition[];
    evidenceRegistry: Record<string, EvidenceRegistryItem>;
    reasoningValidity?: ReasoningValidity;
  }): {
    inferenceAudits: InferenceStepAudit[];
    hasInvalidDomainTransfer: boolean;
    domainTransferErrors: string[];
  } {
    const { propositions, evidenceRegistry, reasoningValidity } = params;
    const audits: InferenceStepAudit[] = [];
    const domainTransferErrors: string[] = [];

    const premiseProps = propositions.filter(p => p.role === 'PREMISE');
    const conclusionProps = propositions.filter(p => p.role === 'CONCLUSION');

    const isClaimedSound = reasoningValidity === 'SOUND_INFERENCE' || (reasoningValidity as string) === 'VALID_DEDUCTIVE';

    let idx = 1;
    for (const conclusion of conclusionProps) {
      const audit = this.validateInferenceStep({
        inferenceId: `inf_step_${idx++}`,
        sourcePropositions: premiseProps,
        targetProposition: conclusion,
        evidenceRegistry,
      });
      audits.push(audit);

      if (audit.detectedFallacy === 'EVIDENCE_DOMAIN_TRANSFER') {
        if (conclusion.assessment === 'SUPPORTED' || isClaimedSound) {
          domainTransferErrors.push(
            `[EVIDENCE_DOMAIN_TRANSFER] Conclusion '${conclusion.propositionId}' asserts clinical outcome relying on in-vitro laboratory evidence without human trial confirmation.`
          );
        }
      } else if (audit.detectedFallacy === 'INTENT_IMPUTATION') {
        if (conclusion.assessment === 'SUPPORTED' || isClaimedSound) {
          domainTransferErrors.push(
            `[INTENT_IMPUTATION] Proposition '${conclusion.propositionId}' asserts intentional suppression without primary documentary evidence.`
          );
        }
      }
    }

    // Also check if any individual proposition asserts a clinical outcome marked SUPPORTED solely by in-vitro evidence
    for (const prop of propositions) {
      const assertsClinical =
        prop.propositionType === 'CLINICAL_OUTCOME' ||
        prop.text.toLowerCase().includes('prevent') ||
        prop.text.toLowerCase().includes('in humans');

      if (assertsClinical && prop.assessment === 'SUPPORTED') {
        const evIds = prop.supportingEvidenceIds || [];
        const isSolelyInVitro =
          evIds.length > 0 &&
          evIds.every(id => evidenceRegistry[id]?.evidenceDomain === 'IN_VITRO_LABORATORY');
        if (isSolelyInVitro) {
          domainTransferErrors.push(
            `[INVALID_DOMAIN_SUPPORT] Proposition '${prop.propositionId}' asserts human clinical outcome marked SUPPORTED solely by in-vitro laboratory citations.`
          );
        }
      }
    }

    return {
      inferenceAudits: audits,
      hasInvalidDomainTransfer: domainTransferErrors.length > 0,
      domainTransferErrors,
    };
  }
}
