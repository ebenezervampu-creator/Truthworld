/**
 * Source-trust hardening (Patch 2) — exploit regressions & unit tests.
 *
 * Covers:
 *  1. Self-serving official statements (press releases, spokespeople) cannot
 *     verify a claim alone without independent corroboration.
 *  2. Syndication text-similarity deduplication: syndicated wire dispatches across
 *     multiple domains collapse into one independent publisher cluster.
 *  3. stanceClassifier hardening: text beyond 3,000 chars is read up to 12,000 chars;
 *     unverified pre-set stances are audited.
 */

import {
  decidePublicVerdict,
  meetsStrongEvidenceBar,
  areSyndicatedCopies,
  countIndependentPublisherClusters,
} from "../../src/pipeline/services/verdictGate";
import {
  classifySourceStances,
} from "../../src/pipeline/services/stanceClassifier";

const live = (url: string) => ({
  status: "VERIFIED",
  httpStatus: 200,
  isSoft404: false,
  originalUrl: url,
  canonicalUrl: url,
  redirectHops: 0,
});

const src = (
  domain: string,
  tier: string,
  claimStance: any = "SUPPORTS",
  sourceKind?: any,
  opts: { text?: string; snippet?: string; path?: string } = {}
) => {
  const url = `https://${domain}${opts.path ?? "/article"}`;
  return {
    title: domain,
    url,
    directUrl: url,
    domain,
    tier,
    ...(claimStance ? { claimStance } : {}),
    ...(sourceKind ? { sourceKind } : {}),
    ...(opts.snippet ? { snippet: opts.snippet } : {}),
    urlVerification: {
      ...live(url),
      ...(opts.text ? { evidenceText: opts.text } : {}),
    },
  };
};

describe("Patch 2: Self-Serving Statement Discounting", () => {
  it("a single Tier A OFFICIAL_STATEMENT alone cannot verify an empirical claim (demoted to UNPROVEN)", () => {
    const singleOfficial = [
      src("ministry.gov.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT", {
        text: "The Ministry of Health announced a 100% cure rate in preliminary trials.",
      }),
    ];

    expect(meetsStrongEvidenceBar(singleOfficial as any, "SUPPORTS")).toBe(false);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: singleOfficial,
    });
    expect(verdict.publicVerdict).toBe("UNPROVEN");
    expect(verdict.demoted).toBe(true);
  });

  it("an OFFICIAL_STATEMENT verified by INDEPENDENT_REPORTING satisfies the strong evidence bar", () => {
    const corroborated = [
      src("ministry.gov.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT"),
      src("reuters.com", "A", "SUPPORTS", "INDEPENDENT_REPORTING"),
    ];

    expect(meetsStrongEvidenceBar(corroborated as any, "SUPPORTS")).toBe(true);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: corroborated,
    });
    expect(verdict.publicVerdict).toBe("VERIFIED");
  });

  it("an OFFICIAL_STATEMENT with a PRIMARY_RECORD satisfies the strong evidence bar", () => {
    const withPrimary = [
      src("ministry.gov.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT"),
      src("sci.gov.in", "A", "SUPPORTS", "PRIMARY_RECORD"),
    ];

    expect(meetsStrongEvidenceBar(withPrimary as any, "SUPPORTS")).toBe(true);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: withPrimary,
    });
    expect(verdict.publicVerdict).toBe("VERIFIED");
  });

  it("two distinct vetted official bodies with non-syndicated statements can verify", () => {
    const twoOfficial = [
      src("ministry.gov.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT", {
        text: "The Ministry of Health statement regarding program rollout and operational statistics.",
      }),
      src("rbi.org.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT", {
        text: "The Reserve Bank of India independent audit findings on macroeconomic allocation.",
      }),
    ];

    expect(meetsStrongEvidenceBar(twoOfficial as any, "SUPPORTS")).toBe(true);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: twoOfficial,
    });
    expect(verdict.publicVerdict).toBe("VERIFIED");
  });

  it("a Tier A PRIMARY_RECORD alone verifies without needing secondary corroboration", () => {
    const primaryRecord = [
      src("sci.gov.in", "A", "SUPPORTS", "PRIMARY_RECORD"),
    ];

    expect(meetsStrongEvidenceBar(primaryRecord as any, "SUPPORTS")).toBe(true);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: primaryRecord,
    });
    expect(verdict.publicVerdict).toBe("VERIFIED");
  });
});

