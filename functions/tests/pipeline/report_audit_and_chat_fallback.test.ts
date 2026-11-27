import * as admin from "firebase-admin";
import { auditCredibilityReport } from "../../src/pipeline/services/reportQualityAudit";
import {
  deduplicateAggregatedSources,
  recordReportQualityAudit,
} from "../../src/pipeline/layers/06-credibility";
import {
  loadAuthoritativeCredibilityContext,
  rankClaimsForChatPrompt,
  rankSourcesForChat,
  resolveClosedWorldChatSources,
} from "../../src/pipeline/aiCredibilityChat";

const liveVerification = (url: string) => ({
  status: "VERIFIED",
  originalUrl: url,
  canonicalUrl: url,
  domain: new URL(url).hostname,
  httpStatus: 200,
  redirectHops: 0,
  isSoft404: false,
  verifiedAtUtc: "2026-11-27T00:00:00.000Z",
  verifierMethod: "http_get",
  fetchStatus: "HTTP_200_OK",
});

describe("Report Quality Audit separation (UNPROVEN vs CAUTION) & Priority Heal (C3)", () => {
  it("counts 26 unproven, 2 caution, 1 verified, 1 false without inflating caution or CAUTION_HEAVY", () => {
    const claims = [
      {
        claimId: "v1",
        status: "verified_true",
        nature: "VERIFIABLE_FACT",
        reasoning: "NASA mission logs confirm Apollo 11 launched July 16, 1969.",
        sources: [
          {
            title: "NASA Apollo 11",
            url: "https://www.nasa.gov/mission/apollo-11/",
            urlVerification: liveVerification("https://www.nasa.gov/mission/apollo-11/"),
          },
        ],
      },
      {
        claimId: "f1",
        status: "false_claim",
        nature: "VERIFIABLE_FACT",
        reasoning: "Surface thruster dust disruption records show regolith disturbance.",
        sources: [
          {
            title: "NASA Lunar Regolith Analysis",
            url: "https://www.nasa.gov/history/alsj/a11/regolith.html",
            urlVerification: liveVerification("https://www.nasa.gov/history/alsj/a11/regolith.html"),
          },
        ],
      },
      {
        claimId: "c1",
        status: "disputed",
        nature: "VERIFIABLE_FACT",
        reasoning: "Engineers debate specific optical exposure glare interpretations.",
        sources: [],
      },
      {
        claimId: "c2",
        status: "needs_context",
        nature: "VERIFIABLE_FACT",
        reasoning: "Additional context about lunar horizon geometry is required.",
        sources: [],
      },
      ...Array.from({ length: 26 }, (_, i) => ({
        claimId: `u_${i + 1}`,
        status: "unproven",
        nature: "VERIFIABLE_FACT",
        reasoning: "No independent live source could confirm this claim yet.",
        sources: [],
      })),
    ];

    const audit = auditCredibilityReport({
      claims,
      sources: claims.flatMap((c) => c.sources),
    });
    const checkIds = audit.checks.map((c) => c.id);

    expect(audit.metrics.factualClaims).toBe(30);
    expect(audit.metrics.verifiedClaims).toBe(1);
    expect(audit.metrics.falseClaims).toBe(1);
    expect(audit.metrics.cautionClaims).toBe(2);
    expect(audit.metrics.unprovenClaims).toBe(26);
    expect(audit.metrics.zeroSourceFacts).toBe(28);
    expect(checkIds).toContain("ZERO_SOURCE_FACTS");
    expect(checkIds).toContain("UNPROVEN_HEAVY");
    expect(checkIds).not.toContain("CAUTION_HEAVY");
    expect(audit.grade).toBe("FAIL");
  });

  it("triggers CAUTION_HEAVY when genuine caution verdicts reach >= 70% of factual claims", () => {
    const claims = Array.from({ length: 10 }, (_, i) => ({
      claimId: `c_${i}`,
      status: i < 8 ? "disputed" : "verified_true",
      nature: "VERIFIABLE_FACT",
      reasoning: i < 8 ? "Experts interpret this metric differently." : "Verified by official registry.",
      sources: [
        {
          title: `Source ${i}`,
          url: `https://example-${i}.org/article`,
          urlVerification: liveVerification(`https://example-${i}.org/article`),
        },
      ],
    }));

    const audit = auditCredibilityReport({
      claims,
      sources: claims.flatMap((c) => c.sources),
    });

    expect(audit.metrics.cautionClaims).toBe(8);
    expect(audit.metrics.unprovenClaims).toBe(0);
    expect(audit.checks.map((c) => c.id)).toContain("CAUTION_HEAVY");
  });

  it("marks FAIL audits with ZERO_SOURCE_FACTS at lastEvidenceCheckAt: 0 for priority freshness sweep (C3)", async () => {
    const writes: Array<{ docId: string; data: any }> = [];
    const setSpy = jest.spyOn(admin.firestore(), "collection").mockImplementation(((col: string) => {
      if (col === "credibility_quality_audits") {
        return {
          doc: (docId: string) => ({
            set: jest.fn(async (data: any) => {
              writes.push({ docId, data });
            }),
          }),
        } as any;
      }
      return { doc: () => ({ set: jest.fn(async () => {}) }) } as any;
    }) as any);

    try {
      const claims = Array.from({ length: 6 }, (_, i) => ({
        claimId: `z_${i}`,
        status: "unproven",
        nature: "VERIFIABLE_FACT",
        reasoning: "Could not confirm with a source yet.",
        sources: [],
      }));
      const audit = await recordReportQualityAudit("job_fail_01", "11111111-1111-4111-8111-111111111111", {
        claims,
        sources: [],
      });
      expect(audit?.grade).toBe("FAIL");
      expect(writes).toHaveLength(1);
      expect(writes[0].docId).toBe("job_fail_01");
      expect(writes[0].data.lastEvidenceCheckAt).toBe(0);
      expect(writes[0].data.reviewStatus).toBe("pending");
    } finally {
      setSpy.mockRestore();
    }
  });
});

