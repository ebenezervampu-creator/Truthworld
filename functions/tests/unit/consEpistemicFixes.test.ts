import { sourceTrustService } from '../../src/pipeline/services/sourceTrustService';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';

describe('Unit: Industry Standard Epistemic Guard Fixes (The 5 Cons)', () => {
  const verificationService = new ClaimVerificationService('test-key', 0.6);

  it('1. Anti-Consensus Trap (Galileo / Semmelweis Protocol): Treats novel hypotheses with scientific openness', async () => {
    const novelClaim = 'Preliminary research proposes a novel hypothesis and alternative model for amyloid plaque etiology in neurodegeneration.';
    const crossExam = await verificationService.crossExamineClaim(
      novelClaim,
      'false_claim', // A rigid consensus-only check would mark this false because it's not standard consensus
      'Not currently part of established medical consensus guidelines.',
      [],
      'Medicine'
    );

    // Must be classified as novel_hypothesis, NOT false_claim or consensus denial
    expect(crossExam.adjudicatedStatus).toBe('novel_hypothesis');
    expect(crossExam.consensusMetadata.secondaryVerdict).toBe('NOVEL_HYPOTHESIS');
    expect(crossExam.publicNote).toContain('Novel Empirical Hypothesis');
  });

  it('2. Sarcasm & Hyperbole Blindness: Filters idiomatic figures of speech from literal falsification', async () => {
    const hyperboleClaim = 'My rent is so high I had to sell both my kidneys just to pay the landlord this month.';
    const crossExam = await verificationService.crossExamineClaim(
      hyperboleClaim,
      'false_claim', // Literal LLM would say false: bilateral nephrectomy is fatal
      'Medical science proves humans cannot survive bilateral nephrectomy without continuous dialysis.',
      [],
      'General'
    );

    // Must be de-escalated to satire_claim
    expect(crossExam.adjudicatedStatus).toBe('satire_claim');
    expect(crossExam.consensusMetadata.secondaryVerdict).toBe('SATIRE_CLAIM');
    expect(crossExam.publicNote).toContain('Rhetorical Hyperbole / Figure of Speech');
  });

  it('3. Establishment Authority Perception: Broadens Tier A to Independent OSINT and Non-Profit Investigative Networks', () => {
    const propublica = sourceTrustService.resolveSourceTrust('https://www.propublica.org/article/investigation-report');
    const bellingcat = sourceTrustService.resolveSourceTrust('https://www.bellingcat.com/news/uk-and-europe/geolocation-analysis');
    const icij = sourceTrustService.resolveSourceTrust('https://www.icij.org/investigations/offshore-records');
    const ourworldindata = sourceTrustService.resolveSourceTrust('https://ourworldindata.org/grapher/life-expectancy');
    const archiveOrg = sourceTrustService.resolveSourceTrust('https://web.archive.org/web/20230101000000/https://example.com');

    // All must be recognized as Tier A primary independent evidence
    expect(propublica.tier).toBe('A');
    expect(propublica.reputationScore).toBe(0.98);

    expect(bellingcat.tier).toBe('A');
    expect(bellingcat.reputationScore).toBe(0.97);

    expect(icij.tier).toBe('A');
    expect(icij.reputationScore).toBe(0.98);

    expect(ourworldindata.tier).toBe('A');
    expect(ourworldindata.reputationScore).toBe(0.98);

    expect(archiveOrg.tier).toBe('A');
    expect(archiveOrg.reputationScore).toBe(0.99);
  });

  it('4. Fog of War & Live Event Latency: Differentiates fast-evolving breaking events from dead-end inconclusive', async () => {
    const developingClaim = 'Developing story: Fluid situation with active standoff and unconfirmed casualty reports at the central terminal.';
    const crossExam = await verificationService.crossExamineClaim(
      developingClaim,
      'inconclusive',
      'No final casualty reports have been filed by the county coroner.',
      [],
      'News'
    );

    // Must be classified as developing_story
    expect(crossExam.adjudicatedStatus).toBe('developing_story');
    expect(crossExam.consensusMetadata.secondaryVerdict).toBe('DEVELOPING_STORY');
    expect(crossExam.publicNote).toContain('Live Developing Event');
  });
});
