/**
 * Verdict Gate — the code-level guarantee behind the published verdict table:
 *
 * | Verdict         | Required evidence                                              |
 * | VERIFIED/FALSE  | ≥1 live Tier A/B source, or ≥2 independent live VETTED C/D,    |
 * |                 | whose OWN content supports (VERIFIED) / refutes (FALSE) it     |
 * | CAUTION         | ≥1 live source with an explicit stance                          |
 * | OPINION_BELIEF  | verbatim subjective quote + timestamp; not falsifiable          |
 * | UNPROVEN        | everything else — fixed message, no generated commentary       |
 */
import {
  applyVerdictGateToClaim,
  applyVerdictGateToReport,
  decidePublicVerdict,
  NO_EVIDENCE_MESSAGE,
} from "../../src/pipeline/services/verdictGate";
import { toInternalAdjudication } from "../../src/pipeline/services/claimVerification";
import { reconcileVerdictWithEvidence } from "../../src/pipeline/services/verdictReconciliation";

const src = (domain: string, tier: string, live = true, claimStance: string | null = "SUPPORTS", sourceKind?: string) => ({
  title: domain,
  url: `https://${domain}/article`,
  domain,
  tier,
  ...(claimStance ? { claimStance } : {}),
  ...(sourceKind ? { sourceKind } : {}),
  urlVerification: {
    status: live ? "VERIFIED" : "NOT_FOUND",
    httpStatus: live ? 200 : 404,
    isSoft404: false,
    originalUrl: `https://${domain}/article`,
    canonicalUrl: `https://${domain}/article`,
    redirectHops: 0,
  },
});

describe("VERIFIED / FALSE need strong, on-point evidence", () => {
  it("one live Tier A or B source whose content supports the claim is enough for VERIFIED", () => {
    for (const tier of ["A", "B"]) {
      expect(decidePublicVerdict({ status: "verified_true", richSources: [src("x.example", tier)] }).publicVerdict).toBe("VERIFIED");
    }
  });

  it("FALSE needs sources whose content REFUTES the claim", () => {
    expect(decidePublicVerdict({ status: "false_claim", richSources: [src("x.example", "B", true, "CONTRADICTS")] }).publicVerdict).toBe("FALSE");
    expect(decidePublicVerdict({ status: "false_claim", richSources: [src("x.example", "B", true, "SUPPORTS")] }).publicVerdict).toBe("UNPROVEN");
  });

  it("one Tier C or D source is not enough; two independent VETTED Tier C/D publishers are", () => {
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("wikipedia.org", "C")] }).publicVerdict).toBe("UNPROVEN");
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("techcrunch.com", "D")] }).publicVerdict).toBe("UNPROVEN");
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("wikipedia.org", "C"), src("techcrunch.com", "D")] }).publicVerdict).toBe("VERIFIED");
    // Two unknown (rule-tiered, unvetted) domains are not two independent publishers.
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("c1.example", "C"), src("d2.example", "D")] }).publicVerdict).toBe("UNPROVEN");
    // Two links from the SAME publisher are one source.
    const same = [src("techcrunch.com", "D"), { ...src("techcrunch.com", "D"), url: "https://techcrunch.com/other" }];
    expect(decidePublicVerdict({ status: "verified_true", richSources: same }).publicVerdict).toBe("UNPROVEN");
  });

  it("unlabelled, off-topic and unreadable sources carry no weight", () => {
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("a.example", "A", true, null)] }).publicVerdict).toBe("UNPROVEN");
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("a.example", "A", true, "OFF_TOPIC")] }).publicVerdict).toBe("UNPROVEN");
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("a.example", "A", true, "UNREADABLE")] }).publicVerdict).toBe("UNPROVEN");
  });

  it("dead links and tier-E sources never count", () => {
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("x.example", "A", false)] }).publicVerdict).toBe("UNPROVEN");
    expect(decidePublicVerdict({ status: "false_claim", richSources: [src("reddit.com", "E")] }).publicVerdict).toBe("UNPROVEN");
  });

  it("an unsupported verdict is replaced by the fixed message with no generated commentary", () => {
    const out = applyVerdictGateToClaim({
      status: "verified_true",
      reasoning: "Karanjeet Kaur is confirmed to be a writer at ThePrint.",
      verifiedFacts: ["She writes for ThePrint"],
      publicNote: "note",
      confidence: 0.95,
      richSources: [],
    });
    expect(out.publicVerdict).toBe("UNPROVEN");
    expect(out.status).toBe("unproven");
    expect(out.reasoning).toBe(NO_EVIDENCE_MESSAGE);
    expect(out.explanation).toBe(NO_EVIDENCE_MESSAGE);
    expect(out.verifiedFacts).toEqual([]);
    expect(out.publicNote).toBeUndefined();
    expect(out.confidence).toBeLessThanOrEqual(0.35);
    expect(out.gateDemotion.from).toBe("verified_true");
  });
});

