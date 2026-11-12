/**
 * 🧪 SUBTITLE PRICING & TIER UNIT TESTS
 */

import { calculateSubtitleCost, getFlatSubtitlePricePerLanguage, SUBTITLE_TIERS } from "../services/cost-engine";

function testSubtitlePricing() {
  console.log("\n==================================================================");
  console.log("💰 RUNNING SUBTITLE TIER & PRICING UNIT TEST SUITE");
  console.log("==================================================================");

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, details?: any) {
    if (condition) {
      console.log(`  ✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${testName}`, details ?? "");
      failed++;
    }
  }

  // Test 1: Ultra Tier 10 minutes (600s), 1 language = $0.50
  const ultra10m = calculateSubtitleCost(1, 600, "standard", 0, "ultra");
  assert(ultra10m === 0.50, `Ultra 10m 1 language is $0.50 (got $${ultra10m})`);

  // Test 2: Ultra Tier 10 minutes, 2 languages (1 add-on at +$0.20) = $0.70
  const ultra10m2Langs = calculateSubtitleCost(2, 600, "standard", 0, "ultra");
  assert(ultra10m2Langs === 0.70, `Ultra 10m 2 languages is $0.70 (got $${ultra10m2Langs})`);

  // Test 3: Backward compatibility - starter/pro map to Ultra rate ($0.50 for 10m)
  const legacyStarter10m = calculateSubtitleCost(1, 600, "standard", 0, "starter");
  assert(legacyStarter10m === 0.50, `Legacy starter 10m maps to Ultra $0.50 (got $${legacyStarter10m})`);

  const legacyPro10m = calculateSubtitleCost(1, 600, "standard", 0, "pro");
  assert(legacyPro10m === 0.50, `Legacy pro 10m maps to Ultra $0.50 (got $${legacyPro10m})`);

  // Test 4: Rate Cards & Flat Price per language Check
  const flatUltra = getFlatSubtitlePricePerLanguage(600, "standard", "ultra");
  assert(flatUltra === 0.50, `Flat Ultra 600s is $0.50 (got $${flatUltra})`);

  assert(SUBTITLE_TIERS.ultra.basePrice10MinUSD === 0.50, "SUBTITLE_TIERS.ultra is $0.50");
  assert(SUBTITLE_TIERS.ultra.additionalLang10MinUSD === 0.20, "Ultra add-on is $0.20");

  console.log(`\nResults: ${passed} passed, ${failed} failed.\n`);
  if (failed > 0) process.exit(1);
}

testSubtitlePricing();
