import * as admin from "firebase-admin";

// The stance step is a model call; these tests are about URL handling, so every source
// is judged as supporting the claim it was cited for.
jest.mock("../../src/pipeline/services/stanceClassifier", () => ({
  classifySourceStances: async (_claim: string, sources: any[]) =>
    sources.map((s: any) => (s.claimStance ? s : { ...s, claimStance: "SUPPORTS", sourceKind: "INDEPENDENT_REPORTING" })),
  isWeightedStance: (st: string) => st === "SUPPORTS" || st === "CONTRADICTS" || st === "MIXED",
  sourceOwnText: () => "",
}));
import { PIPELINE_CONFIG } from "../../src/pipeline/config";
import {
  ClaimNature,
  EvidenceCatalog,
  FilteredClaim,
  FramingStyle,
  RichSource,
  UrlVerificationRecord,
  VerifiedClaim,
} from "../../src/pipeline/types";
import {
  ClaimVerificationService,
  enforceClosedWorldCitationFirewall,
  isVerifiedRichSource,
} from "../../src/pipeline/services/claimVerification";
import {
  UrlVerificationService,
  DnsLookupFn,
  HttpProbeTransport,
  isClosedWorldCacheEntryValid,
  sanitizeReportPayloadForClosedWorld,
  urlVerificationService,
} from "../../src/pipeline/services/urlVerificationService";
import {
  resolveClosedWorldChatSources,
  sanitizeChatMarkdownLinks,
} from "../../src/pipeline/aiCredibilityChat";
import { ClaimCacheService } from "../../src/pipeline/services/claimCacheService";
import { FirestoreClaimCacheProvider } from "../../src/pipeline/services/claimCacheProvider";
import {
  SourceHealingService,
  sourceHealingService,
} from "../../src/pipeline/services/sourceHealingService";
import { tier0KnowledgeService } from "../../src/pipeline/services/tier0Knowledge";
import { reportBrokenSourceUrl } from "../../src/pipeline/pipelineTriggers";

// These tests exercise the Cite-by-ID mode, which is OFF by default in production
// (config.ts ENFORCE_CITE_BY_ID). Turn it on — and turn off the live fused-grounding
// cascade — for the duration of one test only.
async function withCiteById<T>(fn: () => Promise<T>): Promise<T> {
  const cfg: any = PIPELINE_CONFIG;
  const prevCite = cfg.CLOSED_WORLD_CITATIONS?.ENFORCE_CITE_BY_ID;
  const prevFused = cfg.ENABLE_FUSED_GROUNDING;
  cfg.CLOSED_WORLD_CITATIONS = { ...(cfg.CLOSED_WORLD_CITATIONS || {}), ENFORCE_CITE_BY_ID: true };
  cfg.ENABLE_FUSED_GROUNDING = false;
  try {
    return await fn();
  } finally {
    cfg.CLOSED_WORLD_CITATIONS = { ...cfg.CLOSED_WORLD_CITATIONS, ENFORCE_CITE_BY_ID: prevCite };
    cfg.ENABLE_FUSED_GROUNDING = prevFused;
  }
}

import { clearCache } from "../../src/pipeline/utils/memory-cache";

