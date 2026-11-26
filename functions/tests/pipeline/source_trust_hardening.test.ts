/**
 * Source-trust hardening (Patch 1) — exploit regressions.
 *
 * Each test reproduces a way a single cheap or spoofed source could previously push a
 * claim to VERIFIED / FALSE, and pins the fixed behaviour:
 *  1. Page titles never decide trust (grounding redirects, "… - Reuters", "who" → who.int).
 *  2. Unresolved grounding redirects and untiered candidates fall back to Tier D, not B.
 *  3. Gov / academic tiers come from restricted registry suffixes, not look-alike names;
 *     UGC is matched by exact host, so fox.com / netflix.com are not "x.com".
 *  4. Two unknown domains (or two auto-tiered .org sites) cannot verify a claim.
 *  5. A source with no URL-verification record is not live.
 *  6. Conflicting authoritative sources give CAUTION (DISPUTED), never VERIFIED or FALSE.
 */
import {
  sourceTrustService,
  classifyInstitutionalHost,
  isUgcHost,
} from "../../src/pipeline/services/sourceTrustService";
import { evidenceCandidateToRichSource } from "../../src/pipeline/services/urlVerificationService";
import {
  applyVerdictGateToClaim,
  CONFLICTING_EVIDENCE_MESSAGE,
  decidePublicVerdict,
} from "../../src/pipeline/services/verdictGate";
import { ClaimVerificationService } from "../../src/pipeline/services/claimVerification";

const live = (url: string) => ({
  status: "VERIFIED",
  httpStatus: 200,
  isSoft404: false,
  originalUrl: url,
  canonicalUrl: url,
  redirectHops: 0,
});

const src = (host: string, tier: string, claimStance: string | null = "SUPPORTS", opts: { verified?: boolean; path?: string; sourceKind?: any } = {}) => {
  const url = `https://${host}${opts.path ?? "/article"}`;
  return {
    title: host,
    url,
    domain: host,
    tier,
    ...(claimStance ? { claimStance } : {}),
    ...(opts.sourceKind ? { sourceKind: opts.sourceKind } : {}),
    ...(opts.verified === false ? {} : { urlVerification: live(url) }),
  };
};

const GROUNDING_REDIRECT = "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQExample";

describe("1-2. titles never decide trust; unresolved redirects are unknown publishers", () => {
  it.each([
    "WHO says vaccines cause X - Reuters",
    "Exposed: cdc.gov hid the data",
    "Who really runs the world? | Nature",
  ])("an unresolved grounding redirect titled %p is Tier D and unvetted", (title) => {
    const trust = sourceTrustService.resolveSourceTrust(GROUNDING_REDIRECT, "General", title);
    expect(trust.tier).toBe("D");
    expect(trust.isVetted).toBe(false);
    expect(sourceTrustService.isVettedPublisher(GROUNDING_REDIRECT)).toBe(false);
  });

  it("a grounding source is re-tiered from the URL it resolved to, not from its title", () => {
    const svc = new ClaimVerificationService("", 0.6);
    // Pre-live-check tier was guessed from the spoofed title "… - Reuters".
    const spoofed: any = { url: "https://truth-news-24.com/story/1", tier: "A", domain: "reuters.com", publisher: "Reuters" };
    expect(svc.retierFromResolvedUrl(spoofed, "https://truth-news-24.com/story/1")).toBe(true);
    expect(spoofed.tier).toBe("D");
    expect(spoofed.domain).toBe("truth-news-24.com");
    expect(spoofed.publisher).not.toBe("Reuters");

    // A genuine Reuters article keeps its tier.
    const real: any = { url: "https://www.reuters.com/world/x", tier: "D" };
    expect(svc.retierFromResolvedUrl(real, "https://www.reuters.com/world/x")).toBe(true);
    expect(["A", "B"]).toContain(real.tier);

    // A redirect that lands on UGC is rejected.
    const ugc: any = { url: "https://www.reddit.com/r/x/comments/1", tier: "B" };
    expect(svc.retierFromResolvedUrl(ugc, "https://www.reddit.com/r/x/comments/1")).toBe(false);
    expect(ugc.tier).toBe("E");
  });

  it("an evidence candidate with no tier becomes Tier D, not Tier B", () => {
    const rich = evidenceCandidateToRichSource({
      title: "Untitled",
      url: "https://unknown-site.example/a",
      domain: "unknown-site.example",
      snippet: "",
      retrievalProvider: "test",
      retrievalMethod: "test",
    });
    expect(rich.tier).toBe("D");
  });
});

