/**
 * Credibility System — source attribution & verdict consistency regressions.
 *
 * Reproduces the production report where a 9+ minute video produced 30 claims,
 * 25 of them "Caution", ~70% of claims showing the same single source and only ONE
 * source at video level.
 */

const mockGenerateContent = jest.fn();

jest.mock("../../src/pipeline/utils/ai-client", () => {
  const actual = jest.requireActual("../../src/pipeline/utils/ai-client");
  return {
    ...actual,
    getVertexClient: () => ({ models: { generateContent: mockGenerateContent } }),
  };
});

jest.mock("../../src/pipeline/services/cost-engine", () => {
  const actual = jest.requireActual("../../src/pipeline/services/cost-engine");
  return { ...actual, recordTokenUsage: jest.fn() };
});

import { attributeGroundingChunks } from "../../src/pipeline/services/groundingAttribution";
import {
  mapVerificationLabelToStatus,
  reconcileVerdictWithEvidence,
  detectDominantClaimLanguage,
  UNCONFIRMED_POSITIVE_TEXT,
} from "../../src/pipeline/services/verdictReconciliation";
import { sourceTrustService } from "../../src/pipeline/services/sourceTrustService";
import {
  isLiveVerificationRecord,
  isVerifiedRichSource,
  sanitizeReportPayloadForClosedWorld,
} from "../../src/pipeline/services/urlVerificationService";
import { runGroundedAdjudication } from "../../src/pipeline/services/claimVerification";
import { PIPELINE_CONFIG } from "../../src/pipeline/config";

/** Builds a JSON response text plus byte-accurate groundingSupports for each item. */
function buildBatchResponse(
  items: Array<{ claimId: string; verdict: string; rationale: string; chunks: number[] }>
) {
  const payload = items.map((i) => ({
    claimId: i.claimId,
    verdict: i.verdict,
    confidence: 0.9,
    rationale: i.rationale,
    citedChunkIndices: [0], // the model's guess: always 0 — must NOT be trusted for live chunks
    hasConflictingEvidence: false,
  }));
  const text = JSON.stringify(payload, null, 2);
  const supports = items.map((i) => {
    const charStart = text.indexOf(i.rationale);
    const startIndex = Buffer.byteLength(text.slice(0, charStart), "utf8");
    const endIndex = startIndex + Buffer.byteLength(i.rationale, "utf8");
    return { segment: { startIndex, endIndex, text: i.rationale }, groundingChunkIndices: i.chunks };
  });
  return { text, supports };
}

describe("groundingAttribution", () => {
  it("attributes each grounding chunk only to the claim whose JSON item it supports", () => {
    const { text, supports } = buildBatchResponse([
      { claimId: "c1", verdict: "VERIFIED", rationale: "కురంజీత్ కౌర్ ThePrint editor (Telugu bytes before)", chunks: [1] },
      { claimId: "c2", verdict: "VERIFIED", rationale: "Tamas is a 1988 film by Govind Nihalani.", chunks: [2, 3] },
      { claimId: "c3", verdict: "VERIFIED", rationale: "Dhurandhar depicts the 1999 IC-814 hijack.", chunks: [4] },
    ]);
    const map = attributeGroundingChunks(text, supports, ["c1", "c2", "c3"], 5);
    expect(map.get("c1")).toEqual([1]);
    expect(map.get("c2")).toEqual([2, 3]);
    expect(map.get("c3")).toEqual([4]);
  });

  it("returns no attribution (rather than chunk 0) when supports are missing", () => {
    const map = attributeGroundingChunks('[{"claimId":"c1"}]', [], ["c1"], 3);
    expect(map.get("c1")).toEqual([]);
  });
});

