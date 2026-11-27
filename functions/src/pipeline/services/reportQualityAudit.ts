/**
 * Credibility Report Quality Audit
 *
 * Runs on every finished fact-check report before it is saved and grades the OUTPUT
 * (not the pipeline mechanics). It exists so that the failure modes found in the
 * 2026-11-19 audit are caught by the system, not by users:
 *
 *   1. SHARED_SOURCE         — many claims show the same source (mis-attribution).
 *   2. UNVERIFIED_SOURCE     — a displayed source has a failed / missing live check.
 *   3. VERDICT_CONTRADICTION — a Caution verdict whose explanation says "confirmed",
 *                              or a Verified verdict whose explanation says "no proof".
 *   4. ZERO_SOURCE_FACTS     — most factual claims have no source at all.
 *   5. CAUTION_HEAVY         — most factual claims ended in Caution.
 *   6. VIDEO_SOURCES_MISMATCH— the video-level source list misses claim sources.
 *   7. MIXED_LANGUAGE        — explanations are written in more than one script.
 *
 * The audit never changes verdicts and never blocks publishing; it records a grade,
 * emits a structured log line for log-based metrics/alerts, and stores FAIL/WARN
 * reports for review. Pure function + one side-effect helper so it is fully testable.
 */

import { isLiveVerificationRecord } from "./urlVerificationService";

export type QualityGrade = "PASS" | "WARN" | "FAIL";

export interface QualityCheck {
  id:
    | "SHARED_SOURCE"
    | "UNVERIFIED_SOURCE"
    | "VERDICT_CONTRADICTION"
    | "ZERO_SOURCE_FACTS"
    | "CAUTION_HEAVY"
    | "UNPROVEN_HEAVY"
    | "VIDEO_SOURCES_MISMATCH"
    | "MIXED_LANGUAGE";
  severity: "WARN" | "FAIL";
  message: string;
  claimIds?: string[];
  value?: number;
}

export interface ReportQualityAudit {
  version: 1;
  grade: QualityGrade;
  auditedAtUtc: string;
  metrics: {
    totalClaims: number;
    factualClaims: number;
    verifiedClaims: number;
    cautionClaims: number;
    falseClaims: number;
    unprovenClaims: number;
    contextualClaims: number;
    factualWithSources: number;
    zeroSourceFacts: number;
    zeroSourceFactRatio: number;
    cautionRatio: number;
    unprovenRatio: number;
    maxSharedSourceRatio: number;
    maxSharedSourceUrl?: string;
    distinctClaimSources: number;
    videoLevelSources: number;
    contradictions: number;
    unverifiedDisplayedSources: number;
  };
  checks: QualityCheck[];
}

const VERIFIED = new Set(["verified_true", "mostly_true", "correct", "mostly_correct", "partially_true", "novel_hypothesis"]);
const FALSE_LIKE = new Set(["false_claim", "verified_false", "incorrect", "misleading", "historical_consensus_denial", "incorrect_citation"]);
const UNPROVEN = new Set(["unproven", "unsupported", "unverified", "inconclusive", "verification_timeout"]);
const CONTEXTUAL = new Set([
  "opinion", "opinion_claim", "opinion_or_prediction", "satire", "satire_claim", "religious_belief",
  "faith_based_claim", "faith_context", "tradition_linked", "historical_tradition", "not_historically_verifiable",
  "rhetorical_exaggeration", "value_judgment", "preference_statement", "anecdotal_experience",
]);
const NON_FACTUAL_NATURES = new Set([
  "OPINION", "BELIEF", "PREDICTION", "RELIGIOUS_CLAIM", "SUPERNATURAL_CLAIM", "RHETORICAL_EXAGGERATION",
]);

