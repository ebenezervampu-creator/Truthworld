/**
 * Tier 1 Evergreen Cache (1A) + BigQuery Ledger (2A) + Flag Unification Tests
 */

import * as admin from "firebase-admin";
import { env, resolveBigQueryAnalyticsEnabled } from "../../src/config/env";
import {
  BigQueryAnalyticsService,
  BigQueryVerifiedClaim,
  setBigQueryAnalyticsService,
} from "../../src/analytics/bigqueryService";
import {
  hashClaimText,
  hashSemanticClaimText,
  isSettledPastYearClaim,
  isTimeSensitiveClaim,
} from "../../src/pipeline/utils/claim-normalization";
import { ClaimCacheService } from "../../src/pipeline/services/claimCacheService";
import { sourceTrustService } from "../../src/pipeline/services/sourceTrustService";
import { urlVerificationService } from "../../src/pipeline/services/urlVerificationService";
import { PIPELINE_CONFIG } from "../../src/pipeline/config";
import { ClaimNature, FramingStyle, RichSource, VerifiedClaim } from "../../src/pipeline/types";
import {
  buildBackfillRowsFromRecords,
  parseBackfillCliArgs,
  runBackfillClaimsBigQuery,
} from "../../scripts/backfill-claims-bigquery";

function makeLiveSource(url: string, domain: string, overrides: Partial<RichSource> = {}): RichSource {
  const nowIso = new Date().toISOString();
  return {
    title: `Source (${domain})`,
    url,
    directUrl: url,
    domain,
    publisher: domain,
    tier: "A",
    snippet: "Verified authoritative record.",
    status: "verified",
    claimStance: "SUPPORTS",
    sourceKind: "INDEPENDENT_REPORTING",
    claimStanceReason: "Directly confirms the factual assertion.",
    retrievalMethod: "google_grounding",
    lastVerified: nowIso,
    urlVerification: {
      status: "VERIFIED",
      originalUrl: url,
      canonicalUrl: url,
      domain,
      httpStatus: 200,
      redirectHops: 0,
      isSoft404: false,
      verifiedAtUtc: nowIso,
      verifierMethod: "http_get",
      fetchStatus: "HTTP_200_OK",
    },
    ...overrides,
  };
}

function makeVerifiedClaim(text: string, url: string, domain: string, overrides: Partial<VerifiedClaim> = {}): VerifiedClaim {
  return {
    claimId: `c_${Math.random().toString(36).slice(2, 8)}`,
    text,
    nature: ClaimNature.HISTORICAL_FACT,
    framing: FramingStyle.ASSERTIVE,
    confidence: 0.95,
    importance: 0.85,
    chunkIndex: 0,
    start: 1000,
    end: 5000,
    status: "verified_true",
    verificationConfidence: 0.95,
    reasoning: "Official historical records confirm this fact.",
    sources: [url],
    richSources: [makeLiveSource(url, domain)],
    isGrounded: true,
    verificationMethod: "grounded",
    evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
    ...overrides,
  };
}

