/**
 * Regression tests for the credibility audit (2026-11-20), findings #1, #2, #3, #4, #5, #10, and cache stamping.
 *
 * #1  The fast deterministic tiers must rule only on whole sentences they understand and must
 *     compare the stated value with the reference value. Mentioning a topic is not enough.
 * #2  Every verdict written to the public live list (videos/{id}/claims) goes through the
 *     verdict gate, and the stored report's verdicts replace the streamed ones.
 * #3  Hedged empirical claims ("I think...", "In my opinion...") never bypass fact-checking or Tier 4 grounding.
 * #4  AI Credibility Chat strictly prioritizes authoritative Firestore records over client-sent claims and never trusts client verdicts.
 * #5  Video owners are blocked from writing to /videos/{videoId}/media/credibility in firestore.rules.
 * #10 factCheckStats (correct / incorrect / …) are computed from gated verdicts.
 * Bonus: Cache upsert in Tier-0 resolves real domain/tier and never fabricates fake urlVerification records.
 */
import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import { DeterministicRegistryService } from "../../src/pipeline/services/deterministicRegistry";
import { tier0KnowledgeService } from "../../src/pipeline/services/tier0Knowledge";
import { RegistryService } from "../../src/pipeline/registry/RegistryService";
import { VerificationCascadeService } from "../../src/pipeline/services/verificationCascadeService";
import { StreamingClaimProcessor } from "../../src/pipeline/services/streamingClaimProcessor";
import { FastTrackLlmService } from "../../src/pipeline/services/fastTrackLlmService";
import {
  applyVerdictGateToReport,
  NO_EVIDENCE_MESSAGE,
  recomputeFactCheckStats,
  decidePublicVerdict,
} from "../../src/pipeline/services/verdictGate";

const SRC_DIR = path.resolve(__dirname, "../../src");
const ROOT_DIR = path.resolve(__dirname, "../../../");

const liveSource = (domain: string, tier: string, claimStance = "SUPPORTS") => ({
  title: domain,
  url: `https://${domain}/article`,
  domain,
  tier,
  claimStance,
  urlVerification: {
    status: "VERIFIED",
    httpStatus: 200,
    isSoft404: false,
    originalUrl: `https://${domain}/article`,
    canonicalUrl: `https://${domain}/article`,
    redirectHops: 0,
  },
});

// ── #1 Deterministic tiers ─────────────────────────────────────────────────────

