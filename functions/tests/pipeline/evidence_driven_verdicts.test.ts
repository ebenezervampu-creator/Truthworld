/**
 * Verdicts are a function of evidence:
 *  - every factual verdict needs at least one live source (100% evidence rule),
 *  - confidence is capped by how much independent evidence exists,
 *  - when evidence changes after publication, the verdict is re-evaluated, not kept.
 */
import {
  reconcileVerdictWithEvidence,
  evidenceConfidenceCap,
  UNCONFIRMED_CONTEXT_TEXT,
} from "../../src/pipeline/services/verdictReconciliation";
import { reevaluateClaimOnEvidenceChange } from "../../src/pipeline/services/evidenceDrivenReevaluation";
import { SourceHealingService } from "../../src/pipeline/services/sourceHealingService";
import { ClaimVerificationService } from "../../src/pipeline/services/claimVerification";

const live = (url: string, domain: string, claimStance: "SUPPORTS" | "CONTRADICTS" | "MIXED" = "SUPPORTS") => ({
  title: domain, url, directUrl: url, domain, tier: "B" as const, claimStance,
  urlVerification: {
    status: "VERIFIED", originalUrl: url, canonicalUrl: url, domain, httpStatus: 200, redirectHops: 0,
    isSoft404: false, verifiedAtUtc: new Date().toISOString(), verifierMethod: "http_get", fetchStatus: "HTTP_200_OK",
  } as any,
});
const dead = (url: string, domain: string) => ({
  ...live(url, domain),
  urlVerification: { ...live(url, domain).urlVerification, status: "NOT_FOUND", httpStatus: 404 },
});

describe("100% evidence rule", () => {
  it.each(["verified_true", "mostly_true", "false_claim", "misleading", "disputed", "needs_context", "outdated"])(
    "'%s' with no live source is published as unproven",
    (status) => {
      const r = reconcileVerdictWithEvidence({ proposedStatus: status as any, reasoning: "Model text", sources: [] });
      expect(r.status).toBe("unproven");
      expect(r.reasoning).not.toBe("Model text");
    }
  );

  it("a dead link does not count as evidence", () => {
    const r = reconcileVerdictWithEvidence({ proposedStatus: "verified_true", sources: [dead("https://a.example/x", "a.example")] });
    expect(r.status).toBe("unproven");
  });

  it("context verdicts without evidence get an honest context explanation", () => {
    expect(reconcileVerdictWithEvidence({ proposedStatus: "misleading", sources: [] }).reasoning).toBe(UNCONFIRMED_CONTEXT_TEXT);
  });

  it("opinions and beliefs are not fact claims and are left as classified", () => {
    expect(reconcileVerdictWithEvidence({ proposedStatus: "opinion_claim", sources: [] }).status).toBe("opinion_claim");
    expect(reconcileVerdictWithEvidence({ proposedStatus: "religious_belief", sources: [] }).status).toBe("religious_belief");
  });
});

describe("confidence follows evidence", () => {
  it("caps confidence by the number of independent live publishers", () => {
    expect(evidenceConfidenceCap([])).toBe(0.35);
    expect(evidenceConfidenceCap([live("https://a.example/1", "a.example")])).toBe(0.75);
    // Two links from the same publisher are one independent source.
    expect(evidenceConfidenceCap([live("https://a.example/1", "a.example"), live("https://a.example/2", "a.example")])).toBe(0.75);
    expect(evidenceConfidenceCap([live("https://a.example/1", "a.example"), live("https://b.example/1", "b.example")])).toBe(0.88);
    expect(evidenceConfidenceCap([
      live("https://a.example/1", "a.example"), live("https://b.example/1", "b.example"), live("https://c.example/1", "c.example"),
    ])).toBe(0.97);
  });
});

