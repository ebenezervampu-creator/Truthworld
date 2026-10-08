import { calculateMaxClaimsForDuration } from "../config";
import assert from "assert";

console.log("=== Testing Epistemic Policy: 'No Claim Left Unchecked' System Ceiling ===");

// 1. Short clips (< 90 seconds, e.g. 45s Shorts/Reels)
const short45s = calculateMaxClaimsForDuration(45, false);
console.log(`45s video -> maxClaims: ${short45s}`);
assert.strictEqual(short45s, 200, "Shorts must allocate full 200 claim capacity to ensure no claims left unchecked");

// 2. 1.5 - 3 minutes video (e.g. 120s / 2m)
const min2 = calculateMaxClaimsForDuration(120, false);
console.log(`2m video -> maxClaims: ${min2}`);
assert.strictEqual(min2, 200, "2m video must allocate full 200 claim capacity");

// 3. 3 - 5 minutes video (e.g. 300s / 5m)
const min5 = calculateMaxClaimsForDuration(300, false);
console.log(`5m video -> maxClaims: ${min5}`);
assert.strictEqual(min5, 200, "5m video must allocate full 200 claim capacity");

// 4. 5 - 10 minutes video (e.g. 600s / 10m)
const min10 = calculateMaxClaimsForDuration(600, false);
console.log(`10m video -> maxClaims: ${min10}`);
assert.strictEqual(min10, 200, "10m video must allocate full 200 claim capacity");

// 5. 10 - 20 minutes video (e.g. 900s / 15m)
const min15 = calculateMaxClaimsForDuration(900, false);
console.log(`15m video -> maxClaims: ${min15}`);
assert.strictEqual(min15, 200, "15m video must allocate full 200 claim capacity");

// 6. Longform > 20 minutes (e.g. 1800s / 30m)
const min30 = calculateMaxClaimsForDuration(1800, false);
console.log(`30m video -> maxClaims: ${min30}`);
assert.strictEqual(min30, 200, "30m video must allocate full 200 claim capacity");

// 7. Deep Research Tier
const min10Deep = calculateMaxClaimsForDuration(600, true);
console.log(`10m Deep Research -> maxClaims: ${min10Deep}`);
assert.strictEqual(min10Deep, 200, "Deep research must allocate full 200 claim capacity");

// 8. Missing / zero duration fallback
const fallback = calculateMaxClaimsForDuration(0, false);
console.log(`0s fallback -> maxClaims: ${fallback}`);
assert.strictEqual(fallback, 200, "Zero duration fallback must allocate full 200 claim capacity");

console.log("✅ All 'No Claim Left Unchecked' claim capacity assertions passed successfully!");

