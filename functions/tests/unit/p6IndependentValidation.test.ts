import * as crypto from 'crypto';
import { CryptographicProvenanceService } from '../../src/pipeline/services/cryptographicProvenanceService';
import { KeyDiscoveryService } from '../../src/pipeline/services/keyDiscoveryService';
import { EconometricTrendService } from '../../src/pipeline/services/econometricTrendService';
import { CitationRetractionService } from '../../src/pipeline/services/citationRetractionService';
import { BlindEvaluationService } from '../../src/pipeline/services/blindEvaluationService';
import { AuditPortalService } from '../../src/pipeline/services/auditPortalService';
import { AuditPackService } from '../../src/pipeline/services/auditPackService';
import { BLIND_EVALUATION_CORPUS_100 } from '../../src/pipeline/benchmarks/blindEvaluationDataset';
import { ClaimNature, FramingStyle, VerifiedClaim } from '../../src/pipeline/types';

// Standalone verifier
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { verifyAuditPackStandalone, canonicalStringifyStandalone } = require('../../../scripts/verify_audit_pack');

describe('P6 Milestone: Independent External Audit & Real-World Certification Test Suite', () => {
  // ──────────────────────────────────────────────────────────
  // 1. DELIVERABLE 1 & REFINEMENT 1: PUBLIC-KEY AUTHENTICITY & DISCOVERY
  // ──────────────────────────────────────────────────────────
  describe('1. Public-Key Authenticity & Discovery', () => {
    it('serves authoritative /.well-known/truthworld-keys.json with valid SHA-256 fingerprints', () => {
      const keySet = KeyDiscoveryService.getWellKnownKeySet();

      expect(keySet.authority).toBe('https://truthworld.ai');
      expect(keySet.endpoint).toContain('/.well-known/truthworld-keys.json');
      expect(keySet.keys.length).toBeGreaterThan(0);

      const activeKey = keySet.keys.find(k => k.status === 'active')!;
      expect(activeKey.algorithm).toBe('Ed25519');
      expect(activeKey.publicKeyPem).toContain('BEGIN PUBLIC KEY');
      expect(activeKey.publicKeyFingerprintSha256.length).toBe(64); // SHA-256 hex length

      // Authenticity check against registered authority keys
      const authenticityCheck = KeyDiscoveryService.verifyKeyAuthenticity(activeKey.publicKeyPem);
      expect(authenticityCheck.isAuthentic).toBe(true);
      expect(authenticityCheck.keyRecord?.kid).toBe(activeKey.kid);
    });

    it('detects and rejects public-key substitution attack from unauthorized key', () => {
      // Attacker generates an adversary keypair
      const attackerKeys = crypto.generateKeyPairSync('ed25519');
      const attackerPubPem = attackerKeys.publicKey.export({ type: 'spki', format: 'pem' }).toString();

      // Authenticity check against TruthWorld discovery MUST reject attacker key
      const authenticityCheck = KeyDiscoveryService.verifyKeyAuthenticity(attackerPubPem);
      expect(authenticityCheck.isAuthentic).toBe(false);
      expect(authenticityCheck.error).toContain('does not match any registered TruthWorld authority key');
    });

    it('supports key rotation while preserving historical verification keys', () => {
      const initialActive = KeyDiscoveryService.getActiveKey();
      const rotatedKey = KeyDiscoveryService.rotateAuthorityKey();

      expect(rotatedKey.status).toBe('active');
      expect(rotatedKey.kid).not.toBe(initialActive.kid);

      // Verify the old key is now deprecated but still authentic for historical verification
      const historicalCheck = KeyDiscoveryService.verifyKeyAuthenticity(initialActive.publicKeyPem);
      expect(historicalCheck.isAuthentic).toBe(true);
      expect(historicalCheck.keyRecord?.status).toBe('deprecated');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 2. REFINEMENT 2: RFC 8785 CANONICALIZATION EDGE CASES
  // ──────────────────────────────────────────────────────────
  describe('2. RFC 8785 Canonicalization Hardening & Cross-Platform Vectors', () => {
    it('normalizes negative zero (-0) to 0 across both internal service and standalone verifier', () => {
      const objNegativeZero = { count: -0, regularZero: 0, positive: 42 };
      const canonicalInternal = CryptographicProvenanceService.canonicalStringify(objNegativeZero);
      const canonicalStandalone = canonicalStringifyStandalone(objNegativeZero);

      expect(canonicalInternal).toBe('{"count":0,"positive":42,"regularZero":0}');
      expect(canonicalStandalone).toBe(canonicalInternal);
      expect(canonicalInternal).not.toContain('-0');
    });

    it('filters undefined, functions, and symbols deterministically', () => {
      const objWithUndefined = {
        valid: 'yes',
        ghost: undefined,
        func: () => 'omit',
        nested: { inner: 'ok', ghostInner: undefined },
      };

      const canonical = CryptographicProvenanceService.canonicalStringify(objWithUndefined);
      expect(canonical).toBe('{"nested":{"inner":"ok"},"valid":"yes"}');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 3. REFINEMENT 3: ECONOMETRIC AUTOCORRELATION & HAC ADJUSTMENT
  // ──────────────────────────────────────────────────────────
  describe('3. Econometric Autocorrelation Adjustment (Newey-West HAC)', () => {
    it('widens confidence and prediction intervals when serial persistence (r1 > 0.15) is present', () => {
      // Historical series with strong positive serial persistence
      const persistentSeries = [
        { year: 1950, value: 3.1 },
        { year: 1951, value: 3.2 },
        { year: 1952, value: 3.3 },
        { year: 1953, value: 3.5 },
        { year: 1954, value: 3.6 },
        { year: 1955, value: 3.7 },
        { year: 1956, value: 3.9 },
        { year: 1957, value: 4.0 },
        { year: 1958, value: 4.1 },
        { year: 1959, value: 4.2 },
      ];

      const assessment = EconometricTrendService.evaluateEconometricTrend(
        'TestCountry',
        'GDP_TREND',
        1960,
        4.3,
        persistentSeries
      );

      expect(assessment.autocorrelationCoefficient).toBeGreaterThan(0.5);
      expect(assessment.rationale).toContain('Serial persistence r1=');
      expect(assessment.observationPredictionInterval95[1]).toBeGreaterThan(assessment.sampleMean);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 4. REFINEMENT 4: FINDING-LEVEL EVIDENCE ATTRIBUTION
  // ──────────────────────────────────────────────────────────
  describe('4. Finding-Level Evidence Attribution', () => {
    it('evaluates evidence at the specific finding level within partially corrected literature', () => {
      const testDoi = '10.1016/s0140-6736(26)finding-test';
      CitationRetractionService.registerOrUpdateRecord({
        doi: testDoi,
        title: 'Multi-Cohort Clinical Trial of Cardiovascular Intervention',
        journal: 'The Lancet',
        status: 'partially_corrected',
        retractionReason: 'Figure 3 cohort sample size misreported; primary mortality findings unaffected.',
        retractionNoticeUrl: 'https://example.com/partial-correction',
      });

      const source = {
        title: 'Multi-Cohort Trial',
        url: `https://doi.org/${testDoi}`,
        tier: 'B' as const,
        snippet: 'Primary overall mortality reduction was 18% across 12,000 enrolled patients.',
      };

      // 4A. Unaffected finding retains high evidentiary weight
      const unaffectedCheck = CitationRetractionService.evaluateFindingSpecificGrounding(
        source,
        'overall mortality reduction was 18%',
        ['figure 3', 'cohort sample size']
      );
      expect(unaffectedCheck.isAffectedByRetractionOrCorrection).toBe(false);
      expect(unaffectedCheck.findingSpecificWeight).toBe(0.80);

      // 4B. Compromised finding is invalidated
      const affectedCheck = CitationRetractionService.evaluateFindingSpecificGrounding(
        source,
        'Figure 3 cohort sub-analysis proves efficacy in elderly patients',
        ['figure 3', 'cohort sample size']
      );
      expect(affectedCheck.isAffectedByRetractionOrCorrection).toBe(true);
      expect(affectedCheck.findingSpecificWeight).toBe(0.10);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 5. DELIVERABLES 2 & 3: 100-CLAIM BLIND EVALUATION ACROSS EN, TE, HI
  // ──────────────────────────────────────────────────────────
  describe('5. Real-World Blind Evaluation Benchmark (100 Claims Across EN, TE, HI)', () => {
    it('executes double-blind evaluation, achieves high agreement with experts, and computes Cohen Kappa', () => {
      expect(BLIND_EVALUATION_CORPUS_100.length).toBe(100);

      // Run blind evaluation benchmark
      const report = BlindEvaluationService.runBlindEvaluationBenchmark(BLIND_EVALUATION_CORPUS_100);

      expect(report.totalClaims).toBe(100);
      expect(report.agreementRate).toBeGreaterThanOrEqual(0.90); // >= 90% agreement with domain experts
      expect(report.cohenKappa).toBeGreaterThanOrEqual(0.80);    // Almost perfect inter-rater reliability

      // Verify all 3 languages evaluated
      expect(report.byLanguage.en).toBeDefined();
      expect(report.byLanguage.te).toBeDefined();
      expect(report.byLanguage.hi).toBeDefined();

      expect(report.byLanguage.en.total).toBe(40);
      expect(report.byLanguage.te.total).toBe(30);
      expect(report.byLanguage.hi.total).toBe(30);

      expect(report.byLanguage.en.agreementRate).toBeGreaterThanOrEqual(0.85);
      expect(report.byLanguage.te.agreementRate).toBeGreaterThanOrEqual(0.85);
      expect(report.byLanguage.hi.agreementRate).toBeGreaterThanOrEqual(0.85);

      // Verify categories evaluated
      expect(report.byCategory.historical_event).toBeDefined();
      expect(report.byCategory.economic_statistical_indicator).toBeDefined();
      expect(report.byCategory.scientific_empirical_claim).toBeDefined();
      expect(report.byCategory.traditional_religious_belief).toBeDefined();

      expect(report.coverageRate).toBeGreaterThanOrEqual(0.70);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 6. DELIVERABLES 4 & 5: PUBLIC AUDIT PORTAL & TRACEABLE CORRECTION LEDGER
  // ──────────────────────────────────────────────────────────
  describe('6. Public Audit Portal & Traceable Correction Ledger', () => {
    it('publishes audit pack to public registry and cryptographically links appeals amendment', () => {
      const mockClaim: VerifiedClaim = {
        claimId: 'p6_claim_demonstration',
        text: 'Narasimha Rao and Manmohan Singh initiated industrial licensing reforms in July 1991.',
        status: 'verified_true',
        confidence: 0.98,
        verdictConfidence: 0.98,
        verificationConfidence: 0.98,
        importance: 0.95,
        nature: ClaimNature.HISTORICAL_FACT,
        framing: FramingStyle.ASSERTIVE,
        chunkIndex: 0,
        evidenceStrength: 0.95,
        sourceIndependenceScore: 0.92,
        reasoning: 'Archived in Lok Sabha Parliamentary Debates and Ministry of Finance Budget Speech 1991-92.',
        richSources: [
          {
            title: 'Lok Sabha Debates July 1991',
            url: 'https://loksabha.nic.in/debates/1991',
            tier: 'A',
            snippet: 'Statement on Industrial Policy laid on the table of Lok Sabha on 24 July 1991.',
          },
        ],
      };

      const auditPack = AuditPackService.exportAuditPack(mockClaim);

      // 6A. Publish to Public Audit Portal
      const publishResult = AuditPortalService.publishAuditPack(auditPack);
      expect(publishResult.published).toBe(true);
      expect(publishResult.publicUrl).toContain('truthworld.ai/audit/');
      expect(publishResult.fingerprint.length).toBe(64);

      // 6B. Adjudicate an audit amendment (e.g., fine-tuning verdict on formal appeal)
      const { amendment, amendedPack } = AuditPortalService.amendAuditPack(
        auditPack,
        'Appeals Desk review clarified statutory gazette notification date vs Lok Sabha tabling date.',
        'audit_authority_appeals_desk',
        'verified_true',
        'Gazette of India Extraordinary Part II Section 3 confirms statutory notification.'
      );

      expect(amendment.originalPackId).toBe(auditPack.packId);
      expect(amendment.originalPackHash).toBe(auditPack.cryptographicAttestation.auditPackSha256);
      expect(amendment.newAuditPackSha256).toBe(amendedPack.cryptographicAttestation.auditPackSha256);
      expect(amendment.immutableChainHash.length).toBe(64); // SHA-256 chain link

      // 6C. Both original and amended packs remain verifiable and retrievable in history
      const history = AuditPortalService.getAmendmentHistory(auditPack.packId);
      expect(history.length).toBe(1);
      expect(history[0].amendmentReason).toContain('Appeals Desk review');

      const standaloneVerification = verifyAuditPackStandalone(amendedPack, {
        publicKeyPem: amendedPack.cryptographicAttestation.publicKeyPem,
      });
      expect(standaloneVerification.isValid).toBe(true);
    });
  });
});