describe("#1 deterministic tiers compare the stated value, not the topic", () => {
  const resolve = (t: string) => DeterministicRegistryService.resolveDeterministicFact(t)?.status ?? null;

  it.each([
    "The capital of India is New Delhi",
    "India's capital is New Delhi",
    "Paris is the capital of France.",
    "The capital of the United States is Washington, D.C.",
    "The speed of light in vacuum is 299,792,458 m/s",
    "The speed of light is about 300,000 km/s",
    "The speed of light is 186,000 miles per second",
    "Water boils at 100°C at sea level",
    "Water boils at 212°F",
    "Water boils at 100°C at standard atmospheric pressure",
    "Water freezes at 0°C",
    "Apollo 11 landed on the moon in 1969",
    "Neil Armstrong walked on the moon in 1969",
    "The United Nations was founded in 1945",
    "Smoking causes lung cancer",
    "Antibiotics don't kill viruses",
    "Earth's atmosphere is 78% nitrogen and 21% oxygen",
    "DNA is a double helix",
    "Smallpox was declared eradicated in 1980",
    "Smallpox was globally eradicated in 1980",
    "India is the most populous country in the world",
    "The most populous country in the world is India",
  ])("verifies the true statement %p", (text) => {
    expect(resolve(text)).toBe("verified_true");
  });

  it.each([
    "The capital of India is Kolkata",
    "The capital of Japan is Kyoto",
    "The speed of light in a vacuum is 100 kilometres per hour",
    "The boiling point of water at sea level is 50 degrees",
    "Water boils at 100°F",
    "Water boils at 100 degrees on Mount Everest",
    "Water freezes at 10 degrees Celsius",
    "Apollo 11 landed on the moon in 1972",
    "The United Nations was founded in 1950",
    "Antibiotics cure the flu",
    "Turmeric water cures cancer",
    "The Earth is flat",
    "Earth's atmosphere is 50% nitrogen",
    "Smallpox was declared eradicated in 1995",
    "China is the most populous country in the world",
    "The United States is the most populous country in the world",
  ])("marks the wrong value false: %p", (text) => {
    expect(resolve(text)).toBe("false_claim");
  });

  it.each([
    "Apollo 11 was faked in a studio in 1969",
    "Apollo 11 landed on Mars",
    "Apollo 11 did not land on the moon",
    "Smoking cigarettes prevents heart disease and cancer",
    "Smoking cures cancer",
    "The United Nations was founded in 1945 by Hitler",
    "Antibiotics treat bacterial infections that follow the flu",
    "Turmeric does not cure cancer",
    "The flat earth theory is a myth",
    "The Earth is not flat",
    "Earth is a sphere that orbits the planet Mars",
    "Earth's atmosphere is mostly oxygen",
    "DNA is a triple helix",
    "Delhi is the capital of India",
    "The capital of Australia is the largest city",
    "Water boils at lower temperatures on Mount Everest",
    "The speed of light is constant in every frame",
    "I think the earth is flat",
    "Smallpox was not eradicated",
    "India is not the most populous country",
    "5G towers do not cause viruses",
    "Lemon water does not cure cancer",
    "No central bank treaty bans physical cash",
    "The RBI repo rate is 5.5 percent",
    "The Federal Reserve rate is 4 percent",
    "The RBI repo rate is 6.5 percent in 2019",
    "The United States has emitted less CO2 in total",
    "Global temperature permanently breached 1.5 degrees",
    "Casualty figures in Mariupol reached exactly 300",
    "AGI will eliminate all jobs by 2030",
    "Leaked audio proves the president ordered an illegal strike",
  ])("leaves %p to grounded verification", (text) => {
    expect(resolve(text)).toBeNull();
  });

  it("Tier-0 corpus never verifies a claim that only shares keywords with an entry", () => {
    for (const text of [
      "The boiling point of water at sea level is 50 degrees",
      "The speed of light in a vacuum is 100 kilometres per hour",
      "Apollo 11 was faked in a studio in 1969",
      "Smoking cigarettes prevents heart disease and cancer",
      "The United Nations was founded in 1945 by Hitler",
      "Vaccines cause immune system damage and produce antibodies that harm",
      "The structure of DNA is a triple helix",
      "The flat earth theory is a myth",
    ]) {
      expect(tier0KnowledgeService.lookupPreIndexedFact(text)).toBeNull();
    }
    expect(tier0KnowledgeService.lookupPreIndexedFact("The Earth is flat")?.status).toBe("false_claim");
    expect(tier0KnowledgeService.lookupPreIndexedFact("Apollo 11 landed on the moon in 1969")?.status).toBe("verified_true");
  });

  it("the keyword-only RegistryService.resolveTruthCheck is gone and the cascade no longer uses the registry", () => {
    expect((new RegistryService() as any).resolveTruthCheck).toBeUndefined();
    const cascadeSrc = fs.readFileSync(path.join(SRC_DIR, "pipeline/services/verificationCascadeService.ts"), "utf8");
    expect(cascadeSrc).not.toMatch(/registryService|resolveTruthCheck|unstats\.un\.org/);
  });

  it("a medical claim that merely mentions smoking is escalated to grounded verification", () => {
    const route = VerificationCascadeService.analyzeClaimForTierRouting("Smoking cigarettes prevents heart disease and cancer");
    expect(route.recommendedTier).toBe(4);
    expect(route.isMedical).toBe(true);
    // A medical claim the registry rules on in full stays on the fast path.
    expect(VerificationCascadeService.analyzeClaimForTierRouting("Smoking causes lung cancer").recommendedTier).toBe(2);
  });
});

