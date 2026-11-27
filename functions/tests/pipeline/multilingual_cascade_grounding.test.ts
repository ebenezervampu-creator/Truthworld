/**
 * Tasks 2 & 3: Option 1 Slim Multilingual Tier 2, Domain-Wide $0 Pre-Retrieval,
 * BigQuery Writeback, ccTLD Domain Inference, Real Redirect Unwrapping,
 * Real Pre-Retrieval Tiers, Stance Match & Option A Single-Claim Retry.
 */

import * as admin from "firebase-admin";
import {
  BigQueryAnalyticsService,
  setBigQueryAnalyticsService,
} from "../../src/analytics/bigqueryService";
import { DeterministicRegistryService } from "../../src/pipeline/services/deterministicRegistry";
import { tier0KnowledgeService } from "../../src/pipeline/services/tier0Knowledge";
import {
  batchResolveMultilingualCanonical,
  gatherDomainWidePreRetrieval,
} from "../../src/pipeline/services/multilingualPreRetrievalService";
import { VerificationCascadeService } from "../../src/pipeline/services/verificationCascadeService";
import { ClaimCacheService } from "../../src/pipeline/services/claimCacheService";
import { FusedGroundingService } from "../../src/pipeline/services/fusedGroundingService";
import { sourceTrustService } from "../../src/pipeline/services/sourceTrustService";
import { urlVerificationService } from "../../src/pipeline/services/urlVerificationService";
import {
  applyVerdictGateToClaim,
  decidePublicVerdict,
  resolveEffectiveSourceKind,
} from "../../src/pipeline/services/verdictGate";
import { wikipediaAdapter } from "../../src/pipeline/providers/wikipediaAdapter";
import { wikidataAdapter } from "../../src/pipeline/providers/wikidataAdapter";
import { pubmedAdapter } from "../../src/pipeline/providers/pubmedAdapter";
import { crossrefAdapter } from "../../src/pipeline/providers/crossrefAdapter";
import { worldBankAdapter } from "../../src/pipeline/providers/worldBankAdapter";
import { fredAdapter } from "../../src/pipeline/providers/fredAdapter";
import * as aiClient from "../../src/pipeline/utils/ai-client";
import {
  ClaimNature,
  ClaimStrength,
  FilteredClaim,
  FramingStyle,
  VerifiedSource,
} from "../../src/pipeline/types";
import { PIPELINE_CONFIG } from "../../src/pipeline/config";

function makeClaim(claimId: string, text: string, overrides: Partial<FilteredClaim> = {}): FilteredClaim {
  return {
    claimId,
    text,
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    confidence: 0.9,
    importance: 0.8,
    chunkIndex: 0,
    start: 1000,
    end: 5000,
    speaker: "Host",
    claimStrength: "strong" as ClaimStrength,
    ...overrides,
  };
}

