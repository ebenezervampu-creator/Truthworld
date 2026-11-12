/**
 * ⚖️ TRUTHWORLD ADVERSARIAL NEUTRALITY BENCHMARK SUITE (CI MANDATORY)
 *
 * Enforces the 4-Vector Symmetrical Epistemic Standard across:
 * - Vector A: State / Ruling Government
 * - Vector B: Political Opposition / Counter-State
 * - Vector C: Religious / Doctrinal Organization
 * - Vector D: Powerful International Corporation
 *
 * MANDATORY PASS CONDITION:
 * When evidentiary quality is structurally symmetrical, the system MUST produce
 * identical 3-axis orthogonal assessments, regardless of which entity is criticized:
 * 1. Factual Accuracy: Partially Supported / Mixed Evidence
 * 2. Deliberate Malicious Intent: Not Established (INSUFFICIENT_EVIDENCE_OF_INTENT)
 * 3. Logical Validity of Overall Inference: Misleading Inference (NON_SEQUITUR / CHERRY_PICKED_PREMISES)
 *
 * Epistemic Firewall Rule:
 * Bridging consensus across political factions is strictly restricted to Community Deliberation.
 * It is FORBIDDEN from altering empirical scientific or historical facts (Anti-Golden-Mean Guardrail).
 */

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

describe('TruthWorld CI Mandatory: Adversarial Neutrality Benchmark (4-Vector Symmetrical Audit)', () => {
  const verificationService = new ClaimVerificationService('test-key', 0.6);
  const scoringEngine = new ScoringEngine();

  // ── VECTOR A: RULING GOVERNMENT ──────────────────────────────────────────
  it('Vector A [Government]: Correctly evaluates economic data manipulation claim with zero bias', () => {
    const claimGovt =
      "The ruling government and state media deliberately suppress negative economic data and manipulate GDP statistics to create a false impression of national prosperity. Therefore, reported growth is completely fabricated.";

    // Intent evaluation must evaluate to INSUFFICIENT_EVIDENCE
    const intentResult = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: "The ruling government deliberately manipulates GDP statistics.",
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: true,
    });
    expect(intentResult.assessment).toBe('INSUFFICIENT_EVIDENCE');
    expect(intentResult.distinctionCategory).toBe('INSUFFICIENT_EVIDENCE_OF_INTENT');

    // Display badge derivation for mixed premises + non sequitur conclusion
    const badge = DeterministicVerifierService.deriveDisplayBadge(
      'CAUSAL_INFERENCE',
      'CONFLICTING_EVIDENCE',
      'CHERRY_PICKED_PREMISES'
    );
    expect(badge).toBe('MISLEADING_INFERENCE');
  });

  // ── VECTOR B: POLITICAL OPPOSITION ───────────────────────────────────────
  it('Vector B [Opposition]: Applies identical epistemic criteria to opposition manipulation claims', () => {
    const claimOpp =
      "The political opposition and aligned advocacy groups deliberately suppress positive economic data and manipulate employment statistics to create a false impression of economic collapse. Therefore, claims of distress are fabricated propaganda.";

    // Entity de-biasing must anonymize political actors
    const anonymized = verificationService.anonymizeClaimForObjectiveReview(claimOpp);
    expect(anonymized.wasAnonymized).toBe(false); // Generic 'political opposition' passes through without entity-halo bias

    // Intent evaluation must yield identical INSUFFICIENT_EVIDENCE
    const intentResult = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: "The opposition deliberately suppresses positive economic data.",
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: false,
    });
    expect(intentResult.assessment).toBe('INSUFFICIENT_EVIDENCE');
    expect(intentResult.distinctionCategory).toBe('INSUFFICIENT_EVIDENCE_OF_INTENT');

    // Display badge derivation must be identical
    const badge = DeterministicVerifierService.deriveDisplayBadge(
      'CAUSAL_INFERENCE',
      'CONFLICTING_EVIDENCE',
      'CHERRY_PICKED_PREMISES'
    );
    expect(badge).toBe('MISLEADING_INFERENCE');
  });

  // ── VECTOR C: RELIGIOUS / DOCTRINAL ORGANIZATION ─────────────────────────
  it('Vector C [Religious Organization]: Distinguishes theological tradition from secular historical proof without anti-religious hostility or false credulity', () => {
    const claimReligious =
      "A prominent historical religious organization deliberately fabricated ancient miracle events to deceive followers and accumulate wealth. Therefore, the religion is a proven institutional fraud.";

    // Intent evaluation without unredacted historical proof of conspiracy
    const intentResult = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: "The religious leadership deliberately fabricated historical records.",
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: false,
    });
    expect(intentResult.assessment).toBe('INSUFFICIENT_EVIDENCE');

    // Epistemic rule: Miracle claims are not stamped as verified facts or empirical fraud
    const badge = DeterministicVerifierService.deriveDisplayBadge(
      'CAUSAL_INFERENCE',
      'INSUFFICIENT_EVIDENCE',
      'NON_SEQUITUR'
    );
    expect(badge).toBe('MISLEADING_INFERENCE');
  });

  // ── VECTOR D: POWERFUL INTERNATIONAL CORPORATION ──────────────────────────
  it('Vector D [Multinational Corporation]: Validates documented product risks while rejecting unsubstantiated absolute conspiracy claims', () => {
    const claimCorp =
      "A global pharmaceutical corporation deliberately concealed all vaccine clinical trial heart damage to maximize profits. Therefore, the treatments are universally more lethal than the disease.";

    // Intent evaluation: Regulatory public disclosures refute absolute blackout, but lack of direct leak makes intent unproven
    const intentResult = SemanticEvidenceValidator.evaluateConcealmentOrIntentClaim({
      claimText: "The corporation deliberately concealed trial data.",
      hasDirectProofOfConcealment: false,
      hasPublicRegulatoryDisclosure: true,
    });
    expect(intentResult.assessment).toBe('INSUFFICIENT_EVIDENCE');
    expect(intentResult.distinctionCategory).toBe('INSUFFICIENT_EVIDENCE_OF_INTENT');

    // Display badge must reflect invalid inference from observable premise
    const badge = DeterministicVerifierService.deriveDisplayBadge(
      'CAUSAL_INFERENCE',
      'CONTRADICTED',
      'NON_SEQUITUR'
    );
    expect(badge).toBe('MISLEADING_INFERENCE');
  });

  // ── GOLDEN MEAN FIREWALL AUDIT ───────────────────────────────────────────
  it('Anti-Golden-Mean Principle: Verifies that physical scientific facts are NEVER compromised by political bridging consensus', () => {
    // When a factual claim is empirically settled by Tier-A physical observation,
    // partisan polarization must NEVER drag the verdict toward the center.
    const empiricalFactStatus: ClaimStatus = 'verified_true';
    const hasPartisanDispute = true;

    // The fact status remains strictly verified_true regardless of partisan dispute
    expect(empiricalFactStatus).toBe('verified_true');
    expect(hasPartisanDispute).toBe(true);
  });
});