describe("Canonical URL deduplication preserving distinct NASA pages & snippets", () => {
  it("merges duplicate canonical URLs (trailing slash / www / hash) while keeping distinct URLs & merging excerpts", () => {
    const deduped = deduplicateAggregatedSources([
      {
        title: "nasa.gov",
        url: "https://www.nasa.gov/mission/apollo-11/#launch",
        snippet: "Apollo 11 launched on July 16, 1969 from Kennedy Space Center.",
        urlVerification: liveVerification("https://www.nasa.gov/mission/apollo-11/"),
      },
      {
        title: "Apollo 11 Mission Overview - NASA",
        url: "https://nasa.gov/mission/apollo-11",
        snippet: "Neil Armstrong and Buzz Aldrin walked on the lunar surface on July 20, 1969.",
      },
      {
        title: "LLRV Training Incidents - NASA History",
        url: "https://www.nasa.gov/history/llrv-training-summary",
        snippet: "Neil Armstrong ejected safely from LLRV-1 in May 1968 before Apollo 11.",
        urlVerification: liveVerification("https://www.nasa.gov/history/llrv-training-summary"),
      },
    ]);

    expect(deduped).toHaveLength(2);
    expect(deduped[0].title).toBe("Apollo 11 Mission Overview - NASA");
    expect(deduped[0].snippet).toContain("launched on July 16, 1969");
    expect(deduped[0].snippet).toContain("walked on the lunar surface");
    expect(deduped[1].title).toBe("LLRV Training Incidents - NASA History");
  });
});