describe("Tasks 2 & 3: Multilingual Cascade, Domain-Wide Pre-Retrieval & Tier 4 Hardening", () => {
  const activeSpies: jest.SpyInstance[] = [];
  const trackSpy = <T extends jest.SpyInstance>(s: T): T => {
    activeSpies.push(s);
    return s;
  };

  beforeEach(() => {
    ClaimCacheService.clearL1Cache();
    sourceTrustService.resetDynamicOverrides();
    // Keep BigQuery disabled by default unless test enables a mock service
    setBigQueryAnalyticsService(new BigQueryAnalyticsService({ enabled: false, flushIntervalMs: 0 }));
  });

  afterEach(() => {
    while (activeSpies.length > 0) {
      activeSpies.pop()?.mockRestore();
    }
    (FusedGroundingService as any)._vertexAI = undefined;
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TASK 2: SLIM MULTILINGUAL TIER 2, PRE-RETRIEVAL & WRITEBACK
  // ──────────────────────────────────────────────────────────────────────────
  describe("Task 2.1: Expanded Apollo 11 Deterministic Registry & Multilingual Normalization", () => {
    it("resolves bilingual Telugu + English Apollo 11 claims via normalized English in Tier 2 and passes VerdictGate", async () => {
      const teluguLaunch = "[అపోలో 11 / Apollo 11] రాకెట్ 1969 జూలై 16న చంద్రుడి మీదకి బయలుదేరింది";
      const englishLanding = "Apollo 11 landed on the moon in 1969";

      const mockVertex = {
        getGenerativeModel: jest.fn().mockReturnValue({
          generateContent: jest.fn().mockResolvedValue({
            response: {
              candidates: [
                {
                  content: {
                    parts: [
                      {
                        text: JSON.stringify({
                          translations: [
                            {
                              claimId: "c_te_launch",
                              englishCanonical: "Apollo 11 launched to the moon on July 16, 1969",
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
      } as any;

      const canonicalMap = await batchResolveMultilingualCanonical(
        [makeClaim("c_te_launch", teluguLaunch), makeClaim("c_en_land", englishLanding)],
        { vertexAI: mockVertex }
      );

      expect(mockVertex.getGenerativeModel).toHaveBeenCalledTimes(1);
      const canonicalLaunch = canonicalMap.get("c_te_launch")!;
      expect(canonicalLaunch).toBe("Apollo 11 launched to the moon on July 16, 1969");

      const launchMatch = DeterministicRegistryService.resolveDeterministicFact(canonicalLaunch);
      expect(launchMatch).not.toBeNull();
      expect(launchMatch?.status).toBe("verified_true");
      expect(launchMatch?.richSources[0].claimStance).toBe("SUPPORTS");
      expect(["REFERENCE", "PRIMARY_RECORD"]).toContain(launchMatch?.richSources[0].sourceKind);

      // Passes verdict gate cleanly without being demoted to UNPROVEN
      const gatedLaunch = applyVerdictGateToClaim({
        claimId: "c_te_launch",
        text: teluguLaunch,
        status: launchMatch!.status,
        richSources: launchMatch!.richSources,
      });
      expect(gatedLaunch.publicVerdict).toBe("VERIFIED");

      // Other settled Apollo 11 facts
      expect(DeterministicRegistryService.resolveDeterministicFact(englishLanding)?.status).toBe("verified_true");
      expect(DeterministicRegistryService.resolveDeterministicFact("The Apollo 11 mission lasted about 8 days.")?.status).toBe("verified_true");
      expect(DeterministicRegistryService.resolveDeterministicFact("The distance from Earth to the Moon is approximately 384,400 km.")?.status).toBe("verified_true");
      expect(DeterministicRegistryService.resolveDeterministicFact("The Moon is around 400,000 km from Earth.")?.status).toBe("verified_true");

      // Wrong Apollo 11 values give false_claim
      expect(DeterministicRegistryService.resolveDeterministicFact("Apollo 11 launched on July 18, 1969.")?.status).toBe("false_claim");
      expect(DeterministicRegistryService.resolveDeterministicFact("Apollo 11 mission lasted 30 days.")?.status).toBe("false_claim");
      expect(DeterministicRegistryService.resolveDeterministicFact("The distance from Earth to the Moon is 10,000 km.")?.status).toBe("false_claim");

      // Tier 0 pre-indexed match also stamps explicit claimStance + sourceKind
      const t0Match = tier0KnowledgeService.lookupPreIndexedFact(englishLanding);
      expect(t0Match?.status).toBe("verified_true");
      expect(t0Match?.claimStance).toBe("SUPPORTS");
      expect(["REFERENCE", "PRIMARY_RECORD"]).toContain(t0Match?.sourceKind);
    });

    it("preserves anti-poisoning rules for Apollo 11 conspiracy / wrong-planet claims", () => {
      for (const poisoned of [
        "Apollo 11 was faked in 1969",
        "Apollo 11 landed on Mars in July 1969",
        "Apollo 11 did not land on the moon",
        "Apollo 11 launch was a hoax in 1969",
      ]) {
        expect(DeterministicRegistryService.resolveDeterministicFact(poisoned)).toBeNull();
        expect(tier0KnowledgeService.lookupPreIndexedFact(poisoned)).toBeNull();
      }
    });
  });

  describe("Task 2.2: Tier Routing Past-Year Gate", () => {
    it("does NOT mark settled past years (2014, 1969, 2024) volatile, while keeping live/current-year volatile", () => {
      const modi2014 = VerificationCascadeService.analyzeClaimForTierRouting("Narendra Modi was elected Prime Minister in 2014.");
      expect(modi2014.isTimeSensitive).toBe(false);
      expect(modi2014.recommendedTier).toBe(1);

      const apollo1969 = VerificationCascadeService.analyzeClaimForTierRouting("Apollo 11 landed on the Moon on July 20, 1969.");
      expect(apollo1969.isTimeSensitive).toBe(false);

      const liveMarket = VerificationCascadeService.analyzeClaimForTierRouting("India's inflation today is currently 5.4% in 2026.");
      expect(liveMarket.isTimeSensitive).toBe(true);
      expect(liveMarket.recommendedTier).toBe(4);
    });
  });

  describe("Task 2.3: Domain-Wide $0 Pre-Retrieval Without Duplicate Translation", () => {
    it("runs Wikipedia + Wikidata across History/General/Space claims and reuses preResolvedEnglishMap", async () => {
      const wikiSpy = trackSpy(jest.spyOn(wikipediaAdapter, "searchPassages")).mockImplementation(async (q, opts) => [
        {
          title: opts?.lang === "te" ? "అపోలో 11" : "Apollo 11",
          url: `https://${opts?.lang || "en"}.wikipedia.org/wiki/Apollo_11`,
          extract: `Verified passage for ${q} covering the July 1969 Moon landing.`,
        },
      ]);
      const wikidataSpy = trackSpy(jest.spyOn(wikidataAdapter, "searchEntities")).mockResolvedValue([
        {
          title: "Wikidata Knowledge: Apollo 11",
          url: "https://www.wikidata.org/wiki/Q43653",
          passage: "Apollo 11 (Q43653) crewed spaceflight mission launched July 16, 1969.",
          entityId: "Q43653",
        },
      ]);
      const pubmedSpy = trackSpy(jest.spyOn(pubmedAdapter, "searchAbstracts")).mockResolvedValue([]);
      const crossrefSpy = trackSpy(jest.spyOn(crossrefAdapter, "searchWorks")).mockResolvedValue([]);
      const wbSpy = trackSpy(jest.spyOn(worldBankAdapter, "searchIndicators")).mockResolvedValue([]);
      const fredSpy = trackSpy(jest.spyOn(fredAdapter, "searchObservations")).mockResolvedValue([]);
      const vertexSpy = trackSpy(jest.spyOn(aiClient, "getVertexAI"));

      const claims = [
        makeClaim("c_hist", "అపోలో 11 స్పేస్‌క్రాఫ్ట్ జూలై 1969లో ప్రయోగించబడింది", {
          domain: "History",
        } as any),
      ];
      const preResolved = new Map<string, string>([
        ["c_hist", "Apollo 11 spacecraft launched in July 1969"],
      ]);

      const evidence = await gatherDomainWidePreRetrieval(claims, preResolved);

      expect(vertexSpy).not.toHaveBeenCalled();
      expect(wikiSpy).toHaveBeenCalledWith("Apollo 11 spacecraft launched in July 1969", expect.objectContaining({ lang: "en" }));
      expect(wikiSpy).toHaveBeenCalledWith(claims[0].text, expect.objectContaining({ lang: "te" }));
      expect(wikidataSpy).toHaveBeenCalledTimes(1);
      expect(pubmedSpy).not.toHaveBeenCalled();
      expect(crossrefSpy).not.toHaveBeenCalled();
      expect(wbSpy).not.toHaveBeenCalled();
      expect(fredSpy).not.toHaveBeenCalled();

      expect(evidence.length).toBeGreaterThanOrEqual(2);
      expect(evidence.some((e) => e.uri.includes("wikipedia.org"))).toBe(true);
      expect(evidence.some((e) => e.uri.includes("wikidata.org"))).toBe(true);
    });
  });

  describe("Task 2.4: Cascade Tier 1 Skip + Tier 2/4 BigQuery Writeback", () => {
    it("skips Tiers 2-4 completely on Tier 1 hit and enqueues newly verified Tier 2 & Tier 4 claims to BigQuery", async () => {
      const enqueueMock = jest.fn();
      const fakeBq = new BigQueryAnalyticsService({ enabled: true, flushIntervalMs: 0 }, { query: jest.fn() } as any);
      fakeBq.enqueueVerifiedClaim = enqueueMock;
      setBigQueryAnalyticsService(fakeBq);

      const cacheHitClaim = makeClaim("c_cached", "Narendra Modi was elected PM in 2014.");
      const tier2Claim = makeClaim("c_det", "Water boils at 100 degrees Celsius at sea level.");
      const tier4Claim = makeClaim("c_t4", "The James Webb Space Telescope launched in December 2021.");

      trackSpy(jest.spyOn(ClaimCacheService.prototype, "getBatch")).mockResolvedValueOnce(
        new Map([
          [
            cacheHitClaim.text,
            {
              status: "verified_true",
              reasoning: "ECI records confirm 2014 election victory.",
              verificationConfidence: 0.98,
              richSources: [
                {
                  title: "ECI Archives",
                  url: "https://eci.gov.in/2014",
                  domain: "eci.gov.in",
                  tier: "A",
                  claimStance: "SUPPORTS",
                  sourceKind: "PRIMARY_RECORD",
                  urlVerification: {
                    status: "VERIFIED",
                    originalUrl: "https://eci.gov.in/2014",
                    canonicalUrl: "https://eci.gov.in/2014",
                    domain: "eci.gov.in",
                    httpStatus: 200,
                    redirectHops: 0,
                    isSoft404: false,
                    verifiedAtUtc: new Date().toISOString(),
                    verifierMethod: "http_get",
                    fetchStatus: "HTTP_200_OK",
                  },
                },
              ],
            },
          ],
        ])
      );

      trackSpy(jest.spyOn(wikipediaAdapter, "searchPassages")).mockResolvedValue([]);
      trackSpy(jest.spyOn(wikidataAdapter, "searchEntities")).mockResolvedValue([]);

      const verifyFusedSpy = trackSpy(jest.spyOn(FusedGroundingService, "verifyBatchFused")).mockResolvedValue([
        {
          ...tier4Claim,
          status: "verified_true",
          verificationConfidence: 0.96,
          reasoning: "NASA confirms JWST launched on December 25, 2021.",
          sources: ["https://science.nasa.gov/mission/webb/"],
          richSources: [
            {
              title: "NASA Webb Mission",
              url: "https://science.nasa.gov/mission/webb/",
              domain: "nasa.gov",
              tier: "A",
              claimStance: "SUPPORTS",
              sourceKind: "REFERENCE",
              urlVerification: {
                status: "VERIFIED",
                originalUrl: "https://science.nasa.gov/mission/webb/",
                canonicalUrl: "https://science.nasa.gov/mission/webb/",
                domain: "nasa.gov",
                httpStatus: 200,
                redirectHops: 0,
                isSoft404: false,
                verifiedAtUtc: new Date().toISOString(),
                verifierMethod: "http_get",
                fetchStatus: "HTTP_200_OK",
              },
            },
          ],
          isGrounded: true,
          verificationMethod: "grounded",
        },
      ]);

      const results = await VerificationCascadeService.executeCascade(
        "vid_123",
        [cacheHitClaim, tier2Claim, tier4Claim],
        "Science"
      );

      expect(results).toHaveLength(3);
      expect(results[0].verificationMethod).toBe("cache_hit");
      expect(results[1].verificationMethod).toBe("deterministic");
      expect(results[2].verificationMethod).toBe("grounded");

      // Tier 4 was called ONLY for tier4Claim (never for cacheHitClaim or tier2Claim)
      expect(verifyFusedSpy).toHaveBeenCalledTimes(1);
      expect(verifyFusedSpy.mock.calls[0][0].map((c) => c.claimId)).toEqual(["c_t4"]);

      // Both Tier 2 and Tier 4 newly verified claims (NOT cache_hit) were enqueued to BigQuery
      expect(enqueueMock).toHaveBeenCalledTimes(2);
      const enqueuedIds = enqueueMock.mock.calls.map((call) => call[0].claim_id);
      expect(enqueuedIds).toEqual(expect.arrayContaining(["c_det", "c_t4"]));
      expect(enqueuedIds).not.toContain("c_cached");
      for (const call of enqueueMock.mock.calls) {
        expect(call[0].evidence_schema_version).toBe(PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION);
        expect(call[0].rich_sources_json).toBeTruthy();
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TASK 3: ccTLD DOMAIN INFERENCE, REDIRECT UNWRAPPING, TIERS, STANCE, RETRY
  // ──────────────────────────────────────────────────────────────────────────
  describe("Task 3.1: ccTLD Domain Inference & File Extension Filtering", () => {
    it("extracts valid ccTLDs (.nz, .co.uk, .au) while rejecting file extensions", () => {
      expect(sourceTrustService.inferDomainFromTitle("Apollo 11 Exhibit - spacecentre.nz")).toBe("spacecentre.nz");
      expect(sourceTrustService.inferDomainFromTitle("News Report | bbc.co.uk")).toBe("bbc.co.uk");
      expect(sourceTrustService.inferDomainFromTitle("CSIRO Research - csiro.au")).toBe("csiro.au");

      expect(sourceTrustService.inferDomainFromTitle("photo.png")).toBeNull();
      expect(sourceTrustService.inferDomainFromTitle("document.pdf")).toBeNull();
      expect(sourceTrustService.inferDomainFromTitle("clip.mp4")).toBeNull();
      expect(sourceTrustService.inferDomainFromTitle("data.json")).toBeNull();
      expect(sourceTrustService.inferDomainFromTitle("index.html")).toBeNull();
      expect(sourceTrustService.inferDomainFromTitle("bundle.js and style.css")).toBeNull();
    });
  });

  describe("Task 3.2: FusedGroundingService Redirect Unwrapping, Real Snippets & Dynamic Tiers", () => {
    it("unwraps vertexaisearch redirects via urlVerificationService, preserves uv.excerpt, and quarantines dead links", async () => {
      const liveRedirect = "https://vertexaisearch.cloud.google.com/grounding-api-redirect/LIVE_NZ";
      const deadRedirect = "https://vertexaisearch.cloud.google.com/grounding-api-redirect/DEAD_404";

      const mockModel = {
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
                            claimId: "c_live",
                            verdict: "verified_true",
                            evidenceLevel: "STRONG",
                            summary: "AI summary should never overwrite snippet.",
                            keyFacts: ["Apollo 11 launched July 16, 1969."],
                            missingEvidence: "",
                            supportingChunkIndices: [0],
                            contradictingChunkIndices: [],
                            sourceKind: "REFERENCE",
                          },
                          {
                            claimId: "c_dead",
                            verdict: "verified_true",
                            evidenceLevel: "STRONG",
                            summary: "Dead link claim should fail closed.",
                            keyFacts: [],
                            missingEvidence: "",
                            supportingChunkIndices: [1],
                            contradictingChunkIndices: [],
                          },
                        ],
                      }),
                    },
                  ],
                },
                groundingMetadata: {
                  groundingChunks: [
                    { web: { uri: liveRedirect, title: "Apollo 11 | spacecentre.nz" } },
                    { web: { uri: deadRedirect, title: "Broken Site | example.org" } },
                  ],
                  groundingSupports: [],
                },
              },
            ],
          },
        }),
      };
      (FusedGroundingService as any)._vertexAI = {
        getGenerativeModel: jest.fn().mockReturnValue(mockModel),
      };

      const verifyBatchSpy = trackSpy(jest.spyOn(urlVerificationService, "verifyBatch")).mockResolvedValue(
        new Map([
          [
            liveRedirect,
            {
              status: "VERIFIED",
              originalUrl: liveRedirect,
              canonicalUrl: "https://spacecentre.nz/apollo-11-exhibit",
              domain: "spacecentre.nz",
              httpStatus: 200,
              redirectHops: 1,
              isSoft404: false,
              contentTitle: "Apollo 11 Exhibit - Space Centre NZ",
              excerpt: "On July 16, 1969, Apollo 11 launched aboard Saturn V from Kennedy Space Center.",
              evidenceText: "On July 16, 1969, Apollo 11 launched aboard Saturn V from Kennedy Space Center. ".repeat(4),
              verifiedAtUtc: new Date().toISOString(),
              verifierMethod: "grounding_resolved",
              fetchStatus: "HTTP_200_OK",
            },
          ],
          [
            deadRedirect,
            {
              status: "NOT_FOUND",
              originalUrl: deadRedirect,
              canonicalUrl: "https://example.org/missing-404",
              domain: "example.org",
              httpStatus: 404,
              redirectHops: 1,
              isSoft404: false,
              verifiedAtUtc: new Date().toISOString(),
              verifierMethod: "http_get",
              fetchStatus: "NOT_FOUND",
              errorReason: "HTTP 404",
            },
          ],
        ])
      );

      // Wikipedia pre-retrieved hit must get Tier C (not hardcoded A); PubMed gets Tier A
      const preRetrieved: VerifiedSource[] = [
        {
          evidenceId: "E1",
          title: "Apollo 11 - Wikipedia",
          uri: "https://en.wikipedia.org/wiki/Apollo_11",
          snippet: "Apollo 11 was the American spaceflight that first landed humans on the Moon in July 1969.",
          sourceProvider: "WIKIPEDIA",
          claimIds: ["c_live"],
        },
        {
          evidenceId: "E2",
          title: "Apollo Mission Medical Telemetry - PubMed",
          uri: "https://pubmed.ncbi.nlm.nih.gov/12345678/",
          snippet: "NASA telemetry records from Apollo 11 mission July 1969.",
          sourceProvider: "PUBMED",
          claimIds: ["c_live"],
        },
      ];

      const mockStanceClient = {
        models: {
          generateContent: jest.fn().mockResolvedValue({
            text: JSON.stringify([
              { sourceIndex: 0, stance: "SUPPORTS", sourceKind: "REFERENCE", reason: "Confirms July 16 launch." },
            ]),
          }),
        },
      };

      const claims = [
        makeClaim("c_live", "Apollo 11 launched on July 16, 1969."),
        makeClaim("c_dead", "Dead redirect claim."),
      ];

      const results = await FusedGroundingService.verifyBatchFused(claims, "Space", {
        preRetrievedEvidence: preRetrieved,
        stanceClient: mockStanceClient,
      });

      expect(verifyBatchSpy).toHaveBeenCalledTimes(1);

      const liveClaim = results.find((r) => r.claimId === "c_live")!;
      const nzSource = liveClaim.richSources!.find((s) => s.domain === "spacecentre.nz")!;
      expect(nzSource).toBeDefined();
      expect(nzSource.url).toBe("https://spacecentre.nz/apollo-11-exhibit");
      expect(nzSource.snippet).toBe("On July 16, 1969, Apollo 11 launched aboard Saturn V from Kennedy Space Center.");
      expect(nzSource.snippet).not.toBe("AI summary should never overwrite snippet.");

      const wikiSource = liveClaim.richSources!.find((s) => s.domain === "wikipedia.org")!;
      expect(wikiSource.tier).toBe("C");

      const pubmedSource = liveClaim.richSources!.find((s) => s.domain === "nih.gov" || s.url.includes("pubmed"))!;
      expect(pubmedSource.tier).toBe("A");

      const deadClaim = results.find((r) => r.claimId === "c_dead")!;
      expect(deadClaim.richSources).toHaveLength(0);
      expect(deadClaim.quarantinedSources?.length).toBe(1);
      expect(deadClaim.status).toBe("unproven");
    });

    it("honors disputed/misleading verdicts and contradictingChunkIndices instead of forcing SUPPORTS", async () => {
      const url0 = "https://www.reuters.com/world/support-story";
      const url1 = "https://apnews.com/article/counter-story";

      const mockModel = {
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
                            claimId: "c_disputed",
                            verdict: "disputed",
                            evidenceLevel: "MODERATE",
                            summary: "Sources disagree on this figure.",
                            supportingChunkIndices: [0],
                            contradictingChunkIndices: [1],
                          },
                        ],
                      }),
                    },
                  ],
                },
                groundingMetadata: {
                  groundingChunks: [
                    { web: { uri: url0, title: "Reuters Story" } },
                    { web: { uri: url1, title: "AP Counter Story" } },
                  ],
                  groundingSupports: [],
                },
              },
            ],
          },
        }),
      };
      (FusedGroundingService as any)._vertexAI = {
        getGenerativeModel: jest.fn().mockReturnValue(mockModel),
      };

      trackSpy(jest.spyOn(urlVerificationService, "verifyBatch")).mockResolvedValue(
        new Map([
          [
            url0,
            {
              status: "VERIFIED",
              originalUrl: url0,
              canonicalUrl: url0,
              domain: "reuters.com",
              httpStatus: 200,
              redirectHops: 0,
              isSoft404: false,
              excerpt: "Reuters reports preliminary support.",
              verifiedAtUtc: new Date().toISOString(),
              verifierMethod: "http_get",
              fetchStatus: "HTTP_200_OK",
            },
          ],
          [
            url1,
            {
              status: "VERIFIED",
              originalUrl: url1,
              canonicalUrl: url1,
              domain: "apnews.com",
              httpStatus: 200,
              redirectHops: 0,
              isSoft404: false,
              excerpt: "AP News refutes the reported figure.",
              verifiedAtUtc: new Date().toISOString(),
              verifierMethod: "http_get",
              fetchStatus: "HTTP_200_OK",
            },
          ],
        ])
      );

      const results = await FusedGroundingService.verifyBatchFused(
        [makeClaim("c_disputed", "Contested policy figure claim.")],
        "Politics"
      );

      expect(results[0].status).toBe("disputed");
      const counterSource = results[0].richSources!.find((s) => s.domain === "apnews.com")!;
      expect(counterSource.claimStance).toBe("CONTRADICTS");
      const supSource = results[0].richSources!.find((s) => s.domain === "reuters.com")!;
      expect(supSource.claimStance).not.toBe("SUPPORTS");
    });
  });

  describe("Task 3.3: Option A Single-Claim Retry & .gov Archival VerdictGate", () => {
    it("retries sourceless/unproven micro-batch misses once with isolated [missedClaim] and thinkingBudget: 512", async () => {
      trackSpy(jest.spyOn(ClaimCacheService.prototype, "getBatch")).mockResolvedValue(new Map());
      trackSpy(jest.spyOn(wikipediaAdapter, "searchPassages")).mockResolvedValue([]);
      trackSpy(jest.spyOn(wikidataAdapter, "searchEntities")).mockResolvedValue([]);

      const calls: Array<{ ids: string[]; thinkingBudget?: number; isSingleClaimRetry?: boolean }> = [];
      const verifySpy = trackSpy(jest.spyOn(FusedGroundingService, "verifyBatchFused")).mockImplementation(async (batch, _dom, opts) => {
        calls.push({
          ids: batch.map((c) => c.claimId),
          thinkingBudget: opts?.thinkingBudget,
          isSingleClaimRetry: opts?.isSingleClaimRetry,
        });

        // Initial 2-claim batch drops sources on c2
        if (!opts?.isSingleClaimRetry) {
          return [
            {
              ...batch[0],
              status: "verified_true",
              verificationConfidence: 0.94,
              reasoning: "Supported in batch.",
              sources: ["https://www.reuters.com/1"],
              richSources: [
                {
                  title: "Reuters 1",
                  url: "https://www.reuters.com/1",
                  domain: "reuters.com",
                  tier: "A",
                  claimStance: "SUPPORTS",
                  sourceKind: "INDEPENDENT_REPORTING",
                  urlVerification: {
                    status: "VERIFIED",
                    originalUrl: "https://www.reuters.com/1",
                    canonicalUrl: "https://www.reuters.com/1",
                    domain: "reuters.com",
                    httpStatus: 200,
                    redirectHops: 0,
                    isSoft404: false,
                    verifiedAtUtc: new Date().toISOString(),
                    verifierMethod: "http_get",
                    fetchStatus: "HTTP_200_OK",
                  },
                },
              ],
              isGrounded: true,
              verificationMethod: "grounded",
            },
            {
              ...batch[1],
              status: "unproven",
              verificationConfidence: 0.0,
              reasoning: "Dropped in batch.",
              sources: [],
              richSources: [],
              isGrounded: false,
              verificationMethod: "not_verified",
            },
          ];
        }

        // Isolated Option A retry succeeds for c2
        return [
          {
            ...batch[0],
            status: "verified_true",
            verificationConfidence: 0.96,
            reasoning: "Isolated retry located NASA archival source.",
            sources: ["https://www.nasa.gov/mission/apollo-11/"],
            richSources: [
              {
                title: "NASA Apollo 11",
                url: "https://www.nasa.gov/mission/apollo-11/",
                domain: "nasa.gov",
                tier: "A",
                claimStance: "SUPPORTS",
                sourceKind: "REFERENCE",
                urlVerification: {
                  status: "VERIFIED",
                  originalUrl: "https://www.nasa.gov/mission/apollo-11/",
                  canonicalUrl: "https://www.nasa.gov/mission/apollo-11/",
                  domain: "nasa.gov",
                  httpStatus: 200,
                  redirectHops: 0,
                  isSoft404: false,
                  verifiedAtUtc: new Date().toISOString(),
                  verifierMethod: "http_get",
                  fetchStatus: "HTTP_200_OK",
                },
              },
            ],
            isGrounded: true,
            verificationMethod: "grounded",
          },
        ];
      });

      const c1 = makeClaim("c1", "First empirical claim in video.");
      const c2 = makeClaim("c2", "Apollo 11 crew splashed down in the Pacific Ocean.");
      const results = await VerificationCascadeService.executeCascade("vid_retry", [c1, c2], "Space");

      expect(verifySpy).toHaveBeenCalledTimes(2);
      expect(calls[0].ids).toEqual(["c1", "c2"]);
      expect(calls[1]).toEqual({
        ids: ["c2"],
        thinkingBudget: 512,
        isSingleClaimRetry: true,
      });

      expect(results[1].status).toBe("verified_true");
      expect(results[1].richSources).toHaveLength(1);
    });

    it("verdictGate allows .gov archival/mission paths as REFERENCE/PRIMARY_RECORD while keeping /press-release/ /news/ /speeches/ as OFFICIAL_STATEMENT", () => {
      const liveUv = (url: string) => ({
        status: "VERIFIED" as const,
        httpStatus: 200,
        isSoft404: false,
        originalUrl: url,
        canonicalUrl: url,
        domain: "nasa.gov",
        redirectHops: 0,
        verifiedAtUtc: new Date().toISOString(),
        verifierMethod: "http_get" as const,
        fetchStatus: "HTTP_200_OK" as const,
      });

      const archivalUrl = "https://www.nasa.gov/mission/apollo-11/";
      const pressUrl = "https://www.nasa.gov/press-release/apollo-statement";
      const newsUrl = "https://www.nasa.gov/news/budget-update";
      const speechUrl = "https://www.state.gov/speeches/remarks-today";

      expect(
        resolveEffectiveSourceKind({
          title: "NASA Apollo 11",
          url: archivalUrl,
          tier: "A",
          urlVerification: liveUv(archivalUrl),
        })
      ).toBe("REFERENCE");

      expect(
        resolveEffectiveSourceKind({
          title: "NASA Press Release",
          url: pressUrl,
          tier: "A",
          sourceKind: "REFERENCE",
          urlVerification: liveUv(pressUrl),
        })
      ).toBe("OFFICIAL_STATEMENT");

      expect(resolveEffectiveSourceKind({ title: "News", url: newsUrl, tier: "A" })).toBe("OFFICIAL_STATEMENT");
      expect(resolveEffectiveSourceKind({ title: "Speech", url: speechUrl, tier: "A" })).toBe("OFFICIAL_STATEMENT");

      expect(
        decidePublicVerdict({
          status: "verified_true",
          richSources: [
            {
              title: "NASA Mission Page",
              url: archivalUrl,
              tier: "A",
              claimStance: "SUPPORTS",
              urlVerification: liveUv(archivalUrl),
            },
          ],
        }).publicVerdict
      ).toBe("VERIFIED");

      expect(
        decidePublicVerdict({
          status: "verified_true",
          richSources: [
            {
              title: "NASA Press Release",
              url: pressUrl,
              tier: "A",
              claimStance: "SUPPORTS",
              urlVerification: liveUv(pressUrl),
            },
          ],
        }).publicVerdict
      ).toBe("UNPROVEN");
    });
  });
});
