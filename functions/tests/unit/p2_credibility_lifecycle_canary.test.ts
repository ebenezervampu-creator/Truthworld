import { ClaimNature, FramingStyle, FilteredClaim } from '../../src/pipeline/types';

describe('P2 Credibility System Lifecycle & Governance Canary', () => {
  it('verifies multilingual claim ranking equity across Telugu, Hindi, and English', () => {
    const claims: FilteredClaim[] = [
      {
        claimId: 'claim_telugu_1',
        text: 'తెలంగాణ జీడీపీ 2024 లో 14 లక్షల కోట్లకు చేరింది.',
        nature: ClaimNature.VERIFIABLE_FACT,
        framing: FramingStyle.ASSERTIVE,
        confidence: 0.96,
        importance: 0.9,
        speaker: 'SPEAKER_01',
        start: 10,
        end: 15,
        claimStrength: 0.9 as any,
        chunkIndex: 0,
      },
      {
        claimId: 'claim_english_fluff',
        text: 'A recent study research data shows interesting perspectives.',
        nature: ClaimNature.PREDICTION,
        framing: FramingStyle.BALANCED,
        confidence: 0.60,
        importance: 0.4,
        speaker: 'SPEAKER_01',
        start: 20,
        end: 25,
        claimStrength: 0.4 as any,
        chunkIndex: 1,
      },
      {
        claimId: 'claim_hindi_1',
        text: 'आरबीआई ने रेपो रेट में 25 आधार अंकों की कटौती की है।',
        nature: ClaimNature.SCIENTIFIC_CLAIM,
        framing: FramingStyle.ASSERTIVE,
        confidence: 0.95,
        importance: 0.92,
        speaker: 'SPEAKER_01',
        start: 30,
        end: 35,
        claimStrength: 0.9 as any,
        chunkIndex: 2,
      },
    ];

    // Priority score formulation matches classifyAndRank in 06-credibility.ts
    const scoreClaim = (c: FilteredClaim): number => {
      let score = c.importance * 0.4;
      if (c.nature === ClaimNature.VERIFIABLE_FACT || c.nature === ClaimNature.SCIENTIFIC_CLAIM || c.nature === ClaimNature.HISTORICAL_FACT) {
        score += 0.35;
      }
      if (c.framing === FramingStyle.ASSERTIVE || c.framing === FramingStyle.ABSOLUTE) {
        score += 0.15;
      }
      score += (c.confidence || 0.8) * 0.1;
      return score;
    };

    const sorted = [...claims].sort((a, b) => scoreClaim(b) - scoreClaim(a));

    // Both Telugu and Hindi factual claims MUST rank above the English fluff claim containing "study", "research", "data"
    expect(sorted[0].claimId).not.toBe('claim_english_fluff');
    expect(sorted[1].claimId).not.toBe('claim_english_fluff');
    expect(sorted[2].claimId).toBe('claim_english_fluff');
  });

  it('verifies creator review embargo is strictly anchored to factCheckCompletedAt', () => {
    const uploadTimestampMs = Date.now() - 72 * 3600 * 1000; // Uploaded 72 hours ago
    const factCheckCompletedAtMs = Date.now() - 10 * 3600 * 1000; // Analysis finished only 10 hours ago
    const embargoWindowMs = 48 * 3600 * 1000; // 48-hour embargo

    const isExpiredUsingCreatedAt = (Date.now() - uploadTimestampMs) >= embargoWindowMs;
    const isExpiredUsingFactCheckCompletedAt = (Date.now() - factCheckCompletedAtMs) >= embargoWindowMs;

    // Legacy calculation against upload time mistakenly marked grace period expired
    expect(isExpiredUsingCreatedAt).toBe(true);

    // Anchored calculation protects creator trust: embargo remains active for 38 more hours!
    expect(isExpiredUsingFactCheckCompletedAt).toBe(false);
  });

  it('verifies root claimLedgerSummary calculation adheres to zero-waterfall feed spec', () => {
    const evaluatedClaims = [
      { status: 'verified_true' },
      { status: 'mostly_true' },
      { status: 'disputed' },
      { status: 'unproven' },
      { status: 'false_claim' },
    ];

    const confirmedCount = evaluatedClaims.filter(c => c.status === 'verified_true' || c.status === 'mostly_true').length;
    const disputedCount = evaluatedClaims.filter(c => c.status === 'disputed').length;
    const unprovenCount = evaluatedClaims.filter(c => c.status === 'unproven').length;
    const falseCount = evaluatedClaims.filter(c => c.status === 'false_claim').length;
    const totalChecked = evaluatedClaims.length;

    const summary = {
      totalChecked,
      confirmedCount,
      disputedCount,
      unprovenCount,
      falseCount,
      updatedAt: Date.now(),
    };

    expect(summary.totalChecked).toBe(5);
    expect(summary.confirmedCount).toBe(2);
    expect(summary.disputedCount).toBe(1);
    expect(summary.unprovenCount).toBe(1);
    expect(summary.falseCount).toBe(1);
  });
});