// ── #2 Live claim stream is gated ──────────────────────────────────────────────

describe("#2 every verdict in videos/{id}/claims passes the verdict gate", () => {
  const readClaim = async (videoId: string, claimId: string) =>
    (await admin.firestore().collection("videos").doc(videoId).collection("claims").doc(claimId).get()).data() as any;

  it("an ungrounded 'verified_true' from a fast tier is published as UNPROVEN with the fixed message", async () => {
    await StreamingClaimProcessor.publishResolvedClaims("vid_gate_1", [{
      claimId: "c1",
      text: "Apollo 11 was faked in a studio in 1969",
      status: "verified_true",
      verificationConfidence: 1,
      reasoning: "Confirmed by NASA archives.",
      richSources: [{ title: "NASA", url: "https://www.nasa.gov/mission/apollo-11/", domain: "nasa.gov", tier: "A", snippet: "" }],
      start: 12000,
    } as any]);

    const doc = await readClaim("vid_gate_1", "c1");
    expect(doc.status).toBe("unproven");
    expect(doc.verdict).toBe("unproven");
    expect(doc.publicVerdict).toBe("UNPROVEN");
    expect(doc.reasoning).toBe(NO_EVIDENCE_MESSAGE);
    expect(doc.verificationConfidence).toBeLessThanOrEqual(0.35);
    expect(doc.gateDemotion?.from).toBe("verified_true");
    expect(doc.stateLevel).toBe(3);
    expect(doc.startMs).toBe(12000);
  });

  it("a verdict backed by a live, on-point Tier A source is published as VERIFIED", async () => {
    await StreamingClaimProcessor.publishResolvedClaims("vid_gate_2", [{
      claimId: "c2",
      text: "Apollo 11 landed on the moon in 1969",
      status: "verified_true",
      verificationConfidence: 0.97,
      reasoning: "NASA mission record.",
      // A non-government Tier A reference (a lone .gov source counts as an uncorroborated
      // official statement and is not enough on its own).
      richSources: [liveSource("britannica.com", "A")],
      start: 5000,
    } as any]);

    const doc = await readClaim("vid_gate_2", "c2");
    expect(doc.status).toBe("verified_true");
    expect(doc.publicVerdict).toBe("VERIFIED");
  });

  it("re-publishing without timing keeps the stored timestamps", async () => {
    const claim: any = { claimId: "c3", text: "x claim text", status: "unproven", start: 42000, end: 45000 };
    await StreamingClaimProcessor.publishResolvedClaims("vid_gate_3", [claim]);
    await StreamingClaimProcessor.publishResolvedClaims("vid_gate_3", [{ ...claim, start: undefined, end: undefined }]);
    const doc = await readClaim("vid_gate_3", "c3");
    expect(doc.startMs).toBe(42000);
    expect(doc.endMs).toBe(45000);
  });

  it("only StreamingClaimProcessor writes to the claims subcollection, and it never writes a raw status", () => {
    const offenders: string[] = [];
    const walk = (dir: string) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) { if (entry.name !== "__tests__") walk(full); continue; }
        if (!entry.name.endsWith(".ts")) continue;
        const text = fs.readFileSync(full, "utf8");
        if (/collection\(\s*["']claims["']\s*\)/.test(text) && !full.endsWith("streamingClaimProcessor.ts")) {
          offenders.push(path.relative(SRC_DIR, full));
        }
      }
    };
    walk(SRC_DIR);
    expect(offenders).toEqual([]);

    const processorSrc = fs.readFileSync(path.join(SRC_DIR, "pipeline/services/streamingClaimProcessor.ts"), "utf8");
    // Raw statuses may not be copied straight into a write; only "unverified" placeholders are.
    expect(processorSrc).not.toMatch(/\b(status|verdict):\s*(claim|v|update)\.status\s*[,}]/);
  });
});

// ── #10 factCheckStats come from gated verdicts ────────────────────────────────

