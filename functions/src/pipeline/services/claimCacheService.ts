import * as admin from "firebase-admin";
import { VerifiedClaim, ClaimStatus, RichSource } from "../types";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import {
  hashClaimText,
  hashSemanticClaimText,
  isSettledPastYearClaim,
  isTimeSensitiveClaim,
  normalizeClaimText,
} from "../utils/claim-normalization";
import { sanitizeClaimResponse } from "../utils/claim-response-sanitizer";
import { stripEvidenceText } from "./verdictReconciliation";
import { sourceTrustService } from "./sourceTrustService";
import { CitationRetractionService } from "./citationRetractionService";
import {
  enforceClosedWorldCitationFirewall,
  isClosedWorldCacheEntryValid,
  isLiveVerificationRecord,
  isVerifiedRichSource,
  urlVerificationService,
} from "./urlVerificationService";
import {
  BigQueryAnalyticsService,
  BigQueryVerifiedClaim,
  getBigQueryAnalyticsService,
} from "../../analytics/bigqueryService";

export { isTimeSensitiveClaim, isSettledPastYearClaim };

export type CachedClaimHit = Partial<VerifiedClaim>;

export interface ClaimCacheBatchInput {
  claimId?: string;
  text: string;
  englishCanonical?: string;
}

export interface ClaimCacheBatchOptions {
  enableBigQuery?: boolean;
  bigQueryService?: BigQueryAnalyticsService;
}

const URL_CHECK_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;
const VOLATILE_MAX_AGE_MS = 3 * 60 * 60 * 1000;

interface L1CacheEntry {
  claim: Partial<VerifiedClaim>;
  expiresAt: number | null;
  isEvergreen: boolean;
  lastUrlCheckAt: number;
  createdAtMs: number;
  originalText: string;
  englishCanonical?: string;
}

interface ResolvedCandidateHit {
  text: string;
  claim: Partial<VerifiedClaim>;
  exactHash: string;
  englishExactHash?: string;
  semanticHash: string;
  englishSemanticHash?: string;
  isEvergreen: boolean;
  expiresAt: number | null;
  lastUrlCheckAt: number;
  createdAtMs: number;
  originalText: string;
  englishCanonical?: string;
  sourceTier: "L1" | "L2" | "BQ";
  docRef?: admin.firestore.DocumentReference;
  bqRow?: BigQueryVerifiedClaim;
}

/**
 * 🏛 Institutional Cross-Video Global Claim Cache (v16.0 — 1A Evergreen + 2A BigQuery)
 *
 * Strict Tier 1 Read Waterfall:
 * - Tier 1A: L1 In-Memory LRU Cache (0ms, $0)
 * - Tier 1B: L2 Persistent Firestore `claim_cache` (evergreen historical + short-TTL volatile)
 * - Tier 1C: BigQuery `raw_claims_verified` (1 batched SQL query <= 2500ms, warm-backfills L1+L2)
 * - Zero-AI Gate: checks source retraction + $0 HTTP liveness check when lastUrlCheckAt > 30 days.
 */

/**
 * 🛡️ PROPOSITION ALIGNMENT CHECK
 *
 * Epistemic Requirement (Tier 1): A similarity score of 0.94 alone must never
 * authorize verdict reuse.
 *
 * Enforces:
 * 1. Polarity / Negation alignment (rejects negation flips).
 * 2. Antonym / Directional verb alignment (e.g. rose vs fell, won vs lost, increase vs decrease).
 * 3. Exact numerical quantity and percentage matching.
 * 4. Temporal scope and year consistency.
 */