describe("runGroundedAdjudication — per-claim sources", () => {
  beforeEach(() => mockGenerateContent.mockReset());

  it("does not give every claim the first search result", async () => {
    const { text, supports } = buildBatchResponse([
      { claimId: "c1", verdict: "VERIFIED", rationale: "Kuranjeet Kaur writes for ThePrint.", chunks: [1] },
      { claimId: "c2", verdict: "VERIFIED", rationale: "Tamas was released in 1988.", chunks: [2] },
    ]);
    mockGenerateContent.mockResolvedValue({
      text,
      candidates: [
        {
          groundingMetadata: {
            groundingChunks: [
              { web: { uri: "https://ipcs.org/unrelated-telugu-page", title: "ipcs.org" } },
              { web: { uri: "https://theprint.in/author/kuranjeet-kaur/", title: "theprint.in" } },
              { web: { uri: "https://en.wikipedia.org/wiki/Tamas_(film)", title: "wikipedia.org" } },
            ],
            groundingSupports: supports,
            webSearchQueries: ["q1", "q2"],
          },
        },
      ],
    });

    const results = await runGroundedAdjudication({
      videoId: "v1",
      claims: [
        { claimId: "c1", speakerId: "A", startMs: 0, endMs: 1, verbatimQuote: "a", normalizedClaim: "a", domain: "GENERAL_FACT", requiresVerification: true },
        { claimId: "c2", speakerId: "A", startMs: 2, endMs: 3, verbatimQuote: "b", normalizedClaim: "b", domain: "GENERAL_FACT", requiresVerification: true },
      ] as any,
      model: "test-model",
      tierLabel: "TIER_2_BULK_VERIFY",
      thinkingLevel: "LOW" as any,
      requireUsResidency: false,
    });

    const byId = new Map(results.map((r) => [r.claimId, r]));
    expect(byId.get("c1")!.v2VerifiedUrls.map((s) => s.uri)).toEqual(["https://theprint.in/author/kuranjeet-kaur/"]);
    expect(byId.get("c2")!.v2VerifiedUrls.map((s) => s.uri)).toEqual(["https://en.wikipedia.org/wiki/Tamas_(film)"]);
    for (const r of results) {
      expect(r.v2VerifiedUrls.some((s) => s.uri.includes("ipcs.org"))).toBe(false);
    }
  });

  it("drops results whose claimId is unknown instead of attaching them to another claim", async () => {
    mockGenerateContent.mockResolvedValue({
      text: JSON.stringify([
        { claimId: "c1", verdict: "VERIFIED", confidence: 0.9, rationale: "x", citedChunkIndices: [], hasConflictingEvidence: false },
        { claimId: "ghost", verdict: "FALSE", confidence: 0.9, rationale: "y", citedChunkIndices: [], hasConflictingEvidence: false },
        { claimId: "ghost2", verdict: "FALSE", confidence: 0.9, rationale: "z", citedChunkIndices: [], hasConflictingEvidence: false },
      ]),
      candidates: [{ groundingMetadata: { groundingChunks: [], groundingSupports: [] } }],
    });
    const results = await runGroundedAdjudication({
      videoId: "v1",
      claims: [
        { claimId: "c1", speakerId: "A", startMs: 0, endMs: 1, verbatimQuote: "a", normalizedClaim: "a", domain: "GENERAL_FACT", requiresVerification: true },
        { claimId: "c2", speakerId: "A", startMs: 0, endMs: 1, verbatimQuote: "b", normalizedClaim: "b", domain: "GENERAL_FACT", requiresVerification: true },
      ] as any,
      model: "m",
      tierLabel: "TIER_2_BULK_VERIFY",
      thinkingLevel: "LOW" as any,
      requireUsResidency: false,
    });
    expect(results.map((r) => r.claimId)).toEqual(["c1"]);
  });
});

describe("mapVerificationLabelToStatus", () => {
  it.each([
    ["VERIFIED", "verified_true"],
    ["VERIFIED_TRUE", "verified_true"],
    ["Verified True", "verified_true"],
    ["MOSTLY_TRUE", "mostly_true"],
    ["RHETORICAL EXAGGERATION", "rhetorical_exaggeration"],
    ["NEEDS CONTEXT", "needs_context"],
    ["LIMITED SUPPORT", "unsupported"],
    ["FALSE", "false_claim"],
    ["MOSTLY FALSE", "misleading"],
    ["NOT HISTORICALLY VERIFIABLE", "not_historically_verifiable"],
    ["INCONCLUSIVE", "inconclusive"],
    ["OPINION", "opinion_claim"],
  ])("%s -> %s", (label, expected) => {
    expect(mapVerificationLabelToStatus(label)).toBe(expected);
  });
});