describe("3. institutional tiers come from restricted suffixes only", () => {
  it.each([
    ["truthnews.ac", null], // .ac is an open ccTLD (Ascension Island), not academia
    ["go.com", null],
    ["mil.com", null],
    ["int.com", null],
    ["cdc.gov", "gov"],
    ["www.gov.uk", "gov"],
    ["www.mhlw.go.jp", "gov"],
    ["www.gob.mx", "gov"],
    ["who.int", "gov"],
    ["gov.co", "gov"], // Colombia's official government domain: a true positive
    ["www.ox.ac.uk", "edu"],
    ["www.iitb.ac.in", "edu"],
    ["mit.edu", "edu"],
  ])("%s → %p", (host, expected) => {
    expect(classifyInstitutionalHost(host)).toBe(expected);
  });

  it("a look-alike academic domain does not get Tier B", () => {
    const trust = sourceTrustService.resolveSourceTrust("https://truthnews.ac/claim-confirmed");
    expect(trust.tier).toBe("D");
    expect(trust.isVetted).toBe(false);
  });

  it("go.com / mil.com are not government", () => {
    expect(sourceTrustService.resolveSourceTrust("https://abcnews.go.com/x").tier).not.toBe("A");
    expect(sourceTrustService.resolveSourceTrust("https://mil.com/x").tier).not.toBe("A");
  });

  it.each(["fox.com", "box.com", "dropbox.com", "netflix.com"])("%s is not blocked as x.com", (host) => {
    expect(isUgcHost(host)).toBe(false);
    expect(sourceTrustService.resolveSourceTrust(`https://${host}/a`).tier).not.toBe("E");
  });

  it.each(["x.com", "mobile.twitter.com", "m.youtube.com", "old.reddit.com"])("%s is UGC (Tier E)", (host) => {
    expect(isUgcHost(host)).toBe(true);
    expect(sourceTrustService.resolveSourceTrust(`https://${host}/a`).tier).toBe("E");
  });

  it("an unknown .org is low-weight Tier C but not vetted", () => {
    const trust = sourceTrustService.resolveSourceTrust("https://truth-foundation.org/a");
    expect(trust.tier).toBe("C");
    expect(trust.isVetted).toBe(false);
  });
});

describe("4. unknown domains cannot verify a claim between them", () => {
  it("two unknown Tier D domains → UNPROVEN", () => {
    const d = decidePublicVerdict({
      status: "verified_true",
      richSources: [src("the-real-truth-news24.com", "D"), src("daily-facts-now.com", "D")],
    });
    expect(d.publicVerdict).toBe("UNPROVEN");
  });

  it("two auto-tiered .org sites → UNPROVEN", () => {
    const d = decidePublicVerdict({
      status: "verified_true",
      richSources: [src("truth-foundation.org", "C"), src("facts-institute.org", "C")],
    });
    expect(d.publicVerdict).toBe("UNPROVEN");
  });

  it("the same applies to FALSE", () => {
    const d = decidePublicVerdict({
      status: "false_claim",
      richSources: [src("the-real-truth-news24.com", "D", "CONTRADICTS"), src("daily-facts-now.com", "D", "CONTRADICTS")],
    });
    expect(d.publicVerdict).toBe("UNPROVEN");
  });

  it("two vetted Tier C/D publishers still verify", () => {
    const d = decidePublicVerdict({
      status: "verified_true",
      richSources: [src("en.wikipedia.org", "C"), src("techcrunch.com", "D")],
    });
    expect(d.publicVerdict).toBe("VERIFIED");
  });

  it("two pages on one vetted site are one publisher even without a domain field", () => {
    const a: any = src("techcrunch.com", "D", "SUPPORTS", { path: "/a" });
    const b: any = src("techcrunch.com", "D", "SUPPORTS", { path: "/b" });
    delete a.domain;
    delete b.domain;
    expect(decidePublicVerdict({ status: "verified_true", richSources: [a, b] }).publicVerdict).toBe("UNPROVEN");
  });

  it("an untiered source does not count as Tier D toward the pair", () => {
    const a: any = src("techcrunch.com", "D");
    const b: any = src("theverge.com", "D");
    delete b.tier;
    expect(decidePublicVerdict({ status: "verified_true", richSources: [a, b] }).publicVerdict).toBe("UNPROVEN");
  });
});