export function validatePropositionAlignment(
  cachedText: string,
  incomingText: string
): { isAligned: boolean; reason?: string } {
  if (!cachedText || !incomingText) return { isAligned: false, reason: "empty_text" };

  const normCached = cachedText.toLowerCase();
  const normIncoming = incomingText.toLowerCase();

  if (normCached.trim() === normIncoming.trim()) {
    return { isAligned: true };
  }

  // 1. Negation & Polarity Inversion Check
  const negationRegex = /\b(not|never|no|neither|nor|cannot|can't|didn't|doesn't|don't|won't|untrue|false|fake)\b/g;
  const cachedNegations = normCached.match(negationRegex) || [];
  const incomingNegations = normIncoming.match(negationRegex) || [];
  if (cachedNegations.length % 2 !== incomingNegations.length % 2) {
    return { isAligned: false, reason: "polarity_inversion" };
  }

  // 2. Antonym / Directional Verb Inversions
  const antonymPairs: Array<[string, string]> = [
    ["increase", "decrease"],
    ["rose", "fell"],
    ["growth", "decline"],
    ["won", "lost"],
    ["approved", "rejected"],
    ["accepted", "denied"],
    ["alive", "dead"],
    ["guilty", "innocent"],
    ["safe", "dangerous"],
    ["cured", "worsened"],
  ];
  for (const [a, b] of antonymPairs) {
    const cachedHasA = normCached.includes(a);
    const cachedHasB = normCached.includes(b);
    const incomingHasA = normIncoming.includes(a);
    const incomingHasB = normIncoming.includes(b);
    if ((cachedHasA && incomingHasB) || (cachedHasB && incomingHasA)) {
      return { isAligned: false, reason: `antonym_direction_mismatch: ${a} vs ${b}` };
    }
  }

  // 3. Temporal Scope & Year Check (evaluated before generic numbers)
  const extractYears = (t: string) => {
    return (t.match(/\b(19\d\d|20\d\d)\b/g) || []).sort();
  };
  const cachedYears = extractYears(normCached);
  const incomingYears = extractYears(normIncoming);
  if (cachedYears.length > 0 || incomingYears.length > 0) {
    if (cachedYears.join(",") !== incomingYears.join(",")) {
      return { isAligned: false, reason: `temporal_year_mismatch: [${cachedYears}] vs [${incomingYears}]` };
    }
  }

  // 4. Numbers, Percentages, and Quantities Check (excluding 4-digit years)
  const extractNumbers = (t: string) => {
    const raw = t.match(/\b\d+(?:\.\d+)?%?\b/g) || [];
    return raw.filter((w) => !/^(?:19|20)\d\d$/.test(w)).sort();
  };
  const cachedNums = extractNumbers(normCached);
  const incomingNums = extractNumbers(normIncoming);
  if (cachedNums.length > 0 || incomingNums.length > 0) {
    if (cachedNums.join(",") !== incomingNums.join(",")) {
      return { isAligned: false, reason: `numerical_quantity_mismatch: [${cachedNums}] vs [${incomingNums}]` };
    }
  }

  return { isAligned: true };
}

function toEpochMs(val: any, fallback = 0): number {
  if (typeof val === "number" && Number.isFinite(val)) return val;
  if (val && typeof val.toMillis === "function") return val.toMillis();
  if (typeof val === "string") {
    const parsed = Date.parse(val);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function isSourceRetracted(src: RichSource): boolean {
  const url = String(src?.url || src?.directUrl || "").trim();
  if (url && sourceTrustService.isRetracted(url)) return true;
  if (src?.doi && sourceTrustService.isRetracted(src.doi)) return true;
  if (url && CitationRetractionService.lookupDoi(url)?.status === "retracted") return true;
  return false;
}

export class ClaimCacheService {
  private static readonly COLLECTION = "claim_cache";
  private static readonly CACHE_ENABLED = true;
  private static readonly L1_MAX_SIZE = 5000;
  private static readonly l1Cache = new Map<string, L1CacheEntry>();

  private generateHash(text: string): string {
    return hashClaimText(text);
  }

  private generateSemanticHash(text: string): string {
    return hashSemanticClaimText(text);
  }

  private computeLookupKeys(text: string, englishCanonical?: string) {
    const exactHash = this.generateHash(text);
    const semanticHash = this.generateSemanticHash(text);
    const cleanEnglish = englishCanonical?.trim();
    const hasDistinctEnglish =
      Boolean(cleanEnglish) &&
      normalizeClaimText(cleanEnglish!) !== normalizeClaimText(text);
    const englishExactHash = hasDistinctEnglish ? this.generateHash(cleanEnglish!) : undefined;
    const englishSemanticHash = hasDistinctEnglish ? this.generateSemanticHash(cleanEnglish!) : undefined;
    return {
      exactHash,
      semanticHash,
      englishCanonical: hasDistinctEnglish ? cleanEnglish : undefined,
      englishExactHash,
      englishSemanticHash,
    };
  }

  private isEntryExpired(isEvergreen: boolean, expiresAt: number | null | undefined, now: number): boolean {
    if (isEvergreen) return false;
    return typeof expiresAt === "number" && expiresAt > 0 && now > expiresAt;
  }

  private getFromL1Entry(hash: string): L1CacheEntry | null {
    const entry = ClaimCacheService.l1Cache.get(hash);
    if (!entry) return null;
    const now = Date.now();
    if (this.isEntryExpired(entry.isEvergreen, entry.expiresAt, now) || !isClosedWorldCacheEntryValid(entry.claim)) {
      ClaimCacheService.l1Cache.delete(hash);
      return null;
    }
    // Refresh LRU order
    ClaimCacheService.l1Cache.delete(hash);
    ClaimCacheService.l1Cache.set(hash, entry);
    return entry;
  }

  private setToL1(hash: string, entry: L1CacheEntry): void {
    if (ClaimCacheService.l1Cache.size >= ClaimCacheService.L1_MAX_SIZE) {
      const oldestKey = ClaimCacheService.l1Cache.keys().next().value;
      if (oldestKey) ClaimCacheService.l1Cache.delete(oldestKey);
    }
    ClaimCacheService.l1Cache.set(hash, entry);
  }

  private buildCachedClaimFromData(data: any): {
    claim: Partial<VerifiedClaim>;
    verifiedRichSources: RichSource[];
  } | null {
    if (!data || !isClosedWorldCacheEntryValid(data)) {
      return null;
    }
    const verifiedRichSources = ((data.richSources || []) as RichSource[])
      .filter((s) => isVerifiedRichSource(s))
      .map((s) => ({
        ...s,
        ...(s.claimStance ? { claimStance: s.claimStance } : {}),
        ...(s.sourceKind ? { sourceKind: s.sourceKind } : {}),
      }));
    if (verifiedRichSources.length === 0) {
      return null;
    }

    const cleanReasoning = sanitizeClaimResponse(data.reasoning, data.status as ClaimStatus);
    const claim: Partial<VerifiedClaim> = {
      status: data.status as ClaimStatus,
      reasoning: cleanReasoning,
      richSources: verifiedRichSources,
      verifiedAcademicMetadata: Array.isArray(data.verifiedAcademicMetadata) ? data.verifiedAcademicMetadata : undefined,
      evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
      verificationConfidence: data.confidence ?? data.verificationConfidence ?? 0.85,
      displayLabel: data.displayLabel,
      evidenceLevel: data.evidenceLevel,
      evidenceDetails: data.evidenceDetails,
      consensusDetails: data.consensusDetails,
      classificationConfidence: data.classificationConfidence,
      historicalEvidenceConfidence: data.historicalEvidenceConfidence,
      isGrounded: true,
      verificationMethod: "cache_hit",
    };

    return { claim, verifiedRichSources };
  }

  private buildCachedClaimFromBigQuery(row: BigQueryVerifiedClaim): {
    claim: Partial<VerifiedClaim>;
    richSources: RichSource[];
    lastUrlCheckAt: number;
    createdAtMs: number;
    isEvergreen: boolean;
  } | null {
    if (!row || !row.status || !row.is_grounded || !row.rich_sources_json) {
      return null;
    }
    let parsedSources: RichSource[] = [];
    try {
      const raw = JSON.parse(row.rich_sources_json);
      if (Array.isArray(raw)) {
        parsedSources = raw;
      }
    } catch {
      return null;
    }

    const schemaVersion = row.evidence_schema_version ? String(row.evidence_schema_version) : "";
    const candidatePayload = {
      evidenceSchemaVersion: schemaVersion,
      richSources: parsedSources,
      status: row.status,
      reasoning: row.reasoning,
      confidence: row.verification_confidence,
    };
    const built = this.buildCachedClaimFromData(candidatePayload);
    if (!built) return null;

    const rowTs = toEpochMs(row.timestamp, Date.now());
    const newestSourceCheck = built.verifiedRichSources.reduce((maxTs, s) => {
      const ts = toEpochMs(s.urlVerification?.verifiedAtUtc || s.lastVerified, 0);
      return ts > maxTs ? ts : maxTs;
    }, 0);
    const lastUrlCheckAt = newestSourceCheck || rowTs;
    const volatile = isTimeSensitiveClaim(row.claim_text);

    return {
      claim: built.claim,
      richSources: built.verifiedRichSources,
      lastUrlCheckAt,
      createdAtMs: rowTs,
      isEvergreen: !volatile,
    };
  }

  private getVolatileTtlDays(claim: VerifiedClaim): number {
    const domainKey = String((claim as any).claimDomain || claim.ontology || "").toLowerCase();
    if (domainKey.includes("breaking") || domainKey.includes("crisis") || domainKey.includes("disaster") || isTimeSensitiveClaim(claim.text)) {
      return 0.125; // 3 hours: fast-evolving breaking/live claims
    }
    if (domainKey.includes("finance") || domainKey.includes("market") || domainKey.includes("stock")) {
      return 2; // 2 days: financial metrics
    }
    if (domainKey.includes("politic") || domainKey.includes("election")) {
      return 7; // 7 days: political news cycles
    }
    return 30; // 30 days default for non-evergreen mutable claims
  }

  /**
   * Retrieves a single verified claim via the Tier 1A -> 1B -> 1C + Zero-AI liveness pipeline.
   */
  async get(text: string, englishCanonical?: string): Promise<Partial<VerifiedClaim> | null> {
    if (!ClaimCacheService.CACHE_ENABLED || !text) return null;
    const hits = await this.getBatch([{ text, englishCanonical }]);
    return hits.get(text) ?? null;
  }

  /**
   * Stores a verified claim in persistent cache (evergreen for non-volatile settled facts, short-TTL for volatile).
   * Closed-World Write Gate: rejects any claim without live verified sources.
   */
  async set(claim: VerifiedClaim, englishCanonical?: string): Promise<void> {
    if (!ClaimCacheService.CACHE_ENABLED || !claim || !claim.text) return;

    const firewalled = enforceClosedWorldCitationFirewall(claim);
    const verifiedSources = (stripEvidenceText(firewalled.richSources) || []).filter((s) => isVerifiedRichSource(s));

    if (
      !firewalled.status ||
      firewalled.status === "verification_timeout" ||
      firewalled.status === "unverified" ||
      firewalled.verificationMethod === "llm_training" ||
      firewalled.sourceStatus === "missing" ||
      verifiedSources.length === 0 ||
      (firewalled as any).processingMetadata?.requiresCitationRetry === true ||
      (firewalled.verificationConfidence !== undefined && firewalled.verificationConfidence < 0.65)
    ) {
      return;
    }

    try {
      const resolvedEnglish = (englishCanonical ?? (firewalled as any).englishCanonical ?? "").trim() || undefined;
      const keys = this.computeLookupKeys(firewalled.text, resolvedEnglish);
      const now = Date.now();
      const volatile =
        isTimeSensitiveClaim(firewalled.text) ||
        (keys.englishCanonical ? isTimeSensitiveClaim(keys.englishCanonical) : false);

      const isEvergreen = !volatile;
      const ttlMode = isEvergreen ? "evergreen_url_checked" : "short_ttl";
      const ttlDays = isEvergreen ? 0 : this.getVolatileTtlDays(firewalled);
      const expiresAt = isEvergreen ? null : now + ttlDays * 24 * 60 * 60 * 1000;
      const lastUrlCheckAt = now;

      const sanitizedReasoning = sanitizeClaimResponse(firewalled.reasoning, firewalled.status);
      const cleanSources: RichSource[] = JSON.parse(JSON.stringify(verifiedSources));
      const cachePayload: Partial<VerifiedClaim> = {
        status: firewalled.status,
        reasoning: sanitizedReasoning,
        richSources: cleanSources,
        verifiedAcademicMetadata: firewalled.verifiedAcademicMetadata,
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        verificationConfidence: firewalled.verificationConfidence || 0.85,
        displayLabel: firewalled.displayLabel,
        evidenceLevel: firewalled.evidenceLevel,
        evidenceDetails: firewalled.evidenceDetails,
        consensusDetails: firewalled.consensusDetails,
        classificationConfidence: firewalled.classificationConfidence,
        historicalEvidenceConfidence: firewalled.historicalEvidenceConfidence,
        isGrounded: true,
        verificationMethod: "cache_hit",
      };

      const l1Entry: L1CacheEntry = {
        claim: cachePayload,
        expiresAt,
        isEvergreen,
        lastUrlCheckAt,
        createdAtMs: now,
        originalText: firewalled.text,
        englishCanonical: keys.englishCanonical,
      };
      this.setToL1(keys.exactHash, l1Entry);
      if (keys.englishExactHash) {
        this.setToL1(keys.englishExactHash, l1Entry);
      }

      const isAsciiClaim = !/[^\x00-\x7F]/.test(firewalled.text);
      const storedEnglishExactHash = keys.englishExactHash ?? (isAsciiClaim ? keys.exactHash : null);
      const storedEnglishSemanticHash = keys.englishSemanticHash ?? (isAsciiClaim ? keys.semanticHash : null);

      await admin.firestore().collection(ClaimCacheService.COLLECTION).doc(keys.exactHash).set({
        originalText: firewalled.text,
        normalizedText: firewalled.text.toLowerCase().trim(),
        englishCanonical: keys.englishCanonical || (isAsciiClaim ? firewalled.text : null),
        exactHash: keys.exactHash,
        semanticHash: keys.semanticHash,
        englishExactHash: storedEnglishExactHash,
        englishSemanticHash: storedEnglishSemanticHash,
        evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
        citedDomains: Array.from(new Set(cleanSources.map((s) => s.domain).filter(Boolean))),
        citedDois: Array.from(new Set(cleanSources.map((s: any) => s.doi || s.verifiedAcademicMetadata?.doi).filter(Boolean))),
        status: firewalled.status,
        reasoning: sanitizedReasoning,
        richSources: cleanSources,
        verifiedAcademicMetadata: firewalled.verifiedAcademicMetadata || null,
        confidence: firewalled.verificationConfidence || 0.85,
        nature: firewalled.nature || "VERIFIABLE_FACT",
        displayLabel: firewalled.displayLabel || null,
        evidenceLevel: firewalled.evidenceLevel || null,
        evidenceDetails: firewalled.evidenceDetails || null,
        consensusDetails: firewalled.consensusDetails || null,
        classificationConfidence: firewalled.classificationConfidence || null,
        historicalEvidenceConfidence: firewalled.historicalEvidenceConfidence || null,
        isGrounded: true,
        isEvergreen,
        ttlMode,
        lastUrlCheckAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
        hitCount: 1,
        lastHitAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      logger.info(
        `[ClaimCache] Cached verified grounded claim (${PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION}): "${firewalled.text.substring(0, 50)}..." (${ttlMode}${isEvergreen ? "" : `, TTL: ${ttlDays}d`})`
      );
    } catch (error) {
      logger.error("[ClaimCache] Failed to set cache", { error });
    }
  }

  /**
   * Batch retrieval in strict order:
   * Tier 1A L1 LRU -> Tier 1B L2 Firestore `claim_cache` -> Tier 1C BigQuery `raw_claims_verified`
   * -> async warm-backfill -> Zero-AI Link-Liveness & Retraction Gate.
   */
  async getBatch(
    inputs: Array<string | ClaimCacheBatchInput>,
    options: ClaimCacheBatchOptions = {}
  ): Promise<Map<string, CachedClaimHit>> {
    const results = new Map<string, CachedClaimHit>();
    if (!ClaimCacheService.CACHE_ENABLED || !Array.isArray(inputs) || inputs.length === 0) {
      return results;
    }

    const normalizedInputs = inputs
      .map((item) =>
        typeof item === "string"
          ? { text: item, englishCanonical: undefined as string | undefined }
          : { text: item?.text || "", englishCanonical: item?.englishCanonical }
      )
      .filter((item) => Boolean(item.text && item.text.trim()));

    if (normalizedInputs.length === 0) {
      return results;
    }

    const metaByText = new Map<string, ReturnType<ClaimCacheService["computeLookupKeys"]> & { text: string }>();
    for (const item of normalizedInputs) {
      if (!metaByText.has(item.text)) {
        metaByText.set(item.text, {
          text: item.text,
          ...this.computeLookupKeys(item.text, item.englishCanonical),
        });
      }
    }

    const candidateHits = new Map<string, ResolvedCandidateHit>();
    const l1Misses: Array<ReturnType<ClaimCacheService["computeLookupKeys"]> & { text: string }> = [];
    const now = Date.now();

    // ── Tier 1A: L1 In-Memory LRU Cache (0ms, $0) ─────────────────────────────
    for (const item of metaByText.values()) {
      const l1Entry =
        this.getFromL1Entry(item.exactHash) ??
        (item.englishExactHash ? this.getFromL1Entry(item.englishExactHash) : null);

      if (l1Entry) {
        if (isTimeSensitiveClaim(item.text) && l1Entry.createdAtMs > 0 && now - l1Entry.createdAtMs > VOLATILE_MAX_AGE_MS) {
          this.deleteFromL1Hashes([item.exactHash, item.englishExactHash]);
          l1Misses.push(item);
          continue;
        }
        const cleanReasoning = typeof l1Entry.claim.reasoning === "string"
          ? sanitizeClaimResponse(l1Entry.claim.reasoning, l1Entry.claim.status)
          : l1Entry.claim.reasoning;
        candidateHits.set(item.text, {
          text: item.text,
          claim: { ...l1Entry.claim, reasoning: cleanReasoning },
          exactHash: item.exactHash,
          englishExactHash: item.englishExactHash,
          semanticHash: item.semanticHash,
          englishSemanticHash: item.englishSemanticHash,
          isEvergreen: l1Entry.isEvergreen,
          expiresAt: l1Entry.expiresAt,
          lastUrlCheckAt: l1Entry.lastUrlCheckAt,
          createdAtMs: l1Entry.createdAtMs,
          originalText: l1Entry.originalText,
          englishCanonical: l1Entry.englishCanonical || item.englishCanonical,
          sourceTier: "L1",
        });
      } else {
        l1Misses.push(item);
      }
    }

    // ── Tier 1B: L2 Firestore `claim_cache` ───────────────────────────────────
    const l2Misses: Array<ReturnType<ClaimCacheService["computeLookupKeys"]> & { text: string }> = [];
    if (l1Misses.length > 0) {
      try {
        const col = admin.firestore().collection(ClaimCacheService.COLLECTION);
        const docsById = new Map<string, admin.firestore.DocumentSnapshot>();
        const docsByEnglishExact = new Map<string, admin.firestore.DocumentSnapshot>();

        const exactHashes = Array.from(
          new Set(
            l1Misses.flatMap((m) => (m.englishExactHash ? [m.exactHash, m.englishExactHash] : [m.exactHash]))
          )
        );

        const fetchChunks = (list: string[]): string[][] => {
          const out: string[][] = [];
          for (let i = 0; i < list.length; i += 30) {
            out.push(list.slice(i, i + 30));
          }
          return out;
        };

        for (const chunk of fetchChunks(exactHashes)) {
          if (process.env.NODE_ENV === "test") {
            const snaps = await Promise.all(chunk.map((id) => col.doc(id).get()));
            for (const doc of snaps) {
              if (doc.exists) docsById.set(doc.id, doc);
            }
          } else if (typeof (col as any).where === "function") {
            const snap = await col.where(admin.firestore.FieldPath.documentId(), "in", chunk).get();
            snap.forEach((doc) => docsById.set(doc.id, doc));
          }
        }

        // Cross-language fallback: if English claim seeks a cached non-English doc indexed by `englishExactHash`
        const unresolvedAfterDocId = l1Misses.filter(
          (m) => !docsById.has(m.exactHash) && !(m.englishExactHash && docsById.has(m.englishExactHash))
        );
        if (unresolvedAfterDocId.length > 0 && typeof (col as any).where === "function") {
          const missingExactHashes = Array.from(
            new Set(
              unresolvedAfterDocId.flatMap((m) =>
                m.englishExactHash ? [m.exactHash, m.englishExactHash] : [m.exactHash]
              )
            )
          );
          for (const chunk of fetchChunks(missingExactHashes)) {
            const snap = await col.where("englishExactHash", "in", chunk).get();
            snap.forEach((doc) => {
              const d = doc.data();
              if (d?.englishExactHash) {
                docsByEnglishExact.set(d.englishExactHash, doc);
              }
            });
          }
        }

        const acceptL2Doc = (
          item: ReturnType<ClaimCacheService["computeLookupKeys"]> & { text: string },
          doc: admin.firestore.DocumentSnapshot,
          requireAlignmentCheck: boolean
        ): boolean => {
          const data = doc.data();
          if (!data) return false;

          const isEvergreen = data.isEvergreen === true;
          if (this.isEntryExpired(isEvergreen, data.expiresAt, now)) {
            return false;
          }

          if (isTimeSensitiveClaim(item.text)) {
            const createdMs = toEpochMs(data.createdAt, 0);
            if (createdMs > 0 && now - createdMs > VOLATILE_MAX_AGE_MS) {
              return false;
            }
          }

          if (requireAlignmentCheck) {
            const cachedComparisonText = data.englishCanonical || data.originalText || data.normalizedText || "";
            const incomingComparisonText = item.englishCanonical || item.text;
            const alignment = validatePropositionAlignment(cachedComparisonText, incomingComparisonText);
            if (!alignment.isAligned) {
              logger.info(`[ClaimCache] Semantic cache hit rejected due to proposition mismatch: ${alignment.reason}`);
              return false;
            }
          }

          const built = this.buildCachedClaimFromData(data);
          if (!built) {
            doc.ref.delete().catch(() => {});
            return false;
          }

          const createdAtMs = toEpochMs(data.createdAt, now);
          const lastUrlCheckAt = toEpochMs(data.lastUrlCheckAt, createdAtMs || now);

          candidateHits.set(item.text, {
            text: item.text,
            claim: built.claim,
            exactHash: item.exactHash,
            englishExactHash: item.englishExactHash,
            semanticHash: item.semanticHash,
            englishSemanticHash: item.englishSemanticHash,
            isEvergreen,
            expiresAt: isEvergreen ? null : (typeof data.expiresAt === "number" ? data.expiresAt : now + 30 * 24 * 60 * 60 * 1000),
            lastUrlCheckAt,
            createdAtMs,
            originalText: data.originalText || item.text,
            englishCanonical: data.englishCanonical || item.englishCanonical,
            sourceTier: "L2",
            docRef: doc.ref,
          });
          return true;
        };

        const remainingForSemantic: Array<ReturnType<ClaimCacheService["computeLookupKeys"]> & { text: string }> = [];
        for (const item of l1Misses) {
          const directDoc =
            docsById.get(item.exactHash) ??
            (item.englishExactHash ? docsById.get(item.englishExactHash) : undefined) ??
            docsByEnglishExact.get(item.exactHash) ??
            (item.englishExactHash ? docsByEnglishExact.get(item.englishExactHash) : undefined);

          if (directDoc && acceptL2Doc(item, directDoc, false)) {
            continue;
          }
          remainingForSemantic.push(item);
        }

        // Bounded semanticHash fallback (up to 5 remaining misses)
        if (typeof (col as any).where === "function") {
          for (const item of remainingForSemantic.slice(0, 5)) {
            const semanticHashesToTry = item.englishSemanticHash
              ? [item.semanticHash, item.englishSemanticHash]
              : [item.semanticHash];
            let matchedSemantic = false;
            for (const semHash of semanticHashesToTry) {
              const semSnap = await col.where("semanticHash", "==", semHash).limit(1).get();
              if (!semSnap.empty && acceptL2Doc(item, semSnap.docs[0], true)) {
                matchedSemantic = true;
                break;
              }
              const engSemSnap = await col.where("englishSemanticHash", "==", semHash).limit(1).get();
              if (!engSemSnap.empty && acceptL2Doc(item, engSemSnap.docs[0], true)) {
                matchedSemantic = true;
                break;
              }
            }
            if (!matchedSemantic) {
              l2Misses.push(item);
            }
          }
          l2Misses.push(...remainingForSemantic.slice(5));
        } else {
          l2Misses.push(...remainingForSemantic);
        }
      } catch (error) {
        logger.error("[ClaimCache] L2 Firestore batch retrieval failed", { error });
        l2Misses.push(...l1Misses);
      }
    }

    // ── Tier 1C: BigQuery `raw_claims_verified` (1 batched query <= 2500ms) ───
    if (l2Misses.length > 0 && options.enableBigQuery !== false) {
      const bqService = options.bigQueryService ?? getBigQueryAnalyticsService();
      if (bqService.isEnabled()) {
        const eligibleForBq = l2Misses.filter(
          (m) => !isTimeSensitiveClaim(m.text) && !(m.englishCanonical && isTimeSensitiveClaim(m.englishCanonical))
        );
        if (eligibleForBq.length > 0) {
          const allExact = Array.from(
            new Set(eligibleForBq.flatMap((m) => (m.englishExactHash ? [m.exactHash, m.englishExactHash] : [m.exactHash])))
          );
          const allSemantic = Array.from(
            new Set(
              eligibleForBq.flatMap((m) => (m.englishSemanticHash ? [m.semanticHash, m.englishSemanticHash] : [m.semanticHash]))
            )
          );

          const bqRows = await bqService.lookupVerifiedClaimsBatch({
            exactHashes: allExact,
            semanticHashes: allSemantic,
            schemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
            timeoutMs: 2500,
          });

          if (bqRows.length > 0) {
            const byHash = new Map<string, BigQueryVerifiedClaim>();
            const bySem = new Map<string, BigQueryVerifiedClaim>();
            for (const row of bqRows) {
              if (row.normalized_claim_hash && !byHash.has(row.normalized_claim_hash)) {
                byHash.set(row.normalized_claim_hash, row);
              }
              if (row.english_claim_hash && !byHash.has(row.english_claim_hash)) {
                byHash.set(row.english_claim_hash, row);
              }
              if (row.semantic_hash && !bySem.has(row.semantic_hash)) {
                bySem.set(row.semantic_hash, row);
              }
            }

            for (const item of eligibleForBq) {
              let matchedRow =
                byHash.get(item.exactHash) ??
                (item.englishExactHash ? byHash.get(item.englishExactHash) : undefined);
              let semanticMatch = false;

              if (!matchedRow) {
                matchedRow =
                  bySem.get(item.semanticHash) ??
                  (item.englishSemanticHash ? bySem.get(item.englishSemanticHash) : undefined);
                semanticMatch = Boolean(matchedRow);
              }
              if (!matchedRow) continue;

              if (semanticMatch) {
                const alignment = validatePropositionAlignment(
                  matchedRow.claim_text,
                  item.englishCanonical || item.text
                );
                if (!alignment.isAligned) continue;
              }

              const builtBq = this.buildCachedClaimFromBigQuery(matchedRow);
              if (!builtBq) continue;

              candidateHits.set(item.text, {
                text: item.text,
                claim: builtBq.claim,
                exactHash: item.exactHash,
                englishExactHash: item.englishExactHash,
                semanticHash: item.semanticHash,
                englishSemanticHash: item.englishSemanticHash,
                isEvergreen: builtBq.isEvergreen,
                expiresAt: builtBq.isEvergreen ? null : now + 30 * 24 * 60 * 60 * 1000,
                lastUrlCheckAt: builtBq.lastUrlCheckAt,
                createdAtMs: builtBq.createdAtMs,
                originalText: matchedRow.claim_text || item.text,
                englishCanonical: item.englishCanonical,
                sourceTier: "BQ",
                bqRow: matchedRow,
              });
            }
          }
        }
      }
    }

    // ── Zero-AI Link-Liveness & Retraction Gate ───────────────────────────────
    if (candidateHits.size === 0) {
      return results;
    }

    const agedUrlsToVerify = new Set<string>();
    const agedHits = new Set<string>();

    for (const [text, hit] of candidateHits.entries()) {
      const sources = hit.claim.richSources || [];
      if (sources.length === 0 || sources.some(isSourceRetracted)) {
        this.evictRejectedHit(hit);
        candidateHits.delete(text);
        continue;
      }

      const ageSinceLastCheck = now - (hit.lastUrlCheckAt || hit.createdAtMs || 0);
      if (ageSinceLastCheck > URL_CHECK_MAX_AGE_MS) {
        agedHits.add(text);
        for (const s of sources) {
          const u = String(s.url || s.directUrl || "").trim();
          if (u) agedUrlsToVerify.add(u);
        }
      }
    }

    let urlChecks = new Map<string, any>();
    if (agedUrlsToVerify.size > 0) {
      try {
        urlChecks = await urlVerificationService.verifyBatch(Array.from(agedUrlsToVerify), {
          bypassCache: false,
        });
      } catch (err: any) {
        logger.warn("[ClaimCache] Zero-AI aged URL check failed; failing open to re-verification", {
          err: err?.message,
        });
      }
    }

    const backfillPromises: Promise<any>[] = [];

    for (const [text, hit] of candidateHits.entries()) {
      let sources = hit.claim.richSources || [];
      let refreshedCheckAt = hit.lastUrlCheckAt;

      if (agedHits.has(text)) {
        const surviving: RichSource[] = [];
        for (const s of sources) {
          const u = String(s.url || s.directUrl || "").trim();
          const uv = u ? urlChecks.get(u) : undefined;
          if (!uv || !isLiveVerificationRecord(uv) || sourceTrustService.isRetracted(uv.canonicalUrl || u)) {
            continue;
          }
          const cleanUv = stripEvidenceText([{ ...s, urlVerification: uv }])?.[0]?.urlVerification ?? uv;
          surviving.push({
            ...s,
            url: uv.canonicalUrl || s.url,
            directUrl: uv.canonicalUrl || s.directUrl || s.url,
            urlVerification: cleanUv,
          });
        }

        if (surviving.length === 0) {
          this.evictRejectedHit(hit);
          continue;
        }
        sources = surviving;
        refreshedCheckAt = Date.now();
        hit.claim = { ...hit.claim, richSources: surviving };
        hit.lastUrlCheckAt = refreshedCheckAt;
      }

      results.set(text, hit.claim);

      // Warm L1 synchronously
      const l1Payload: L1CacheEntry = {
        claim: hit.claim,
        expiresAt: hit.expiresAt,
        isEvergreen: hit.isEvergreen,
        lastUrlCheckAt: refreshedCheckAt,
        createdAtMs: hit.createdAtMs,
        originalText: hit.originalText,
        englishCanonical: hit.englishCanonical,
      };
      this.setToL1(hit.exactHash, l1Payload);
      if (hit.englishExactHash) {
        this.setToL1(hit.englishExactHash, l1Payload);
      }

      // Warm-backfill L2 Firestore on Tier 1C BigQuery hit, or bump hitCount / lastUrlCheckAt on L2 hit
      if (hit.sourceTier === "BQ") {
        const cleanSources = stripEvidenceText(JSON.parse(JSON.stringify(sources))) || [];
        const isAscii = !/[^\x00-\x7F]/.test(hit.originalText);
        const backfillPromise = admin
          .firestore()
          .collection(ClaimCacheService.COLLECTION)
          .doc(hit.exactHash)
          .set(
            {
              originalText: hit.originalText,
              normalizedText: hit.originalText.toLowerCase().trim(),
              englishCanonical: hit.englishCanonical || (isAscii ? hit.originalText : null),
              exactHash: hit.exactHash,
              semanticHash: hit.semanticHash,
              englishExactHash: hit.englishExactHash ?? hit.bqRow?.english_claim_hash ?? (isAscii ? hit.exactHash : null),
              englishSemanticHash: hit.englishSemanticHash ?? (isAscii ? hit.semanticHash : null),
              evidenceSchemaVersion: PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION,
              citedDomains: Array.from(new Set(cleanSources.map((s) => s.domain).filter(Boolean))),
              status: hit.claim.status,
              reasoning: hit.claim.reasoning,
              richSources: cleanSources,
              confidence: hit.claim.verificationConfidence ?? 0.85,
              isGrounded: true,
              isEvergreen: hit.isEvergreen,
              ttlMode: hit.isEvergreen ? "evergreen_url_checked" : "short_ttl",
              lastUrlCheckAt: refreshedCheckAt,
              createdAt: hit.createdAtMs || Date.now(),
              expiresAt: hit.expiresAt,
              hitCount: 1,
              lastHitAt: admin.firestore.FieldValue.serverTimestamp(),
              warmBackfilledFromBigQuery: true,
            },
            { merge: true }
          )
          .catch(() => {});
        backfillPromises.push(backfillPromise);
      } else if (hit.docRef) {
        const updatePayload: Record<string, any> = {
          hitCount: admin.firestore.FieldValue.increment(1),
          lastHitAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (agedHits.has(text)) {
          updatePayload.lastUrlCheckAt = refreshedCheckAt;
          updatePayload.richSources = stripEvidenceText(JSON.parse(JSON.stringify(sources)));
        }
        backfillPromises.push(hit.docRef.update(updatePayload).catch(() => {}));
      }
    }

    if (backfillPromises.length > 0) {
      await Promise.allSettled(backfillPromises);
    }

    return results;
  }

  private deleteFromL1Hashes(hashes: Array<string | undefined>): void {
    for (const h of hashes) {
      if (h) ClaimCacheService.l1Cache.delete(h);
    }
  }

  private evictRejectedHit(hit: ResolvedCandidateHit): void {
    this.deleteFromL1Hashes([hit.exactHash, hit.englishExactHash]);
    if (hit.docRef) {
      hit.docRef.delete().catch(() => {});
    }
  }

  /**
   * Batch save verified claims to cache.
   */
  async setBatch(claims: VerifiedClaim[], englishCanonicalMap?: Map<string, string>): Promise<void> {
    if (!ClaimCacheService.CACHE_ENABLED || claims.length === 0) return;
    await Promise.allSettled(
      claims.map((c) => {
        const english = englishCanonicalMap?.get(c.claimId) ?? englishCanonicalMap?.get(c.text);
        return this.set(c, english);
      })
    );
  }

  /**
   * Clears the L1 in-memory cache (useful for testing or cache invalidation).
   */
  static clearL1Cache(): void {
    ClaimCacheService.l1Cache.clear();
  }

  /**
   * 🛡️ Invalidate cached claims citing a retracted URL, domain, or DOI.
   * Purges from both L1 memory cache and persistent L2 Firestore cache.
   */
  public static async invalidateForRetractedSource(urlOrDoi: string): Promise<number> {
    if (!urlOrDoi) return 0;
    const clean = urlOrDoi.toLowerCase().trim();
    let invalidatedCount = 0;

    // 1. Purge L1 Memory Cache
    for (const [key, entry] of ClaimCacheService.l1Cache.entries()) {
      const sources = entry.claim.richSources || [];
      const hasRetracted = sources.some(
        (s) =>
          (s.url && s.url.toLowerCase().includes(clean)) ||
          (s.domain && clean.includes(s.domain.toLowerCase()))
      );
      if (hasRetracted) {
        ClaimCacheService.l1Cache.delete(key);
        invalidatedCount++;
      }
    }

    // 2. Invalidate L2 Firestore Cache
    try {
      const snap = await admin
        .firestore()
        .collection(ClaimCacheService.COLLECTION)
        .where("citedDomains", "array-contains", clean)
        .limit(100)
        .get();

      for (const doc of snap.docs) {
        await doc.ref.delete().catch(() => {});
        invalidatedCount++;
      }
    } catch (_) {}

    return invalidatedCount;
  }
}

export const claimCacheService = new ClaimCacheService();
