import { calculateMaxClaimsForDuration } from "../config";
import assert from "assert";

console.log("=== Testing Cost-Optimized Duration-Based Claim Scaling ===");

// 1. Short clips (< 90 seconds, e.g. 45s Shorts/Reels)
const short45s = calculateMaxClaimsForDuration(45, false);
console.log(`45s video -> maxClaims: ${short45s}`);
assert.strictEqual(short45s, 12, `Expected 12 claims for 45s, got ${short45s}`);

// 2. 1.5 - 3 minutes video (e.g. 120s / 2m)
const min2 = calculateMaxClaimsForDuration(120, false);
console.log(`2m video -> maxClaims: ${min2}`);
assert.strictEqual(min2, 20, `Expected 20 claims for 2m, got ${min2}`);

// 3. 3 - 5 minutes video (e.g. 300s / 5m) - must cross legacy 20 claims cap, but stay cost-effective!
const min5 = calculateMaxClaimsForDuration(300, false);
console.log(`5m video -> maxClaims: ${min5}`);
assert.strictEqual(min5, 24, `Expected 24 claims for 5m, got ${min5}`);
assert.ok(min5 > 20, "5m video must exceed legacy 20 claims cap");
assert.ok(min5 <= 28, "5m video must stay under 28 claims to prevent high API expenses");

// 4. 5 - 10 minutes video (e.g. 600s / 10m) - must cross legacy 20 claims cap, but stay cost-effective!
const min10 = calculateMaxClaimsForDuration(600, false);
console.log(`10m video -> maxClaims: ${min10}`);
assert.strictEqual(min10, 30, `Expected 30 claims for 10m, got ${min10}`);
assert.ok(min10 > 20, "10m video must exceed legacy 20 claims cap");
assert.ok(min10 <= 35, "10m video must stay under 35 claims to prevent high API expenses");

// 5. 10 - 20 minutes video (e.g. 900s / 15m)
const min15 = calculateMaxClaimsForDuration(900, false);
console.log(`15m video -> maxClaims: ${min15}`);
assert.strictEqual(min15, 36, `Expected 36 claims for 15m, got ${min15}`);

// 6. Longform > 20 minutes (e.g. 1800s / 30m) - strictly capped at 40
const min30 = calculateMaxClaimsForDuration(1800, false);
console.log(`30m video -> maxClaims: ${min30}`);
assert.strictEqual(min30, 40, `Expected 40 claims for 30m, got ${min30}`);

// 7. Deep Research Tier bonus
const min10Deep = calculateMaxClaimsForDuration(600, true);
console.log(`10m Deep Research -> maxClaims: ${min10Deep}`);
assert.strictEqual(min10Deep, 38, `Expected 38 claims for 10m Deep Research, got ${min10Deep}`);
assert.ok(min10Deep <= 48, "Deep research must remain cost-bounded");

// 8. Missing / zero duration fallback
const fallback = calculateMaxClaimsForDuration(0, false);
console.log(`0s fallback -> maxClaims: ${fallback}`);
assert.strictEqual(fallback, 24, `Expected 24 claims for 0s fallback, got ${fallback}`);

console.log(" All cost-effective duration-based claim scaling assertions passed successfully!");
