import { getAdversarial100Dataset } from '../../src/pipeline/evaluation/adversarialDataset';
import { DeterministicVerifierService } from '../../src/pipeline/services/deterministicVerifier';
import { SemanticEvidenceValidator } from '../../src/pipeline/services/semanticEvidenceValidator';

describe('Adversarial Benchmark Evaluation Suite (N = 100 Cases across 12 Strata)', () => {
  const dataset = getAdversarial100Dataset();

  it('contains exactly 100 independently reviewable test cases', () => {
    expect(dataset.length).toBe(100);
  });

  it('covers all 12 specified adversarial strata with correct distribution', () => {
    const strataCounts = new Map<string, number>();
    for (const testCase of dataset) {
      strataCounts.set(testCase.strata, (strataCounts.get(testCase.strata) || 0) + 1);
    }

    expect(strataCounts.get('GENUINE_SOURCE_MISLEADING_INTERPRETATION')).toBe(10);
    expect(strataCounts.get('FABRICATED_CITATION')).toBe(10);
    expect(strataCounts.get('GENUINE_CITATION_IRRELEVANT_SUPPORT')).toBe(10);
    expect(strataCounts.get('ACCURATE_PREMISES_INVALID_CONCLUSION')).toBe(10);
    expect(strataCounts.get('CONFLICTING_SCIENTIFIC_EVIDENCE')).toBe(8);
    expect(strataCounts.get('HISTORICAL_UNCERTAINTY_AND_DATING')).toBe(8);
    expect(strataCounts.get('RELIGIOUS_AND_THEOLOGICAL_CLAIMS')).toBe(10);
    expect(strataCounts.get('POLITICAL_SELECTIVE_CONTEXT')).toBe(8);
    expect(strataCounts.get('BREAKING_NEWS_UNCERTAINTY')).toBe(8);
    expect(strataCounts.get('SYNDICATED_REPETITION_AND_DUPLICATE_DATASETS')).toBe(8);
    expect(strataCounts.get('DEBUNKING_QUOTED_MYTHS')).toBe(6);
    expect(strataCounts.get('SATIRE_AND_RHETORICAL_HYPERBOLE')).toBe(4);
  });

  it('executes automated evaluation across all 100 adversarial cases with 100% adherence to expected outcomes', () => {
    let passedCount = 0;
    const failures: Array<{ caseId: string; strata: string; reason: string }> = [];

    for (const testCase of dataset) {
      const { caseId, strata, assessment, semanticLinks = [], expected } = testCase;

      // 1. Prepare assessment with semantic links if present
      const fullAssessment = {
        ...assessment,
        semanticValidation: semanticLinks.length > 0 ? {
          links: semanticLinks,
          overclaimingAudit: { overclaimingDetected: false, violationTypes: [], details: [] },
          semanticEvidenceLevel: 'ROBUST_SUPPORT' as const,
        } : undefined,
      };

      // Validation check
      const validation = DeterministicVerifierService.validateAssessmentV2(fullAssessment);

      if (expected.requiresValidationFailure) {
        if (validation.isValid) {
          failures.push({
            caseId,
            strata,
            reason: `Expected validation failure, but validation passed.`,
          });
          continue;
        }

        if (expected.expectedFailureErrorSubstrings) {
          const hasExpectedErrors = expected.expectedFailureErrorSubstrings.every(sub =>
            validation.errors.some(err => err.includes(sub))
          );
          if (!hasExpectedErrors) {
            failures.push({
              caseId,
              strata,
              reason: `Expected error substrings [${expected.expectedFailureErrorSubstrings.join(
                ', '
              )}], but got [${validation.errors.join('; ')}].`,
            });
            continue;
          }
        }
      } else {
        if (!validation.isValid) {
          failures.push({
            caseId,
            strata,
            reason: `Expected valid assessment, but failed with: ${validation.errors.join('; ')}`,
          });
          continue;
        }
      }

      // 2. Overclaiming check
      let overclaimingAudit: any = undefined;
      if (expected.expectedOverclaimingViolation || assessment.semanticValidation?.overclaimingAudit) {
        const provenanceGraph = SemanticEvidenceValidator.constructProvenanceGraph({
          evidenceRegistry: assessment.evidenceRegistry,
          datasets: [{ datasetId: 'WIRE_PR_009', name: 'PR Wire' }, { datasetId: 'NCT01234567', name: 'Clinical Trial' }],
        });

        overclaimingAudit = SemanticEvidenceValidator.auditOverclaiming(
          assessment,
          semanticLinks,
          provenanceGraph
        );

        if (expected.expectedOverclaimingViolation) {
          if (!overclaimingAudit.overclaimingDetected || !overclaimingAudit.violationTypes.includes(expected.expectedOverclaimingViolation)) {
            failures.push({
              caseId,
              strata,
              reason: `Expected overclaiming violation '${expected.expectedOverclaimingViolation}', but got [${overclaimingAudit.violationTypes.join(
                ', '
              )}].`,
            });
            continue;
          }
        }
      }

      // 3. Display badge derivation check
      const derivedBadge = DeterministicVerifierService.deriveDisplayBadge(
        assessment.classification.propositionType,
        assessment.classification.evidenceStatus,
        assessment.classification.reasoningValidity,
        overclaimingAudit
      );

      if (derivedBadge !== expected.displayBadge && !expected.requiresValidationFailure) {
        failures.push({
          caseId,
          strata,
          reason: `Derived badge '${derivedBadge}' does not match expected badge '${expected.displayBadge}'.`,
        });
        continue;
      }

      passedCount++;
    }

    if (failures.length > 0) {
      console.error('Adversarial benchmark failures:', failures);
    }

    expect(failures).toEqual([]);
    expect(passedCount).toBe(100);
  });
});