describe("Task 1: Flag Unification, BigQuery Ledger & Evergreen Tier 1 Cache", () => {
  const originalEnvFlag = process.env.ENABLE_BIGQUERY_ANALYTICS;
  const originalNodeEnv = process.env.NODE_ENV;

  beforeEach(() => {
    ClaimCacheService.clearL1Cache();
    sourceTrustService.resetDynamicOverrides();
    setBigQueryAnalyticsService(new BigQueryAnalyticsService({ enabled: false, flushIntervalMs: 0 }));
    process.env.NODE_ENV = "test";
    if (originalEnvFlag === undefined) {
      delete process.env.ENABLE_BIGQUERY_ANALYTICS;
    } else {
      process.env.ENABLE_BIGQUERY_ANALYTICS = originalEnvFlag;
    }
  });

  afterAll(() => {
    process.env.NODE_ENV = originalNodeEnv;
    if (originalEnvFlag === undefined) {
      delete process.env.ENABLE_BIGQUERY_ANALYTICS;
    } else {
      process.env.ENABLE_BIGQUERY_ANALYTICS = originalEnvFlag;
    }
  });

  describe("1. Env Flag Unification (resolveBigQueryAnalyticsEnabled)", () => {
    it("aligns env.analytics.enableBigQueryAnalytics and BigQueryAnalyticsService defaults in test and runtime", () => {
      // In NODE_ENV=test without override, both default to false
      delete process.env.ENABLE_BIGQUERY_ANALYTICS;
      expect(resolveBigQueryAnalyticsEnabled()).toBe(false);
      expect(env.analytics.enableBigQueryAnalytics).toBe(false);
      const defaultTestBq = new BigQueryAnalyticsService({ flushIntervalMs: 0 });
      expect(defaultTestBq.isEnabled()).toBe(false);

      // Explicit override enables both
      expect(resolveBigQueryAnalyticsEnabled(true)).toBe(true);
      const enabledTestBq = new BigQueryAnalyticsService({ enabled: true, flushIntervalMs: 0 });
      expect(enabledTestBq.isEnabled()).toBe(true);

      // Runtime (NODE_ENV=production) defaults to enabled unless ENABLE_BIGQUERY_ANALYTICS="false"
      process.env.NODE_ENV = "production";
      expect(resolveBigQueryAnalyticsEnabled()).toBe(true);
      process.env.ENABLE_BIGQUERY_ANALYTICS = "false";
      expect(resolveBigQueryAnalyticsEnabled()).toBe(false);
      expect(resolveBigQueryAnalyticsEnabled(true)).toBe(true);
    });
  });

  describe("2. Past-Year Settled vs Volatile Claim Detection (1A)", () => {
    const fixedNow = new Date("2026-11-27T00:00:00Z");

    it("treats settled past-year claims as evergreen (non-volatile)", () => {
      expect(isSettledPastYearClaim("Narendra Modi was elected PM in 2014.", fixedNow)).toBe(true);
      expect(isTimeSensitiveClaim("Narendra Modi was elected PM in 2014.", fixedNow)).toBe(false);

      expect(isSettledPastYearClaim("Apollo 11 landed on the Moon on July 20, 1969.", fixedNow)).toBe(true);
      expect(isTimeSensitiveClaim("Apollo 11 landed on the Moon on July 20, 1969.", fixedNow)).toBe(false);

      expect(isSettledPastYearClaim("India held general elections in 2024.", fixedNow)).toBe(true);
      expect(isTimeSensitiveClaim("India held general elections in 2024.", fixedNow)).toBe(false);
    });

    it("keeps live/present-tense and current/future-year claims volatile", () => {
      expect(isSettledPastYearClaim("The RBI repo rate today is currently 6.5%.", fixedNow)).toBe(false);
      expect(isTimeSensitiveClaim("The RBI repo rate today is currently 6.5%.", fixedNow)).toBe(true);

      expect(isSettledPastYearClaim("India's GDP growth forecast for 2026 is 6.8%.", fixedNow)).toBe(false);
      expect(isTimeSensitiveClaim("India's GDP growth forecast for 2026 is 6.8%.", fixedNow)).toBe(true);

      expect(isSettledPastYearClaim("Elected in 2014 and currently serving today.", fixedNow)).toBe(false);
      expect(isTimeSensitiveClaim("Elected in 2014 and currently serving today.", fixedNow)).toBe(true);
    });
  });

  describe("3. BigQuery Schema Migration & Batched Tier 1C Lookup", () => {
    it("migrates existing raw_claims_verified table missing new columns idempotently", async () => {
      const mockSetMetadata = jest.fn().mockResolvedValue([{}]);
      const mockGetMetadata = jest.fn().mockResolvedValue([
        {
          schema: {
            fields: [
              { name: "claim_id", type: "STRING", mode: "REQUIRED" },
              { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
              { name: "video_id", type: "STRING", mode: "REQUIRED" },
              { name: "claim_text", type: "STRING", mode: "REQUIRED" },
              { name: "status", type: "STRING", mode: "REQUIRED" },
            ],
          },
        },
      ]);

      const mockTable = {
        exists: jest.fn().mockResolvedValue([true]),
        getMetadata: mockGetMetadata,
        setMetadata: mockSetMetadata,
        insert: jest.fn().mockResolvedValue([{}]),
      };

      const mockDataset = {
        exists: jest.fn().mockResolvedValue([true]),
        table: jest.fn().mockReturnValue(mockTable),
        createTable: jest.fn().mockResolvedValue([{}]),
      };

      const mockBqClient = {
        dataset: jest.fn().mockReturnValue(mockDataset),
        query: jest.fn().mockResolvedValue([[]]),
      };

      const bqService = new BigQueryAnalyticsService(
        { enabled: true, flushIntervalMs: 0, datasetId: "truthworld_analytics" },
        mockBqClient as any
      );
      await bqService.ensureSchema();

      expect(mockSetMetadata).toHaveBeenCalledTimes(1);
      const updatedFieldNames = mockSetMetadata.mock.calls[0][0].schema.fields.map((f: any) => f.name);
      expect(updatedFieldNames).toEqual(
        expect.arrayContaining([
          "english_claim_hash",
          "semantic_hash",
          "evidence_schema_version",
          "rich_sources_json",
        ])
      );
    });

    it("executes a single batched QUALIFY ROW_NUMBER lookup and fails open on error or timeout", async () => {
      const mockQuery = jest.fn().mockResolvedValue([
        [
          {
            claim_id: "c1",
            timestamp: new Date().toISOString(),
            video_id: "v1",
            claim_text: "Narendra Modi was elected PM in 2014.",
            normalized_claim_hash: hashClaimText("Narendra Modi was elected PM in 2014."),
            status: "verified_true",
            is_grounded: true,
            evidence_schema_version: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
          },
        ],
      ]);

      const bqService = new BigQueryAnalyticsService(
        { enabled: true, flushIntervalMs: 0, datasetId: "truthworld_analytics" },
        { query: mockQuery } as any
      );

      const rows = await bqService.lookupVerifiedClaimsBatch({
        exactHashes: [hashClaimText("Narendra Modi was elected PM in 2014.")],
        semanticHashes: [hashSemanticClaimText("Narendra Modi was elected PM in 2014.")],
        schemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
      });

      expect(mockQuery).toHaveBeenCalledTimes(1);
      const callArg = mockQuery.mock.calls[0][0];
      expect(callArg.query).toContain("QUALIFY ROW_NUMBER()");
      expect(callArg.query).toContain("is_grounded = TRUE");
      expect(callArg.query).toContain("UNNEST(@hashes)");
      expect(callArg.query).toContain("UNNEST(@semHashes)");
      expect(rows).toHaveLength(1);

      // Fail-open on query error
      mockQuery.mockRejectedValueOnce(new Error("BigQuery unavailable"));
      const errRows = await bqService.lookupVerifiedClaimsBatch({
        exactHashes: ["h1"],
        semanticHashes: ["s1"],
        schemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
      });
      expect(errRows).toEqual([]);

      // Fail-open on timeout
      mockQuery.mockImplementationOnce(() => new Promise(() => {}));
      const timeoutRows = await bqService.lookupVerifiedClaimsBatch({
        exactHashes: ["h2"],
        semanticHashes: ["s2"],
        schemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        timeoutMs: 60,
      });
      expect(timeoutRows).toEqual([]);
    });
  });

  describe("4. Tier 1A -> 1B -> 1C Warm Backfill & Zero-AI Liveness Gate", () => {
    it("hits BigQuery on L1+L2 miss once for multiple claims, warms L1+L2, and skips subsequent BQ reads", async () => {
      const claim1 = "Narendra Modi was elected PM in 2014.";
      const claim2 = "Apollo 11 landed on the Moon on July 20, 1969.";
      const h1 = hashClaimText(claim1);
      const h2 = hashClaimText(claim2);

      const bqRows: BigQueryVerifiedClaim[] = [
        {
          claim_id: "bq_1",
          timestamp: new Date().toISOString(),
          video_id: "hist_vid_1",
          claim_text: claim1,
          normalized_claim_hash: h1,
          english_claim_hash: h1,
          semantic_hash: hashSemanticClaimText(claim1),
          status: "verified_true",
          verification_confidence: 0.96,
          reasoning: "Election Commission of India records confirm Narendra Modi became Prime Minister in May 2014.",
          is_grounded: true,
          evidence_schema_version: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
          rich_sources_json: JSON.stringify([
            makeLiveSource("https://eci.gov.in/2014-general-elections", "eci.gov.in", {
              sourceKind: "PRIMARY_RECORD",
              claimStance: "SUPPORTS",
            }),
          ]),
        },
        {
          claim_id: "bq_2",
          timestamp: new Date().toISOString(),
          video_id: "hist_vid_2",
          claim_text: claim2,
          normalized_claim_hash: h2,
          english_claim_hash: h2,
          semantic_hash: hashSemanticClaimText(claim2),
          status: "verified_true",
          verification_confidence: 0.99,
          reasoning: "NASA Apollo 11 mission logs confirm the lunar landing on July 20, 1969.",
          is_grounded: true,
          evidence_schema_version: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
          rich_sources_json: JSON.stringify([
            makeLiveSource("https://www.nasa.gov/mission/apollo-11/", "nasa.gov", {
              sourceKind: "REFERENCE",
              claimStance: "SUPPORTS",
            }),
          ]),
        },
      ];

      const mockQuery = jest.fn().mockResolvedValue([bqRows]);
      const mockBq = new BigQueryAnalyticsService(
        { enabled: true, flushIntervalMs: 0 },
        { query: mockQuery } as any
      );
      setBigQueryAnalyticsService(mockBq);

      const cache = new ClaimCacheService();
      const hits = await cache.getBatch([
        { claimId: "c1", text: claim1 },
        { claimId: "c2", text: claim2 },
      ]);

      expect(mockQuery).toHaveBeenCalledTimes(1);
      expect(hits.size).toBe(2);
      expect(hits.get(claim1)?.verificationMethod).toBe("cache_hit");
      expect(hits.get(claim1)?.richSources?.[0]?.claimStance).toBe("SUPPORTS");
      expect(hits.get(claim1)?.richSources?.[0]?.sourceKind).toBe("PRIMARY_RECORD");
      expect(hits.get(claim2)?.richSources?.[0]?.sourceKind).toBe("REFERENCE");

      // L2 Firestore was warm-backfilled
      const l2Doc = await admin.firestore().collection("claim_cache").doc(h1).get();
      expect(l2Doc.exists).toBe(true);
      expect(l2Doc.data()?.isEvergreen).toBe(true);

      // Clear L1 only -> next read hits L2 Firestore with 0 BigQuery queries
      ClaimCacheService.clearL1Cache();
      const hitsFromL2 = await cache.getBatch([{ claimId: "c1", text: claim1 }]);
      expect(hitsFromL2.size).toBe(1);
      expect(mockQuery).toHaveBeenCalledTimes(1);
    });

    it("fails open cleanly in getBatch when BigQuery throws or times out", async () => {
      const mockBq = new BigQueryAnalyticsService(
        { enabled: true, flushIntervalMs: 0 },
        { query: jest.fn().mockRejectedValue(new Error("BQ timeout")) } as any
      );
      setBigQueryAnalyticsService(mockBq);

      const cache = new ClaimCacheService();
      const hits = await cache.getBatch([{ claimId: "c1", text: "Novel uncached claim from 2015." }]);
      expect(hits.size).toBe(0);
    });

    it("keeps evergreen entries valid indefinitely and runs 0-AI HTTP check only past 30 days", async () => {
      const claimText = "India launched Mars Orbiter Mission in 2013.";
      const exactHash = hashClaimText(claimText);
      const url = "https://www.isro.gov.in/MarsOrbiterMission.html";
      const cache = new ClaimCacheService();

      const verifyBatchSpy = jest.spyOn(urlVerificationService, "verifyBatch");
      try {

      // Seed 2-year-old evergreen entry whose lastUrlCheckAt is 10 days old (<= 30d)
      const twoYearsAgo = Date.now() - 730 * 24 * 60 * 60 * 1000;
      const tenDaysAgo = Date.now() - 10 * 24 * 60 * 60 * 1000;
      await admin.firestore().collection("claim_cache").doc(exactHash).set({
        originalText: claimText,
        exactHash,
        semanticHash: hashSemanticClaimText(claimText),
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        status: "verified_true",
        reasoning: "ISRO archives confirm the 2013 launch.",
        richSources: [makeLiveSource(url, "isro.gov.in", { sourceKind: "REFERENCE" })],
        isEvergreen: true,
        ttlMode: "evergreen_url_checked",
        lastUrlCheckAt: tenDaysAgo,
        createdAt: twoYearsAgo,
        expiresAt: twoYearsAgo + 30 * 24 * 60 * 60 * 1000, // Legacy expiresAt ignored when isEvergreen=true
        isGrounded: true,
      });

      const freshHits = await cache.getBatch([{ claimId: "c1", text: claimText }]);
      expect(freshHits.size).toBe(1);
      expect(verifyBatchSpy).not.toHaveBeenCalled();

      // Now simulate aged lastUrlCheckAt > 30 days -> HTTP 200 refreshes timestamp & returns hit
      ClaimCacheService.clearL1Cache();
      const fortyDaysAgo = Date.now() - 40 * 24 * 60 * 60 * 1000;
      await admin.firestore().collection("claim_cache").doc(exactHash).update({
        lastUrlCheckAt: fortyDaysAgo,
      });

      verifyBatchSpy.mockResolvedValueOnce(
        new Map([
          [
            url,
            {
              status: "VERIFIED",
              originalUrl: url,
              canonicalUrl: url,
              domain: "isro.gov.in",
              httpStatus: 200,
              redirectHops: 0,
              isSoft404: false,
              verifiedAtUtc: new Date().toISOString(),
              verifierMethod: "http_get",
              fetchStatus: "HTTP_200_OK",
            },
          ],
        ])
      );

      const refreshedHits = await cache.getBatch([{ claimId: "c1", text: claimText }]);
      expect(verifyBatchSpy).toHaveBeenCalledTimes(1);
      expect(refreshedHits.size).toBe(1);
      const updatedDoc = (await admin.firestore().collection("claim_cache").doc(exactHash).get()).data();
      expect(updatedDoc?.lastUrlCheckAt).toBeGreaterThan(fortyDaysAgo);

      // Aged entry whose URL now returns 404 NOT_FOUND is rejected cleanly
      ClaimCacheService.clearL1Cache();
      await admin.firestore().collection("claim_cache").doc(exactHash).update({
        lastUrlCheckAt: fortyDaysAgo,
      });
      verifyBatchSpy.mockResolvedValueOnce(
        new Map([
          [
            url,
            {
              status: "NOT_FOUND",
              originalUrl: url,
              canonicalUrl: url,
              domain: "isro.gov.in",
              httpStatus: 404,
              redirectHops: 0,
              isSoft404: false,
              verifiedAtUtc: new Date().toISOString(),
              verifierMethod: "http_get",
              fetchStatus: "NOT_FOUND",
            },
          ],
        ])
      );

      const deadHits = await cache.getBatch([{ claimId: "c1", text: claimText }]);
      expect(deadHits.size).toBe(0);
      } finally {
        verifyBatchSpy.mockRestore();
      }
    });

    it("rejects cached hits whose source is formally retracted", async () => {
      const claimText = "Study X showed drug Y cures disease Z in 2018.";
      const url = "https://journal.org/retracted-paper-2018";
      const cache = new ClaimCacheService();

      await cache.set(
        makeVerifiedClaim(claimText, url, "journal.org", {
          richSources: [
            makeLiveSource(url, "journal.org", {
              urlVerification: {
                status: "VERIFIED",
                originalUrl: url,
                canonicalUrl: url,
                domain: "journal.org",
                httpStatus: 200,
                redirectHops: 0,
                isSoft404: false,
                verifiedAtUtc: new Date().toISOString(),
                verifierMethod: "http_get",
                fetchStatus: "HTTP_200_OK",
                evidenceText: "Full text that must be stripped before persistence",
              },
            }),
          ],
        })
      );

      const stored = (await admin.firestore().collection("claim_cache").doc(hashClaimText(claimText)).get()).data();
      expect(stored?.isEvergreen).toBe(true);
      expect(stored?.ttlMode).toBe("evergreen_url_checked");
      expect(stored?.richSources?.[0]?.urlVerification?.evidenceText).toBeUndefined();

      sourceTrustService.registerFormalRetraction({
        targetUrlOrDoi: url,
        sourceDomain: "journal.org",
        retractingEntity: "Editorial Board",
        reason: "Data fabrication",
        retractedAtUtc: new Date().toISOString(),
      });

      const hits = await cache.getBatch([{ claimId: "c1", text: claimText }]);
      expect(hits.size).toBe(0);
    });

    it("persists short TTL for volatile breaking claims and supports bidirectional multilingual hits", async () => {
      const cache = new ClaimCacheService();
      const volatileText = "Breaking news today: central bank announced emergency policy review.";
      await cache.set(makeVerifiedClaim(volatileText, "https://reuters.com/news/rbi-today", "reuters.com"));
      const volatileDoc = (await admin.firestore().collection("claim_cache").doc(hashClaimText(volatileText)).get()).data();
      expect(volatileDoc?.isEvergreen).toBe(false);
      expect(volatileDoc?.ttlMode).toBe("short_ttl");
      expect(typeof volatileDoc?.expiresAt).toBe("number");

      // Multilingual: save Telugu claim with English canonical -> English claim hits it
      const teluguText = "అపోలో 11 1969 జూలై 20న చంద్రునిపై దిగింది";
      const englishCanonical = "Apollo 11 landed on the Moon on July 20, 1969.";
      await cache.set(
        makeVerifiedClaim(teluguText, "https://www.nasa.gov/mission/apollo-11/", "nasa.gov"),
        englishCanonical
      );

      ClaimCacheService.clearL1Cache();
      const englishHits = await cache.getBatch([{ claimId: "en_1", text: englishCanonical }]);
      expect(englishHits.size).toBe(1);

      // Reverse: save English claim -> Telugu claim with englishCanonical hits it
      ClaimCacheService.clearL1Cache();
      await admin.firestore().collection("claim_cache").doc(hashClaimText(teluguText)).delete();
      const englishOnly = "The United Nations was founded in 1945.";
      const teluguQuery = "ఐక్యరాజ్యసమితి 1945లో స్థాపించబడింది";
      await cache.set(makeVerifiedClaim(englishOnly, "https://www.un.org/en/about-us/history-of-the-un", "un.org"));
      ClaimCacheService.clearL1Cache();

      const teluguHits = await cache.getBatch([
        { claimId: "te_1", text: teluguQuery, englishCanonical: englishOnly },
      ]);
      expect(teluguHits.size).toBe(1);
    });
  });

  describe("5. Backfill Script Helper & Dry-Run vs --apply", () => {
    it("parses CLI flags cleanly with dry-run default", () => {
      expect(parseBackfillCliArgs([])).toEqual({
        apply: false,
        limit: undefined,
        source: "both",
      });
      expect(parseBackfillCliArgs(["--apply", "--limit=250", "--source=gcs"])).toEqual({
        apply: true,
        limit: 250,
        source: "gcs",
      });
    });

    it("maps and deduplicates Firestore claim_cache & GCS full.json claims with stripEvidenceText", () => {
      const dupText = "Apollo 11 landed on the Moon on July 20, 1969.";
      const srcWithEvidence = makeLiveSource("https://www.nasa.gov/mission/apollo-11/", "nasa.gov", {
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
          evidenceText: "Large fetched HTML text that must be stripped",
        },
      });

      const rows = buildBackfillRowsFromRecords({
        cacheDocs: [
          {
            id: hashClaimText(dupText),
            data: {
              originalText: dupText,
              exactHash: hashClaimText(dupText),
              semanticHash: hashSemanticClaimText(dupText),
              evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
              status: "verified_true",
              confidence: 0.99,
              reasoning: "Confirmed by NASA archives.",
              richSources: [srcWithEvidence],
              isGrounded: true,
            },
          },
        ],
        gcsReports: [
          {
            path: "factChecks/job_1/full.json",
            report: {
              videoId: "vid_1",
              claims: [
                {
                  claimId: "c_dup",
                  text: dupText,
                  status: "verified_true",
                  richSources: [srcWithEvidence],
                },
                {
                  claimId: "c_new",
                  text: "Water boils at 100 degrees Celsius at sea level.",
                  status: "verified_true",
                  verificationConfidence: 0.99,
                  reasoning: "NIST standard boiling point.",
                  richSources: [
                    makeLiveSource("https://physics.nist.gov/cuu/Constants/", "nist.gov", {
                      sourceKind: "REFERENCE",
                    }),
                  ],
                },
                {
                  claimId: "c_unproven",
                  text: "Unproven claim without live sources.",
                  status: "unproven",
                  richSources: [],
                },
              ],
            },
          },
        ],
      });

      expect(rows).toHaveLength(2);
      const apolloRow = rows.find((r) => r.claim_text === dupText)!;
      expect(apolloRow.normalized_claim_hash).toBe(hashClaimText(dupText));
      expect(apolloRow.evidence_schema_version).toBe(PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION);
      expect(apolloRow.rich_sources_json).toBeDefined();
      const parsedRich = JSON.parse(apolloRow.rich_sources_json!);
      expect(parsedRich[0].urlVerification.evidenceText).toBeUndefined();
      expect(parsedRich[0].claimStance).toBe("SUPPORTS");
    });

    it("respects dry-run vs --apply in runBackfillClaimsBigQuery", async () => {
      const claimText = "The United Nations was founded in 1945.";
      await admin.firestore().collection("claim_cache").doc(hashClaimText(claimText)).set({
        originalText: claimText,
        exactHash: hashClaimText(claimText),
        semanticHash: hashSemanticClaimText(claimText),
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        status: "verified_true",
        reasoning: "UN Charter signed in 1945.",
        richSources: [makeLiveSource("https://www.un.org/en/about-us/history-of-the-un", "un.org")],
        isGrounded: true,
      });

      const mockInsert = jest.fn().mockResolvedValue([{}]);
      const mockTable = {
        exists: jest.fn().mockResolvedValue([true]),
        insert: mockInsert,
        getMetadata: jest.fn().mockResolvedValue([
          {
            schema: {
              fields: [
                { name: "english_claim_hash" },
                { name: "semantic_hash" },
                { name: "evidence_schema_version" },
                { name: "rich_sources_json" },
              ],
            },
          },
        ]),
      };
      const mockBqClient = {
        dataset: jest.fn().mockReturnValue({
          exists: jest.fn().mockResolvedValue([true]),
          table: jest.fn().mockReturnValue(mockTable),
        }),
      };
      const mockBq = new BigQueryAnalyticsService({ enabled: true, flushIntervalMs: 0 }, mockBqClient as any);

      // Dry-run: scans rows, writes 0
      const drySummary = await runBackfillClaimsBigQuery(
        { apply: false, source: "cache" },
        { bigQueryService: mockBq }
      );
      expect(drySummary.scannedCacheDocs).toBe(1);
      expect(drySummary.preparedRows).toBe(1);
      expect(drySummary.writtenRows).toBe(0);
      expect(mockInsert).not.toHaveBeenCalled();

      // Apply: writes rows
      const applySummary = await runBackfillClaimsBigQuery(
        { apply: true, source: "cache" },
        { bigQueryService: mockBq }
      );
      expect(applySummary.writtenRows).toBe(1);
      expect(mockInsert).toHaveBeenCalledTimes(1);
    });
  });
});