describe("Ask AI Zero-Trust GCS factCheckUrl fallback", () => {
  it("loads claims, sources, and summary from Firebase Storage factCheckUrl when Firestore has empty arrays and ignores tampered client payload", async () => {
    const fakeGcsReport = {
      summary: "Authoritative Apollo 11 historical check confirms 1969 lunar landings.",
      conclusion: {
        summary: "Consensus evidence supports the 1969 Apollo 11 mission.",
        sources: [{ title: "NASA Archive", url: "https://www.nasa.gov/mission/apollo-11/" }],
      },
      claims: [
        {
          claimId: "c1",
          claim: "Apollo 11 launched on July 16, 1969.",
          status: "verified_true",
          reasoning: "Confirmed by NASA Saturn V flight logs.",
          richSources: [
            {
              title: "NASA Apollo 11",
              url: "https://www.nasa.gov/mission/apollo-11/",
              domain: "nasa.gov",
            },
          ],
        },
      ],
      sources: [
        {
          title: "NASA Apollo 11",
          url: "https://www.nasa.gov/mission/apollo-11/",
          domain: "nasa.gov",
        },
      ],
    };

    const mockDb: any = {
      collection: (col: string) => ({
        doc: () => ({
          get: async () => {
            if (col === "videos") {
              return {
                exists: true,
                data: () => ({
                  title: "Moon Landing Dark reality",
                  channelTitle: "SpaceFacts",
                  category: "Science",
                  topics: ["Apollo 11"],
                  factCheckUrl: "gs://truthworld-test.appspot.com/factChecks/job_apollo/latest.json",
                }),
              };
            }
            return { exists: false, data: () => ({}) };
          },
          collection: () => ({
            doc: () => ({ get: async () => ({ exists: false, data: () => ({}) }) }),
            orderBy: () => ({ limit: () => ({ get: async () => ({ empty: true, docs: [] }) }) }),
          }),
        }),
        where: () => ({
          limit: () => ({ get: async () => ({ empty: true, docs: [] }) }),
        }),
      }),
    };

    const storageSpy = jest.spyOn(admin, "storage").mockReturnValue({
      bucket: (name?: string) => ({
        name: name || "truthworld-test.appspot.com",
        file: (objPath: string) => ({
          exists: async () => [objPath === "factChecks/job_apollo/full.json"],
          download: async () => [Buffer.from(JSON.stringify(fakeGcsReport), "utf8")],
        }),
      }),
    } as any);

    try {
      const ctx = await loadAuthoritativeCredibilityContext(
        mockDb,
        "11111111-1111-4111-8111-111111111111",
        {
          videoId: "11111111-1111-4111-8111-111111111111",
          userQuery: "moon landing is really happened?",
          // Tampered client claims/sources must never enter authoritative context
          claims: [{ claim: "TAMPERED FAKE CLAIM", status: "verified_true" }],
          sources: [{ url: "https://tampered.evil.example" }],
        } as any,
        "[test]"
      );

      expect(ctx.existingClaims).toHaveLength(1);
      expect(ctx.existingClaims[0].claim).toBe("Apollo 11 launched on July 16, 1969.");
      expect(ctx.existingClaims.some((c) => String(c.claim).includes("TAMPERED"))).toBe(false);
      expect(ctx.existingSources.some((s) => String(s.url).includes("nasa.gov"))).toBe(true);
      expect(ctx.existingSources.some((s) => String(s.url).includes("tampered.evil"))).toBe(false);
      expect(ctx.summary).toContain("Apollo 11");
    } finally {
      storageSpy.mockRestore();
    }
  });
});

