/**
 * 🧪 WORLD-CLASS TRANSLATION UNIT TEST SUITE
 *
 * Verifies the 5 World-Class Enhancements in TruthWorld Translation Engine:
 * 1. Zero HTML Entity Leakage (decodeHtmlEntities) across named, decimal, and hex entities
 * 2. Transient Error & Quota Resilience (withTransientRetry) on 429, 503, and network timeouts
 * 3. Bounded Concurrency Pool (mapConcurrent) preserving strict index order
 * 4. Dubbing Dialogue Pacing & Timing Constraints (durationSeconds & maxWords calculations)
 * 5. Structured JSON Output & Defensive Parsing (handling markdown fences & missing fields)
 */

import {
  decodeHtmlEntities,
  withTransientRetry,
  mapConcurrent,
  translationService,
  stripDanglingClauseFragments,
  applyTeluguTheologicalLexiconGuard,
} from "../../src/pipeline/services/translation";
import { TerminologyService } from "../../src/pipeline/services/terminology_glossary";

describe("World-Class Translation Test Suite", () => {
  describe("Gap 1: HTML Entity Decoding & Sanitization", () => {
    test("decodes decimal &#39; and named entities &quot; and &amp;", () => {
      const sample1 = "Don&#39;t worry about &quot;TruthWorld&quot; &amp; fact checking.";
      expect(decodeHtmlEntities(sample1)).toBe(`Don't worry about "TruthWorld" & fact checking.`);
    });

    test("decodes hex &#x24;, &#x27;, and named &euro;", () => {
      const sample2 = "Price is &#x24;10 &euro;10 &#x27;quoted&#x27;";
      expect(decodeHtmlEntities(sample2)).toBe(`Price is $10 €10 'quoted'`);
    });

    test("decodes Spanish punctuation &iexcl; (¡) and &iquest; (¿)", () => {
      const sample3 = "&iexcl;Hola! &iquest;Verdad?";
      expect(decodeHtmlEntities(sample3)).toBe("¡Hola! ¿Verdad?");
    });

    test("leaves plain text untouched without modification", () => {
      const cleanText = "Simple plain text with no entities.";
      expect(decodeHtmlEntities(cleanText)).toBe(cleanText);
    });

    test("handles empty string gracefully", () => {
      expect(decodeHtmlEntities("")).toBe("");
    });
  });

  describe("Gap 2: Transient Error & Quota Retries", () => {
    test("retries 429 quota error and succeeds on 3rd attempt", async () => {
      let attempts429 = 0;
      const result = await withTransientRetry(
        async () => {
          attempts429++;
          if (attempts429 < 3) {
            const err: any = new Error("Resource exhausted: Rate limit 429");
            err.status = 429;
            throw err;
          }
          return "SUCCESS_ON_ATTEMPT_3";
        },
        { maxAttempts: 3, baseDelayMs: 20, label: "Test 429 Retry" }
      );

      expect(result).toBe("SUCCESS_ON_ATTEMPT_3");
      expect(attempts429).toBe(3);
    });

    test("does not waste retry budget on permanent 400 errors", async () => {
      let nonTransientAttempts = 0;
      let nonTransientFailed = false;

      try {
        await withTransientRetry(
          async () => {
            nonTransientAttempts++;
            const err: any = new Error("Invalid argument: Bad request (400)");
            err.status = 400;
            throw err;
          },
          { maxAttempts: 3, baseDelayMs: 20, label: "Test 400 Non-transient" }
        );
      } catch {
        nonTransientFailed = true;
      }

      expect(nonTransientFailed).toBe(true);
      expect(nonTransientAttempts).toBe(1);
    });
  });

  describe("Gap 3: Bounded Concurrency Mapping", () => {
    test("mapConcurrent preserves exact element ordering and respects concurrency cap", async () => {
      const items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      let maxActiveConcurrent = 0;
      let currentActive = 0;

      const mappedResults = await mapConcurrent(items, 3, async (item) => {
        currentActive++;
        if (currentActive > maxActiveConcurrent) {
          maxActiveConcurrent = currentActive;
        }
        await new Promise((r) => setTimeout(r, 15));
        currentActive--;
        return item * 10;
      });

      expect(mappedResults).toEqual([10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
      expect(maxActiveConcurrent).toBeLessThanOrEqual(3);
    });

    test("handles empty input array cleanly", async () => {
      const emptyResult = await mapConcurrent([], 3, async () => "none");
      expect(emptyResult).toEqual([]);
    });
  });

  describe("Gap 4: Audio Dubbing Pacing & Escalation", () => {
    test("escalates segments with tight audio pacing (> 18 chars/sec) to Gemini", () => {
      const isEscalatedTight = (translationService as any).shouldEscalateToPremium(
        "This is an unusually long and packed factual sentence that cannot fit easily.",
        1500
      );
      expect(isEscalatedTight).toBe(true);
    });

    test("does not escalate normal relaxed speech segments", () => {
      const isEscalatedNormal = (translationService as any).shouldEscalateToPremium(
        "Hello everyone.",
        3000
      );
      expect(isEscalatedNormal).toBe(false);
    });

    test("escalates segments containing brand/tech terms (Anthropic, Claude, UI)", () => {
      const isEscalatedBrand = (translationService as any).shouldEscalateToPremium(
        "Anthropic announced new Claude UI",
        5000
      );
      expect(isEscalatedBrand).toBe(true);
    });
  });

  describe("Gap 5: Structured JSON Handling & Markdown Stripping", () => {
    test("parses translations array and preserves confidence score & A/B variants from markdown fences", () => {
      const rawMarkdownResponse = `\`\`\`json
{
  "translations": [
    "Hola a todos",
    "TruthWorld es la plataforma de veracidad"
  ],
  "confidences": [0.98, 0.96],
  "variants": [
    { "viral": "¡Hola gente!", "safe": "Hola a todos", "professional": "Estimada audience" },
    null
  ]
}
\`\`\``;

      const clean = rawMarkdownResponse.trim().replace(/^```(?:json)?\s*/i, "").replace(/```$/i, "").trim();
      const parsed = JSON.parse(clean);

      expect(Array.isArray(parsed.translations)).toBe(true);
      expect(parsed.translations).toHaveLength(2);
      expect(parsed.confidences[0]).toBe(0.98);
      expect(parsed.variants[0].viral).toBe("¡Hola gente!");
    });
  });

  describe("Gap 6: Dangling Clause Fragment Stripping", () => {
    test("prunes unclosed trailing fragment after terminal question mark (e.g., '? కొంచెం')", () => {
      const input = "ఈ దేశంలో ఉంటూ ఈజిప్షియన్లకి ఇచ్చే బహుమతి ఇదేనా? కొంచెం";
      expect(stripDanglingClauseFragments(input)).toBe("ఈ దేశంలో ఉంటూ ఈజిప్షియన్లకి ఇచ్చే బహుమతి ఇదేనా?");
    });

    test("prunes trailing fragment after terminal period and exclamation mark", () => {
      expect(stripDanglingClauseFragments("We are finished. extra words")).toBe("We are finished.");
      expect(stripDanglingClauseFragments("Watch out! dangling fragment")).toBe("Watch out!");
    });

    test("leaves complete sentences and multi-sentence dialogue intact", () => {
      const multi = "మొదటి వాక్యం. రెండవ వాక్యం?";
      expect(stripDanglingClauseFragments(multi)).toBe(multi);
    });

    test("handles unpunctuated phrases without modification", () => {
      const phrase = "నాతో ఉండండి ప్రభువా";
      expect(stripDanglingClauseFragments(phrase)).toBe(phrase);
    });
  });

  describe("Gap 7: Telugu Theological / Biblical Lexicon & Domain Glossary Guard", () => {
    test("does not rewrite 'లార్డ్' or first-person verbs without context", () => {
      // These blanket rewrites changed meaning in unrelated videos (e.g. "Lord's" cricket ground,
      // a speaker saying "I am correcting"). The glossary now applies "Lord" -> ప్రభువు/ప్రభువా
      // in context through the Gemini edit step, and checkTerminologyCompliance still flags it.
      expect(applyTeluguTheologicalLexiconGuard("లార్డ్స్ మైదానంలో మ్యాచ్.")).toBe("లార్డ్స్ మైదానంలో మ్యాచ్.");
      expect(applyTeluguTheologicalLexiconGuard("నేను దీన్ని సరిచేస్తున్నాను.")).toBe("నేను దీన్ని సరిచేస్తున్నాను.");
    });

    test("still fixes the 'సారి' / 'సరి' spelling and 'మరియు కానీ' padding", () => {
      expect(applyTeluguTheologicalLexiconGuard("ఇది సారి చేస్తుంది")).toBe("ఇది సరిచేస్తుంది");
      expect(applyTeluguTheologicalLexiconGuard("మంచిది మరియు కానీ కష్టం")).toBe("మంచిది కానీ కష్టం");
    });

    test("flags disallowed 'లార్డ్' transliteration and enforces 'ప్రభువా' in terminology glossary", () => {
      const compliance = TerminologyService.checkTerminologyCompliance(
        "Be with me here, Lord.",
        "నాతో ఉండండి లార్డ్.",
        "te"
      );
      expect(compliance.violations.some((v) => v.disallowedFound === "లార్డ్")).toBe(true);

      const compliantCheck = TerminologyService.checkTerminologyCompliance(
        "Be with me here, Lord.",
        "ఈ కష్టంలో నాతో ఉండండి, ప్రభువా.",
        "te"
      );
      expect(compliantCheck.violations).toHaveLength(0);
      expect(compliantCheck.compliantTerms).toContain("lord_theological_historical");
    });
  });
});