describe("CAUTION is never a fallback", () => {
  it.each(["misleading", "needs_context", "disputed", "rhetorical_exaggeration", "partially_true"])(
    "'%s' with zero sources becomes UNPROVEN, not CAUTION",
    (status) => {
      expect(decidePublicVerdict({ status, richSources: [] }).publicVerdict).toBe("UNPROVEN");
    }
  );

  it("CAUTION with one live source carries its caution type", () => {
    const d = decidePublicVerdict({ status: "needs_context", richSources: [src("d1.example", "D", true, "MIXED")] });
    expect(d.publicVerdict).toBe("CAUTION");
    expect(d.cautionType).toBe("MISSING_CONTEXT");
  });

  it.each(["inconclusive", "unverified", "unsupported", "verification_timeout", "some_new_label", ""])(
    "unrecognised or undecided status '%s' fails closed to UNPROVEN",
    (status) => {
      expect(decidePublicVerdict({ status, richSources: [src("x.example", "A")] }).publicVerdict).toBe("UNPROVEN");
    }
  );
});

describe("OPINION_BELIEF needs a verbatim subjective quote with a timestamp", () => {
  it("accepts a subjective phrase actually spoken at the claim's timestamp", () => {
    const d = decidePublicVerdict({
      status: "opinion_claim",
      claim: "The Kandahar hijack and 26/11 attacks are seared into public memory",
      transcriptExcerpt: "Kandahar hijack and the 26/11 attacks are seared into public memory. Demonetisation was different.",
      start: 267000,
    });
    expect(d.publicVerdict).toBe("OPINION_BELIEF");
    expect(d.opinionEvidence?.quote).toMatch(/seared into public memory/);
    expect(d.opinionEvidence?.timestampSec).toBe(267);
  });

  it("accepts a model-supplied quote only if it is really in the transcript", () => {
    const base = { status: "opinion_claim", claim: "This is the best film of the decade", transcriptExcerpt: "Honestly I think this is the best film of the decade.", start: 60000 };
    expect(decidePublicVerdict({ ...base, opinionEvidence: { quote: "I think this is the best film of the decade", timestampSec: 60 } }).publicVerdict).toBe("OPINION_BELIEF");
    expect(decidePublicVerdict({ ...base, transcriptExcerpt: "The film was released in theatres." }).publicVerdict).toBe("UNPROVEN");
  });

  it("numbers alone do not make an opinion a fact (falsifiability decides)", () => {
    const years = decidePublicVerdict({
      status: "opinion_claim", falsifiable: false,
      claim: "He has been the best actor for 20 years",
      transcriptExcerpt: "Honestly, he has been the best actor for 20 years.", start: 5000,
    });
    expect(years.publicVerdict).toBe("OPINION_BELIEF");
    const rating = decidePublicVerdict({
      status: "opinion_claim", falsifiable: false,
      claim: "That policy was a 10 out of 10",
      transcriptExcerpt: "That policy was a 10 out of 10 for me.", start: 9000,
    });
    expect(rating.publicVerdict).toBe("OPINION_BELIEF");
  });

  it("rejects an 'opinion' the adjudicator judged falsifiable", () => {
    const d = decidePublicVerdict({
      status: "opinion_claim", falsifiable: true,
      claim: "I think the film was released in 1988",
      transcriptExcerpt: "I think the film was released in 1988", start: 1000,
    });
    expect(d.publicVerdict).toBe("UNPROVEN");
  });

  it("without a falsifiability judgment, an asserted amount or statistic is not an opinion", () => {
    const d = decidePublicVerdict({
      status: "opinion_claim",
      claim: "I think the film earned 500 crore",
      transcriptExcerpt: "I think the film earned 500 crore", start: 1000,
    });
    expect(d.publicVerdict).toBe("UNPROVEN");
  });

  it("rejects an 'opinion' with no subjective phrase (it is a fact claim without evidence)", () => {
    const d = decidePublicVerdict({
      status: "opinion_claim",
      claim: "For the majority of Indians, there is no personal connection with the Kandahar hijack",
      transcriptExcerpt: "For most Indians there is no personal connection with the Kandahar hijack.",
      start: 271000,
    });
    expect(d.publicVerdict).toBe("UNPROVEN");
  });
});