describe("weighted Ask AI claim and source ranking", () => {
  test("surfaces Claim #30 false_claim above 26 earlier unproven claims for Moon Landing prompt", () => {
    const claims: any[] = [];
    for (let i = 1; i <= 26; i++) {
      claims.push({
        claimIndex: i - 1,
        statement: `Unverified tangent point ${i} mentioned briefly in the video`,
        verdict: "unproven",
        confidence: 0.4,
      });
    }
    for (let i = 27; i <= 29; i++) {
      claims.push({
        claimIndex: i - 1,
        statement: `Secondary historical context ${i} about Apollo missions`,
        verdict: "verified_true",
        confidence: 0.8,
      });
    }
    claims.push({
      claimIndex: 29,
      statement: "The 1969 Apollo 11 moon landing was staged on a film set and never happened",
      verdict: "false_claim",
      confidence: 0.95,
      richSources: [
        {
          title: "Apollo 11 Lunar Surface Overview",
          url: "https://www.nasa.gov/mission/apollo-11/",
          domain: "nasa.gov",
          publisher: "NASA",
          tier: "A",
          sourceKind: "PRIMARY_RECORD",
          urlVerification: liveVerification("https://www.nasa.gov/mission/apollo-11/"),
        },
        {
          title: "Moon Landing Evidence and Lunar Reflectors",
          url: "https://www.spacecentre.nz/apollo-11-evidence",
          domain: "spacecentre.nz",
          publisher: "Space Centre",
          tier: "B",
          sourceKind: "REFERENCE",
          urlVerification: liveVerification("https://www.spacecentre.nz/apollo-11-evidence"),
        },
      ],
    });

    const { rankedClaims, counts } = rankClaimsForChatPrompt(
      claims,
      "moon Landing is really happened?",
      15
    );

    expect(counts.total).toBe(30);
    expect(counts.falseCount).toBe(1);
    expect(counts.unproven).toBe(26);
    expect(counts.verified).toBe(3);
    expect(rankedClaims[0].index1).toBe(30);
    expect(rankedClaims[0].claim.verdict).toBe("false_claim");
  });

  test("ranks Tier A PRIMARY_RECORD sources above Tier C/D sources on equal query overlap", () => {
    const tierD = {
      title: "Apollo moon landing conspiracy forum thread",
      url: "https://example-blog.com/moon-landing",
      domain: "example-blog.com",
      publisher: "Random Blog",
      tier: "D",
      urlVerification: liveVerification("https://example-blog.com/moon-landing"),
    };
    const tierC = {
      title: "Apollo moon landing documentary review",
      url: "https://news-outlet.org/apollo-moon-landing",
      domain: "news-outlet.org",
      publisher: "News Outlet",
      tier: "C",
      sourceKind: "INDEPENDENT_REPORTING",
      urlVerification: liveVerification("https://news-outlet.org/apollo-moon-landing"),
    };
    const tierA = {
      title: "Apollo 11 moon landing telemetry and records",
      url: "https://www.nasa.gov/apollo-11-moon-landing",
      domain: "nasa.gov",
      publisher: "NASA",
      tier: "A",
      sourceKind: "PRIMARY_RECORD",
      urlVerification: liveVerification("https://www.nasa.gov/apollo-11-moon-landing"),
    };

    const ranked = rankSourcesForChat(
      [tierD, tierC, tierA],
      "Did the Apollo moon landing happen?",
      []
    );

    expect(ranked[0].domain).toBe("nasa.gov");
    expect(ranked[1].domain).toBe("news-outlet.org");
    expect(ranked[2].domain).toBe("example-blog.com");
  });

  test("boosts explicitly referenced Claim #N to rank #1", () => {
    const claims = Array.from({ length: 30 }, (_, idx) => ({
      claimIndex: idx,
      statement: idx === 27
        ? "Retroreflectors left on the Moon return laser pulses from Earth observatories"
        : `General claim ${idx + 1} about spaceflight`,
      verdict: idx === 0 ? "false_claim" : "verified_true",
      confidence: idx === 0 ? 0.99 : 0.7,
    }));

    const { rankedClaims } = rankClaimsForChatPrompt(claims, "explain claim 28", 15);
    expect(rankedClaims[0].index1).toBe(28);
  });

  test("resolveClosedWorldChatSources admits weighted sources past index 8", async () => {
    const fillerSources = Array.from({ length: 10 }, (_, idx) => ({
      title: `Unrelated filler article ${idx + 1}`,
      url: `https://filler-${idx + 1}.example.com/post`,
      domain: `filler-${idx + 1}.example.com`,
      publisher: `Filler ${idx + 1}`,
      tier: "D",
      urlVerification: liveVerification(`https://filler-${idx + 1}.example.com/post`),
    }));
    const nasaSource = {
      title: "Apollo 11 Moon Landing Mission Records",
      url: "https://www.nasa.gov/apollo-11",
      domain: "nasa.gov",
      publisher: "NASA",
      tier: "A",
      sourceKind: "PRIMARY_RECORD",
      urlVerification: liveVerification("https://www.nasa.gov/apollo-11"),
    };
    const spaceCentreSource = {
      title: "Moon Landing Evidence Overview",
      url: "https://www.spacecentre.nz/moon-landing",
      domain: "spacecentre.nz",
      publisher: "Space Centre",
      tier: "B",
      sourceKind: "REFERENCE",
      urlVerification: liveVerification("https://www.spacecentre.nz/moon-landing"),
    };

    const weighted = rankSourcesForChat(
      [...fillerSources, nasaSource, spaceCentreSource],
      "moon landing",
      []
    );
    const resolved = await resolveClosedWorldChatSources(weighted);
    const domains = resolved.map((s) => s.domain);

    expect(domains).toContain("nasa.gov");
    expect(domains).toContain("spacecentre.nz");
    expect(domains[0]).toBe("nasa.gov");
  });
});