describe("Unit: Closed-World Citation Firewall, Cite-by-ID & Claim #18 Healing", () => {
  const publicDns: DnsLookupFn = async () => [{ address: "93.184.216.34", family: 4 }];

  const buildVerifiedRecord = (url: string, domain: string): UrlVerificationRecord => ({
    status: "VERIFIED",
    originalUrl: url,
    canonicalUrl: url,
    domain,
    httpStatus: 200,
    redirectHops: 0,
    isSoft404: false,
    verifiedAtUtc: "2026-11-11T00:00:00.000Z",
    verifierMethod: "http_get",
    fetchStatus: "HTTP_200_OK",
  });

  const makeTransport = (
    routes: Record<string, { statusCode: number; html: string }>
  ): HttpProbeTransport => {
    return async (url) => {
      const full = url.toString();
      const hit = Object.entries(routes).find(([k]) => full.includes(k));
      if (!hit) {
        return {
          statusCode: 404,
          headers: { "content-type": "text/html" },
          bodyText: "<html><head><title>404 Not Found</title></head><body>Not found</body></html>",
        };
      }
      return {
        statusCode: hit[1].statusCode,
        headers: { "content-type": "text/html" },
        bodyText: hit[1].html,
      };
    };
  };

  let localSpies: jest.SpyInstance[] = [];

  beforeEach(() => {
    localSpies.push(
      jest.spyOn(tier0KnowledgeService, "getBatchContext").mockResolvedValue([])
    );
  });

  afterEach(() => {
    while (localSpies.length > 0) {
      localSpies.pop()?.mockRestore();
    }
    clearCache();
  });

  it("enforces Cite-by-ID in verifyClaimBatch: hydrates E1, quarantines hallucinated LLM URLs, and handles Telugu Claim #18", async () => {
    const teluguClaim: FilteredClaim = {
      claimId: "claim_18",
      text: "మనం ఎంత ఫాస్ట్ గా వృద్ధాప్యం వైపు వెళుతున్నాము అనేది కొంత మేరకు మనం మార్చుకోవచ్చు",
      nature: ClaimNature.SCIENTIFIC_CLAIM,
      framing: FramingStyle.BALANCED,
      speaker: "Doctor Advices",
      chunkIndex: 0,
      start: 128000,
      end: 138000,
      importance: 0.9,
      confidence: 0.95,
    };

    const verifiedPubmedUrl = "https://pubmed.ncbi.nlm.nih.gov/38900123";
    const mockCatalog: EvidenceCatalog = {
      claimText: teluguClaim.text,
      normalizedQueries: [
        "rate of biological aging lifestyle diet exercise sleep modify",
        "biological age vs chronological age lifestyle intervention",
      ],
      candidatesById: {
        E1: {
          evidenceId: "E1",
          title: "Lifestyle interventions and epigenetic biological aging rate",
          url: verifiedPubmedUrl,
          canonicalUrl: verifiedPubmedUrl,
          domain: "pubmed.ncbi.nlm.nih.gov",
          publisher: "NIH / PubMed",
          snippet:
            "Controlled studies confirm diet, regular exercise, quality sleep, and stress management modulate biological aging rate.",
          tier: "A",
          retrievalProvider: "PubMed",
          retrievalMethod: "pubmed_esearch",
          verification: buildVerifiedRecord(verifiedPubmedUrl, "pubmed.ncbi.nlm.nih.gov"),
          verifiedAcademicMetadata: {
            title: "Lifestyle interventions and epigenetic biological aging rate",
            authors: ["R. Rao"],
            journalName: "Nature Aging",
            yearPublished: 2025,
            doi: "10.1038/s41514-025-0001-9",
            pmid: "38900123",
            retrievalProvider: "PubMed",
          },
        },
      },
      orderedCandidates: [],
      rejectedCandidates: [
        {
          url: "https://news.harvard.edu/gazette/story/fake-biological-aging",
          title: "Harvard Gazette Aging",
          status: "NOT_FOUND",
          reason: "HTTP 404",
          provider: "Google Grounding",
          httpStatus: 404,
        },
      ],
      verifiedAcademicMetadata: [
        {
          title: "Lifestyle interventions and epigenetic biological aging rate",
          authors: ["R. Rao"],
          journalName: "Nature Aging",
          yearPublished: 2025,
          doi: "10.1038/s41514-025-0001-9",
          pmid: "38900123",
          retrievalProvider: "PubMed",
        },
      ],
      retrievedAtUtc: "2026-11-11T00:00:00.000Z",
    };
    mockCatalog.orderedCandidates = [mockCatalog.candidatesById.E1];

    const verifier = new UrlVerificationService({
      dnsLookup: publicDns,
      useFirestoreCache: false,
      transport: makeTransport({
        "pubmed.ncbi.nlm.nih.gov/38900123": {
          statusCode: 200,
          html: "<html><head><title>Lifestyle interventions and aging</title></head><body><p>Biological aging study</p></body></html>",
        },
      }),
    });

    const mockEvidenceRetrieval = {
      buildEvidenceCatalogForClaim: jest.fn().mockResolvedValue(mockCatalog),
    } as any;

    const svc = new ClaimVerificationService("test-key", 0.6, {
      urlVerifier: verifier,
      evidenceRetrieval: mockEvidenceRetrieval,
    });

    // Mock Gemini returning citedEvidenceIds + attempting to smuggle an unverified Mayo Clinic URL in `sources`
    (svc as any).genAI = {
      getGenerativeModel: jest.fn().mockReturnValue({
        generateContent: jest.fn().mockResolvedValue({
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        verifications: [
                          {
                            claimId: "claim_18",
                            claim: teluguClaim.text,
                            nature: "SCIENTIFIC_CLAIM",
                            label: "VERIFIED TRUE",
                            evidenceLevel: "STRONG",
                            rating: 9,
                            confidence: 0.91,
                            citedEvidenceIds: ["E1", "E99"],
                            summary:
                              "Chronological age never stops ticking, but healthy sleep, diet, and exercise can slow biological aging.",
                            verifiedFacts: ["Lifestyle choices measurably influence biological age markers."],
                            sources: [
                              {
                                title: "Mayo Clinic Hallucinated 404",
                                url: "https://www.mayoclinic.org/healthy-lifestyle/adult-health/in-depth/aging/art-20046070",
                                domain: "mayoclinic.org",
                                snippet: "Hallucinated excerpt",
                              },
                            ],
                          },
                        ],
                      }),
                    },
                  ],
                },
              },
            ],
          },
        }),
      }),
    };

    const results = await withCiteById(() => svc.verifyClaimBatch([teluguClaim], "Health", {
      groundingMode: "always",
      forcePro: false,
      minSourcesRequired: 1,
      sourceDiversityRequired: false,
    }));

    expect(results).toHaveLength(1);
    const verified = results[0];

    expect(verified.evidenceSchemaVersion).toBe(PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION);
    expect(verified.richSources).toHaveLength(1);
    expect(verified.richSources?.[0].url).toBe(verifiedPubmedUrl);
    expect(verified.richSources?.[0].urlVerification?.status).toBe("VERIFIED");

    // Hallucinated Mayo URL and catalog-rejected 404 Harvard URL must stay strictly quarantined
    const quarantinedUrls = (verified.quarantinedSources || []).map((q) => q.url);
    expect(quarantinedUrls.some((u) => u.includes("mayoclinic.org"))).toBe(true);
    expect(quarantinedUrls.some((u) => u.includes("news.harvard.edu"))).toBe(true);
    expect(verified.richSources?.some((s) => s.url.includes("mayoclinic.org"))).toBe(false);

    // Verified non-clickable academic metadata is preserved
    expect(verified.verifiedAcademicMetadata?.[0].doi).toBe("10.1038/s41514-025-0001-9");
  });

  it("enforces Decision 1 missing-source state (richSources: [], sourceStatus: 'missing') with zero homepage substitution", async () => {
    const claim: FilteredClaim = {
      claimId: "claim_missing",
      text: "Specific clinical biomarker declines after intervention X",
      nature: ClaimNature.SCIENTIFIC_CLAIM,
      framing: FramingStyle.BALANCED,
      chunkIndex: 0,
      start: 10000,
      end: 15000,
      importance: 0.8,
      confidence: 0.9,
    };

    const emptyCatalog: EvidenceCatalog = {
      claimText: claim.text,
      normalizedQueries: [claim.text],
      candidatesById: {},
      orderedCandidates: [],
      rejectedCandidates: [
        {
          url: "https://www.medicalnewstoday.com/articles/broken-404",
          status: "NOT_FOUND",
          reason: "HTTP 404",
          provider: "Google Grounding",
          httpStatus: 404,
        },
      ],
      verifiedAcademicMetadata: [
        {
          title: "Peer-reviewed study with paywalled/dead landing page",
          doi: "10.1000/test-doi",
          journalName: "Lancet Test",
          yearPublished: 2024,
          retrievalProvider: "Crossref",
        },
      ],
      retrievedAtUtc: "2026-11-11T00:00:00.000Z",
    };

    const verifier = new UrlVerificationService({
      dnsLookup: publicDns,
      useFirestoreCache: false,
      transport: makeTransport({}),
    });

    const svc = new ClaimVerificationService("test-key", 0.6, {
      urlVerifier: verifier,
      evidenceRetrieval: {
        buildEvidenceCatalogForClaim: jest.fn().mockResolvedValue(emptyCatalog),
      } as any,
    });

    (svc as any).genAI = {
      getGenerativeModel: jest.fn().mockReturnValue({
        generateContent: jest.fn().mockResolvedValue({
          response: {
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        verifications: [
                          {
                            claimId: "claim_missing",
                            claim: claim.text,
                            nature: "SCIENTIFIC_CLAIM",
                            label: "UNVERIFIED",
                            evidenceLevel: "STRONG",
                            rating: 8,
                            confidence: 0.85,
                            citedEvidenceIds: [],
                            summary: "Claim explanation.",
                            sources: [
                              { title: "Homepage Fallback", url: "https://www.mayoclinic.org" },
                              { title: "Fake Article", url: "https://news.harvard.edu/gazette/404-page" },
                            ],
                          },
                        ],
                      }),
                    },
                  ],
                },
              },
            ],
          },
        }),
      }),
    };

    const results = await withCiteById(() => svc.verifyClaimBatch([claim], "Health"));
    expect(results).toHaveLength(1);
    expect(results[0].richSources).toEqual([]);
    expect(results[0].sourceStatus).toBe("missing");
    expect(results[0].verifiedAcademicMetadata?.[0].doi).toBe("10.1000/test-doi");
  });

  it("retrieves verified sources & retains academic metadata inside retrieveCitationsForFailedClaims", async () => {
    const failed: VerifiedClaim = {
      claimId: "retry_1",
      text: "Regular aerobic exercise lowers biological aging markers",
      nature: ClaimNature.SCIENTIFIC_CLAIM,
      framing: FramingStyle.BALANCED,
      status: "unverified",
      chunkIndex: 0,
      start: 5000,
      end: 10000,
      importance: 0.8,
      confidence: 0.85,
      verificationConfidence: 0.4,
      reasoning: "Needs citations",
    };

    const nihUrl = "https://pubmed.ncbi.nlm.nih.gov/39000111";
    const mockCatalog: EvidenceCatalog = {
      claimText: failed.text,
      normalizedQueries: [failed.text],
      candidatesById: {
        E1: {
          evidenceId: "E1",
          title: "Aerobic exercise and DNA methylation age",
          url: nihUrl,
          canonicalUrl: nihUrl,
          domain: "pubmed.ncbi.nlm.nih.gov",
          publisher: "NIH / PubMed",
          snippet: "Exercise attenuates epigenetic clock acceleration.",
          tier: "A",
          retrievalProvider: "PubMed",
          retrievalMethod: "pubmed_esearch",
          verification: buildVerifiedRecord(nihUrl, "pubmed.ncbi.nlm.nih.gov"),
          verifiedAcademicMetadata: {
            title: "Aerobic exercise and DNA methylation age",
            doi: "10.1016/j.test.2025.01",
            journalName: "Cell Metabolism",
            yearPublished: 2025,
            retrievalProvider: "PubMed",
          },
        },
      },
      orderedCandidates: [],
      rejectedCandidates: [],
      verifiedAcademicMetadata: [
        {
          title: "Aerobic exercise and DNA methylation age",
          doi: "10.1016/j.test.2025.01",
          journalName: "Cell Metabolism",
          yearPublished: 2025,
          retrievalProvider: "PubMed",
        },
      ],
      retrievedAtUtc: "2026-11-11T00:00:00.000Z",
    };
    mockCatalog.orderedCandidates = [mockCatalog.candidatesById.E1];

    const verifier = new UrlVerificationService({
      dnsLookup: publicDns,
      useFirestoreCache: false,
      transport: makeTransport({}),
    });

    const svc = new ClaimVerificationService("test-key", 0.6, {
      urlVerifier: verifier,
      evidenceRetrieval: {
        buildEvidenceCatalogForClaim: jest.fn().mockResolvedValue(mockCatalog),
      } as any,
    });

    const map = await svc.retrieveCitationsForFailedClaims([failed], "Health");
    const recovered = map.get("retry_1") || [];
    expect(recovered).toHaveLength(1);
    expect(recovered[0].url).toBe(nihUrl);
    expect(recovered[0].doi).toBe("10.1016/j.test.2025.01");
    expect(recovered[0].journalName).toBe("Cell Metabolism");
    expect(failed.verifiedAcademicMetadata?.[0].doi).toBe("10.1016/j.test.2025.01");
  });

  it("blocks broken/unverified URLs in Ask AI chat helpers (resolveClosedWorldChatSources & sanitizeChatMarkdownLinks)", async () => {
    const validUrl = "https://pubmed.ncbi.nlm.nih.gov/38900123";
    const deadUrl = "https://www.mayoclinic.org/broken-article";

    localSpies.push(
      jest.spyOn(urlVerificationService, "verifyBatch").mockResolvedValue(
        new Map<string, UrlVerificationRecord>([
          [validUrl, buildVerifiedRecord(validUrl, "pubmed.ncbi.nlm.nih.gov")],
          [
            deadUrl,
            {
              status: "NOT_FOUND",
              originalUrl: deadUrl,
              canonicalUrl: deadUrl,
              domain: "mayoclinic.org",
              httpStatus: 404,
              redirectHops: 0,
              isSoft404: false,
              verifiedAtUtc: "2026-11-11T00:00:00.000Z",
              verifierMethod: "http_get",
              fetchStatus: "NOT_FOUND",
            },
          ],
        ])
      )
    );

    const admitted = await resolveClosedWorldChatSources([
      { title: "Valid PubMed", url: validUrl, domain: "pubmed.ncbi.nlm.nih.gov" },
      { title: "Dead Mayo", url: deadUrl, domain: "mayoclinic.org" },
      { title: "Homepage Only", url: "https://www.harvard.edu/", domain: "harvard.edu" },
    ]);

    expect(admitted).toHaveLength(1);
    expect(admitted[0].url).toBe(validUrl);

    const cleaned = sanitizeChatMarkdownLinks(
      `Read [PubMed](${validUrl}) or [Mayo Fake](${deadUrl}) and also https://unverified.example.com/fake-path.`,
      admitted
    );
    expect(cleaned).toContain(`[PubMed](${validUrl})`);
    expect(cleaned).toContain("Mayo Fake");
    expect(cleaned).not.toContain(deadUrl);
    expect(cleaned).not.toContain("https://unverified.example.com/fake-path");
  });

  it("enforces DB & Persistence Boundary Invariants (ClaimCacheService, FirestoreClaimCacheProvider, sanitizeReportPayloadForClosedWorld)", async () => {
    const validUrl = "https://pubmed.ncbi.nlm.nih.gov/38900123";
    const validSource: RichSource = {
      title: "Valid PubMed Study",
      url: validUrl,
      domain: "pubmed.ncbi.nlm.nih.gov",
      tier: "A",
      urlVerification: buildVerifiedRecord(validUrl, "pubmed.ncbi.nlm.nih.gov"),
      evidenceAssessment: {
        admissionStatus: "admitted",
        publisherTier: "A",
        publisherVerified: true,
        claimRelevanceScore: 0.9,
        directEvidenceScore: 0.85,
        isPrimaryEvidence: true,
        isIndependent: true,
        retrievedAt: "2026-11-11T00:00:00.000Z",
      },
    };

    const unverifiedSource: RichSource = {
      title: "Legacy Hallucinated Link",
      url: "https://news.harvard.edu/gazette/broken-404",
      domain: "news.harvard.edu",
      tier: "A",
    };

    expect(isVerifiedRichSource(validSource)).toBe(true);
    expect(isVerifiedRichSource(unverifiedSource)).toBe(false);

    // Pre-v2 cache records must never be served as cache hits
    expect(isClosedWorldCacheEntryValid({ richSources: [validSource] })).toBe(false);
    expect(
      isClosedWorldCacheEntryValid({
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        richSources: [unverifiedSource],
      })
    ).toBe(false);
    expect(
      isClosedWorldCacheEntryValid({
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        richSources: [validSource],
      })
    ).toBe(true);

    // In-memory Firestore store spy to assert persistence boundary
    const fakeStore = new Map<string, any>();
    jest.spyOn(admin, "firestore").mockReturnValue({
      collection: () => ({
        doc: (id: string) => ({
          get: async () => ({
            exists: fakeStore.has(id),
            data: () => fakeStore.get(id),
            ref: { delete: async () => fakeStore.delete(id) },
          }),
          set: async (payload: any) => {
            fakeStore.set(id, payload);
          },
          delete: async () => {
            fakeStore.delete(id);
          },
        }),
      }),
    } as any);

    const cacheSvc = new ClaimCacheService();
    const unverifiedClaim: VerifiedClaim = {
      claimId: "c_unverified",
      text: "Claim with only unverified hallucinated link",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: FramingStyle.BALANCED,
      status: "verified_true",
      chunkIndex: 0,
      start: 0,
      end: 5000,
      importance: 0.9,
      confidence: 0.9,
      verificationConfidence: 0.9,
      reasoning: "Explained",
      richSources: [unverifiedSource],
    };

    // Write gate must block unverified claim from polluting Firestore cache
    await cacheSvc.set(unverifiedClaim);
    expect(fakeStore.size).toBe(0);

    // FirestoreClaimCacheProvider write gate & legacy eviction check
    const provider = new FirestoreClaimCacheProvider();
    await provider.cacheVerifiedClaim(unverifiedClaim, 3600);
    expect(fakeStore.size).toBe(0);

    // Seed a legacy v1 record directly and verify read gate treats it as miss & deletes it
    fakeStore.set("legacy_hash", {
      claim: { ...unverifiedClaim, richSources: [unverifiedSource] },
      expiresAt: Date.now() + 60000,
    });
    const cachedLegacy = await provider.getVerifiedClaim("legacy_hash");
    expect(cachedLegacy).toBeNull();
    expect(fakeStore.has("legacy_hash")).toBe(false);

    // Firewall & persistence payload sanitizer
    const firewalled = enforceClosedWorldCitationFirewall(unverifiedClaim);
    expect(firewalled.richSources).toEqual([]);
    expect(firewalled.sourceStatus).toBe("missing");

    const sanitizedReport = sanitizeReportPayloadForClosedWorld({
      credibility: {
        claims: [unverifiedClaim],
        explainability: [
          {
            claimId: "c_unverified",
            sources: [{ title: "Dead", url: unverifiedSource.url }],
          },
        ],
      },
    }) as any;
    expect(sanitizedReport.credibility.claims[0].richSources).toEqual([]);
    expect(sanitizedReport.credibility.explainability[0].sources).toEqual([]);
    expect(sanitizedReport.credibility.explainability[0].sourceStatus).toBe("missing");
  });

  it("retroactively heals Claim #18 broken links (Mayo Clinic, MedicalNewsToday, Harvard Gazette) in SourceHealingService", async () => {
    const nihUrl = "https://pubmed.ncbi.nlm.nih.gov/38900123";
    const verifier = new UrlVerificationService({
      dnsLookup: publicDns,
      useFirestoreCache: false,
      transport: makeTransport({
        "mayoclinic.org/healthy-lifestyle/adult-health": {
          statusCode: 200,
          html: "<html><head><title>Page Not Found - Mayo Clinic</title></head><body><h1>Page Not Found</h1><p>The page you are trying to reach is not available on our site.</p></body></html>",
        },
        "medicalnewstoday.com/articles/biological-age": {
          statusCode: 200,
          html: "<html><head><title>Medical News Today</title></head><body><h1>Oops! Looks like we've hit a bit of a snag.</h1><p>Status: 404 Message: Not Found</p></body></html>",
        },
        "news.harvard.edu/gazette/story/aging": {
          statusCode: 404,
          html: "<html><head><title>404 | The Harvard Gazette</title></head><body><p>This page could not be found.</p></body></html>",
        },
        "pubmed.ncbi.nlm.nih.gov/38900123": {
          statusCode: 200,
          html: "<html><head><title>Biological aging rate - PubMed</title></head><body><p>Peer reviewed article.</p></body></html>",
        },
      }),
    });

    const savedPayloads: any[] = [];
    const mockRepo = {
      loadAnalysis: jest.fn().mockResolvedValue({
        verifiedClaims: [
          {
            claimId: "claim_18",
            text: "మనం ఎంత ఫాస్ట్ గా వృద్ధాప్యం వైపు వెళుతున్నాము అనేది కొంత మేరకు మనం మార్చుకోవచ్చు",
            nature: ClaimNature.SCIENTIFIC_CLAIM,
            status: "verified_true",
            chunkIndex: 0,
            start: 128000,
            end: 138000,
            priority: 1,
            importance: 0.9,
            verificationConfidence: 0.9,
            reasoning: "Lifestyle factors modulate biological aging rate.",
            isCheckable: true,
            richSources: [
              { title: "Mayo", url: "https://www.mayoclinic.org/healthy-lifestyle/adult-health/broken", tier: "A" },
              { title: "MNT", url: "https://www.medicalnewstoday.com/articles/biological-age", tier: "C" },
              { title: "Harvard", url: "https://news.harvard.edu/gazette/story/aging", tier: "A" },
            ],
          },
        ],
        explainability: [
          {
            claimId: "claim_18",
            sources: [
              { title: "Mayo", url: "https://www.mayoclinic.org/healthy-lifestyle/adult-health/broken" },
            ],
          },
        ],
      }),
      saveAnalysis: jest.fn().mockImplementation(async (_vid, _type, payload) => {
        savedPayloads.push(payload);
      }),
    } as any;

    const mockRetrieval = {
      buildEvidenceCatalogForClaim: jest.fn().mockResolvedValue({
        claimText: "aging",
        normalizedQueries: ["biological aging lifestyle"],
        candidatesById: {
          E1: {
            evidenceId: "E1",
            title: "Lifestyle intervention & biological aging - PubMed",
            url: nihUrl,
            canonicalUrl: nihUrl,
            domain: "pubmed.ncbi.nlm.nih.gov",
            publisher: "NIH / PubMed",
            snippet: "Peer reviewed evidence.",
            tier: "A",
            retrievalProvider: "PubMed",
            retrievalMethod: "pubmed_esearch",
            verification: buildVerifiedRecord(nihUrl, "pubmed.ncbi.nlm.nih.gov"),
          },
        },
        orderedCandidates: [
          {
            evidenceId: "E1",
            title: "Lifestyle intervention & biological aging - PubMed",
            url: nihUrl,
            canonicalUrl: nihUrl,
            domain: "pubmed.ncbi.nlm.nih.gov",
            publisher: "NIH / PubMed",
            snippet: "Peer reviewed evidence.",
            tier: "A",
            retrievalProvider: "PubMed",
            retrievalMethod: "pubmed_esearch",
            verification: buildVerifiedRecord(nihUrl, "pubmed.ncbi.nlm.nih.gov"),
          },
        ],
        rejectedCandidates: [],
        verifiedAcademicMetadata: [],
        retrievedAtUtc: "2026-11-11T00:00:00.000Z",
      }),
    } as any;

    jest.spyOn(admin, "firestore").mockReturnValue({
      collection: () => ({
        doc: () => ({
          set: async () => {},
          delete: async () => {},
        }),
      }),
    } as any);

    const healingService = new SourceHealingService({
      urlVerifier: verifier,
      evidenceRetrieval: mockRetrieval,
      analysisRepository: mockRepo,
    });

    const summary = await healingService.auditAndHealVideoReport("vid_doctor_advices", {
      repairWithRetrieval: true,
    });

    expect(summary.healed).toBe(true);
    expect(summary.brokenUrlsRemoved).toBe(3);
    expect(summary.urlsRepaired).toBe(1);
    expect(summary.remainingVerifiedUrls).toBe(1);

    expect(savedPayloads).toHaveLength(1);
    const healedClaim = savedPayloads[0].verifiedClaims[0];
    expect(healedClaim.richSources).toHaveLength(1);
    expect(healedClaim.richSources[0].url).toBe(nihUrl);
    expect(savedPayloads[0].explainability[0].sources).toHaveLength(1);
    expect(savedPayloads[0].explainability[0].sources[0].url).toBe(nihUrl);
  });

  it("deduplicates broken_source_reports and enforces per-video healing cooldown in SourceHealingService.recordBrokenSourceReport", async () => {
    const deadUrl = "https://www.mayoclinic.org/healthy-lifestyle/deleted-page";
    const verifier = new UrlVerificationService({
      dnsLookup: publicDns,
      useFirestoreCache: false,
      transport: makeTransport({
        "www.mayoclinic.org/healthy-lifestyle/deleted-page": {
          statusCode: 404,
          html: "<html><title>404</title></html>",
        },
      }),
    });

    const healSvc = new SourceHealingService({ urlVerifier: verifier });
    const auditSpy = jest.spyOn(healSvc, "auditAndHealVideoReport").mockResolvedValue({
      videoId: "vid_cooldown",
      healed: true,
      claimsAudited: 1,
      brokenUrlsRemoved: 1,
      urlsRepaired: 0,
      remainingVerifiedUrls: 0,
    });
    localSpies.push(auditSpy);

    // Seed video document inside 5-minute cooldown window
    await admin.firestore().collection("videos").doc("vid_cooldown").set({
      lastSourceAuditAt: Date.now(),
    });

    const res1 = await healSvc.recordBrokenSourceReport({
      url: deadUrl,
      videoId: "vid_cooldown",
      claimId: "claim_18",
      reason: "http_404",
      reporterUid: "user_1",
    });
    const res2 = await healSvc.recordBrokenSourceReport({
      url: deadUrl,
      videoId: "vid_cooldown",
      claimId: "claim_18",
      reason: "http_404",
      reporterUid: "user_2",
    });

    expect(res1.accepted).toBe(true);
    expect(res1.verificationStatus).toBe("NOT_FOUND");
    expect(res1.healedVideo).toBe(false);
    expect(res2.healedVideo).toBe(false);
    expect(auditSpy).not.toHaveBeenCalled();

    // Deterministic single deduped document with reportCount === 2
    const reportsSnap = await admin.firestore().collection("broken_source_reports").get();
    expect(reportsSnap.docs).toHaveLength(1);
    expect(reportsSnap.docs[0].data().reportCount).toBe(2);

    // Move lastSourceAuditAt past cooldown -> next report triggers healing once
    await admin.firestore().collection("videos").doc("vid_cooldown").set({
      lastSourceAuditAt: Date.now() - 10 * 60 * 1000,
    });

    const res3 = await healSvc.recordBrokenSourceReport({
      url: deadUrl,
      videoId: "vid_cooldown",
      claimId: "claim_18",
      reason: "http_404",
    });
    expect(res3.healedVideo).toBe(true);
    expect(auditSpy).toHaveBeenCalledTimes(1);
  });

  it("enforces auth/App Check gating and caller rate limiting on reportBrokenSourceUrl", async () => {
    const recordSpy = jest
      .spyOn(sourceHealingService, "recordBrokenSourceReport")
      .mockResolvedValue({
        accepted: true,
        verificationStatus: "NOT_FOUND",
        healedVideo: false,
      });
    localSpies.push(recordSpy);

    await expect(
      (reportBrokenSourceUrl as any).run({
        data: { url: "https://www.mayoclinic.org/broken", videoId: "vid_1" },
      })
    ).rejects.toMatchObject({ code: "unauthenticated" });

    // Authenticated or App Check verified callers pass up to per-minute window (12), then degrade cleanly
    for (let i = 0; i < 12; i++) {
      const ok = await (reportBrokenSourceUrl as any).run({
        auth: { uid: "uid_rate_limit_test" },
        data: { url: "https://www.mayoclinic.org/broken", videoId: "vid_1" },
      });
      expect(ok.accepted).toBe(true);
    }

    const limited = await (reportBrokenSourceUrl as any).run({
      auth: { uid: "uid_rate_limit_test" },
      data: { url: "https://www.mayoclinic.org/broken", videoId: "vid_1" },
    });
    expect(limited).toEqual({
      accepted: false,
      verificationStatus: "RATE_LIMITED",
      healedVideo: false,
    });
    expect(recordSpy).toHaveBeenCalledTimes(12);
  });
});
