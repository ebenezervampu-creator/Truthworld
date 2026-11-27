/**
 * One-time & idempotent backfill CLI: migrates existing verified claims from
 * Firestore `claim_cache` and GCS `factChecks/<jobId>/full.json` reports into
 * BigQuery `raw_claims_verified`.
 *
 * Dry-run by default. Pass `--apply` to persist rows to BigQuery.
 * Flags:
 *   --apply                Actually write rows to BigQuery (default: dry-run)
 *   --limit=<N>            Cap maximum claims processed
 *   --source=cache|gcs|both  Source to scan (default: both)
 */

import * as admin from "firebase-admin";
import {
  BigQueryAnalyticsService,
  BigQueryVerifiedClaim,
  getBigQueryAnalyticsService,
} from "../src/analytics/bigqueryService";
import { PIPELINE_CONFIG } from "../src/pipeline/config";
import { RichSource } from "../src/pipeline/types";
import { isClosedWorldCacheEntryValid, isVerifiedRichSource } from "../src/pipeline/services/urlVerificationService";
import { stripEvidenceText } from "../src/pipeline/services/verdictReconciliation";
import {
  hashClaimText,
  hashSemanticClaimText,
} from "../src/pipeline/utils/claim-normalization";

export type BackfillSourceMode = "cache" | "gcs" | "both";

export interface BackfillCliOptions {
  apply: boolean;
  limit?: number;
  source: BackfillSourceMode;
}

export interface BackfillCacheRecord {
  id: string;
  data: Record<string, any>;
}

export interface BackfillGcsReportRecord {
  path: string;
  report: Record<string, any>;
}

export interface BackfillRunSummary {
  apply: boolean;
  source: BackfillSourceMode;
  scannedCacheDocs: number;
  scannedGcsReports: number;
  preparedRows: number;
  writtenRows: number;
}

const NON_GROUNDED_STATUSES = new Set([
  "unproven",
  "unsupported",
  "unverified",
  "inconclusive",
  "verification_timeout",
  "opinion_claim",
  "opinion",
  "religious_belief",
  "satire_claim",
]);

export function parseBackfillCliArgs(argv: string[]): BackfillCliOptions {
  let apply = false;
  let limit: number | undefined;
  let source: BackfillSourceMode = "both";

  for (const arg of argv) {
    if (arg === "--apply") {
      apply = true;
    } else if (arg.startsWith("--limit=")) {
      const n = Number(arg.slice("--limit=".length));
      if (Number.isFinite(n) && n > 0) {
        limit = Math.floor(n);
      }
    } else if (arg.startsWith("--source=")) {
      const val = arg.slice("--source=".length).toLowerCase();
      if (val === "cache" || val === "gcs" || val === "both") {
        source = val;
      }
    }
  }

  return { apply, limit, source };
}

function isAsciiText(text: string): boolean {
  return !/[^\x00-\x7F]/.test(text);
}

function toIsoTimestamp(val: any, fallbackIso: string): string {
  if (typeof val === "number" && Number.isFinite(val)) {
    return new Date(val).toISOString();
  }
  if (val && typeof val.toDate === "function") {
    return val.toDate().toISOString();
  }
  if (typeof val === "string" && !Number.isNaN(Date.parse(val))) {
    return new Date(val).toISOString();
  }
  return fallbackIso;
}

function normalizeCleanSources(rawSources: any[]): RichSource[] {
  if (!Array.isArray(rawSources)) return [];
  const stripped = stripEvidenceText(rawSources as RichSource[]) || [];
  return stripped.filter((s) => isVerifiedRichSource(s));
}

