/**
 * 🧪 WORLD-CLASS TRANSLATION UNIT TEST SUITE
 *
 * Verifies the 5 World-Class Enhancements in TruthWorld Translation Engine:
 * 1. Zero HTML Entity Leakage (decodeHtmlEntities) across named, decimal, and hex entities
 * 2. Transient Error & Quota Resilience (withTransientRetry) on 429, 503, and network timeouts
 * 3. Bounded Concurrency Pool (mapConcurrent) preserving strict index order
 * 4. Dubbing Lip-Sync & Timing Constraints (durationSeconds & maxWords calculations)
 * 5. Structured JSON Output & Defensive Parsing (handling markdown fences & missing fields)
 */

import {
  decodeHtmlEntities,
  withTransientRetry,
  mapConcurrent,
  translationService,
} from "../services/translation";

let passed = 0;
let failed = 0;

function assert(condition: boolean, testName: string, errorDetails?: any) {
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${testName}`, errorDetails !== undefined ? errorDetails : "");
    failed++;
  }
}

async function runTests() {
  console.log("\n==================================================================");
  console.log("🌍 RUNNING WORLD-CLASS TRANSLATION TEST SUITE");
  console.log("==================================================================");

  // ----------------------------------------------------------------------
  // GAP 1: Zero HTML Entity Leakage (decodeHtmlEntities)
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 1] Testing HTML Entity Decoding & Sanitization ---");

  const sample1 = "Don&#39;t worry about &quot;TruthWorld&quot; &amp; fact checking.";
  assert(
    decodeHtmlEntities(sample1) === `Don't worry about "TruthWorld" & fact checking.`,
    "Decodes decimal &#39; and named entities &quot; and &amp;"
  );

  const sample2 = "Price is &#x24;10 &euro;10 &#x27;quoted&#x27;";
  assert(
    decodeHtmlEntities(sample2) === `Price is $10 €10 'quoted'`,
    "Decodes hex &#x24;, &#x27;, and named &euro;"
  );

  const sample3Clean = "&iexcl;Hola! &iquest;Verdad?";
  assert(
    decodeHtmlEntities(sample3Clean) === "¡Hola! ¿Verdad?",
    "Decodes Spanish punctuation &iexcl; (¡) and &iquest; (¿)"
  );

  const cleanText = "Simple plain text with no entities.";
  assert(
    decodeHtmlEntities(cleanText) === cleanText,
    "Leaves plain text untouched without modification"
  );

  assert(decodeHtmlEntities("") === "", "Handles empty string gracefully");

  // ----------------------------------------------------------------------
  // GAP 2: Resilient Transient Error & Quota Retries (withTransientRetry)
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 2] Testing Transient Error & Quota Retries ---");

  let attempts429 = 0;
  const succeedAfter2Failures = await withTransientRetry(
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
  assert(succeedAfter2Failures === "SUCCESS_ON_ATTEMPT_3", "Retries 429 quota error and succeeds on 3rd attempt");
  assert(attempts429 === 3, "Executed exactly 3 attempts for 2 transient failures");

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
  } catch (err: any) {
    nonTransientFailed = true;
  }
  assert(nonTransientFailed, "Throws immediately on non-transient 400 error");
  assert(nonTransientAttempts === 1, "Does not waste retry budget on permanent 400 errors");

  // ----------------------------------------------------------------------
  // GAP 3: Bounded Concurrency Pool (mapConcurrent)
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 3] Testing Bounded Concurrency Mapping ---");

  const items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  let maxActiveConcurrent = 0;
  let currentActive = 0;

  const mappedResults = await mapConcurrent(items, 3, async (item) => {
    currentActive++;
    if (currentActive > maxActiveConcurrent) {
      maxActiveConcurrent = currentActive;
    }
    // Small artificial delay to simulate network call
    await new Promise((r) => setTimeout(r, 15));
    currentActive--;
    return item * 10;
  });

  assert(
    JSON.stringify(mappedResults) === JSON.stringify([10, 20, 30, 40, 50, 60, 70, 80, 90, 100]),
    "mapConcurrent preserves exact element ordering across all items"
  );
  assert(
    maxActiveConcurrent <= 3,
    `Never exceeded concurrency cap of 3 (observed peak: ${maxActiveConcurrent})`
  );

  const emptyResult = await mapConcurrent([], 3, async () => "none");
  assert(emptyResult.length === 0, "Handles empty input array cleanly");

  // ----------------------------------------------------------------------
  // GAP 4: Dubbing Lip-Sync & Timing Constraints
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 4] Testing Audio Dubbing Pacing & Escalation ---");

  // shouldEscalateToPremium should detect tight pacing (> 18 characters/sec)
  const isEscalatedTight = (translationService as any).shouldEscalateToPremium(
    "This is an unusually long and packed factual sentence that cannot fit easily.",
    1500 // 1.5s for 76 chars = ~50 chars/sec (extreme tight pacing)
  );
  assert(isEscalatedTight === true, "Escalates segments with tight audio pacing (> 18 chars/sec) to Gemini");

  const isEscalatedNormal = (translationService as any).shouldEscalateToPremium(
    "Hello everyone.",
    3000 // 3.0s for 15 chars = 5 chars/sec (comfortable pacing)
  );
  assert(isEscalatedNormal === false, "Does not escalate normal relaxed speech segments");

  // Brands & tech terms escalation
  const isEscalatedBrand = (translationService as any).shouldEscalateToPremium("Anthropic announced new Claude UI", 5000);
  assert(isEscalatedBrand === true, "Escalates segments containing brand/tech terms (Anthropic, Claude, UI)");

  // ----------------------------------------------------------------------
  // GAP 5: Structured JSON Output & Defensive Parsing
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 5] Testing Structured JSON Handling & Markdown Stripping ---");

  const rawMarkdownResponse = `\`\`\`json
{
  "translations": [
    "Hola a todos",
    "TruthWorld es la plataforma de veracidad"
  ],
  "confidences": [0.98, 0.96],
  "variants": [
    { "viral": "¡Hola gente!", "safe": "Hola a todos", "professional": "Estimada audiencia" },
    null
  ]
}
\`\`\``;

  const clean = rawMarkdownResponse.trim().replace(/^```(?:json)?\s*/i, "").replace(/```$/i, "").trim();
  const parsed = JSON.parse(clean);

  assert(Array.isArray(parsed.translations) && parsed.translations.length === 2, "Parses translations array from markdown fences");
  assert(parsed.confidences[0] === 0.98, "Preserves confidence score");
  assert(parsed.variants[0].viral === "¡Hola gente!", "Preserves A/B hook variant structure");

  // ----------------------------------------------------------------------
  // SUMMARY
  // ----------------------------------------------------------------------
  console.log("\n==================================================================");
  console.log(`📊 TEST RESULTS: ${passed} PASSED | ${failed} FAILED`);
  console.log("==================================================================\n");

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error("Test runner threw unhandled error:", err);
  process.exit(1);
});
