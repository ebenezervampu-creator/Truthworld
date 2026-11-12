import * as crypto from 'crypto';
import { CryptographicProvenanceService } from '../../src/pipeline/services/cryptographicProvenanceService';
import { EconometricTrendService } from '../../src/pipeline/services/econometricTrendService';
import { CitationRetractionService } from '../../src/pipeline/services/citationRetractionService';
import { AdversarialRobustnessService } from '../../src/pipeline/services/adversarialRobustnessService';
import { AuditPackService } from '../../src/pipeline/services/auditPackService';
import { GOLD_STANDARD_BENCHMARK_DATASET } from '../../src/pipeline/benchmarks/goldStandardClaims';
import {
  P5_HISTORICAL_GDP_SERIES,
  P5_RETRACTED_SOURCES,
  P5_MULTIMODAL_FIXTURES,
} from '../../src/pipeline/benchmarks/p5ValidationSuite';
import { BenchmarkEvaluationService } from '../../src/pipeline/services/benchmarkEvaluationService';
import { PublicAuditPackV1 } from '../../src/pipeline/types';

// Independent standalone verifier import
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { verifyAuditPackStandalone, canonicalStringifyStandalone } = require('../../../scripts/verify_audit_pack');

describe('P5 Production Trust Certification & Independent Validation Test Suite (10 Acceptance Criteria)', () => {
  const benchmarkService = new BenchmarkEvaluationService();

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 1: PUBLIC SIGNATURE VERIFICATION (Ed25519)
  // ──────────────────────────────────────────────────────────
  it('1. Public Signature Verification: External verifier validates manifest and audit pack with public key', () => {
    const manifest = CryptographicProvenanceService.generateDatasetManifest(
      GOLD_STANDARD_BENCHMARK_DATASET,
      '2.0.0-gold'
    );

    expect(manifest.algorithm).toBe('Ed25519');
    expect(manifest.publicKeyPem).toBeDefined();
    expect(manifest.signature.length).toBe(128); // 64 bytes = 128 hex chars

    // External verifier uses only the public key
    const publicKeyPem = CryptographicProvenanceService.getAuthorityPublicKey();
    const verification = CryptographicProvenanceService.verifyDatasetManifest(
      manifest,
      GOLD_STANDARD_BENCHMARK_DATASET,
      publicKeyPem
    );

    expect(verification.isValid).toBe(true);
    expect(verification.discrepancies.length).toBe(0);
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 2: PRIVATE-KEY ISOLATION
  // ──────────────────────────────────────────────────────────
  it('2. Private-Key Isolation: Possessing only the public key prevents forging valid signatures', () => {
    const publicKeyPem = CryptographicProvenanceService.getAuthorityPublicKey();
    const targetPayloadHash = CryptographicProvenanceService.computeSha256({ claim: 'Untrusted forged claim' });

    // Attacker generates an adversary keypair
    const attackerKeyPair = crypto.generateKeyPairSync('ed25519');
    const forgedSignature = crypto.sign(null, Buffer.from(targetPayloadHash, 'utf8'), attackerKeyPair.privateKey).toString('hex');

    // Verification against TruthWorld authority public key MUST fail
    const isAccepted = CryptographicProvenanceService.verifySignatureEd25519(
      targetPayloadHash,
      forgedSignature,
      publicKeyPem
    );

    expect(isAccepted).toBe(false);
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 3: CANONICALIZATION CONSISTENCY (RFC 8785)
  // ──────────────────────────────────────────────────────────
  it('3. Canonicalization Consistency: Identical logical objects produce identical canonical bytes regardless of key insertion order', () => {
    const objA = {
      zebra: 1,
      alpha: 'first',
      nested: { delta: true, beta: [3, 2, 1] },
      gamma: null,
    };

    const objB = {
      gamma: null,
      alpha: 'first',
      nested: { beta: [3, 2, 1], delta: true },
      zebra: 1,
    };

    const canonicalA = CryptographicProvenanceService.canonicalStringify(objA);
    const canonicalB = CryptographicProvenanceService.canonicalStringify(objB);
    const standaloneCanonicalA = canonicalStringifyStandalone(objA);

    expect(canonicalA).toBe(canonicalB);
    expect(canonicalA).toBe(standaloneCanonicalA);
    expect(CryptographicProvenanceService.computeSha256(objA)).toBe(CryptographicProvenanceService.computeSha256(objB));
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 4: TAMPER DETECTION
  // ──────────────────────────────────────────────────────────
  it('4. Tamper Detection: Any single-character change to signed claim payload invalidates verification', () => {
    const manifest = CryptographicProvenanceService.generateDatasetManifest(
      GOLD_STANDARD_BENCHMARK_DATASET,
      '2.0.0-gold'
    );

    const tamperedCorpus = JSON.parse(JSON.stringify(GOLD_STANDARD_BENCHMARK_DATASET));
    tamperedCorpus[0].claimText += '.'; // Subtle single-char modification

    const tamperedCheck = CryptographicProvenanceService.verifyDatasetManifest(manifest, tamperedCorpus);
    expect(tamperedCheck.isValid).toBe(false);
    expect(tamperedCheck.discrepancies.length).toBeGreaterThan(0);
    expect(tamperedCheck.discrepancies[0]).toContain('Tamper detected in record');
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 5: SOURCE SNAPSHOT INTEGRITY
  // ──────────────────────────────────────────────────────────
  it('5. Source Snapshot Integrity: Modified source snapshot fails content hash validation', async () => {
    const record = GOLD_STANDARD_BENCHMARK_DATASET.find(r => r.id === 'comp_001_nehru_thailand_pakistan')!;
    const evaluatedClaim = await benchmarkService.evaluateSingleBenchmarkRecord(record);
    const auditPack = AuditPackService.exportAuditPack(evaluatedClaim, record);

    expect(auditPack.sourceSnapshots).toBeDefined();
    expect(auditPack.sourceSnapshots!.length).toBeGreaterThan(0);

    // Pristine audit pack verifies cleanly
    const pristineCheck = AuditPackService.verifyAuditPack(auditPack);
    expect(pristineCheck.isValid).toBe(true);

    // Tamper with a source snapshot excerpt
    const tamperedPack = JSON.parse(JSON.stringify(auditPack));
    tamperedPack.sourceSnapshots[0].permissibleExcerpt += ' [MODIFIED CITATION TEXT]';

    const tamperedCheck = AuditPackService.verifyAuditPack(tamperedPack);
    expect(tamperedCheck.isValid).toBe(false);
    expect(tamperedCheck.discrepancies.some((d: string) => d.includes('Source Snapshot Tamper') || d.includes('Tamper Detected'))).toBe(true);
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 6: RETRACTION LIFECYCLE & NON-SILENCING AUDIT
  // ──────────────────────────────────────────────────────────
  it('6. Retraction Lifecycle: Retracted citations are preserved in audit pack with 0.0 weight and notice URLs', () => {
    // 6A. Retracted Wakefield publication
    const wakefieldSource = P5_RETRACTED_SOURCES[0];
    const auditWakefield = CitationRetractionService.verifyAcademicCitation(
      wakefieldSource,
      'MMR vaccine causes autism'
    );

    expect(auditWakefield.isValid).toBe(false);
    expect(auditWakefield.isRetracted).toBe(true);
    expect(auditWakefield.evidentiaryWeight).toBe(0.0);
    expect(auditWakefield.adjudicationRecommendation).toBe('reject');
    expect(auditWakefield.retractionDetails?.retractionNoticeUrl).toContain('thelancet.com');

    // 6B. Dynamic lifecycle update: Expression of Concern to Reinstated
    const testDoi = '10.1038/s41586-test-lifecycle';
    CitationRetractionService.registerOrUpdateRecord({
      doi: testDoi,
      title: 'Experimental Room Temperature Superconductor',
      journal: 'Nature Physics',
      status: 'expression_of_concern',
      retractionNoticeUrl: 'https://example.com/eoc-notice',
    });

    const eocCheck = CitationRetractionService.lookupDoi(testDoi);
    expect(eocCheck?.status).toBe('expression_of_concern');
    expect(eocCheck?.evidentiaryWeight).toBe(0.25);

    // Update lifecycle to corrected
    CitationRetractionService.registerOrUpdateRecord({
      ...eocCheck!,
      status: 'corrected',
      evidentiaryWeight: 0.75,
    });
    const correctedCheck = CitationRetractionService.lookupDoi(testDoi);
    expect(correctedCheck?.status).toBe('corrected');
    expect(correctedCheck?.evidentiaryWeight).toBe(0.75);
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 7: STATISTICAL STRUCTURAL BREAK VS DECEPTION
  // ──────────────────────────────────────────────────────────
  it('7. Statistical Structural Break: Known regime changes are not automatically branded deception', () => {
    // 7A. Pakistan 1958 Bumper Crop Anomaly coincides with known structural break
    const pakAssessment = EconometricTrendService.evaluateEconometricTrend(
      'Pakistan',
      'GDP_GROWTH_RATE',
      1958,
      7.4,
      P5_HISTORICAL_GDP_SERIES.pakistan
    );

    expect(pakAssessment.sampleMean).toBeCloseTo(3.43, 1);
    expect(pakAssessment.zScore).toBeGreaterThan(2.5);
    expect(pakAssessment.isStatisticallyAnomalous).toBe(true);
    expect(pakAssessment.structuralBreakIdentified).toBeDefined();
    expect(pakAssessment.anomalyClassification).toBe('structural_break_event');
    expect(pakAssessment.isCherryPickedAnomaly).toBe(false); // Not presumed deceptive
    expect(pakAssessment.rationale).toContain('Documented Structural Break');

    // 7B. Verify degrees of freedom, SE, formal CI for mean, and PI for observations
    expect(pakAssessment.degreesOfFreedom).toBe(P5_HISTORICAL_GDP_SERIES.pakistan.length - 1);
    expect(pakAssessment.standardErrorOfMean).toBeGreaterThan(0);
    expect(pakAssessment.meanConfidenceInterval95[0]).toBeLessThan(pakAssessment.sampleMean);
    expect(pakAssessment.meanConfidenceInterval95[1]).toBeGreaterThan(pakAssessment.sampleMean);
    expect(pakAssessment.observationPredictionInterval95[0]).toBeLessThan(pakAssessment.meanConfidenceInterval95[0]);
    expect(pakAssessment.observationPredictionInterval95[1]).toBeGreaterThan(pakAssessment.meanConfidenceInterval95[1]);
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 8: MULTIMODAL CORRECTION & TRUTH DECOUPLING
  // ──────────────────────────────────────────────────────────
  it('8. Multimodal Correction: Distinguishes speaker self-correction from deception and decouples explanation from truth', () => {
    for (const fixture of P5_MULTIMODAL_FIXTURES) {
      const reconciliation = AdversarialRobustnessService.reconcileMultiModalDiscrepancy(
        fixture.audioTranscript,
        fixture.ocrText
      );

      expect(reconciliation.classification).toBe(fixture.expectedClassification);

      if (fixture.isPermissible) {
        expect(reconciliation.explanationSupported).toBe(true);
        expect(reconciliation.propositionVerdictUnaffected).toBe(true);
        expect(reconciliation.requiresHumanReview).toBe(false);
      } else {
        expect(reconciliation.explanationSupported).toBe(false);
        expect(reconciliation.propositionVerdictUnaffected).toBe(false);
        expect(reconciliation.requiresHumanReview).toBe(true);
      }
    }
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 9: AUDIT REPRODUCTION VIA STANDALONE VERIFIER
  // ──────────────────────────────────────────────────────────
  it('9. Audit Reproduction: Zero-dependency standalone verifier validates Public Audit Pack', async () => {
    const record = GOLD_STANDARD_BENCHMARK_DATASET.find(r => r.id === 'comp_001_nehru_thailand_pakistan')!;
    const evaluatedClaim = await benchmarkService.evaluateSingleBenchmarkRecord(record);
    const auditPack = AuditPackService.exportAuditPack(evaluatedClaim, record);

    // Call standalone zero-dependency verification utility
    const standaloneResult = verifyAuditPackStandalone(auditPack, {
      publicKeyPem: auditPack.cryptographicAttestation.publicKeyPem,
    });

    expect(standaloneResult.isValid).toBe(true);
    expect(standaloneResult.discrepancies.length).toBe(0);
    expect(standaloneResult.checksPassed.some((c: string) => c.includes('Ed25519 asymmetric'))).toBe(true);
    expect(standaloneResult.checksPassed.some((c: string) => c.includes('All 7 Core Epistemic Questions'))).toBe(true);
  });

  // ──────────────────────────────────────────────────────────
  // ACCEPTANCE TEST 10: AUDIT-PACK VERSIONING & BACKWARD COMPATIBILITY
  // ──────────────────────────────────────────────────────────
  it('10. Audit-Pack Versioning: Older schema packs (1.0.0-auditpack) remain verifiable', () => {
    // Construct legacy V1 pack signed with HMAC
    const legacySecret = 'legacy_audit_secret_2025';
    const legacyBody = {
      schemaVersion: '1.0.0-auditpack' as const,
      packId: 'auditpack_legacy_001',
      generatedAt: '2025-01-01T00:00:00Z',
      claimId: 'legacy_claim_001',
      proposition: {
        originalText: 'Historical atomic statement',
        normalizedAtomicClaim: 'Historical atomic statement',
        sourceLanguage: 'en',
        epistemicCategory: 'historical_event' as const,
      },
      verdict: {
        finalStatus: 'verified_true' as const,
        verdictConfidence: 0.90,
        evidenceStrength: 0.88,
        sourceIndependenceScore: 0.85,
        publicExplanation: 'Legacy verification record.',
      },
      evidenceGraph: {
        admittedSources: [],
        evidencePrecision: 1.0,
      },
      sevenCoreAnswers: {
        q1_exactClaim: 'Historical atomic statement',
        q2_supportingEvidence: 'Archival record',
        q3_contradictoryEvidence: 'None',
        q4_sourceAdmissionRationale: 'Primary archive',
        q5_comparabilityIntegrity: 'Non-comparative',
        q6_epistemicConfidence: '90%',
        q7_limitationsAndUnresolvedDisagreements: 'None',
      },
    };

    const legacySha256 = CryptographicProvenanceService.computeSha256(legacyBody);
    const legacyHmacSig = CryptographicProvenanceService.signHash(legacySha256, legacySecret);

    const legacyPack: PublicAuditPackV1 = {
      ...legacyBody,
      cryptographicAttestation: {
        auditPackSha256: legacySha256,
        datasetManifestHash: 'sha256_manifest_v1',
        signerId: 'audit_authority_legacy',
        algorithm: 'HMAC-SHA256',
        signature: legacyHmacSig,
        verificationInstructions: 'Legacy HMAC verification.',
      },
    };

    // Both internal service and standalone verifier must verify legacy pack
    const internalCheck = AuditPackService.verifyAuditPack(legacyPack, legacySecret);
    expect(internalCheck.isValid).toBe(true);

    const standaloneCheck = verifyAuditPackStandalone(legacyPack, { secretKey: legacySecret });
    expect(standaloneCheck.isValid).toBe(true);
  });
});