function extractVideoIdFromReportPath(path: string, report: Record<string, any>): string {
  if (typeof report?.videoId === "string" && report.videoId.trim()) {
    return report.videoId.trim();
  }
  if (typeof report?.jobId === "string" && report.jobId.trim()) {
    return report.jobId.trim();
  }
  const match = path.match(/factChecks\/([^/]+)\//);
  return match ? match[1] : "backfill_report";
}

export function buildBackfillRowsFromRecords(params: {
  cacheDocs?: BackfillCacheRecord[];
  gcsReports?: BackfillGcsReportRecord[];
  nowIso?: string;
}): BigQueryVerifiedClaim[] {
  const nowIso = params.nowIso ?? new Date().toISOString();
  const deduped = new Map<string, BigQueryVerifiedClaim>();

  const upsertRow = (row: BigQueryVerifiedClaim) => {
    const key = row.normalized_claim_hash || row.claim_id;
    const existing = deduped.get(key);
    if (!existing) {
      deduped.set(key, row);
      return;
    }
    const existingCount = existing.sources_count ?? 0;
    const nextCount = row.sources_count ?? 0;
    if (nextCount > existingCount) {
      deduped.set(key, row);
    }
  };

  for (const doc of params.cacheDocs || []) {
    const data = doc.data || {};
    const status = String(data.status || data.claim?.status || "").toLowerCase();
    if (!status || NON_GROUNDED_STATUSES.has(status)) continue;

    const claimText = String(data.originalText || data.normalizedText || data.claim?.text || "").trim();
    if (!claimText) continue;

    const cleanSources = normalizeCleanSources(data.richSources || data.claim?.richSources || []);
    const schemaVersion = String(
      data.evidenceSchemaVersion || data.claim?.evidenceSchemaVersion || PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION
    );
    if (!isClosedWorldCacheEntryValid({ evidenceSchemaVersion: schemaVersion, richSources: cleanSources })) {
      continue;
    }

    const exactHash = String(data.exactHash || doc.id || hashClaimText(claimText));
    const semanticHash = String(data.semanticHash || hashSemanticClaimText(claimText));
    const englishCanonical = typeof data.englishCanonical === "string" && data.englishCanonical.trim()
      ? data.englishCanonical.trim()
      : undefined;
    const englishHash =
      data.englishExactHash ||
      (englishCanonical ? hashClaimText(englishCanonical) : isAsciiText(claimText) ? exactHash : null);

    const primary = cleanSources[0];
    upsertRow({
      claim_id: `backfill_cache_${exactHash.slice(0, 24)}`,
      timestamp: toIsoTimestamp(data.lastUrlCheckAt || data.createdAt, nowIso),
      video_id: "cache_backfill",
      claim_text: claimText,
      normalized_claim_hash: exactHash,
      english_claim_hash: englishHash,
      semantic_hash: semanticHash,
      evidence_schema_version: schemaVersion,
      rich_sources_json: JSON.stringify(cleanSources),
      status,
      verification_method: "cache_hit",
      verification_confidence: typeof data.confidence === "number" ? data.confidence : 0.85,
      reasoning: typeof data.reasoning === "string" ? data.reasoning : "",
      sources_count: cleanSources.length,
      primary_source_url: primary?.url || null,
      primary_source_domain: primary?.domain || null,
      primary_source_tier: primary?.tier || null,
      is_grounded: true,
      nature: typeof data.nature === "string" ? data.nature : "VERIFIABLE_FACT",
    });
  }

  for (const item of params.gcsReports || []) {
    const report = item.report || {};
    const videoId = extractVideoIdFromReportPath(item.path, report);
    const claims: any[] = Array.isArray(report.claims)
      ? report.claims
      : Array.isArray(report.verifiedClaims)
        ? report.verifiedClaims
        : [];

    for (const c of claims) {
      if (!c || typeof c !== "object") continue;
      const status = String(c.status || "").toLowerCase();
      if (!status || NON_GROUNDED_STATUSES.has(status)) continue;
      if (c.verificationMethod === "llm_training") continue;

      const claimText = String(c.text || c.claim || "").trim();
      if (!claimText) continue;

      const cleanSources = normalizeCleanSources(c.richSources || []);
      const schemaVersion = String(
        c.evidenceSchemaVersion || report.evidenceSchemaVersion || PIPELINE_CONFIG.EVIDENCE_SCHEMA_VERSION
      );
      if (!isClosedWorldCacheEntryValid({ evidenceSchemaVersion: schemaVersion, richSources: cleanSources })) {
        continue;
      }

      const exactHash = hashClaimText(claimText);
      const semanticHash = hashSemanticClaimText(claimText);
      const englishHash = isAsciiText(claimText) ? exactHash : null;
      const primary = cleanSources[0];

      upsertRow({
        claim_id: String(c.claimId || `backfill_gcs_${exactHash.slice(0, 24)}`),
        timestamp: toIsoTimestamp(report.completedAt || report.updatedAt || report.createdAt, nowIso),
        video_id: videoId,
        channel_id: report.channelId || null,
        user_id: report.userId || null,
        claim_text: claimText,
        normalized_claim_hash: exactHash,
        english_claim_hash: englishHash,
        semantic_hash: semanticHash,
        evidence_schema_version: schemaVersion,
        rich_sources_json: JSON.stringify(cleanSources),
        status,
        verification_method: c.verificationMethod || "grounded",
        verification_confidence: typeof c.verificationConfidence === "number" ? c.verificationConfidence : (typeof c.confidence === "number" ? c.confidence : 0.85),
        reasoning: typeof c.reasoning === "string" ? c.reasoning : "",
        sources_count: cleanSources.length,
        primary_source_url: primary?.url || null,
        primary_source_domain: primary?.domain || null,
        primary_source_tier: primary?.tier || null,
        is_grounded: true,
        nature: typeof c.nature === "string" ? c.nature : "VERIFIABLE_FACT",
        language: report.language || null,
      });
    }
  }

  return Array.from(deduped.values());
}

export async function runBackfillClaimsBigQuery(
  options: BackfillCliOptions,
  deps: {
    firestore?: admin.firestore.Firestore;
    bucket?: any;
    bigQueryService?: BigQueryAnalyticsService;
  } = {}
): Promise<BackfillRunSummary> {
  const db = deps.firestore ?? admin.firestore();
  const bq = deps.bigQueryService ?? getBigQueryAnalyticsService();
  const pageSize = 200;

  const cacheDocs: BackfillCacheRecord[] = [];
  const gcsReports: BackfillGcsReportRecord[] = [];

  if (options.source === "cache" || options.source === "both") {
    let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;
    while (true) {
      let query: admin.firestore.Query = db
        .collection("claim_cache")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(pageSize);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }
      const snap = await query.get();
      if (snap.empty) break;

      for (const doc of snap.docs) {
        cacheDocs.push({ id: doc.id, data: doc.data() });
        if (options.limit && cacheDocs.length >= options.limit) break;
      }

      if ((options.limit && cacheDocs.length >= options.limit) || snap.docs.length < pageSize) {
        break;
      }
      lastDoc = snap.docs[snap.docs.length - 1];
    }
  }

  if (options.source === "gcs" || options.source === "both") {
    const bucket = deps.bucket ?? admin.storage().bucket();
    if (bucket && typeof bucket.getFiles === "function") {
      let pageToken: string | undefined;
      while (true) {
        const [files, nextQuery] = await bucket.getFiles({
          prefix: "factChecks/",
          autoPaginate: false,
          maxResults: pageSize,
          ...(pageToken ? { pageToken } : {}),
        });
        const reportFiles = (files || []).filter((f: any) => String(f?.name || "").endsWith("/full.json"));
        for (const file of reportFiles) {
          try {
            const [buf] = await file.download();
            const report = JSON.parse(buf.toString("utf8"));
            gcsReports.push({ path: file.name, report });
          } catch {
            // Skip malformed report files cleanly
          }
          if (options.limit && gcsReports.length >= options.limit) break;
        }
        pageToken = nextQuery?.pageToken;
        if (!pageToken || (options.limit && gcsReports.length >= options.limit)) {
          break;
        }
      }
    }
  }

  let rows = buildBackfillRowsFromRecords({ cacheDocs, gcsReports });
  if (options.limit && rows.length > options.limit) {
    rows = rows.slice(0, options.limit);
  }

  let writtenRows = 0;
  if (options.apply && rows.length > 0) {
    await bq.ensureSchema();
    for (let i = 0; i < rows.length; i += 200) {
      const batch = rows.slice(i, i + 200);
      await bq.insertVerifiedClaims(batch);
      writtenRows += batch.length;
    }
  }

  return {
    apply: options.apply,
    source: options.source,
    scannedCacheDocs: cacheDocs.length,
    scannedGcsReports: gcsReports.length,
    preparedRows: rows.length,
    writtenRows,
  };
}

if (require.main === module) {
  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    process.env.PROJECT_ID ||
    "truthworld-1";
  const storageBucket =
    process.env.STORAGE_BUCKET ||
    process.env.FIREBASE_STORAGE_BUCKET ||
    `${projectId}.firebasestorage.app`;

  if (!admin.apps.length) {
    admin.initializeApp({ projectId, storageBucket });
  }
  const opts = parseBackfillCliArgs(process.argv.slice(2));
  runBackfillClaimsBigQuery(opts, {
    bucket: admin.storage().bucket(storageBucket),
    bigQueryService: new BigQueryAnalyticsService({ enabled: true, projectId, flushIntervalMs: 0 }),
  })
    .then((summary) => {
      console.log(JSON.stringify({ status: "ok", ...summary }, null, 2));
      process.exit(0);
    })
    .catch((err) => {
      console.error("[backfill-claims-bigquery] Failed:", err);
      process.exit(1);
    });
}
