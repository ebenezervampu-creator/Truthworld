/**
 * Edge cases raised in review (2026-11-19):
 *  1. A removed source that was the only one on its side must trigger a model re-reading.
 *  3. The daily sweep must only advance reports whose check fully completed.
 *  4. Both 06-credibility save paths must run the verdict gate and the quality audit.
 */
import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import { reevaluateClaimOnEvidenceChange } from "../../src/pipeline/services/evidenceDrivenReevaluation";
import { runEvidenceFreshnessSweep } from "../../src/pipeline/services/evidenceFreshnessSweep";

const live = (domain: string, extra: Record<string, unknown> = {}) => ({
  title: domain, url: `https://${domain}/a`, directUrl: `https://${domain}/a`, domain, tier: "B", claimStance: "SUPPORTS",
  urlVerification: { status: "VERIFIED", httpStatus: 200, isSoft404: false, originalUrl: `https://${domain}/a`, canonicalUrl: `https://${domain}/a`, redirectHops: 0 },
  ...extra,
}) as any;

describe("1. removing an opposing source re-reads the evidence", () => {
  const reAdjudicator = () => ({
    reAdjudicateClaimWithRecoveredEvidence: jest.fn(async () => ({ status: "verified_true" as any, verdictConfidence: 0.9, reasoning: "The remaining source confirms it." })),
  });

  it("a DISPUTED claim whose contradicting source died is re-judged, not left 'disputed'", async () => {
    const r = reAdjudicator();
    const claim = {
      claimId: "c1", claim: "X", status: "disputed",
      richSources: [live("supports.example", { stance: "SUPPORTS" }), live("contradicts.example", { claimStance: "CONTRADICTS", isContradictory: true })],
    };
    const out = await reevaluateClaimOnEvidenceChange({ claim, newSources: [claim.richSources[0]], trigger: "source_health", reAdjudicator: r });
    expect(r.reAdjudicateClaimWithRecoveredEvidence).toHaveBeenCalledTimes(1);
    expect(out.newStatus).toBe("verified_true");
  });

  it("a one-sided VERIFIED claim losing one of two supporting sources needs no model call", async () => {
    const r = reAdjudicator();
    const claim = { claimId: "c2", claim: "Y", status: "verified_true", richSources: [live("a.example"), live("b.example")] };
    const out = await reevaluateClaimOnEvidenceChange({ claim, newSources: [claim.richSources[0]], trigger: "source_health", reAdjudicator: r });
    expect(r.reAdjudicateClaimWithRecoveredEvidence).not.toHaveBeenCalled();
    expect(out.newStatus).toBe("verified_true");
  });

  it("without an AI budget the claim is flagged and re-read on the next run", async () => {
    const claim = {
      claimId: "c3", claim: "Z", status: "disputed",
      richSources: [live("s.example"), live("c.example", { claimStance: "CONTRADICTS", isContradictory: true })],
    };
    const first = await reevaluateClaimOnEvidenceChange({ claim, newSources: [claim.richSources[0]], trigger: "source_health" });
    expect(first.modelSkipped).toBe(true);
    expect(first.claim.pendingEvidenceRecheck).toBe(true);

    const r = reAdjudicator();
    const second = await reevaluateClaimOnEvidenceChange({ claim: first.claim, newSources: first.claim.richSources, trigger: "evidence_freshness_sweep", reAdjudicator: r });
    expect(r.reAdjudicateClaimWithRecoveredEvidence).toHaveBeenCalledTimes(1);
    expect(second.claim.pendingEvidenceRecheck).toBeUndefined();
  });
});