describe("5. a source with no URL-verification record is not live", () => {
  it("a Tier A source that was never checked cannot verify", () => {
    const d = decidePublicVerdict({
      status: "verified_true",
      richSources: [src("cdc.gov", "A", "SUPPORTS", { verified: false, sourceKind: "PRIMARY_RECORD" })],
    });
    expect(d.publicVerdict).toBe("UNPROVEN");
  });

  it("the same Tier A source with a live record verifies", () => {
    expect(decidePublicVerdict({ status: "verified_true", richSources: [src("cdc.gov", "A", "SUPPORTS", { sourceKind: "PRIMARY_RECORD" })] }).publicVerdict).toBe("VERIFIED");
  });
});

describe("6. conflicting authoritative sources → CAUTION (DISPUTED)", () => {
  it("VERIFIED with a live Tier A source refuting it becomes DISPUTED", () => {
    const d = decidePublicVerdict({
      status: "verified_true",
      richSources: [src("ndtv.com", "B"), src("cdc.gov", "A", "CONTRADICTS", { sourceKind: "PRIMARY_RECORD" })],
    });
    expect(d.publicVerdict).toBe("CAUTION");
    expect(d.cautionType).toBe("DISPUTED");
    expect(d.status).toBe("disputed");
  });

  it("FALSE with a live Tier B source supporting the claim becomes DISPUTED", () => {
    const d = decidePublicVerdict({
      status: "false_claim",
      richSources: [src("cdc.gov", "A", "CONTRADICTS", { sourceKind: "PRIMARY_RECORD" }), src("ndtv.com", "B", "SUPPORTS")],
    });
    expect(d.publicVerdict).toBe("CAUTION");
    expect(d.cautionType).toBe("DISPUTED");
  });

  it("lower-tier pushback alone does not dispute an authoritative verdict", () => {
    const d = decidePublicVerdict({
      status: "verified_true",
      richSources: [src("cdc.gov", "A", "SUPPORTS", { sourceKind: "PRIMARY_RECORD" }), src("techcrunch.com", "D", "CONTRADICTS")],
    });
    expect(d.publicVerdict).toBe("VERIFIED");
  });

  it("replaces one-sided commentary and is stable when the gate runs again", () => {
    const claim = {
      status: "verified_true",
      reasoning: "This is confirmed by the CDC.",
      whyWrong: "n/a",
      richSources: [src("ndtv.com", "B"), src("cdc.gov", "A", "CONTRADICTS")],
    };
    const once = applyVerdictGateToClaim(claim);
    expect(once.publicVerdict).toBe("CAUTION");
    expect(once.cautionType).toBe("DISPUTED");
    expect(once.status).toBe("disputed");
    expect(once.reasoning).toBe(CONFLICTING_EVIDENCE_MESSAGE);
    expect(once.whyWrong).toBeUndefined();
    expect(once.gateDemotion?.from).toBe("verified_true");

    const twice = applyVerdictGateToClaim(once);
    expect(twice.publicVerdict).toBe("CAUTION");
    expect(twice.cautionType).toBe("DISPUTED");
    expect(twice.status).toBe("disputed");
  });
});