describe("#10 factCheckStats agree with the gated verdicts", () => {
  it("demoted claims are no longer counted as correct or incorrect", () => {
    const report = applyVerdictGateToReport({
      claims: [
        { claimId: "a", text: "Apollo 11 landed on the moon in 1969", status: "verified_true", richSources: [liveSource("britannica.com", "A")] },
        { claimId: "b", text: "Ungrounded true claim", status: "verified_true", richSources: [] },
        { claimId: "c", text: "Ungrounded false claim", status: "false_claim", richSources: [] },
        { claimId: "d", text: "Refuted claim", status: "false_claim", richSources: [liveSource("britannica.com", "A", "CONTRADICTS")] },
      ],
      factCheckStats: {
        totalClaims: 6, extractedClaims: 6, filtered: 2, checkedClaimsRatio: 0.67,
        evaluatedClaims: 4, correct: 2, mostly_correct: 0, incorrect: 2, unsupported: 0, unverifiable: 0,
        religious_belief: 0, opinion_claim: 0, satire_claim: 0, verification_timeout: 0,
      },
    }) as any;

    expect(report.publicVerdictCounts).toMatchObject({ VERIFIED: 1, FALSE: 1, UNPROVEN: 2 });
    expect(report.factCheckStats.correct).toBe(1);
    expect(report.factCheckStats.incorrect).toBe(1);
    expect(report.factCheckStats.unsupported).toBe(2);
    expect(report.factCheckStats.evaluatedClaims).toBe(4);
    // Extraction totals are kept as they were.
    expect(report.factCheckStats.totalClaims).toBe(6);
    expect(report.factCheckStats.filtered).toBe(2);
    expect(report.factCheckStats.checkedClaimsRatio).toBe(0.67);
    expect(report.claimLedger.confirmedCount).toBe(report.factCheckStats.correct);
    expect(report.claimLedger.falseCount).toBe(report.factCheckStats.incorrect);
  });

  it("status-named counters are recomputed only where the report already carries them", () => {
    const out = recomputeFactCheckStats(
      { totalClaims: 2, verified_true: 9, disputed: 9 },
      [{ status: "verified_true" }, { status: "disputed" }],
    );
    expect(out.verified_true).toBe(1);
    expect(out.disputed).toBe(1);
    expect("false_claim" in out).toBe(false);
  });

  it("the fact-complete event reads its counts from the stored, gated report", () => {
    const layerSrc = fs.readFileSync(path.join(SRC_DIR, "pipeline/layers/06-credibility.ts"), "utf8");
    expect(layerSrc).toMatch(/const storedResult = await this\.storeResult\(/);
    expect(layerSrc).toMatch(/correct:\s+gatedStats\.correct/);
    expect(layerSrc).toMatch(/await this\.syncLiveClaimsWithReport\(targetVideoId, sanitizedResult, jobId\)/);
  });
});

// ── #3 Fast-track triage never skips grounding for hedged claims ───────────────

describe("#3 hedged empirical claims never skip fact-checking", () => {
  it("pure aesthetic taste is resolved as opinion without grounding", async () => {
    const res = await FastTrackLlmService.evaluateClaim("My favorite color is blue");
    expect(res.resolved).toBe(true);
    expect(res.status).toBe("opinion_claim");
    expect(res.requiresGrounding).toBe(false);
  });

  it.each([
    "I think smoking prevents cancer",
    "In my opinion, the capital of India is Kolkata",
    "I believe Apollo 11 was faked",
    "Personally, I feel the speed of light is 100 km/h",
    "I believe vaccines cause autism",
    "I think the Earth is flat",
  ])("hedged empirical claim %p never resolves as opinion_claim via heuristic pre-check", async (text) => {
    const res = await FastTrackLlmService.evaluateClaim(text);
    // In test environment without live LLM credentials, safely times out/falls back to Tier 4 grounding
    expect(res.status).not.toBe("opinion_claim");
    expect(res.requiresGrounding).toBe(true);
  });

  it("source code enforces conversational hedges rule in Tier 3 prompt and removes loose regex", () => {
    const src = fs.readFileSync(path.join(SRC_DIR, "pipeline/services/fastTrackLlmService.ts"), "utf8");
    // Ensure the old loose regex that caught "i feel|in my opinion|i believe|personally|i think" is eliminated
    expect(src).not.toMatch(/\/\b\(i feel\|in my opinion\|i believe\|personally\|i think/i);
    // Ensure prompt explicitly specifies rule that conversational hedges are not opinions
    expect(src).toContain("CONVERSATIONAL HEDGES ARE NOT OPINIONS");
  });

  it("verdict gate rejects hedged empirical claim 'I believe the election was rigged' and demotes to UNPROVEN", () => {
    const verdict = decidePublicVerdict({
      status: "opinion_claim",
      claim: "I believe the election was rigged",
      transcriptExcerpt: "I believe the election was rigged",
      start: 1000,
    });
    expect(verdict.publicVerdict).toBe("UNPROVEN");
    expect(verdict.status).toBe("unproven");
  });
});

// ── #4 AI Credibility Chat prioritizes server records over client payload ─────

describe("#4 AI Credibility Chat strictly prioritizes authoritative Firestore records", () => {
  it("chatWithCredibilityAi and streamCredibilityAiChat never use client-sent claims or sources and enforce auth & App Check", () => {
    const src = fs.readFileSync(path.join(SRC_DIR, "pipeline/aiCredibilityChat.ts"), "utf8");

    // existingClaims and existingSources start empty, not populated with data.claims
    expect(src).not.toMatch(/let existingClaims:\s*any\[\]\s*=\s*Array\.isArray\(data\.claims\)\s*&&\s*data\.claims\.length\s*>\s*0\s*\?\s*data\.claims\s*:\s*\[\]/);

    // Never fall back to data.claims or data.sources
    expect(src).not.toMatch(/existingClaims\s*=\s*data\.claims/);
    expect(src).not.toMatch(/existingSources\s*=\s*data\.sources/);

    // targetClaim in scope === 'claim' never falls back to data.verdict for ungrounded claims
    expect(src).not.toMatch(/verdict:\s*data\.verdict\s*\|\|\s*["']Under Review["']/);
    expect(src).not.toMatch(/const verd = targetClaim\.verdict \|\| targetClaim\.status \|\| data\.verdict/);

    // Queries live claims subcollection via StreamingClaimProcessor if credDoc claims empty
    expect(src).toContain("StreamingClaimProcessor.getLiveClaims(videoId");

    // Both endpoints strictly enforce auth and App Check
    expect(src).toContain("enforceAppCheck: true");
    expect(src).toContain("admin.appCheck().verifyToken(");
    expect(src).toContain("Please sign in to access TruthWorld Ask AI.");
  });
});

// ── #5 Video owners cannot write to media/credibility in firestore.rules ───────

describe("#5 Video owners are blocked from writing to media/credibility in firestore.rules", () => {
  it("firestore.rules enforces docId != 'credibility' on /media/{docId} writes", () => {
    const rulesPath = path.join(ROOT_DIR, "firestore.rules");
    const rulesContent = fs.readFileSync(rulesPath, "utf8");

    // Must match: allow write: if isVideoOwner(videoId) && docId != 'credibility';
    expect(rulesContent).toMatch(/match\s*\/media\/\{docId\}\s*\{[\s\S]*?allow write:\s*if\s*isVideoOwner\(videoId\)\s*&&\s*docId\s*!=\s*['"]credibility['"];/);
  });
});

// ── Bonus: Cache upsert in Tier0 never fabricates fake urlVerification ─────────

describe("Tier-0 upsertVerifiedClaims resolves genuine source trust without fake urlVerification", () => {
  it("tier0Knowledge.ts never stamps synthetic httpStatus: 200 or accessible: true", () => {
    const src = fs.readFileSync(path.join(SRC_DIR, "pipeline/services/tier0Knowledge.ts"), "utf8");
    expect(src).not.toContain("httpStatus: 200");
    expect(src).not.toContain("accessible: true");
    expect(src).toContain("sourceTrustService.resolveSourceTrust(s.uri)");
  });
});