describe("3. sweep queue only advances completed reports", () => {
  const col = () => admin.firestore().collection("credibility_quality_audits");

  async function seed() {
    await col().doc("job_done").set({ videoId: "v_done", lastEvidenceCheckAt: 1 });
    await col().doc("job_capped").set({ videoId: "v_capped", lastEvidenceCheckAt: 2 });
    await col().doc("job_fail").set({ videoId: "v_fail", lastEvidenceCheckAt: 3 });
  }

  it("keeps capped and failed reports at the front; advances completed ones", async () => {
    await seed();
    const healing = {
      auditAndHealVideoReport: jest.fn(async (videoId: string) => {
        if (videoId === "v_fail") throw new Error("storage timeout");
        return {
          videoId, healed: true, claimsAudited: 3, brokenUrlsRemoved: 1, urlsRepaired: 0, remainingVerifiedUrls: 2,
          verdictsChanged: 0, modelRechecks: videoId === "v_capped" ? 2 : 1, modelRechecksSkipped: videoId === "v_capped" ? 1 : 0,
        };
      }),
    };
    const result = await runEvidenceFreshnessSweep({ healing, maxVideos: 10, maxModelRechecks: 100 });
    expect(result.videosChecked).toBe(2);
    expect(result.videosDeferred).toBe(1);

    const done = (await col().doc("job_done").get()).data()!;
    const capped = (await col().doc("job_capped").get()).data()!;
    const failed = (await col().doc("job_fail").get()).data()!;
    expect(done.lastEvidenceCheckAt).toBeGreaterThan(1000);
    expect(capped.lastEvidenceCheckAt).toBe(2);
    expect(capped.lastEvidenceSweep.completed).toBe(false);
    expect(failed.lastEvidenceCheckAt).toBe(3);
    expect(failed.evidenceSweepFailures).toBe(1);
  });

  it("stops before checking more reports once the AI budget is spent", async () => {
    await seed();
    const healing = {
      auditAndHealVideoReport: jest.fn(async (videoId: string) => ({
        videoId, healed: true, claimsAudited: 1, brokenUrlsRemoved: 0, urlsRepaired: 1, remainingVerifiedUrls: 1,
        verdictsChanged: 1, modelRechecks: 5, modelRechecksSkipped: 0,
      })),
    };
    await runEvidenceFreshnessSweep({ healing, maxVideos: 10, maxModelRechecks: 5 });
    expect(healing.auditAndHealVideoReport).toHaveBeenCalledTimes(1);
  });

  it("moves a report back after 3 consecutive failures so it cannot block the queue", async () => {
    await col().doc("job_broken").set({ videoId: "v_broken", lastEvidenceCheckAt: 0, evidenceSweepFailures: 2 });
    const healing = { auditAndHealVideoReport: jest.fn(async () => { throw new Error("corrupt report"); }) };
    await runEvidenceFreshnessSweep({ healing: healing as any, maxVideos: 1 });
    const broken = (await col().doc("job_broken").get()).data()!;
    expect(broken.evidenceSweepFailures).toBe(3);
    expect(broken.lastEvidenceCheckAt).toBeGreaterThan(1000);
    expect(broken.reviewStatus).toBe("pending");
  });
});

describe("4. save-path wiring guard (catches the 19:44 overwrite regression)", () => {
  const src = (rel: string) => fs.readFileSync(path.resolve(__dirname, "../../src/pipeline", rel), "utf8");

  it("06-credibility: both save paths run the verdict gate and the quality audit", () => {
    const code = src("layers/06-credibility.ts");
    const storeResult = code.slice(code.indexOf("private async storeResult("));
    const storeBody = storeResult.slice(0, storeResult.indexOf("saveAnalysis("));
    expect(storeBody).toMatch(/applyVerdictGateToReport\(sanitizeReportPayloadForClosedWorld\(result\)\)/);
    expect(storeBody).toMatch(/recordReportQualityAudit\(/);

    const synth = code.slice(code.indexOf("const sanitizedExistingResult"));
    const synthBody = synth.slice(0, 600);
    expect(synthBody).toMatch(/applyVerdictGateToReport\(sanitizeReportPayloadForClosedWorld\(targetResult\)\)/);
    expect(synthBody).toMatch(/recordReportQualityAudit\(/);

    expect(code).toMatch(/async function recordReportQualityAudit\(/);
    expect(code).toMatch(/attachTranscriptExcerpts\(rawClaims/);
  });

  it("post-publication save paths also run the gate and the audit", () => {
    for (const file of ["services/sourceHealingService.ts", "services/communityEvidenceService.ts"]) {
      const code = src(file);
      expect(code).toMatch(/applyVerdictGateToReport\(sanitizeReportPayloadForClosedWorld\(/);
      expect(code).toMatch(/auditCredibilityReport\(/);
    }
  });
});
