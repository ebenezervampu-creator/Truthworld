import {
  GeminiExtractionSchema,
  GeminiIntelligenceSchema,
  GeminiVerificationSchema,
} from '../../src/pipeline/types';

describe('Unit: Validators and Data Sanitizers', () => {
  // Production-grade comment / text sanitizer logic
  function sanitizeText(text: string): string {
    return text
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '')
      .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '')
      .replace(/<[^>]*>/g, '')
      .replace(/on\w+="[^"]*"/gi, '')
      .replace(/on\w+='[^']*'/gi, '')
      .replace(/on\w+=\w+/gi, '')
      .replace(/javascript:/gi, 'javascript_blocked:')
      .replace(/data:/gi, 'data_blocked:')
      .replace(/vbscript:/gi, 'vbscript_blocked:')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .trim();
  }

  // Zero charm pricing compliance validator
  function validateHonestPrice(amount: number): boolean {
    if (typeof amount !== 'number' || isNaN(amount) || amount <= 0) return false;
    // Disallow decimals/cents like .99 or .95
    if (!Number.isInteger(amount)) return false;
    // Disallow charm endings like 9, 99, 999, 9999
    const str = amount.toString();
    if (str.endsWith('9')) return false;
    return true;
  }

  describe('Text Sanitization & Anti-XSS Filter', () => {
    it('strips script tags and inner contents', () => {
      const input = 'Hello <script>alert("pwned")</script> World!';
      expect(sanitizeText(input)).toBe('Hello  World!');
    });

    it('strips HTML image tags with malicious onerror handlers', () => {
      const input = '<img src="x" onerror="stealCookies()">Nice video!';
      expect(sanitizeText(input)).toBe('Nice video!');
    });

    it('neutralizes dangerous javascript: URI schemes', () => {
      const input = '<a href="javascript:doSomething()">Link</a>';
      expect(sanitizeText(input)).not.toContain('javascript:');
    });

    it('handles clean user text without corruption', () => {
      const clean = 'This fact-check is accurate and well sourced.';
      expect(sanitizeText(clean)).toBe(clean);
    });
  });

  describe('TruthWorld Epistemic Pricing Rule (Zero Charm Pricing)', () => {
    it('approves honest round numbers ($10, $15, $20, $50, $100)', () => {
      expect(validateHonestPrice(10)).toBe(true);
      expect(validateHonestPrice(15)).toBe(true);
      expect(validateHonestPrice(20)).toBe(true);
      expect(validateHonestPrice(50)).toBe(true);
      expect(validateHonestPrice(100)).toBe(true);
    });

    it('strictly rejects charm pricing and deceptive marketing endings ($9, $9.99, $14.99, $99)', () => {
      expect(validateHonestPrice(9)).toBe(false);
      expect(validateHonestPrice(9.99)).toBe(false);
      expect(validateHonestPrice(14.99)).toBe(false);
      expect(validateHonestPrice(29.99)).toBe(false);
      expect(validateHonestPrice(99)).toBe(false);
      expect(validateHonestPrice(9999)).toBe(false);
    });
  });

  describe('Pipeline Zod Schemas Validation', () => {
    it('validates a valid GeminiExtraction payload', () => {
      const payload = {
        claims: [
          {
            text: 'Global temperatures have risen 1.1 degrees Celsius since the pre-industrial era.',
            nature: 'FACTUAL',
            framing: 'ASSERTIVE',
            confidence: 0.95,
            importance: 0.8,
            isVerifiableEvent: true,
            honestyWashingRisk: false,
          },
        ],
        summary: 'Discussion covering global climate changes.',
      };

      const result = GeminiExtractionSchema.safeParse(payload);
      expect(result.success).toBe(true);
    });

    it('rejects GeminiExtraction payload missing claims array', () => {
      const invalid = {
        summary: 'Only summary, no claims.',
      };
      const result = GeminiExtractionSchema.safeParse(invalid);
      expect(result.success).toBe(false);
    });

    it('validates GeminiIntelligenceSchema', () => {
      const payload = {
        summary: 'A deep-dive investigation into renewable energy systems.',
        conclusion: {
          label: 'VERIFIED',
          text: 'Solar and wind infrastructure expanded significantly.',
          confidence: 0.91,
        },
        keyThemes: ['Energy', 'Economy', 'Climate'],
        viewerNote: 'Independent fact check verified with empirical metrics.',
        chapters: [
          {
            index: 1,
            title: 'Introduction',
            start: 0,
            end: 60,
            primaryTopics: ['Renewable Energy'],
          },
        ],
      };

      const result = GeminiIntelligenceSchema.safeParse(payload);
      expect(result.success).toBe(true);
    });

    it('validates GeminiIntelligenceSchema with conclusion sources and citations', () => {
      const payload = {
        summary: 'A deep-dive investigation into renewable energy systems.',
        conclusion: {
          label: 'VERIFIED',
          text: 'Solar and wind infrastructure expanded significantly across multiple grids.',
          confidence: 0.95,
          sources: [
            {
              title: 'Global Energy Review 2026',
              url: 'https://iea.org/reports/energy-2026',
              domain: 'iea.org',
              trustLevel: 'High',
              snippet: 'Renewables accounted for over 80% of net capacity additions.',
            },
            {
              title: 'Nature Energy Research',
              url: 'https://nature.com/articles/energy123',
              domain: 'nature.com',
              trustLevel: 'High',
              type: 'journal',
            },
          ],
        },
        keyThemes: ['Energy', 'Economy', 'Climate'],
        viewerNote: 'Independent fact check verified with empirical metrics.',
        chapters: [],
      };

      const result = GeminiIntelligenceSchema.safeParse(payload);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.conclusion.sources).toBeDefined();
        expect(result.data.conclusion.sources?.length).toBe(2);
        expect(result.data.conclusion.sources?.[0].title).toBe('Global Energy Review 2026');
        expect(result.data.conclusion.sources?.[0].domain).toBe('iea.org');
        expect(result.data.conclusion.sources?.[1].type).toBe('journal');
      }
    });

    it('validates GeminiVerificationSchema with verifiable claims', () => {
      const payload = {
        verifications: [
          {
            claimId: 'claim_001',
            claim: 'CO2 levels reached 420 ppm',
            claimType: 'EMPIRICAL',
            label: 'TRUE',
            evidenceLevel: 'STRONG',
            rating: 95,
            confidence: 0.98,
            freshness: 'RECENT',
            summary: 'Supported by NOAA atmospheric observations.',
            verifiedFacts: ['Atmospheric CO2 reached 420 ppm'],
            missingEvidence: [],
            sourceConsensus: 'HIGH',
            riskLevel: 'LOW',
            publicNote: 'Verified with official meteorological data.',
            recommendedAction: 'APPROVE',
            sources: [
              {
                sourceUrl: 'https://gml.noaa.gov',
                title: 'NOAA Global Monitoring',
                reliabilityScore: 99,
              },
            ],
          },
        ],
      };

      const result = GeminiVerificationSchema.safeParse(payload);
      expect(result.success).toBe(true);
    });
  });
});
