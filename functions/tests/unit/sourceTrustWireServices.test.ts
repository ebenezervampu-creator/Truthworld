import { sourceTrustService } from '../../src/pipeline/services/sourceTrustService';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { RichSource } from '../../src/pipeline/types';

describe('Unit: Source Trust Wire Services & Real-Time Reporting Fix', () => {
  it('1. Verifies that Gold-Standard Wire Services are Tier A and outrank retrospective Encyclopedias', () => {
    const reuters = sourceTrustService.resolveSourceTrust('https://www.reuters.com/world/breaking-news-missile-strike');
    const apnews = sourceTrustService.resolveSourceTrust('https://apnews.com/article/war-frontline-reporting');
    const afp = sourceTrustService.resolveSourceTrust('https://www.afp.com/en/news/crisis-dispatch');
    const bloomberg = sourceTrustService.resolveSourceTrust('https://www.bloomberg.com/news/articles/market-shock');
    const britannica = sourceTrustService.resolveSourceTrust('https://www.britannica.com/topic/world-war');

    // Premier global wire services must be Tier A (0.98 - 0.99)
    expect(reuters.tier).toBe('A');
    expect(reuters.reputationScore).toBe(0.99);

    expect(apnews.tier).toBe('A');
    expect(apnews.reputationScore).toBe(0.99);

    expect(afp.tier).toBe('A');
    expect(afp.reputationScore).toBe(0.99);

    expect(bloomberg.tier).toBe('A');
    expect(bloomberg.reputationScore).toBe(0.98);

    // Encyclopaedia Britannica is a curated reference encyclopedia (Tier B, 0.92), NOT Tier A
    expect(britannica.tier).toBe('B');
    expect(britannica.reputationScore).toBe(0.92);

    // Wire services strictly outrank encyclopedias for real-time reporting
    expect(reuters.reputationScore).toBeGreaterThan(britannica.reputationScore);
    expect(apnews.reputationScore).toBeGreaterThan(britannica.reputationScore);
  });

  it('2. Verifies publisher resolution maps wire services to Tier A', () => {
    const reutersPub = sourceTrustService.resolvePublisher('https://www.reuters.com/world');
    expect(reutersPub.publisher).toBe('Reuters');
    expect(reutersPub.tier).toBe('A');

    const apPub = sourceTrustService.resolvePublisher('https://apnews.com/hub/world-news');
    expect(apPub.publisher).toBe('AP News');
    expect(apPub.tier).toBe('A');

    const afpPub = sourceTrustService.resolvePublisher('https://www.afp.com/en');
    expect(afpPub.publisher).toBe('AFP');
    expect(afpPub.tier).toBe('A');

    const britannicaPub = sourceTrustService.resolvePublisher('https://www.britannica.com/science');
    expect(britannicaPub.publisher).toBe('Britannica');
    expect(britannicaPub.tier).toBe('B');
  });

  it('3. Verifies that breaking news reported by Reuters provides Tier A evidence level', () => {
    const verificationService = new ClaimVerificationService('test-key', 0.6);

    const reutersSource: RichSource = {
      title: 'Reuters Live Field Dispatch',
      url: 'https://www.reuters.com/world/missile-intercepted-over-airfield',
      domain: 'reuters.com',
      publisher: 'Reuters',
      tier: 'A',
      type: 'primary',
      snippet: 'Reuters correspondents on the ground confirmed the missile strike with photographic evidence.',
      retrievalMethod: 'direct',
      retrievalProvider: 'Reuters Bureau',
      lastVerified: new Date().toISOString()
    };

    const apSource: RichSource = {
      title: 'Associated Press World News',
      url: 'https://apnews.com/article/military-strike-confirmed',
      domain: 'apnews.com',
      publisher: 'Associated Press',
      tier: 'A',
      type: 'primary',
      snippet: 'AP journalists observed the impact site and confirmed the event with local civil defense.',
      retrievalMethod: 'direct',
      retrievalProvider: 'AP News',
      lastVerified: new Date().toISOString()
    };

    const evidence = verificationService.calculateEvidenceLevel([reutersSource, apSource]);
    expect(evidence.status).toBe('complete');
    expect(evidence.summary.tierA).toBe(2);
    expect(evidence.summary.independentPublishers).toBe(2);
    expect(evidence.level).toBe('STRONG');
  });

  it('4. Verifies that Conflict Observation Protocol accepts Tier A wire service proof', async () => {
    const verificationService = new ClaimVerificationService('test-key', 0.6);

    const reutersSource: RichSource = {
      title: 'Reuters Frontline Bureau',
      url: 'https://www.reuters.com/world/conflict-zone-missile-confirmed',
      domain: 'reuters.com',
      publisher: 'Reuters',
      tier: 'A',
      type: 'primary',
      snippet: 'Frontline reporters confirm missile impact at the specified location.',
      retrievalMethod: 'direct',
      retrievalProvider: 'Reuters Bureau',
      lastVerified: new Date().toISOString()
    };

    // When Tier A wire service is present, the war guard does NOT de-escalate to Disputed
    const crossExam = await verificationService.crossExamineClaim(
      'A missile strike hit the airfield in the disputed conflict zone.',
      'verified_true',
      'Confirmed by Reuters correspondents on the ground.',
      [reutersSource],
      'War'
    );

    // It is not forced to disputed unconfirmed because Tier A wire service is accepted
    expect(crossExam.adjudicatedStatus).not.toBe('disputed');
  });
});