// Heuristic phrase lists (English) — intentionally conservative to avoid false alarms.
const CONFIRMS_RX = /\b(is confirmed|are confirmed|confirmed (to|that|by)|is (indeed )?(true|correct|accurate)|backed up by|records (show|confirm)|reports confirm|this is true)\b/i;
const DENIES_RX = /\b(no (solid |clear |real )?(proof|evidence|sources?)|could not (find|confirm|link)|couldn't (find|confirm|link)|not (been )?(confirmed|verified)|cannot be confirmed|unconfirmed)\b/i;

const SCRIPTS: Array<[string, RegExp]> = [
  ["latin", /[A-Za-z]/g], ["telugu", /[ఀ-౿]/g], ["devanagari", /[ऀ-ॿ]/g],
  ["tamil", /[஀-௿]/g], ["kannada", /[ಀ-೿]/g], ["malayalam", /[ഀ-ൿ]/g],
  ["bengali", /[ঀ-৿]/g], ["arabic", /[؀-ۿ]/g],
];

function dominantScript(text: string): string | undefined {
  let best: [string, number] | undefined;
  for (const [name, rx] of SCRIPTS) {
    const n = (text.match(rx) || []).length;
    if (n > 0 && (!best || n > best[1])) best = [name, n];
  }
  return best && best[1] >= 12 ? best[0] : undefined;
}

function normUrl(u: unknown): string {
  return String(u || "").trim().toLowerCase().split("#")[0].replace(/\/+$/, "");
}

function displayedSources(claim: any): any[] {
  const list = Array.isArray(claim?.sources) && claim.sources.some((s: any) => s && typeof s === "object")
    ? claim.sources
    : Array.isArray(claim?.richSources) ? claim.richSources : [];
  return list.filter((s: any) => s && typeof s === "object" && /^https?:\/\//i.test(String(s.url || s.directUrl || "")));
}

export function auditCredibilityReport(report: any, now: Date = new Date()): ReportQualityAudit {
  const claims: any[] = Array.isArray(report?.claims) ? report.claims : [];
  const checks: QualityCheck[] = [];

  let factual = 0, verified = 0, caution = 0, falseCount = 0, unproven = 0, contextual = 0, factualWithSources = 0;
  const sourceToClaims = new Map<string, Set<string>>();
  const contradictionIds: string[] = [];
  const unverifiedIds: string[] = [];
  const zeroSourceIds: string[] = [];
  const scripts = new Map<string, number>();

  claims.forEach((c, idx) => {
    const id = String(c?.claimId || `claim_${idx}`);
    const status = String(c?.status || "").toLowerCase();
    const nature = String(c?.nature || "").toUpperCase();
    const reasoning = String(c?.reasoning || c?.explanation || c?.verificationSummary || "");
    const isContextual = CONTEXTUAL.has(status) || NON_FACTUAL_NATURES.has(nature);

    if (isContextual) { contextual++; return; }
    factual++;
    if (VERIFIED.has(status)) verified++;
    else if (FALSE_LIKE.has(status)) falseCount++;
    else if (UNPROVEN.has(status) || !status) unproven++;
    else caution++;

    const srcs = displayedSources(c);
    if (srcs.length > 0) factualWithSources++; else zeroSourceIds.push(id);

    const seenInClaim = new Set<string>();
    for (const s of srcs) {
      const key = normUrl(s.url || s.directUrl);
      if (!key || seenInClaim.has(key)) continue;
      seenInClaim.add(key);
      if (!sourceToClaims.has(key)) sourceToClaims.set(key, new Set());
      sourceToClaims.get(key)!.add(id);
      if (s.urlVerification && !isLiveVerificationRecord(s.urlVerification)) unverifiedIds.push(id);
    }

    const isUnconfirmedVerdict = !VERIFIED.has(status) && !FALSE_LIKE.has(status);
    if ((isUnconfirmedVerdict && CONFIRMS_RX.test(reasoning) && !DENIES_RX.test(reasoning)) ||
        (VERIFIED.has(status) && DENIES_RX.test(reasoning) && !CONFIRMS_RX.test(reasoning))) {
      contradictionIds.push(id);
    }

    const script = dominantScript(reasoning);
    if (script) scripts.set(script, (scripts.get(script) || 0) + 1);
  });

  // 1. Shared source concentration
  let maxShared = 0;
  let maxSharedUrl: string | undefined;
  let maxSharedIds: string[] = [];
  for (const [url, ids] of sourceToClaims) {
    if (ids.size > maxShared) { maxShared = ids.size; maxSharedUrl = url; maxSharedIds = Array.from(ids); }
  }
  const sharedRatio = factualWithSources > 0 ? maxShared / factualWithSources : 0;
  if (maxShared >= 4 && sharedRatio >= 0.4) {
    checks.push({
      id: "SHARED_SOURCE", severity: "FAIL", value: round(sharedRatio), claimIds: maxSharedIds,
      message: `${maxShared} of ${factualWithSources} sourced claims show the same source (${maxSharedUrl}); likely mis-attribution.`,
    });
  } else if (maxShared >= 3 && sharedRatio >= 0.3) {
    checks.push({
      id: "SHARED_SOURCE", severity: "WARN", value: round(sharedRatio), claimIds: maxSharedIds,
      message: `${maxShared} claims share one source (${maxSharedUrl}).`,
    });
  }

  // 2. Displayed sources that failed live verification
  const uniqueUnverified = Array.from(new Set(unverifiedIds));
  if (uniqueUnverified.length > 0) {
    checks.push({
      id: "UNVERIFIED_SOURCE", severity: "FAIL", value: uniqueUnverified.length, claimIds: uniqueUnverified,
      message: `${uniqueUnverified.length} claim(s) display a source whose live URL check did not pass.`,
    });
  }

  // 3. Verdict / explanation contradiction
  if (contradictionIds.length > 0) {
    checks.push({
      id: "VERDICT_CONTRADICTION", severity: contradictionIds.length >= 2 ? "FAIL" : "WARN",
      value: contradictionIds.length, claimIds: contradictionIds,
      message: `${contradictionIds.length} claim(s) have a verdict that contradicts their own explanation.`,
    });
  }

  // 4. Zero-source factual claims
  const zeroRatio = factual > 0 ? zeroSourceIds.length / factual : 0;
  if (factual >= 5 && zeroRatio >= 0.7) {
    checks.push({ id: "ZERO_SOURCE_FACTS", severity: "FAIL", value: round(zeroRatio), claimIds: zeroSourceIds,
      message: `${zeroSourceIds.length} of ${factual} factual claims have no source.` });
  } else if (factual >= 5 && zeroRatio >= 0.4) {
    checks.push({ id: "ZERO_SOURCE_FACTS", severity: "WARN", value: round(zeroRatio), claimIds: zeroSourceIds,
      message: `${zeroSourceIds.length} of ${factual} factual claims have no source.` });
  }

  // 5. Caution-heavy / Unproven-heavy outcome (keep CAUTION and UNPROVEN distinct)
  const cautionRatio = factual > 0 ? caution / factual : 0;
  const unprovenRatio = factual > 0 ? unproven / factual : 0;
  if (factual >= 5 && cautionRatio >= 0.7) {
    checks.push({ id: "CAUTION_HEAVY", severity: "WARN", value: round(cautionRatio),
      message: `${caution} of ${factual} factual claims ended in Caution.` });
  }
  if (factual >= 5 && unprovenRatio >= 0.7) {
    checks.push({ id: "UNPROVEN_HEAVY", severity: "WARN", value: round(unprovenRatio),
      message: `${unproven} of ${factual} factual claims ended with no evidence yet.` });
  }

  // 6. Video-level source list should cover claim sources
  const videoSources: any[] = Array.isArray(report?.sources) ? report.sources : [];
  const videoSet = new Set(videoSources.map((s) => normUrl(typeof s === "string" ? s : s?.url || s?.directUrl)).filter(Boolean));
  const missingAtVideoLevel = Array.from(sourceToClaims.keys()).filter((u) => !videoSet.has(u));
  if (sourceToClaims.size >= 2 && missingAtVideoLevel.length / sourceToClaims.size > 0.5) {
    checks.push({ id: "VIDEO_SOURCES_MISMATCH", severity: "WARN", value: missingAtVideoLevel.length,
      message: `Video-level Sources list shows ${videoSet.size} source(s) but claims cite ${sourceToClaims.size}.` });
  }

  // 7. Mixed explanation languages
  if (scripts.size > 1) {
    const total = Array.from(scripts.values()).reduce((a, b) => a + b, 0);
    const minority = total - Math.max(...scripts.values());
    checks.push({ id: "MIXED_LANGUAGE", severity: "WARN", value: minority,
      message: `Explanations are written in ${scripts.size} scripts (${Array.from(scripts.keys()).join(", ")}).` });
  }

  const grade: QualityGrade = checks.some((c) => c.severity === "FAIL") ? "FAIL" : checks.length > 0 ? "WARN" : "PASS";

  return {
    version: 1,
    grade,
    auditedAtUtc: now.toISOString(),
    metrics: {
      totalClaims: claims.length,
      factualClaims: factual,
      verifiedClaims: verified,
      cautionClaims: caution,
      falseClaims: falseCount,
      unprovenClaims: unproven,
      contextualClaims: contextual,
      factualWithSources,
      zeroSourceFacts: zeroSourceIds.length,
      zeroSourceFactRatio: round(zeroRatio),
      cautionRatio: round(cautionRatio),
      unprovenRatio: round(unprovenRatio),
      maxSharedSourceRatio: round(sharedRatio),
      maxSharedSourceUrl: maxSharedUrl,
      distinctClaimSources: sourceToClaims.size,
      videoLevelSources: videoSet.size,
      contradictions: contradictionIds.length,
      unverifiedDisplayedSources: uniqueUnverified.length,
    },
    checks,
  };
}

function round(n: number): number {
  return Math.round(n * 1000) / 1000;
}