describe("Patch 2: Syndication Text-Similarity Deduplication", () => {
  const wireText = `NEW DELHI: The national meteorological department confirmed today that seasonal rainfall reached 105 percent of the long period average across the subcontinent, marking the second consecutive surplus monsoon year with robust agricultural reservoirs.`;

  it("areSyndicatedCopies detects syndicated wire dispatches across publishers", () => {
    const copyA = wireText;
    const copyB = wireText + " Officials noted crop sowing completed on schedule.";
    expect(areSyndicatedCopies(copyA, copyB)).toBe(true);
  });

  it("areSyndicatedCopies rejects genuinely distinct independent reporting", () => {
    const articleA = `Financial regulators reported that foreign direct investments surged by twenty percent this fiscal quarter, led by substantial capital injections in semiconductor and electronics manufacturing plants.`;
    const articleB = `The state transportation authority announced the completion of the coastal highway corridor expansion, promising to cut commuting duration between southern industrial hubs by half.`;
    expect(areSyndicatedCopies(articleA, articleB)).toBe(false);
  });

  it("two vetted C/D domains carrying identical syndicated wire copy collapse to 1 cluster (UNPROVEN)", () => {
    const syndicatedSources = [
      src("hindustantimes.com", "B", "SUPPORTS", "INDEPENDENT_REPORTING", { text: wireText }),
      src("timesofindia.indiatimes.com", "B", "SUPPORTS", "INDEPENDENT_REPORTING", { text: wireText }),
    ];

    // But wait, hindustantimes and timesofindia are Tier B. Let's test with vetted Tier C/D publishers:
    const cdSyndicated = [
      src("moneycontrol.com", "C", "SUPPORTS", "INDEPENDENT_REPORTING", { text: wireText }),
      src("techcrunch.com", "D", "SUPPORTS", "INDEPENDENT_REPORTING", { text: wireText }),
    ];

    expect(countIndependentPublisherClusters(cdSyndicated as any)).toBe(1);
    expect(meetsStrongEvidenceBar(cdSyndicated as any, "SUPPORTS")).toBe(false);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: cdSyndicated,
    });
    expect(verdict.publicVerdict).toBe("UNPROVEN");
  });

  it("two vetted C/D domains carrying distinct independent reports form 2 clusters (VERIFIED)", () => {
    const independentSources = [
      src("moneycontrol.com", "C", "SUPPORTS", "INDEPENDENT_REPORTING", {
        text: "Financial quarterly audits from domestic exchanges corroborate fiscal compliance across listed firms.",
      }),
      src("techcrunch.com", "D", "SUPPORTS", "INDEPENDENT_REPORTING", {
        text: "Technology enterprise venture fund disclosures independently verify series B capitalization benchmarks.",
      }),
    ];

    expect(countIndependentPublisherClusters(independentSources as any)).toBe(2);
    expect(meetsStrongEvidenceBar(independentSources as any, "SUPPORTS")).toBe(true);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: independentSources,
    });
    expect(verdict.publicVerdict).toBe("VERIFIED");
  });
});

describe("Patch 2: Stance Classifier Hardening", () => {
  it("audits and re-classifies unverified pre-set stances when auditPresets is enabled", async () => {
    const fakeClient = {
      calls: [] as any[],
      models: {
        generateContent: async (req: any) => {
          fakeClient.calls.push(req);
          return {
            text: JSON.stringify([
              {
                sourceIndex: 0,
                stance: "CONTRADICTS",
                sourceKind: "INDEPENDENT_REPORTING",
                reason: "Documented contradiction in text.",
              },
            ]),
          };
        },
      },
    };

    // Source arrives with claimStance: SUPPORTS, but has no claimStanceReason
    const unverifiedSource = src("wire.com", "B", "SUPPORTS", undefined, {
      text: ("Contradictory findings confirmed in long report. ").repeat(25),
    });

    const out = await classifySourceStances(
      "Test Claim",
      [unverifiedSource] as any,
      { client: fakeClient, model: "test", auditPresets: true }
    );

    expect(fakeClient.calls).toHaveLength(1);
    expect(out[0].claimStance).toBe("CONTRADICTS");
    expect(out[0].claimStanceReason).toBe("Documented contradiction in text.");
  });

  it("passes text up to 12,000 characters to the classification model", async () => {
    let capturedPrompt = "";
    const fakeClient = {
      models: {
        generateContent: async (req: any) => {
          capturedPrompt = req.contents;
          return {
            text: JSON.stringify([
              {
                sourceIndex: 0,
                stance: "SUPPORTS",
                sourceKind: "PRIMARY_RECORD",
                reason: "Full passage corroboration.",
              },
            ]),
          };
        },
      },
    };

    // Text of 8,000 characters
    const longArticle = "Paragraph detailing deep investigation evidence and historical data. ".repeat(120);
    expect(longArticle.length).toBeGreaterThan(6000);

    const sourceWithLongText = src("record.gov", "A", null, undefined, {
      text: longArticle,
    });

    await classifySourceStances(
      "Test Claim",
      [sourceWithLongText] as any,
      { client: fakeClient, model: "test" }
    );

    // Previously capped at 3000 chars; now includes deep text well past 5000 chars
    expect(capturedPrompt.length).toBeGreaterThan(6000);
  });
});

