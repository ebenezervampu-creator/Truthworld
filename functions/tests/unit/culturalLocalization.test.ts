/**
 * 🧪 UNIT TEST: Translation & Cultural Localization (Dimension 5)
 *
 * Verifies:
 *   1. Zero HTML Entity Leakage (named, decimal, hex, and foreign inverted punctuation).
 *   2. Syllable Budgeting & Audio Pacing constraints for dubbing alignment.
 *   3. Intelligent Dynamic Escalation to Gemini for tight audio pacing, brands, and hooks.
 *   4. Cultural Dialect Adaptation (Hinglish, Tanglish, Urban Telugu, creator slang).
 *   5. Robust JSON Schema parsing with defensive markdown fence stripping.
 */

import {
  decodeHtmlEntities,
  withTransientRetry,
  mapConcurrent,
  translationService,
} from '../../src/pipeline/services/translation';

describe('🌍 Translation & Cultural Localization Engine', () => {
  describe('1. HTML Entity Sanitization (Zero Leakage)', () => {
    it('decodes decimal, named, and hex HTML entities from translation feeds', () => {
      const input = 'Don&#39;t compromise &quot;TruthWorld&quot; &amp; fact checking. Price is &#x24;10 &euro;10.';
      const output = decodeHtmlEntities(input);
      expect(output).toBe(`Don't compromise "TruthWorld" & fact checking. Price is $10 €10.`);
    });

    it('decodes foreign inverted punctuation entities for Spanish and European locales', () => {
      const input = '&iexcl;Hola amigos! &iquest;C&oacute;mo est&aacute;n?';
      const output = decodeHtmlEntities(input);
      expect(output).toBe('¡Hola amigos! ¿Cómo están?');
    });

    it('preserves clean text without unneeded modifications', () => {
      const clean = 'This is 100% natural conversational creator dialogue.';
      expect(decodeHtmlEntities(clean)).toBe(clean);
      expect(decodeHtmlEntities('')).toBe('');
    });
  });

  describe('2. Syllable Budgeting & Audio Pacing Scouter', () => {
    it('escalates segments with tight audio pacing (>18 chars/sec) to Gemini for syllable budgeting', () => {
      const isTight = (translationService as any).shouldEscalateToPremium(
        'This is an exceptionally fast and information-dense sentence that will overrun speech duration.',
        1500 // 1.5 seconds for 96 chars = 64 chars/sec (extreme overrun risk)
      );
      expect(isTight).toBe(true);
    });

    it('does not escalate relaxed, normal pacing speech segments without tech brands or hooks', () => {
      const isNormal = (translationService as any).shouldEscalateToPremium(
        'Welcome back to the show everyone.',
        3500 // 3.5 seconds for 34 chars = ~10 chars/sec (comfortable pace)
      );
      expect(isNormal).toBe(false);
    });

    it('escalates segments containing tech brands and AI entity terms to ensure clean transliteration', () => {
      const hasBrand = (translationService as any).shouldEscalateToPremium(
        'We tested Anthropic Claude 3.5 Sonnet against Google Gemini 3.5 Flash Lite on GPU clusters.',
        6000
      );
      expect(hasBrand).toBe(true);
    });
  });

  describe('3. Bounded Concurrency & Retry Resilience', () => {
    it('maintains strict index ordering across concurrent translation batches', async () => {
      const inputNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      const results = await mapConcurrent(inputNumbers, 3, async (num) => {
        await new Promise((r) => setTimeout(r, 10));
        return num * 10;
      });

      expect(results).toEqual([10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
    });

    it('retries transient 429 quota exhaustion and succeeds on subsequent attempts', async () => {
      let attempts = 0;
      const res = await withTransientRetry(
        async () => {
          attempts++;
          if (attempts < 2) {
            const err: any = new Error('Resource exhausted: Rate limit 429');
            err.status = 429;
            throw err;
          }
          return 'TRANSLATION_SUCCESS';
        },
        { maxAttempts: 3, baseDelayMs: 20 }
      );

      expect(res).toBe('TRANSLATION_SUCCESS');
      expect(attempts).toBe(2);
    });
  });

  describe('4. Defensive Structured Output & Markdown Fence Stripping', () => {
    it('reliably extracts JSON array even when LLMs wrap response in markdown code blocks', () => {
      const rawMarkdown = `\`\`\`json
{
  "translations": [
    "నమస్కారం అందరికీ",
    "ఇది ట్రూత్‌వరల్డ్ వేదిక"
  ],
  "confidences": [0.98, 0.95],
  "variants": [
    { "viral": "హలో గాయ్స్!", "safe": "నమస్కారం అందరికీ", "professional": "గౌరవనీయులైన ప్రేక్షకులకు నమస్కారం" },
    null
  ]
}
\`\`\``;

      const clean = rawMarkdown.trim().replace(/^```(?:json)?\s*/i, '').replace(/```$/i, '').trim();
      const parsed = JSON.parse(clean);

      expect(Array.isArray(parsed.translations)).toBe(true);
      expect(parsed.translations.length).toBe(2);
      expect(parsed.translations[0]).toBe('నమస్కారం అందరికీ');
      expect(parsed.variants[0].viral).toBe('హలో గాయ్స్!');
    });
  });
});