describe("dual-mass invariant & verdict reconciliation", () => {
  const tierB = { tier: "B" as const, isContradictory: false, url: "https://publisher.example/article", domain: "publisher.example", claimStance: "SUPPORTS" as const };

  it("keeps a single-source confirmation instead of forcing 'unproven'", () => {
    const r = reconcileVerdictWithEvidence({ proposedStatus: "verified_true", reasoning: "Confirmed.", sources: [tierB] });
    expect(r.status).toBe("verified_true");
    expect(r.reasoning).toBe("Confirmed.");
  });

  it("does not turn 'misleading' or 'needs_context' into Caution for lack of a 2nd source", () => {
    expect(reconcileVerdictWithEvidence({ proposedStatus: "misleading", sources: [tierB] }).status).toBe("misleading");
    expect(reconcileVerdictWithEvidence({ proposedStatus: "needs_context", sources: [tierB] }).status).toBe("needs_context");
  });

  it("nulls an evidence-free 'verified_true' AND replaces the contradictory 'confirmed' text", () => {
    const r = reconcileVerdictWithEvidence({
      proposedStatus: "verified_true",
      reasoning: "Karanjeet Kaur is confirmed to be a writer at ThePrint.",
      publicNote: "Note",
      sources: [],
    });
    expect(r.status).toBe("unproven");
    expect(r.reasoning).toBe(UNCONFIRMED_POSITIVE_TEXT);
    expect(r.publicNote).toBe("Note"); // internal arithmetic never leaks to users
    expect(r.invariantReason).toMatch(/evidence/i);
  });

  it("never promotes 'misleading' to verified_true just because 3 sources exist", () => {
    const res = sourceTrustService.evaluateDualMassInvariants([tierB, tierB, tierB], "misleading");
    expect(res.invariantVerdict).not.toBe("verified_true");
  });

  it("still promotes an undecided verdict with strong corroboration", () => {
    const res = sourceTrustService.evaluateDualMassInvariants([tierB, tierB, tierB], "inconclusive");
    expect(res.invariantVerdict).toBe("verified_true");
  });
});

describe("source gates are consistent across layers", () => {
  const botBlockedViaGoogle = {
    status: "BOT_BLOCKED",
    originalUrl: "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQabc",
    canonicalUrl: "https://theprint.in/opinion/dhurandhar-review/123456/",
    domain: "theprint.in",
    httpStatus: 403,
    redirectHops: 1,
    isSoft404: false,
    verifiedAtUtc: new Date().toISOString(),
    verifierMethod: "grounding_resolved",
    fetchStatus: "BOT_BLOCKED",
  } as any;

  it("accepts a bot-blocked article reached through a Google grounding redirect", () => {
    expect(isLiveVerificationRecord(botBlockedViaGoogle)).toBe(true);
  });

  it("rejects bot-blocked URLs not reached via grounding, soft-404s and fabricated homepages", () => {
    expect(isLiveVerificationRecord({ ...botBlockedViaGoogle, redirectHops: 0, originalUrl: "https://theprint.in/x" })).toBe(false);
    expect(isLiveVerificationRecord({ ...botBlockedViaGoogle, status: "VERIFIED", httpStatus: 200, isSoft404: true })).toBe(false);
    expect(isLiveVerificationRecord({ ...botBlockedViaGoogle, canonicalUrl: "https://theprint.in/" })).toBe(false);
  });

  it("keeps the same admitted source in claim, explainability and video-level lists", () => {
    const source = {
      title: "ThePrint review",
      url: botBlockedViaGoogle.canonicalUrl,
      directUrl: botBlockedViaGoogle.canonicalUrl,
      domain: "theprint.in",
      tier: "B",
      urlVerification: botBlockedViaGoogle,
    };
    expect(isVerifiedRichSource(source as any)).toBe(true);
    const report = sanitizeReportPayloadForClosedWorld({
      claims: [{ claimId: "c1", text: "t", nature: "VERIFIABLE_FACT", richSources: [source], sources: [source] }],
      sources: [source],
      synthesis: { sources: [source] },
    } as any);
    expect((report as any).claims[0].richSources).toHaveLength(1);
    expect((report as any).sources).toHaveLength(1);
    expect((report as any).synthesis.sources).toHaveLength(1);
  });

  it("evidence schema version was bumped so poisoned v2 cache entries are invalidated", () => {
    expect(PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION).not.toBe("v2_verified_urls");
  });
});

