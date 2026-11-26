/**
 * Stance step: a source counts toward a verdict only after its OWN content has been judged
 * against the specific claim. Sources that were not actually read get zero weight.
 */
import { classifySourceStances } from "../../src/pipeline/services/stanceClassifier";
import { reevaluateClaimOnEvidenceChange } from "../../src/pipeline/services/evidenceDrivenReevaluation";

const longText = (s: string) => (s + " ").repeat(40);

const source = (domain: string, text?: string, extra: Record<string, any> = {}) => ({
  title: domain,
  url: `https://${domain}/a`,
  directUrl: `https://${domain}/a`,
  domain,
  tier: "B",
  urlVerification: {
    status: "VERIFIED",
    httpStatus: 200,
    isSoft404: false,
    originalUrl: `https://${domain}/a`,
    canonicalUrl: `https://${domain}/a`,
    finalUrl: `https://${domain}/a`,
    redirectHops: 0,
    ...(text ? { evidenceText: text } : {}),
  },
  ...extra,
});

const fakeClient = (responses: any[]) => {
  const calls: any[] = [];
  return {
    calls,
    models: {
      async generateContent(req: any) {
        calls.push(req);
        const next = responses.shift();
        if (next instanceof Error) throw next;
        return next;
      },
    },
  };
};

describe("classifySourceStances", () => {
  it("judges sources from their own text and records the source kind", async () => {
    const client = fakeClient([
      { text: JSON.stringify([
        { sourceIndex: 0, stance: "SUPPORTS", sourceKind: "PRIMARY_RECORD", reason: "Judgment text states the date." },
        { sourceIndex: 1, stance: "OFF_TOPIC", sourceKind: "INDEPENDENT_REPORTING", reason: "Same people, different event." },
      ]) },
    ]);
    const out = await classifySourceStances(
      "The court ruled on 3 March 2021",
      [source("court.example", longText("ruled on 3 March 2021")), source("paper.example", longText("unrelated story"))] as any,
      { client, model: "test" }
    );
    expect(out[0].claimStance).toBe("SUPPORTS");
    expect(out[0].sourceKind).toBe("PRIMARY_RECORD");
    expect(out[1].claimStance).toBe("OFF_TOPIC");
    expect(client.calls[0].config.responseSchema).toBeDefined();
  });

  it("for unreadable pages, accepts the model's judgment only for URLs it actually retrieved", async () => {
    const client = fakeClient([
      {
        text: JSON.stringify([
          { sourceIndex: 0, stance: "SUPPORTS", sourceKind: "INDEPENDENT_REPORTING", reason: "read" },
          { sourceIndex: 1, stance: "SUPPORTS", sourceKind: "INDEPENDENT_REPORTING", reason: "guessed" },
        ]),
        candidates: [{ urlContextMetadata: { urlMetadata: [
          { retrievedUrl: "https://read.example/a", urlRetrievalStatus: "URL_RETRIEVAL_STATUS_SUCCESS" },
          { retrievedUrl: "https://blocked.example/a", urlRetrievalStatus: "URL_RETRIEVAL_STATUS_ERROR" },
        ] } }],
      },
    ]);
    const out = await classifySourceStances("Claim", [source("read.example"), source("blocked.example")] as any, { client, model: "test" });
    expect(client.calls[0].config.tools).toEqual([{ urlContext: {} }]);
    expect(out[0].claimStance).toBe("SUPPORTS");
    expect(out[1].claimStance).toBe("UNREADABLE");
  });

  it("a model failure leaves sources UNREADABLE (zero weight), never supporting", async () => {
    const client = fakeClient([new Error("quota")]);
    const out = await classifySourceStances("Claim", [source("a.example", longText("text"))] as any, { client, model: "test" });
    expect(out[0].claimStance).toBe("UNREADABLE");
  });

  it("does not re-judge sources that already carry a stance", async () => {
    const client = fakeClient([]);
    const out = await classifySourceStances("Claim", [source("a.example", undefined, { claimStance: "CONTRADICTS" })] as any, { client, model: "test" });
    expect(out[0].claimStance).toBe("CONTRADICTS");
    expect(client.calls).toHaveLength(0);
  });
});

describe("re-evaluation runs the stance step on new evidence", () => {
  const claim = {
    claim: "The film released in 1988",
    status: "verified_true",
    confidence: 0.9,
    richSources: [source("a.example", undefined, { claimStance: "SUPPORTS" }), source("b.example", undefined, { claimStance: "SUPPORTS" })],
  };

  it("an off-topic new source is dropped and cannot change the verdict", async () => {
    let reAdjudicated = false;
    const res = await reevaluateClaimOnEvidenceChange({
      claim,
      newSources: [...claim.richSources, source("offtopic.example")] as any,
      trigger: "community_evidence",
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: async () => { reAdjudicated = true; return { status: "false_claim", verdictConfidence: 0.9, reasoning: "x" } as any; } },
      classifyStances: async (_c, srcs) => srcs.map((s) => (s.claimStance ? s : { ...s, claimStance: "OFF_TOPIC" as const })),
    });
    const domains = (res.claim.richSources || []).map((s: any) => s.domain);
    expect(domains).not.toContain("offtopic.example");
    expect(reAdjudicated).toBe(false);
    expect(res.claim.status).toBe("verified_true");
  });

  it("a new source that refutes the claim triggers a re-judgment", async () => {
    let reAdjudicated = false;
    await reevaluateClaimOnEvidenceChange({
      claim,
      newSources: [...claim.richSources, source("archive.example")] as any,
      trigger: "community_evidence",
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: async () => { reAdjudicated = true; return { status: "disputed", verdictConfidence: 0.6, reasoning: "x" } as any; } },
      classifyStances: async (_c, srcs) => srcs.map((s) => (s.claimStance ? s : { ...s, claimStance: "CONTRADICTS" as const })),
    });
    expect(reAdjudicated).toBe(true);
  });
});