describe("re-evaluation when evidence changes", () => {
  const baseClaim = {
    claimId: "c1",
    claim: "Tamas was released in 1988.",
    status: "verified_true",
    reasoning: "Records confirm the 1988 release.",
    confidence: 0.9,
    richSources: [live("https://en.wikipedia.org/wiki/Tamas_(film)", "wikipedia.org")],
  };

  it("unchanged evidence leaves the claim untouched", async () => {
    const r = await reevaluateClaimOnEvidenceChange({ claim: baseClaim, newSources: baseClaim.richSources as any, trigger: "source_health" });
    expect(r.evidenceChanged).toBe(false);
    expect(r.claim).toBe(baseClaim);
  });

  it("losing every source turns a verified verdict into unproven and records why", async () => {
    const r = await reevaluateClaimOnEvidenceChange({ claim: baseClaim, newSources: [], trigger: "source_health" });
    expect(r.newStatus).toBe("unproven");
    expect(r.usedModel).toBe(false);
    expect(r.claim.verdictHistory[0]).toMatchObject({ previousStatus: "verified_true", newStatus: "unproven", trigger: "source_health", sourcesRemoved: 1 });
    expect(r.claim.confidence).toBeLessThanOrEqual(0.35);
  });

  it("new evidence makes the model re-judge the claim, and the verdict can flip", async () => {
    const reAdjudicator = {
      reAdjudicateClaimWithRecoveredEvidence: jest.fn(async () => ({
        status: "false_claim" as any, verdictConfidence: 0.95, reasoning: "The film was released in 1987, not 1988.",
      })),
    };
    // The new source's own text refutes the 1988 date.
    const newer = [...baseClaim.richSources, live("https://archive.example/tamas", "archive.example", "CONTRADICTS")] as any;
    const r = await reevaluateClaimOnEvidenceChange({ claim: baseClaim, newSources: newer, trigger: "evidence_freshness_sweep", reAdjudicator });
    expect(reAdjudicator.reAdjudicateClaimWithRecoveredEvidence).toHaveBeenCalledTimes(1);
    expect(r.newStatus).toBe("false_claim");
    expect(r.claim.reasoning).toMatch(/1987/);
    expect(r.claim.confidence).toBe(0.88); // two publishers → capped below the model's 0.95
  });
});

describe("source healing re-evaluates the verdict (no more fixed verdicts)", () => {
  it("removes dead sources AND changes the verdict when no evidence remains", async () => {
    const urlVerifier = {
      verifyBatch: jest.fn(async (urls: string[]) => new Map(urls.map((u) => [u, dead(u, "x").urlVerification]))),
    } as any;
    const svc = new SourceHealingService({
      urlVerifier,
      evidenceRetrieval: { buildEvidenceCatalogForClaim: jest.fn() } as any,
      analysisRepository: {} as any,
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: jest.fn() },
      reportStore: { load: jest.fn(), save: jest.fn() },
    });
    const claim: any = {
      claimId: "c9", text: "X happened in 2001.", nature: "VERIFIABLE_FACT", status: "verified_true",
      reasoning: "Confirmed.", richSources: [live("https://gone.example/a", "gone.example")],
    };
    const out = await svc.healClaimSources(claim, { repairWithRetrieval: false });
    expect(out.brokenRemoved).toBe(1);
    expect(out.verdictChanged).toBe(true);
    expect(out.claim.status).toBe("unproven");
  });
});

describe("cached verdicts are only reused while their evidence is live", () => {
  it("sends a cached claim whose sources died back for fresh verification", async () => {
    const svc = new ClaimVerificationService("", 0.6);
    (svc as any).urlVerifier = {
      verifyBatch: jest.fn(async (urls: string[]) =>
        new Map(urls.map((u) => [u, u.includes("dead") ? dead(u, "d").urlVerification : live(u, "l").urlVerification]))
      ),
    };
    const alive: any = { claimId: "a", text: "A", nature: "VERIFIABLE_FACT", status: "verified_true", richSources: [live("https://live.example/1", "live.example")] };
    const gone: any = { claimId: "b", text: "B", nature: "VERIFIABLE_FACT", status: "verified_true", richSources: [live("https://dead.example/1", "dead.example")] };
    const noEvidence: any = { claimId: "c", text: "C", nature: "VERIFIABLE_FACT", status: "verified_true", richSources: [] };
    const opinion: any = { claimId: "d", text: "D", nature: "OPINION", status: "opinion_claim", richSources: [] };

    const { keep, reverify } = await (svc as any).revalidateCachedClaims([alive, gone, noEvidence, opinion]);
    expect(keep.map((c: any) => c.claimId).sort()).toEqual(["a", "d"]);
    expect(reverify.map((c: any) => c.claimId).sort()).toEqual(["b", "c"]);
  });
});

describe("nuanced verdicts are not hardened by source count", () => {
  it("'misleading' backed by three sources stays misleading (not forced to false)", () => {
    const srcs = [live("https://a.example/1", "a.example", "CONTRADICTS"), live("https://b.example/1", "b.example", "CONTRADICTS"), live("https://c.example/1", "c.example", "CONTRADICTS")];
    expect(reconcileVerdictWithEvidence({ proposedStatus: "misleading", sources: srcs }).status).toBe("misleading");
  });
  it("a 'false' verdict backed by its sources stays false", () => {
    const srcs = [live("https://a.example/1", "a.example", "CONTRADICTS"), live("https://b.example/1", "b.example", "CONTRADICTS")];
    expect(reconcileVerdictWithEvidence({ proposedStatus: "false_claim", sources: srcs }).status).toBe("false_claim");
  });
});