describe("report language", () => {
  it("uses English for English claim text even if one claim has a Telugu phrase", () => {
    expect(
      detectDominantClaimLanguage([
        "Dhurandhar movie depicts the Kandahar hijack and the 26/11 attacks",
        "[Kandahar hijack మరియు 26/11 దాడులు / Kandahar hijack and 26/11 attacks] incidents are seared into public memory",
      ])
    ).toBe("English");
  });

  it("uses Telugu when claims are written in Telugu", () => {
    expect(detectDominantClaimLanguage(["ధురంధర్ చిత్రంలో 1999 కాందహార్ విమానం హైజాక్ చూపించారు"])).toBe("Telugu");
  });
});

import { auditCredibilityReport } from "../../src/pipeline/services/reportQualityAudit";

describe("report quality audit (catches these bugs before users do)", () => {
  const live = (url: string) => ({
    status: "VERIFIED", originalUrl: url, canonicalUrl: url, domain: "x", httpStatus: 200,
    redirectHops: 0, isSoft404: false, verifiedAtUtc: "", verifierMethod: "http_get", fetchStatus: "HTTP_200_OK",
  });
  const src = (url: string, uv: any = live(url)) => ({ title: url, url, directUrl: url, urlVerification: uv });

  it("FAILS the 2026-11-19 Dhurandhar-style report", () => {
    const ipcs = "https://ipcs.org/telugu-page";
    const claims = Array.from({ length: 10 }, (_, i) => ({
      claimId: `c${i}`,
      status: i < 2 ? "verified_true" : "unproven",
      nature: "VERIFIABLE_FACT",
      reasoning: i === 3 ? "Karanjeet Kaur is confirmed to be a writer at ThePrint." : i === 4 ? "Confirmed by records." : "Plain English text explaining the outcome here.",
      sources: i < 8 ? [src(ipcs)] : [],
    }));
    claims[5].reasoning = "ఆదిత్య ధర్ దర్శకత్వంలో వచ్చిన ధురంధర్ చిత్రంలో 1999 కాందహార్ విమానం హైజాక్ చూపించారు.";
    claims[6].sources = [src("https://fake.example/a", { ...live("https://fake.example/a"), status: "FETCH_FAILED", httpStatus: 0 })];

    const audit = auditCredibilityReport({ claims, sources: [src(ipcs)] });
    const ids = audit.checks.map((c) => c.id);
    expect(audit.grade).toBe("FAIL");
    expect(ids).toEqual(expect.arrayContaining(["SHARED_SOURCE", "VERDICT_CONTRADICTION", "UNVERIFIED_SOURCE", "CAUTION_HEAVY", "MIXED_LANGUAGE"]));
    expect(audit.metrics.maxSharedSourceUrl).toBe(ipcs);
  });

  it("PASSES a healthy report with per-claim sources", () => {
    const claims = Array.from({ length: 6 }, (_, i) => ({
      claimId: `c${i}`, status: "verified_true", nature: "VERIFIABLE_FACT",
      reasoning: "Official records confirm the release year and the director.",
      sources: [src(`https://site${i}.example/article-${i}`), src(`https://other${i}.example/story`)],
    }));
    const opinion = { claimId: "o1", status: "opinion_claim", nature: "OPINION", reasoning: "A viewpoint.", sources: [] };
    const audit = auditCredibilityReport({
      claims: [...claims, opinion],
      sources: claims.flatMap((c) => c.sources),
    });
    expect(audit.grade).toBe("PASS");
    expect(audit.metrics.contextualClaims).toBe(1);
  });
});

describe("source trust registry", () => {
  it("does not reject major Indian publishers or unknown publishers outright", () => {
    expect(sourceTrustService.resolveSourceTrust("https://theprint.in/opinion/x/123/").tier).not.toBe("E");
    expect(sourceTrustService.resolveSourceTrust("https://www.imdb.com/title/tt0096283/").tier).not.toBe("E");
    expect(sourceTrustService.resolveSourceTrust("https://some-regional-paper.co.in/article/1").tier).toBe("D");
  });
  it("still rejects user-generated content", () => {
    expect(sourceTrustService.resolveSourceTrust("https://www.reddit.com/r/india/comments/x").tier).toBe("E");
    expect(sourceTrustService.resolveSourceTrust("https://someone.blogspot.com/post").tier).toBe("E");
  });
});