describe("Patch 2 Sanity Checks & Robustness", () => {
  it("FALSE path symmetry: a single Tier A OFFICIAL_STATEMENT cannot mark a claim FALSE alone", () => {
    const singleDenial = [
      src("ministry.gov.in", "A", "CONTRADICTS", "OFFICIAL_STATEMENT", {
        text: "The Ministry officially denies the allegations of procurement irregularity.",
      }),
    ];

    expect(meetsStrongEvidenceBar(singleDenial as any, "CONTRADICTS")).toBe(false);

    const verdict = decidePublicVerdict({
      status: "false_claim",
      richSources: singleDenial,
    });
    expect(verdict.publicVerdict).toBe("UNPROVEN");
    expect(verdict.demoted).toBe(true);
  });

  it("FALSE path symmetry: an OFFICIAL_STATEMENT corroborated by INDEPENDENT_REPORTING verifies as FALSE", () => {
    const corroboratedDenial = [
      src("ministry.gov.in", "A", "CONTRADICTS", "OFFICIAL_STATEMENT"),
      src("reuters.com", "A", "CONTRADICTS", "INDEPENDENT_REPORTING"),
    ];

    expect(meetsStrongEvidenceBar(corroboratedDenial as any, "CONTRADICTS")).toBe(true);

    const verdict = decidePublicVerdict({
      status: "false_claim",
      richSources: corroboratedDenial,
    });
    expect(verdict.publicVerdict).toBe("FALSE");
  });

  it("missing sourceKind on .gov domains defaults to OFFICIAL_STATEMENT", () => {
    // Government source with sourceKind left completely undefined
    const govWithNoKind = [
      src("state-dept.gov", "A", "SUPPORTS", undefined, {
        text: "Official press release regarding foreign aid allocation.",
      }),
    ];

    // Defaults to OFFICIAL_STATEMENT, so a single uncorroborated source cannot verify empirical claim
    expect(meetsStrongEvidenceBar(govWithNoKind as any, "SUPPORTS")).toBe(false);

    const verdict = decidePublicVerdict({
      status: "verified_true",
      richSources: govWithNoKind,
    });
    expect(verdict.publicVerdict).toBe("UNPROVEN");
  });

  it("syndication length guard: two short independent snippets under 30 tokens are not falsely merged", () => {
    const shortA = "The central bank held the benchmark interest rate unchanged at 6.5 percent today.";
    const shortB = "The federal reserve kept the benchmark policy rate steady at 6.5 percent today.";
    expect(areSyndicatedCopies(shortA, shortB)).toBe(false);
  });

  it("syndication wire byline detection: detects syndicated pieces sharing wire attribution", () => {
    const wirePTI_A = `NEW DELHI (PTI): Seasonal monsoon rainfall concluded with a nationwide surplus, boosting reservoir levels across central agricultural districts and supporting early winter sowing.`;
    const wirePTI_B = `NEW DELHI: In a release by PTI, seasonal monsoon rainfall concluded with a nationwide surplus, supporting reservoir storage and winter sowing forecasts across key regions.`;
    expect(areSyndicatedCopies(wirePTI_A, wirePTI_B)).toBe(true);
  });

  it("announcement meta-claim exemption: an official statement can verify that an announcement was made", () => {
    const announcementSource = [
      src("ministry.gov.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT"),
    ];

    // Meta-claim about the announcement itself
    const announcementClaim = "Ministry of Health announced new clinical trial guidelines today";
    expect(meetsStrongEvidenceBar(announcementSource as any, "SUPPORTS", announcementClaim)).toBe(true);

    const verdictAnnouncement = decidePublicVerdict({
      status: "verified_true",
      claim: announcementClaim,
      richSources: announcementSource,
    });
    expect(verdictAnnouncement.publicVerdict).toBe("VERIFIED");

    // Empirical claim: official statement alone is not enough
    const empiricalClaim = "The new health guidelines reduced trial failure rates by 50 percent";
    expect(meetsStrongEvidenceBar(announcementSource as any, "SUPPORTS", empiricalClaim)).toBe(false);

    const verdictEmpirical = decidePublicVerdict({
      status: "verified_true",
      claim: empiricalClaim,
      richSources: announcementSource,
    });
    expect(verdictEmpirical.publicVerdict).toBe("UNPROVEN");
  });
});
