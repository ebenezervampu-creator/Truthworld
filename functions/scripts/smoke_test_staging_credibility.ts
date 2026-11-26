/**
 * Staging End-to-End Smoke Test: Live Credibility Engine & Pipeline
 *
 * Exercises the Layer 06 Credibility Engine end-to-end against staging services:
 *  - Live Google Search Grounding & URL redirection
 *  - Real URL verification (HTTP 200, paywalls, soft-404s, bot blocks)
 *  - Live Gemini sourceKind & claimStance extraction (up to 12,000 characters)
 *  - Syndication deduplication (Jaccard + 4-gram shingles + wire byline)
 *  - Verdict Gate enforcement (Patch 1 + Patch 2 invariants)
 *
 * Usage:
 *   cd functions
 *   npx ts-node scripts/smoke_test_staging_credibility.ts
 */

import * as dotenv from "dotenv";
import * as path from "path";
import * as admin from "firebase-admin";

// Load test/staging environment variables
dotenv.config({ path: path.resolve(__dirname, "../.env.test") });
dotenv.config({ path: path.resolve(__dirname, "../.env") });

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "truthworld-1",
  });
}
try {
  admin.firestore().settings({ ignoreUndefinedProperties: true });
} catch (_) {}

import { ClaimVerificationService } from "../src/pipeline/services/claimVerification";
import { decidePublicVerdict, applyVerdictGateToClaim } from "../src/pipeline/services/verdictGate";
import { ClaimNature, FramingStyle, FilteredClaim } from "../src/pipeline/types";

interface SmokeTestCase {
  id: string;
  category: string;
  claim: string;
  expectedVerdict: "VERIFIED" | "FALSE" | "CAUTION" | "UNPROVEN" | "OPINION_BELIEF";
  expectedCautionType?: string;
  notes: string;
}

const SMOKE_TEST_CLAIMS: SmokeTestCase[] = [
  {
    id: "SMOKE-01",
    category: "Breaking News / Authoritative Corroboration",
    claim: "Japan Meteorological Agency issued a tsunami warning following a 7.1 magnitude earthquake off Sendai.",
    expectedVerdict: "VERIFIED",
    notes: "Requires >= 1 live Tier A/B source with independent reporting.",
  },
  {
    id: "SMOKE-02",
    category: "Debunked Medical Misinformation",
    claim: "Drinking warm salt water mixed with turmeric completely cures coronavirus in 24 hours.",
    expectedVerdict: "FALSE",
    notes: "Requires authoritative medical sources (WHO, CDC, ICMR) explicitly refuting.",
  },
  {
    id: "SMOKE-03",
    category: "Government Announcement Meta-Claim",
    claim: "Ministry of Education announced new PM-USHA higher education guidelines on its official portal.",
    expectedVerdict: "VERIFIED",
    notes: "Announcement meta-claim exemption: official statement proves the announcement.",
  },
  {
    id: "SMOKE-04",
    category: "Self-Serving Government Empirical Claim",
    claim: "State Transport Department claims operational losses dropped by 95% within 60 days.",
    expectedVerdict: "UNPROVEN",
    notes: "Uncorroborated official press release for empirical statistic cannot verify alone.",
  },
  {
    id: "SMOKE-05",
    category: "Unverified Viral Rumor",
    claim: "A secret subterranean gold mine was discovered under a residential apartment complex in Hyderabad yesterday.",
    expectedVerdict: "UNPROVEN",
    notes: "Should fail closed to UNPROVEN when supported only by unvetted blogs/social posts.",
  },
  {
    id: "SMOKE-06",
    category: "Institutional Suffix Lookalike Defense",
    claim: "World Science Academy on truthnews.ac published proof that gravity fluctuates weekly.",
    expectedVerdict: "UNPROVEN",
    notes: "truthnews.ac must not be treated as Tier B academic; falls back to Tier D unvetted.",
  },
  {
    id: "SMOKE-07",
    category: "Syndicated Wire Story Deduplication",
    claim: "ISRO launched an earth observation satellite into sun-synchronous orbit from Sriharikota.",
    expectedVerdict: "VERIFIED",
    notes: "Wire dispatch (PTI/ANI) syndicated across regional portals must collapse to 1 cluster.",
  },
  {
    id: "SMOKE-08",
    category: "Controversial / Disputed Policy",
    claim: "US Section 301 tariffs on Chinese imports generate an aggregate net positive economic benefit for the United States.",
    expectedVerdict: "CAUTION",
    expectedCautionType: "DISPUTED",
    notes: "Conflicting Tier A/B economic analyses must route to CAUTION (DISPUTED).",
  },
  {
    id: "SMOKE-09",
    category: "Subjective Value Judgment / Opinion",
    claim: "In my opinion, this is the most brilliant cinematic performance of the decade.",
    expectedVerdict: "OPINION_BELIEF",
    notes: "Subjective marker without factual consensus routes to OPINION_BELIEF or fails closed.",
  },
  {
    id: "SMOKE-10",
    category: "Symmetric Government Denial Defense",
    claim: "Municipal corporation denied that toxic lead levels were found in municipal tap water.",
    expectedVerdict: "UNPROVEN",
    notes: "Official denial alone cannot mark claim FALSE without primary water test records.",
  },
];

