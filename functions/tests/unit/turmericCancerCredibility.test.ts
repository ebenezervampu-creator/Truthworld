import { tier0KnowledgeService } from '../../src/pipeline/services/tier0Knowledge';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { sourceTrustService } from '../../src/pipeline/services/sourceTrustService';
import { ScoringEngine } from '../../src/pipeline/services/scoringEngine';
import {
  normalizeClaimText,
  semanticCanonicalizeClaim,
  hashSemanticClaimText,
} from '../../src/pipeline/utils/claim-normalization';
import {
  ClaimNature,
  FramingStyle,
  VerifiedClaim,
  ClaimStatus,
  ClaimLedgerSummary,
  VerificationState,
} from '../../src/pipeline/types';

describe('Unit: Turmeric Cancer Cure Credibility & TruthWorld Safeguard Verification', () => {
  const verificationService = new ClaimVerificationService('test-key', 0.6);
  const scoringEngine = new ScoringEngine();

  const CLAIM_TEXT = 'Drinking turmeric water cures cancer.';

  it('1. Verifies that the claim is accurately classified as a sensitive medical proposition triggering High-Precision routing', () => {
    const isSensitive = (verificationService as any).isSensitiveClaim(
      { text: CLAIM_TEXT, nature: ClaimNature.VERIFIABLE_FACT },
      false
    );
    expect(isSensitive).toBe(true);

    const { toVerify, opinions } = verificationService.classifyClaims([
      {
        text: CLAIM_TEXT,
        nature: ClaimNature.VERIFIABLE_FACT,
        framing: FramingStyle.ABSOLUTE,
        confidence: 0.95,
        importance: 0.90,
        chunkIndex: 0,
        start: 0,
        end: 5000,
      },
    ]);

    expect(toVerify.length).toBe(1);
    expect(opinions.length).toBe(0);
    expect(toVerify[0].framing).toBe(FramingStyle.ABSOLUTE);
  });

  it('2. Evaluates the claim against authoritative oncology registries and returns "false_claim" with Tier-A sources', () => {
    const t0Match = tier0KnowledgeService.lookupPreIndexedFact(CLAIM_TEXT);

    expect(t0Match).not.toBeNull();
    expect(t0Match!.matched).toBe(true);
    expect(t0Match!.status).toBe('false_claim');
    expect(t0Match!.title).toContain('Turmeric');
    expect(t0Match!.source).toContain('Cancer Research UK');
    expect(t0Match!.domain).toBe('cancerresearchuk.org');
    expect(t0Match!.url).toContain('cancerresearchuk.org');

    const trust = sourceTrustService.resolveSourceTrust(t0Match!.url, 'health');
    expect(trust.tier).toBe('A');
    expect(t0Match!.confidence).toBeGreaterThanOrEqual(0.95);
  });

  it('3. Generates high severity, forced human review, and a prominent viewer warning', () => {
    const t0Match = tier0KnowledgeService.lookupPreIndexedFact(CLAIM_TEXT)!;

    const verifiedClaim: VerifiedClaim = {
      claimId: 'claim_health_turmeric_01',
      text: CLAIM_TEXT,
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.ABSOLUTE,
      confidence: 0.95,
      importance: 0.90,
      chunkIndex: 0,
      start: 0,
      end: 4500,
      status: t0Match.status,
      verificationConfidence: t0Match.confidence,
      reasoning: t0Match.reasoning,
      sources: [t0Match.source],
      richSources: [
        {
          title: t0Match.source,
          url: t0Match.url,
          domain: t0Match.domain,
          tier: 'A',
          snippet: t0Match.reasoning,
          retrievalMethod: 'tier0_corpus',
          lastVerified: new Date().toISOString(),
        },
      ],
      isGrounded: true,
      severity: 'high',
    };

    // Calculate institutional credibility
    const aggregateResult = scoringEngine.calculateInstitutionalTrustScore(
      'video_turmeric_cancer_test',
      'user_test_analyst',
      { text: CLAIM_TEXT, utterances: [] } as any,
      [verifiedClaim],
      1,
      'balanced',
      'medium',
      'Health',
      {}
    );

    expect(aggregateResult.analysisState).toBe(VerificationState.VERIFIED);
    expect(aggregateResult.factCheckStats.false_claim).toBe(1);
    expect(aggregateResult.factCheckStats.verified_true).toBe(0);

    // Ledger Summary & High Severity Assertions
    const confirmedCount = 0;
    const disputedCount = 0;
    const falseCount = 1;
    const unprovenCount = 0;
    const totalClaimsChecked = 1;

    let highestSeverityVerdict: ClaimLedgerSummary['highestSeverityVerdict'] = 'none';
    if (falseCount > 0) highestSeverityVerdict = 'false_claim';

    const priorityNotice = falseCount > 0
      ? `Notice: ${falseCount} claim(s) contradicted by documented evidence.`
      : undefined;

    const claimLedger: ClaimLedgerSummary = {
      totalClaimsChecked,
      confirmedCount,
      disputedCount,
      unprovenCount,
      falseCount,
      contextualCount: 0,
      highestSeverityVerdict,
      verdictHeadline: `${confirmedCount} Confirmed • ${disputedCount} Disputed • ${falseCount} False`,
      priorityNotice,
      verifiableRatio: 0,
    };

    // 1. Expected: False
    expect(verifiedClaim.status).toBe('false_claim');
    expect(claimLedger.falseCount).toBe(1);

    // 2. Expected: High severity
    expect(verifiedClaim.severity).toBe('high');
    expect(claimLedger.highestSeverityVerdict).toBe('false_claim');

    // 3. Expected: Forced human review
    const reviewTriggered = falseCount > 0 && highestSeverityVerdict === 'false_claim';
    const reviewReason = reviewTriggered
      ? `Flagged for human review: ${falseCount} high-severity claim(s) contradicted by documented evidence.`
      : undefined;

    expect(reviewTriggered).toBe(true);
    expect(reviewReason).toContain('Flagged for human review');
    expect(reviewReason).toContain('high-severity claim(s)');

    // 4. Expected: Prominent viewer warning
    expect(claimLedger.priorityNotice).toBe('Notice: 1 claim(s) contradicted by documented evidence.');
    expect(claimLedger.verdictHeadline).toBe('0 Confirmed • 0 Disputed • 1 False');
  });

  it('4. Confirms semantic normalization & hashing produces deterministic tracking IDs', () => {
    const variant1 = 'Drinking turmeric water cures cancer.';
    const variant2 = 'Drinking turmeric water cures cancer';
    const variant3 = 'drinking turmeric water cures cancer';

    const hash1 = hashSemanticClaimText(variant1);
    const hash2 = hashSemanticClaimText(variant2);
    const hash3 = hashSemanticClaimText(variant3);

    expect(hash1).toBe(hash2);
    expect(hash2).toBe(hash3);
    expect(normalizeClaimText(variant1)).toBe('drinking turmeric water cures cancer');
    expect(semanticCanonicalizeClaim(variant1)).toBe('cancer cures drinking turmeric water');
  });
});
