/**
 * 🧪 UNIT TEST: CLAIM CLUSTERING SERVICE (TRUTHWORLD PHASE 1 OPTIMIZATION)
 *
 * Verifies:
 * 1. Thematic clustering groups claims sharing entities/topics into batches of <= 4.
 * 2. Cross-domain claims (Health vs War vs Economics) are never mixed into the same cluster.
 * 3. Amortization ratio: 10 claims with 3 topics yield 3-4 clusters instead of 10 separate queries.
 * 4. Graceful handling of empty arrays, single claims, and disparate claims without shared entities.
 */

import { ClaimClusteringService, extractKeywords, jaccardSimilarity } from "../services/claimClusteringService";
import type { ModernExtractedClaim } from "../services/factExtraction";

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

console.log("\n==================================================================");
console.log("🧩 AUDIT TEST SUITE: INTRA-VIDEO CLAIM CLUSTERING SERVICE");
console.log("==================================================================");

// ----------------------------------------------------------------------
// 1. Keyword Extraction & Similarity
// ----------------------------------------------------------------------
console.log("\n--- [Test 1] Keyword Extraction & Lexical Similarity ---");

const kw1 = extractKeywords("The US consumer price index rose 3.4% in 2024.");
assert(kw1.has("consumer") && kw1.has("price") && kw1.has("index") && kw1.has("2024"), "Extracts significant keywords");
assert(!kw1.has("the") && !kw1.has("in"), "Filters common stopwords");

const kw2 = extractKeywords("Annual inflation rate measured by consumer price index reached 3.4%.");
const sim = jaccardSimilarity(kw1, kw2);
assert(sim > 0.25, `Jaccard similarity captures thematic overlap (sim = ${sim.toFixed(3)})`);

// ----------------------------------------------------------------------
// 2. Thematic Clustering by Entity and Subject Overlap
// ----------------------------------------------------------------------
console.log("\n--- [Test 2] Thematic Clustering with Shared Entities ---");

const testClaims: ModernExtractedClaim[] = [
  // Cluster A: US Inflation / Federal Reserve (Economics)
  {
    claimId: "econ_01",
    speakerId: "A",
    startMs: 1000,
    endMs: 4000,
    verbatimQuote: "US consumer price inflation hit 3.4% last year.",
    normalizedClaim: "US CPI inflation reached 3.4% in 2024.",
    domain: "MACROECONOMICS_FINANCE",
    topicEntities: ["Federal Reserve", "CPI Inflation"],
    requiresVerification: true,
  },
  {
    claimId: "econ_02",
    speakerId: "A",
    startMs: 5000,
    endMs: 8000,
    verbatimQuote: "The Federal Reserve held the benchmark interest rate at 5.25%.",
    normalizedClaim: "The Federal Reserve maintained benchmark interest rates at 5.25%.",
    domain: "MACROECONOMICS_FINANCE",
    topicEntities: ["Federal Reserve", "Interest Rates"],
    requiresVerification: true,
  },
  {
    claimId: "econ_03",
    speakerId: "A",
    startMs: 9000,
    endMs: 12000,
    verbatimQuote: "Core inflation numbers exclude volatile food and energy components.",
    normalizedClaim: "Core CPI inflation excludes food and energy prices.",
    domain: "MACROECONOMICS_FINANCE",
    topicEntities: ["CPI Inflation"],
    requiresVerification: true,
  },

  // Cluster B: Medical / Vaccine Clinical Trial (Health)
  {
    claimId: "med_01",
    speakerId: "B",
    startMs: 14000,
    endMs: 18000,
    verbatimQuote: "The phase 3 clinical trial demonstrated 94% efficacy against hospitalization.",
    normalizedClaim: "The phase 3 trial demonstrated 94% vaccine efficacy.",
    domain: "HEALTH_MEDICAL",
    topicEntities: ["Clinical Trial", "Vaccine"],
    requiresVerification: true,
  },
  {
    claimId: "med_02",
    speakerId: "B",
    startMs: 19000,
    endMs: 23000,
    verbatimQuote: "The trial enrolled 30,000 diverse participants across 12 countries.",
    normalizedClaim: "The clinical trial enrolled 30,000 participants globally.",
    domain: "HEALTH_MEDICAL",
    topicEntities: ["Clinical Trial"],
    requiresVerification: true,
  },

  // Cluster C: Geopolitical Conflict (War)
  {
    claimId: "war_01",
    speakerId: "A",
    startMs: 25000,
    endMs: 29000,
    verbatimQuote: "The UN Security Council passed Resolution 2728 calling for an immediate ceasefire.",
    normalizedClaim: "UN Security Council passed Resolution 2728 demanding a ceasefire.",
    domain: "GEOPOLITICS_WAR",
    topicEntities: ["UN Security Council", "Resolution 2728"],
    requiresVerification: true,
  },
];

