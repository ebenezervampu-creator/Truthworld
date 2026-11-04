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

  // Test 1: Starter Tier 10 minutes (600s), 1 language = $0.50
  const starter10m = calculateSubtitleCost(1, 600, "standard", 0, "starter");
  assert(starter10m === 0.50, `Starter 10m 1 language is $0.50 (got $${starter10m})`);

  // Test 2: Pro Tier 10 minutes (600s), 1 language = $0.75
  const pro10m = calculateSubtitleCost(1, 600, "standard", 0, "pro");
  assert(pro10m === 0.75, `Pro 10m 1 language is $0.75 (got $${pro10m})`);

  // Test 3: Starter Tier 10 minutes, 2 languages (1 add-on at +$0.20) = $0.70
  const starter10m2Langs = calculateSubtitleCost(2, 600, "standard", 0, "starter");
  assert(starter10m2Langs === 0.70, `Starter 10m 2 languages is $0.70 (got $${starter10m2Langs})`);

  // Test 4: Pro Tier 10 minutes, 2 languages (1 add-on at +$0.30) = $1.05
  const pro10m2Langs = calculateSubtitleCost(2, 600, "standard", 0, "pro");
  assert(pro10m2Langs === 1.05, `Pro 10m 2 languages is $1.05 (got $${pro10m2Langs})`);

  // Test 5: Rate Cards & Flat Price per language Check
  const flatStarter = getFlatSubtitlePricePerLanguage(600, "standard", "starter");
  assert(flatStarter === 0.50, `Flat Starter 600s is $0.50 (got $${flatStarter})`);

  const flatPro = getFlatSubtitlePricePerLanguage(600, "standard", "pro");
  assert(flatPro === 0.75, `Flat Pro 600s is $0.75 (got $${flatPro})`);

  assert(SUBTITLE_TIERS.starter.basePrice10MinUSD === 0.50, "SUBTITLE_TIERS.starter is $0.50");
  assert(SUBTITLE_TIERS.pro.basePrice10MinUSD === 0.75, "SUBTITLE_TIERS.pro is $0.75");
  assert(SUBTITLE_TIERS.starter.additionalLang10MinUSD === 0.20, "Starter add-on is $0.20");
  assert(SUBTITLE_TIERS.pro.additionalLang10MinUSD === 0.30, "Pro add-on is $0.30");

  console.log(`\nResults: ${passed} passed, ${failed} failed.\n`);
  if (failed > 0) process.exit(1);
}

testSubtitlePricing();