describe("report-level gate", () => {
  it("gates every claim list and recomputes counts so the summary cannot disagree", () => {
    const report: any = applyVerdictGateToReport<any>({
      claims: [
        { status: "verified_true", richSources: [src("a.example", "B")] },
        { status: "verified_true", richSources: [] },
        { status: "misleading", richSources: [] },
        { status: "misleading", richSources: [src("b.example", "D", true, "MIXED")] },
      ],
      explainability: [{ claimId: "x", sources: [] }],
    });
    expect(report.claims.map((c: any) => c.publicVerdict)).toEqual(["VERIFIED", "UNPROVEN", "UNPROVEN", "CAUTION"]);
    expect(report.publicVerdictCounts).toEqual({ VERIFIED: 1, FALSE: 0, CAUTION: 1, OPINION_BELIEF: 0, UNPROVEN: 2 });
    expect(report.explainability[0]).toEqual({ claimId: "x", sources: [] }); // cards without a status are untouched
  });
});

describe("schema-locked model verdicts", () => {
  it("maps the exact enum and fails closed on anything else", () => {
    expect(toInternalAdjudication({ verdict: "VERIFIED", cautionType: "NONE", opinionQuote: "", opinionTimestampSec: -1 }).verdict).toBe("VERIFIED");
    expect(toInternalAdjudication({ verdict: "CAUTION", cautionType: "DISPUTED", opinionQuote: "", opinionTimestampSec: -1 })).toEqual({ verdict: "DISPUTED", cautionType: "DISPUTED" });
    expect(toInternalAdjudication({ verdict: "CAUTION", cautionType: "NONE", opinionQuote: "", opinionTimestampSec: -1 })).toEqual({ verdict: "MISLEADING", cautionType: "MISLEADING" });
    expect(toInternalAdjudication({ verdict: "UNPROVEN", cautionType: "NONE", opinionQuote: "", opinionTimestampSec: -1 }).verdict).toBe("UNVERIFIABLE");
    expect(toInternalAdjudication({ verdict: "MOSTLY_TRUE" as any, cautionType: "NONE", opinionQuote: "", opinionTimestampSec: -1 }).verdict).toBe("UNVERIFIABLE");
    expect(toInternalAdjudication({ verdict: "OPINION_BELIEF", cautionType: "NONE", opinionQuote: "I think", opinionTimestampSec: 12 }).opinionEvidence)
      .toEqual({ quote: "I think", timestampSec: 12 });
  });
});

describe("verified claims and official statements", () => {
  it("a Tier A PRIMARY RECORD is not turned into 'disputed' by lower-tier pushback", () => {
    const sources = [
      { ...src("court.example", "A", true, "SUPPORTS", "PRIMARY_RECORD"), evidentiaryCapacity: 1.0 },
      { ...src("c1.example", "C", true, "CONTRADICTS", "INDEPENDENT_REPORTING"), evidentiaryCapacity: 0.5 },
      { ...src("c2.example", "C", true, "CONTRADICTS", "INDEPENDENT_REPORTING"), evidentiaryCapacity: 0.5 },
    ] as any;
    expect(reconcileVerdictWithEvidence({ proposedStatus: "verified_true", sources }).status).toBe("verified_true");
  });

  it("an OFFICIAL STATEMENT can be disputed by credible independent reporting", () => {
    const sources = [
      { ...src("ministry.example", "A", true, "SUPPORTS", "OFFICIAL_STATEMENT"), evidentiaryCapacity: 1.0 },
      { ...src("regional-paper.example", "C", true, "CONTRADICTS", "INDEPENDENT_REPORTING"), evidentiaryCapacity: 0.5 },
    ] as any;
    expect(reconcileVerdictWithEvidence({ proposedStatus: "verified_true", sources }).status).toBe("disputed");
  });

  it("an official statement with no credible contradiction still verifies", () => {
    const sources = [{ ...src("ministry.example", "A", true, "SUPPORTS", "OFFICIAL_STATEMENT") }] as any;
    expect(reconcileVerdictWithEvidence({ proposedStatus: "verified_true", sources }).status).toBe("verified_true");
  });

  it("a FALSE verdict with one authoritative refuting source stays FALSE", () => {
    expect(reconcileVerdictWithEvidence({ proposedStatus: "false_claim", sources: [src("wire.example", "B", true, "CONTRADICTS")] as any }).status).toBe("false_claim");
  });

  it("a verdict whose only sources are unlabelled is not supported (no inherited stance)", () => {
    expect(reconcileVerdictWithEvidence({ proposedStatus: "verified_true", sources: [src("a.example", "A", true, null)] as any }).status).toBe("unproven");
  });
});

describe("saved reports do not carry fetched page text", () => {
  it("strips urlVerification.evidenceText from every saved source", () => {
    const s = src("a.example", "A") as any;
    s.urlVerification.evidenceText = "x".repeat(3000);
    const out = applyVerdictGateToClaim({ status: "verified_true", richSources: [s], quarantinedSources: [s] });
    expect(out.richSources[0].urlVerification.evidenceText).toBeUndefined();
    expect(out.quarantinedSources[0].urlVerification.evidenceText).toBeUndefined();
    expect(out.richSources[0].urlVerification.status).toBe("VERIFIED");
  });
});
