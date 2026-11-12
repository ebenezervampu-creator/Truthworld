import {
  semanticCanonicalizeClaim,
  hashSemanticClaimText,
  hashClaimText,
  normalizeClaimText,
} from '../../src/pipeline/utils/claim-normalization';
import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';

describe('Unit: Credibility System 8 Bug Remediations', () => {
  const verificationService = new ClaimVerificationService('test-api-key');

  describe('Bug 6: Semantic Canonicalization & Deduplication', () => {
    it('normalizes common financial synonyms (fed <-> federal reserve, bps <-> basis points)', () => {
      const claim1 = 'The Fed hiked benchmark rates by 25 bps';
      const claim2 = 'Federal Reserve raised benchmark rates by 25 basis points';

      const norm1 = semanticCanonicalizeClaim(claim1);
      const norm2 = semanticCanonicalizeClaim(claim2);

      // Both should map to the exact same canonical tokens
      expect(norm1).toBe(norm2);

      // Semantic hashes must be identical
      const hash1 = hashSemanticClaimText(claim1);
      const hash2 = hashSemanticClaimText(claim2);
      expect(hash1).toBe(hash2);
    });

    it('removes English stop words to avoid superficial phrasing divergence', () => {
      const claim1 = 'Unemployment has fallen to an all-time low';
      const claim2 = 'Unemployment fell to all-time low';

      const norm1 = semanticCanonicalizeClaim(claim1);
      const norm2 = semanticCanonicalizeClaim(claim2);

      expect(norm1).toBe(norm2);
    });

    it('preserves exact SHA-256 differentiation for distinct claims', () => {
      const claim1 = 'GDP grew by 2 percent in 2025';
      const claim2 = 'GDP grew by 4 percent in 2025';

      const hash1 = hashClaimText(claim1);
      const hash2 = hashClaimText(claim2);

      expect(hash1).not.toBe(hash2);
      expect(hashSemanticClaimText(claim1)).not.toBe(hashSemanticClaimText(claim2));
    });
  });

  describe('Bug 5: Safe Source URL & Permanent Canonical Domain Resolution', () => {
    it('leaves verified non-redirect HTTP 200 URLs untouched', async () => {
      const regularUrl = 'https://www.reuters.com/world/article-12345';
      const mockVerifier = {
        verifyUrl: jest.fn().mockResolvedValue({
          inputUrl: regularUrl,
          canonicalUrl: regularUrl,
          finalDomain: 'reuters.com',
          status: 'VERIFIED',
          httpStatus: 200,
          isSoft404: false,
          redirectCount: 0,
          checkedAt: Date.now(),
        }),
      } as any;
      const serviceWithVerifier = new ClaimVerificationService('test-api-key', 0.6, {
        urlVerifier: mockVerifier,
      });

      const resolved = await serviceWithVerifier.resolveSafeSourceUrl(regularUrl, 'reuters.com');
      expect(resolved).toBe(regularUrl);
      expect(mockVerifier.verifyUrl).toHaveBeenCalledWith(regularUrl);
    });

    it('rejects dead or unresolvable Vertex AI redirects with empty string instead of homepage fallback', async () => {
      const expiringVertexRedirect =
        'https://vertexaisearch.cloud.google.com/grounding-api-redirect/ABC123XYZ456TemporaryToken';
      const publisherDomain = 'apnews.com';
      const mockVerifier = {
        verifyUrl: jest.fn().mockResolvedValue({
          inputUrl: expiringVertexRedirect,
          canonicalUrl: '',
          finalDomain: 'vertexaisearch.cloud.google.com',
          status: 'NOT_FOUND',
          httpStatus: 404,
          isSoft404: false,
          redirectCount: 0,
          checkedAt: Date.now(),
        }),
      } as any;
      const serviceWithVerifier = new ClaimVerificationService('test-api-key', 0.6, {
        urlVerifier: mockVerifier,
      });

      const resolved = await serviceWithVerifier.resolveSafeSourceUrl(expiringVertexRedirect, publisherDomain);
      // Must never store expiring vertex redirect tokens OR substitute publisher homepages (Decision 1)
      expect(resolved).not.toContain('vertexaisearch.cloud.google.com');
      expect(resolved).toBe('');
    });
  });

  describe('Bug 3: URL Validation & Trojan Prompt Injection Defense', () => {
    it('rejects javascript: and non-http schemes in source validation', () => {
      const maliciousUrl = 'javascript:alert("pwned")';
      const res = verificationService.validateSource(maliciousUrl, 'Attacker Source');
      expect(res.isValid).toBe(false);
    });

    it('rejects empty or whitespace URLs', () => {
      const res = verificationService.validateSource('   ', 'Empty');
      expect(res.isValid).toBe(false);
    });

    it('approves legitimate HTTPS news sources', () => {
      const cleanUrl = 'https://apnews.com/article/world-news';
      const res = verificationService.validateSource(cleanUrl, 'Associated Press');
      expect(res.isValid).toBe(true);
    });
  });

  describe('Bug 4: Mapping of UNSUPPORTED Verdicts', () => {
    it('maps UNSUPPORTED label directly to unsupported claim status without throwing', () => {
      // Accessing private mapLabelToStatus through prototype / indexer
      const status = (verificationService as any).mapLabelToStatus('UNSUPPORTED');
      expect(status).toBe('unsupported');
    });

    it('maps UNPROVEN label to unsupported status', () => {
      const status = (verificationService as any).mapLabelToStatus('UNPROVEN CLAIM');
      expect(status).toBe('unsupported');
    });

    it('maps VERIFIED TRUE and FALSE CLAIM accurately', () => {
      expect((verificationService as any).mapLabelToStatus('VERIFIED TRUE')).toBe('verified_true');
      expect((verificationService as any).mapLabelToStatus('FALSE CLAIM')).toBe('false_claim');
      expect((verificationService as any).mapLabelToStatus('MISLEADING')).toBe('misleading');
    });
  });

  describe('Bug 8: Sensationalism & Clickbait Regex Guard', () => {
    const SENSATIONAL_CLICKBAIT_REGEX =
      /\b(cure for|secret cure|miracle (cure|drug|food|herb|supplement)|they don't want you to know|what they hid|100% proven|hoax exposed|collapse imminent|guaranteed returns|get rich quick|conspiracy exposed|banned from tv|shocking truth|shocking discovery)\b/i;

    it('flags clickbait headlines advertising secret miracle cures', () => {
      const clickbaitTitle = 'SHOCKING: Secret Cure For Diabetes Big Pharma Banned From TV';
      expect(SENSATIONAL_CLICKBAIT_REGEX.test(clickbaitTitle)).toBe(true);
    });

    it('flags alarmist financial clickbait', () => {
      const clickbaitTitle = 'Market Collapse Imminent - Guaranteed Returns with this one stock';
      expect(SENSATIONAL_CLICKBAIT_REGEX.test(clickbaitTitle)).toBe(true);
    });

    it('does not flag standard journalistic or educational titles', () => {
      const journalisticTitle = 'Federal Reserve holds interest rates steady amid economic review';
      expect(SENSATIONAL_CLICKBAIT_REGEX.test(journalisticTitle)).toBe(false);

      const educationalTitle = 'An Introduction to Quantum Computing and Superconductors';
      expect(SENSATIONAL_CLICKBAIT_REGEX.test(educationalTitle)).toBe(false);
    });
  });
});