const clusters = ClaimClusteringService.clusterClaims(testClaims, { maxClusterSize: 4 });

assert(clusters.length === 3, `Correctly grouped 6 claims into 3 domain/topic clusters (got ${clusters.length})`);

const econCluster = clusters.find((c) => c.domain === "MACROECONOMICS_FINANCE");
assert(econCluster !== undefined && econCluster.claims.length === 3, "All 3 macroeconomics claims grouped into one cohesive cluster");
assert(econCluster?.claims.some((c) => c.claimId === "econ_01") === true, "Econ cluster contains econ_01");
assert(econCluster?.claims.some((c) => c.claimId === "econ_02") === true, "Econ cluster contains econ_02");
assert(econCluster?.claims.some((c) => c.claimId === "econ_03") === true, "Econ cluster contains econ_03");

const medCluster = clusters.find((c) => c.domain === "HEALTH_MEDICAL");
assert(medCluster !== undefined && medCluster.claims.length === 2, "Both medical claims grouped into medical cluster");

const warCluster = clusters.find((c) => c.domain === "GEOPOLITICS_WAR");
assert(warCluster !== undefined && warCluster.claims.length === 1, "Geopolitical claim isolated in its own cluster");

// ----------------------------------------------------------------------
// 3. Cluster Slicing & Boundary Enforcement
// ----------------------------------------------------------------------
console.log("\n--- [Test 3] Cluster Size Limits & Edge Cases ---");

const batches = ClaimClusteringService.toBatches(clusters);
assert(batches.length === 3, "toBatches returns batch array for adjudication");
assert(batches.every((b) => b.length <= 4), "Every batch strictly obeys maxClusterSize <= 4");

const emptyClusters = ClaimClusteringService.clusterClaims([]);
assert(emptyClusters.length === 0, "Handles empty claims array without error");

const singleClaimCluster = ClaimClusteringService.clusterClaims([testClaims[0]]);
assert(singleClaimCluster.length === 1 && singleClaimCluster[0].claims.length === 1, "Handles single claim correctly");

// ----------------------------------------------------------------------
// 4. Verification of Search Grounding Amortization Potential
// ----------------------------------------------------------------------
console.log("\n--- [Test 4] Financial Amortization Calculation ---");
const unclusteredQueryCost = testClaims.length * 0.014; // $0.084
const clusteredQueryCost = clusters.length * 0.014;   // $0.042
const savingsPercent = ((unclusteredQueryCost - clusteredQueryCost) / unclusteredQueryCost) * 100;

assert(clusteredQueryCost < unclusteredQueryCost, `Clustered grounding cost ($${clusteredQueryCost.toFixed(3)}) is lower than unclustered ($${unclusteredQueryCost.toFixed(3)})`);
assert(savingsPercent === 50, `Grounding cost slashed by ${savingsPercent}% on this video`);

console.log("\n==================================================================");
console.log(`TEST RESULTS: ${passed} PASSED | ${failed} FAILED`);
console.log("==================================================================\n");

if (failed > 0) {
  process.exit(1);
}