async function runSmokeTests() {
  const targetFilter = process.argv.slice(2).filter((arg) => !arg.startsWith("-"));
  const testCases = targetFilter.length > 0
    ? SMOKE_TEST_CLAIMS.filter((tc) => targetFilter.includes(tc.id))
    : SMOKE_TEST_CLAIMS;

  console.log("================================================================================");
  console.log("TruthWorld Layer 06 Credibility Engine — Staging E2E Smoke Test");
  console.log(`Executing ${testCases.length} representative claims with live search & adjudicator`);
  console.log("================================================================================\n");

  const apiKey = process.env.GEMINI_API_KEY || process.env.VERTEX_API_KEY || process.env.GOOGLE_API_KEY || "";
  const service = new ClaimVerificationService(apiKey, 0.6);
  let passedCount = 0;
  let failedCount = 0;

  for (const tc of testCases) {
    console.log(`[${tc.id}] Category: ${tc.category}`);
    console.log(`  Claim: "${tc.claim}"`);
    console.log(`  Expected: ${tc.expectedVerdict}${tc.expectedCautionType ? ` (${tc.expectedCautionType})` : ""}`);

    try {
      const startTime = Date.now();
      const inputClaim: FilteredClaim = {
        claimId: tc.id,
        text: tc.claim,
        nature: ClaimNature.VERIFIABLE_FACT,
        framing: FramingStyle.ASSERTIVE,
        confidence: 0.95,
        importance: 0.9,
        chunkIndex: 0,
      };

      const result = await service.verifyClaims(
        [inputClaim],
        1,
        1,
        "General",
        {
          groundingMode: "always",
          forcePro: false,
          minSourcesRequired: 1,
          sourceDiversityRequired: false,
          bypassCache: true,
        }
      );

      const elapsedMs = Date.now() - startTime;
      const adjudicated = result.claims[0];
      if (!adjudicated) {
        console.log(`  Outcome: [WARN] No claim returned in verification result`);
        failedCount++;
        console.log("--------------------------------------------------------------------------------\n");
        continue;
      }

      const gateResult = decidePublicVerdict(adjudicated);
      const gatedClaim = applyVerdictGateToClaim(adjudicated);

      const actualVerdict = gateResult.publicVerdict;
      const actualCautionType = gateResult.cautionType;
      const sourcesCount = adjudicated?.richSources?.length ?? 0;

      console.log(`  Actual: ${actualVerdict}${actualCautionType ? ` (${actualCautionType})` : ""} [Elapsed: ${elapsedMs}ms]`);
      console.log(`  Gated Public Verdict: ${gatedClaim.publicVerdict} | Explanation: "${String(gatedClaim.explanation || "").slice(0, 80)}..."`);
      console.log(`  Pipeline Status: ${adjudicated?.status} | Confidence: ${adjudicated?.verificationConfidence}`);
      console.log(`  Sources: ${sourcesCount} admitted, ${adjudicated?.quarantinedSources?.length ?? 0} quarantined`);
      if (adjudicated?.quarantinedSources && adjudicated.quarantinedSources.length > 0) {
        for (const q of adjudicated.quarantinedSources) {
          const qReason = q.claimStance === "OFF_TOPIC"
            ? (q.claimStanceReason ? `OFF_TOPIC (${q.claimStanceReason})` : "OFF_TOPIC")
            : q.claimStance === "UNREADABLE"
            ? (q.claimStanceReason || "UNREADABLE")
            : ((q as any).urlVerification?.errorReason || (q as any).urlVerification?.status || 'n/a');
          console.log(`    [Quarantined] ${q.url} -> Tier: ${q.tier}, Stance: ${q.claimStance}, Reason: ${qReason}`);
        }
      }
      if (adjudicated?.richSources && adjudicated.richSources.length > 0) {
        for (const s of adjudicated.richSources) {
          console.log(`    [Admitted] ${s.url} -> Tier: ${s.tier}, Kind: ${(s as any).sourceKind}, Stance: ${s.claimStance}`);
        }
      }
      if (gateResult.demoted) {
        console.log(`  Gate Demotion: True (Reason: ${gateResult.reason})`);
      }

      // Check verdict match
      const verdictMatches = actualVerdict === tc.expectedVerdict;
      const cautionMatches = !tc.expectedCautionType || actualCautionType === tc.expectedCautionType;

      if (verdictMatches && cautionMatches) {
        console.log(`  Outcome: [PASS] matches expected epistemic rubric`);
        passedCount++;
      } else {
        console.log(`  Outcome: [WARN / REVIEW] Expected ${tc.expectedVerdict}, got ${actualVerdict}`);
        console.log(`  Notes: ${tc.notes}`);
        failedCount++;
      }
    } catch (err: any) {
      console.error(`  Execution Error:`, err?.message || err);
      failedCount++;
    }
    console.log("--------------------------------------------------------------------------------\n");
  }

  console.log("================================================================================");
  console.log(`Smoke Test Summary: ${passedCount}/${testCases.length} Passed, ${failedCount} Needs Review`);
  console.log("================================================================================");
}

if (require.main === module) {
  runSmokeTests().catch((err) => {
    console.error("Fatal Smoke Test Failure:", err);
    process.exit(1);
  });
}
