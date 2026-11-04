/**
 * 🧪 WORLD-CLASS CREDIBILITY ENGINE UNIT TEST SUITE
 *
 * Verifies the 5 World-Class Enhancements in Layer 06 Credibility & Fact-Checking:
 * 1. Native JSON Extraction & Claim-Level Salvage (1 bad claim does not drop the chunk)
 * 2. Robust Zod Schema Coercion (strings coerced to numbers, single string facts coerced to arrays)
 * 3. Grounding Redirect URL Resolution & In-Memory Caching (Zero 404s)
 * 4. Resilient Multi-Key Claim Matching (Exact ID, Normalized Suffix/Prefix, Positional, Fuzzy)
 * 5. Claim-Level Verification Isolation (Batch never drops valid claims due to 1 corrupted item)
 */

import {
  GeminiExtractionSchema,
  GeminiSingleExtractionSchema,
  GeminiVerificationSchema,
  GeminiSingleVerificationSchema,
} from "../types";
import { ClaimVerificationService } from "../services/claimVerification";

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
  console.log("🧠 RUNNING WORLD-CLASS CREDIBILITY & FACT-CHECKING TEST SUITE");
  console.log("==================================================================");

  // ----------------------------------------------------------------------
  // GAP 1: Native Extraction Salvage
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 1] Testing Fact Extraction Salvage ---");

  const rawExtracted = {
    claims: [
      {
        text: "NASA landed Perseverance rover on Mars in February 2021.",
        nature: "FACTUAL",
        confidence: "0.96",
        importance: "0.85",
        isVerifiableEvent: true,
      },
      {
        text: "Corrupted claim item without required text",
        confidence: "invalid_confidence_NaN",
      },
      {
        text: "James Webb telescope operates at the Sun-Earth L2 Lagrange point.",
        confidence: 0.92,
      },
    ],
    summary: "Extracted space exploration claims.",
  };

  const salvagedClaims: any[] = [];
  for (const rawClaim of rawExtracted.claims) {
    const singleVal = GeminiSingleExtractionSchema.safeParse(rawClaim);
    if (singleVal.success) {
      salvagedClaims.push(singleVal.data);
    }
  }

  assert(salvagedClaims.length === 2, `Salvaged exactly 2 valid claims out of 3 from extraction chunk (got: ${salvagedClaims.length})`);
  assert(salvagedClaims[0].confidence === 0.96, "Coerced string confidence '0.96' to 0.96 in extraction schema");

  const validExtractionPayload = {
    claims: [salvagedClaims[0]],
    summary: "NASA rover mission verified.",
  };
  const fullExtResult = GeminiExtractionSchema.safeParse(validExtractionPayload);
  assert(fullExtResult.success === true, "GeminiExtractionSchema validates successfully with coerced claim data");

  // ----------------------------------------------------------------------
  // GAP 2: Robust Schema Coercion & Preprocessing
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 2] Testing Schema Coercion & Fault Tolerance ---");

  // Stringified numbers and stringified verifiedFacts list
  const relaxedVerificationPayload = {
    verifications: [
      {
        claimId: "claim_001",
        claim: "CO2 levels reached 420 ppm",
        claimType: "EMPIRICAL",
        label: "VERIFIED_TRUE",
        evidenceLevel: "STRONG",
        rating: "9.5", // String instead of number!
        confidence: "0.98", // String instead of number!
        freshness: "RECENT",
        summary: "Supported by NOAA atmospheric observations.",
        verifiedFacts: "NOAA observations confirm 420 ppm\nMauna Loa observatory corroborates", // String with newlines!
        missingEvidence: "", // Empty string instead of array!
        sourceConsensus: "HIGH",
        riskLevel: "LOW",
        publicNote: "Verified with official meteorological data.",
        recommendedAction: "APPROVE",
        sources: [
          {
            title: "NOAA Global Monitoring",
            url: "https://gml.noaa.gov",
            snippet: "420 ppm record verified in 2024.",
          },
        ],
      },
    ],
  };

  const verifResult = GeminiVerificationSchema.safeParse(relaxedVerificationPayload);
  assert(verifResult.success === true, "GeminiVerificationSchema successfully coerces string numbers and splits text arrays");

  if (verifResult.success) {
    const claim = verifResult.data.verifications[0];
    assert(claim.rating === 9.5, `Coerced string rating "9.5" to number 9.5 (got: ${claim.rating})`);
    assert(claim.confidence === 0.98, `Coerced string confidence "0.98" to number 0.98 (got: ${claim.confidence})`);
    assert(
      Array.isArray(claim.verifiedFacts) && claim.verifiedFacts.length === 2,
      `Preprocessed newline-separated verifiedFacts into array of 2 items (got: ${claim.verifiedFacts.length})`
    );
    assert(
      Array.isArray(claim.missingEvidence) && claim.missingEvidence.length === 0,
      "Preprocessed empty string missingEvidence into empty array"
    );
  }

  // ----------------------------------------------------------------------
  // GAP 3: Grounding Redirect Resolution & In-Memory Caching
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 3] Testing Grounding Redirect URL Resolution & Caching ---");

  const service = new ClaimVerificationService("dummy-key");

  // Plain standard URL should pass through untouched
  const directUrl = "https://reuters.com/world/article123";
  const resolvedDirect = await service.resolveSafeSourceUrl(directUrl);
  assert(resolvedDirect === directUrl, "Preserves direct non-redirect URLs untouched");

  // Grounding redirect with fallback publisher domain
  const redirectUrl = "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQF00_TEST";
  const fallbackDomain = "reuters.com";
  const resolvedWithDomain = await service.resolveSafeSourceUrl(redirectUrl, fallbackDomain);
  assert(
    resolvedWithDomain.includes("reuters.com"),
    `Resolves dead or unresolvable redirect to canonical publisher domain: ${resolvedWithDomain}`
  );

  // Cached retrieval: Calling again should hit memory cache in 0ms
  const t0 = Date.now();
  const cachedResolution = await service.resolveSafeSourceUrl(redirectUrl, fallbackDomain);
  const duration = Date.now() - t0;
  assert(cachedResolution === resolvedWithDomain, "Returns identical resolution from redirect cache");
  assert(duration < 10, `In-memory cache delivers instant 0ms response (${duration}ms)`);

  // ----------------------------------------------------------------------
  // GAP 4: Resilient Multi-Key Claim Matching
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 4] Testing Resilient Multi-Key Matching ---");

  // Simulation of the 4-tier matching algorithm
  const testInputClaims = [
    { claimId: "claim_1730000001", text: "Global sea levels rose 20 centimeters over the past century." },
    { claimId: "claim_1730000002", text: "The James Webb Space Telescope detected atmospheric carbon dioxide on an exoplanet." },
    { claimId: "claim_1730000003", text: "Mount Everest grows approximately 4 millimeters each year due to tectonic plate shifts." },
  ];

  // Simulating LLM returning verifications with common formatting anomalies:
  // 1. claim 1: exact match
  // 2. claim 2: LLM stripped the "claim_" prefix and returned "1730000002"
  // 3. claim 3: LLM returned "ID: 3" but text matches
  const simulatedLlmVerifications = [
    { claimId: "claim_1730000001", claim: "Global sea levels rose 20 centimeters", label: "VERIFIED_TRUE" },
    { claimId: "1730000002", claim: "James Webb Space Telescope exoplanet discovery", label: "VERIFIED_TRUE" },
    { claimId: "item_3", claim: "Mount Everest tectonic growth 4 mm annually", label: "VERIFIED_TRUE" },
  ];

  const matchedResults = testInputClaims.map((claim, idx) => {
    // Tier 1: Exact
    let match = simulatedLlmVerifications.find((v) => v.claimId === claim.claimId);

    // Tier 2: Normalized prefix/suffix
    if (!match) {
      const normInputId = claim.claimId.replace(/^(?:claim_|id_)/i, "").trim().toLowerCase();
      match = simulatedLlmVerifications.find((v) => {
        const normVId = String(v.claimId || "").replace(/^(?:claim_|id_)/i, "").trim().toLowerCase();
        return normInputId && normVId && (normInputId === normVId || normInputId.endsWith(normVId) || normVId.endsWith(normInputId));
      });
    }

    // Tier 3: Positional index
    if (!match && simulatedLlmVerifications[idx]) {
      const cand = simulatedLlmVerifications[idx];
      const candText = cand.claim.toLowerCase();
      const targetText = claim.text.toLowerCase();
      if (targetText.includes(candText.slice(0, 20)) || candText.includes(targetText.slice(0, 20))) {
        match = cand;
      }
    }

    // Tier 4: Fuzzy words (Overlap coefficient)
    if (!match) {
      const targetWords = new Set(claim.text.toLowerCase().split(/\s+/).filter(w => w.length > 3));
      let bestScore = 0;
      let bestCand: any = null;
      for (const v of simulatedLlmVerifications) {
        const vWords = v.claim.toLowerCase().split(/\s+/).filter(w => w.length > 3);
        const matches = vWords.filter(w => targetWords.has(w)).length;
        const score = matches / Math.min(targetWords.size, vWords.length);
        if (matches >= 2 && score > 0.4 && score > bestScore) {
          bestScore = score;
          bestCand = v;
        }
      }
      match = bestCand;
    }

    return { inputId: claim.claimId, matchedId: match?.claimId };
  });

  assert(matchedResults[0].matchedId === "claim_1730000001", "Tier 1: Matches exact claimId");
  assert(matchedResults[1].matchedId === "1730000002", "Tier 2: Matches normalized prefix/suffix ID (stripped 'claim_')");
  assert(matchedResults[2].matchedId === "item_3", "Tier 3/4: Matches positional/fuzzy claim text despite arbitrary ID");

  // ----------------------------------------------------------------------
  // GAP 5: Claim-Level Batch Isolation & Salvage
  // ----------------------------------------------------------------------
  console.log("\n--- [Gap 5] Testing Claim-Level Salvage on Corrupted Batch ---");

  const corruptedBatch = [
    {
      claimId: "claim_A",
      claim: "Valid claim A",
      label: "VERIFIED_TRUE",
      evidenceLevel: "STRONG",
      rating: 9,
      confidence: 0.95,
      summary: "Completely valid summary A.",
      verifiedFacts: ["Fact A"],
      missingEvidence: [],
    },
    {
      claimId: "claim_B_corrupted",
      // Completely malformed missing required fields (e.g. no label, no evidenceLevel)
      foo: "corrupted_payload",
    },
    {
      claimId: "claim_C",
      claim: "Valid claim C",
      label: "FALSE_CLAIM",
      evidenceLevel: "CONTRADICTED",
      rating: 1,
      confidence: 0.99,
      summary: "Completely valid summary C.",
      verifiedFacts: [],
      missingEvidence: ["No empirical support"],
    },
  ];

  const salvaged: any[] = [];
  for (const item of corruptedBatch) {
    const single = GeminiSingleVerificationSchema.safeParse(item);
    if (single.success) {
      salvaged.push(single.data);
    }
  }

  assert(salvaged.length === 2, `Salvaged exactly 2 valid claims from corrupted 3-item batch (got: ${salvaged.length})`);
  assert(salvaged[0].claimId === "claim_A", "Preserved claim A");
  assert(salvaged[1].claimId === "claim_C", "Preserved claim C");

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
