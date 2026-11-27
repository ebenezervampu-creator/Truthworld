/**
 * Verdict Gate — the last code-level check before any credibility report is saved.
 *
 * Prompts guide the model; this gate GUARANTEES the published output. Every save path
 * (first fact-check, async synthesis update, source healing, approved community evidence,
 * the daily evidence-freshness sweep) runs `applyVerdictGateToReport` on the report.
 *
 * Public verdict classes and the evidence each one requires:
 *
 * | Public verdict  | Required evidence                                                       |
 * |-----------------|-------------------------------------------------------------------------|
 * | VERIFIED        | ≥1 live Tier A/B source that SUPPORTS the claim, or ≥2 independent live   |
 * |                 | VETTED Tier C/D publishers that SUPPORT it (unknown domains don't count) |
 * | FALSE           | same bar with sources that CONTRADICT the claim                          |
 * | CAUTION         | ≥1 live source with an explicit stance (supports / contradicts / mixed)   |
 * | OPINION_BELIEF  | verbatim subjective quote from the video + timestamp; not falsifiable     |
 *
 * A source's stance comes from the stance step (stanceClassifier.ts), judged from the
 * source's own text. Off-topic, unreadable or unlabelled sources carry no weight.
 * | UNPROVEN        | anything that fails the above — fixed message, no generated commentary   |
 *
 * Rules that follow from the table:
 *  - CAUTION is never a fallback: no evidence → UNPROVEN, never CAUTION.
 *  - Failing the evidence bar moves a verdict to UNPROVEN, never to CAUTION, so a
 *    confirmed claim can never be "downgraded to Caution" by a search miss.
 *  - Unknown / unmapped statuses fail closed to UNPROVEN.
 *  - A source with no URL-verification record is not live (fail closed).
 *  - Authoritative conflict: if a live Tier A/B source points the OTHER way, VERIFIED and
 *    FALSE both become CAUTION (DISPUTED) — neither side wins by default.
 */

import { RichSource, SourceRole } from "../types";
import { isLiveVerificationRecord } from "./urlVerificationService";
import { explicitStance, stripEvidenceText } from "./verdictReconciliation";
import { sourceTrustService, classifyInstitutionalHost, hostOf } from "./sourceTrustService";

export type PublicVerdict = "VERIFIED" | "FALSE" | "CAUTION" | "OPINION_BELIEF" | "UNPROVEN";
export type CautionType = "MISLEADING" | "MISSING_CONTEXT" | "EXAGGERATED" | "DISPUTED" | "HALF_TRUE" | "OUTDATED";

export const CONFLICTING_EVIDENCE_MESSAGE =
  "Reliable sources disagree on this claim. At least one authoritative source supports it and at least one refutes it, so we are not rating it true or false.";

export const NO_EVIDENCE_MESSAGE =
  "No verifiable evidence found yet. We searched for a live, checkable source for this claim and could not find one, so we are not rating it true or false.";

const VERIFIED_STATUSES = new Set(["verified_true", "mostly_true", "correct", "mostly_correct"]);
const FALSE_STATUSES = new Set(["false_claim", "verified_false", "incorrect", "historical_consensus_denial", "incorrect_citation"]);
const CAUTION_STATUS_TYPE: Record<string, CautionType> = {
  misleading: "MISLEADING",
  needs_context: "MISSING_CONTEXT",
  rhetorical_exaggeration: "EXAGGERATED",
  disputed: "DISPUTED",
  partially_true: "HALF_TRUE",
  outdated: "OUTDATED",
};
const OPINION_STATUSES = new Set([
  "opinion_claim", "opinion", "opinion_or_prediction", "religious_belief", "faith_based_claim", "faith_context",
  "satire_claim", "satire", "value_judgment", "preference_statement", "tradition_linked", "historical_tradition",
  "anecdotal_experience",
]);
/** Statuses that are not verdicts yet (work in progress) — left untouched. */
const IN_PROGRESS_STATUSES = new Set(["evaluating", "pending", "processing"]);

// Words that mark a statement as a judgment, feeling, belief or preference.
const SUBJECTIVE_MARKER_RX = new RegExp(
  [
    "\\b(i|we)\\s+(think|believe|feel|guess|suppose|reckon|consider|hope|love|hate|like|prefer)\\b",
    "\\bin my (view|opinion)\\b", "\\bto me\\b", "\\bpersonally\\b", "\\bi'm (sure|convinced)\\b",
    "\\b(should|ought to|must)\\b",
    "\\b(best|worst|greatest|beautiful|ugly|brilliant|terrible|awful|amazing|wonderful|disgraceful|shameful|boring|overrated|underrated|masterpiece)\\b",
    "\\b(seared|unforgettable|heartbreaking|inspiring|disturbing|moving)\\b",
    "\\b\\d+(\\.\\d+)?\\s*(out of|/)\\s*(5|10|100)\\b", "\\b(rate|rating|rated)\\b",
    "\\b(god|divine|faith|sacred|blessed|soul|karma|destiny)\\b",
    "నా అభిప్రాయం", "నేను అనుకుంటున్నా", "నమ్ముతున్నా",
    "मेरा मानना", "मुझे लगता", "मेरी राय",
  ].join("|"),
  "i"
);

// Empirical assertions, crimes, or allegations that can NEVER be classified as opinions,
// even if hedged ("I believe the election was rigged", "I think vaccines cause autism")
const EMPIRICAL_OR_ALLEGATION_RX = /\b(rigged|stolen|fraud|election|ballots?|vote-rigging|voting|bribe|bribery|corrupt|stole|embezzled|laundered|killed|murdered|assassinated|vaccin\w*|autism|cancer|cure|prevent\w*|disease|virus|infection|pathogen|hospital|doctor|5g|radiation|boil\w*|freeze\w*|speed of light|atmosphere|capital of|repo rate|interest rate|gdp|treaty|banned?|faked|conspiracy|hoax|landed on|moon landing)\b/i;

// Genuine subjective sentiment, aesthetic evaluation, or faith markers (conversational hedges alone are not opinions)
const GENUINE_SUBJECTIVE_MARKER_RX = new RegExp(
  [
    "\\b(best|worst|greatest|beautiful|ugly|brilliant|terrible|awful|amazing|wonderful|disgraceful|shameful|boring|overrated|underrated|masterpiece)\\b",
    "\\b(favorite|favourite|prefer|preference|love|hate|enjoy)\\b",
    "\\b(seared|unforgettable|heartbreaking|inspiring|disturbing|moving)\\b",
    "\\b\\d+(\\.\\d+)?\\s*(out of|/)\\s*(5|10|100)\\b", "\\b(rate|rating|rated)\\b",
    "\\b(god|divine|faith|sacred|blessed|soul|karma|destiny)\\b",
    "నా అభిప్రాయం", "నేను అనుకుంటున్నా", "నమ్ముతున్నా",
    "मेरा मानना", "मुझे लगता", "मेरी राय",
  ].join("|"),
  "i"
);

// Amounts, percentages and statistics — used ONLY when the adjudicator gave no
// falsifiability judgment for the statement.
const UNJUDGED_CHECKABLE_RX = /\b\d+(\.\d+)?\s?(%|percent|per cent|crore|lakh|million|billion)\b|[₹$€£]\s?\d/i;

export interface OpinionEvidence {
  quote: string;
  timestampSec: number;
}

const norm = (s: string) =>
  String(s || "").toLowerCase().normalize("NFKC").replace(/[“”"'`]/g, "").replace(/\s+/g, " ").trim();

/** Claim start in seconds. Pipeline claim timestamps (`start`, `startMs`) are milliseconds. */
function claimStartSec(claim: any): number | undefined {
  if (typeof claim?.startMs === "number" && Number.isFinite(claim.startMs)) return claim.startMs / 1000;
  if (typeof claim?.start === "number" && Number.isFinite(claim.start)) return claim.start / 1000;
  if (typeof claim?.startSec === "number" && Number.isFinite(claim.startSec)) return claim.startSec;
  return undefined;
}

/** Verbatim text the claim came from (transcript excerpt), most specific first. */
function verbatimTexts(claim: any): string[] {
  // Prefer what was actually said in the video. The claim text itself is only used when
  // no transcript words are attached (e.g. media-only extraction).
  const spoken = [claim?.transcriptExcerpt, claim?.verbatimQuote, claim?.originalText]
    .filter((t) => typeof t === "string" && t.trim().length > 0);
  if (spoken.length > 0) return spoken;
  return [claim?.claim, claim?.text].filter((t) => typeof t === "string" && t.trim().length > 0);
}

/**
 * Validates (or derives) the transcript proof for an Opinion & Belief label:
 * a verbatim quote that is present in the claim's own transcript text, contains a
 * subjective marker, sits at the claim's timestamp, and asserts no testable fact.
 */
export function validateOpinionEvidence(claim: any): { ok: true; evidence: OpinionEvidence } | { ok: false; reason: string } {
  const texts = verbatimTexts(claim);
  const statement = String(claim?.claim || claim?.text || texts.join(" ") || "");

  // Falsifiability, not digits, decides: "the best actor for 20 years" is an opinion even
  // though it contains a number. The adjudicator marks each claim falsifiable or not;
  // a statement it judged provable true/false cannot be labelled an opinion.
  if (claim?.falsifiable === true) {
    return { ok: false, reason: "The statement can be proven true or false, so it is a fact claim, not an opinion." };
  }

  // Mandatory Epistemic Invariant: Empirical allegations and scientific/political assertions
  // can never be classified as personal opinions, even if hedged ("I believe the election was rigged")
  if (EMPIRICAL_OR_ALLEGATION_RX.test(statement)) {
    return {
      ok: false,
      reason: "The statement asserts an empirical fact, statistic, or allegation and cannot be classified as an opinion or personal belief.",
    };
  }

  // Fallback only when no adjudicator judged falsifiability: a statement asserting a money
  // amount, percentage or statistic is checkable. Durations ("for 20 years") and ratings
  // ("10 out of 10") are deliberately NOT treated as checkable.
  if (claim?.falsifiable === undefined) {
    if (UNJUDGED_CHECKABLE_RX.test(statement)) {
      return { ok: false, reason: "The statement asserts an amount or statistic and was not judged an opinion." };
    }
  }
  const start = claimStartSec(claim);
  const provided = claim?.opinionEvidence as Partial<OpinionEvidence> | undefined;

  const candidates: OpinionEvidence[] = [];
  if (provided?.quote) {
    candidates.push({ quote: String(provided.quote), timestampSec: Number(provided.timestampSec ?? start ?? NaN) });
  }
  // Derive from the claim's own transcript text: the sentence carrying the subjective marker.
  for (const t of texts) {
    for (const sentence of t.split(/(?<=[.!?।])\s+/)) {
      if (SUBJECTIVE_MARKER_RX.test(sentence)) candidates.push({ quote: sentence.trim(), timestampSec: start ?? NaN });
    }
  }

  const haystacks = texts.map(norm);
  for (const c of candidates) {
    const q = norm(c.quote);
    if (q.split(" ").length < 2) continue;
    if (!haystacks.some((h) => h.includes(q))) continue;
    if (!SUBJECTIVE_MARKER_RX.test(c.quote)) continue;
    if (EMPIRICAL_OR_ALLEGATION_RX.test(c.quote)) continue;
    // Conversational hedges alone without genuine subjective sentiment cannot qualify as opinion evidence
    if (!GENUINE_SUBJECTIVE_MARKER_RX.test(c.quote)) continue;
    if (start !== undefined && Number.isFinite(c.timestampSec) && Math.abs(c.timestampSec - start) > 15) continue;
    if (!Number.isFinite(c.timestampSec)) continue;
    return { ok: true, evidence: { quote: c.quote, timestampSec: c.timestampSec } };
  }
  return { ok: false, reason: "No verbatim subjective phrase with a timestamp was found in the video for this statement." };
}

/**
 * Live, admissible sources: URL present, a URL-verification record that passed the live
 * check, not tier E. A missing verification record fails closed — "never checked" is not
 * "live".
 */
export function liveSources(claim: any): RichSource[] {
  const list: any[] = Array.isArray(claim?.richSources) && claim.richSources.length > 0
    ? claim.richSources
    : Array.isArray(claim?.sources) ? claim.sources.filter((s: any) => s && typeof s === "object") : [];
  return list.filter((s) => {
    const url = String(s?.url || s?.directUrl || "");
    if (!/^https?:\/\//i.test(url)) return false;
    if (String(s?.tier) === "E") return false;
    return Boolean(s?.urlVerification) && isLiveVerificationRecord(s.urlVerification);
  });
}

const sourceUrl = (s: RichSource) => String((s as any)?.url || (s as any)?.directUrl || "");
const isAuthoritative = (s: RichSource) => ["A", "B"].includes(String(s.tier || "").toUpperCase());

const GOV_OFFICIAL_STATEMENT_PATH_RX = /(?:^|\/)(?:press-releases?|press|news|newsroom|speeches|remarks|statements?|briefings?|announcements?|media-releases?|releases?)(?:\/|$)/i;
const GOV_ARCHIVAL_REFERENCE_PATH_RX = /(?:^|\/)(?:missions?|archive[sd]?|history|historical|facts?|factsheets?|reference|encyclopedia|cuu\/constants?|constants?|education|overview)(?:\/|$)/i;
const GOV_PRIMARY_RECORD_PATH_RX = /(?:^|\/)(?:datasets?|statistics|stats|tables?|dockets?|judgments?|opinions?|rulings?|statutes?|laws?|acts?|gazettes?|orders?|filings?|treaties)(?:\/|$)/i;

function extractPathname(rawUrl: string): string {
  try {
    return new URL(rawUrl).pathname.toLowerCase();
  } catch {
    const stripped = String(rawUrl || "").replace(/^https?:\/\/[^/]+/i, "").split(/[?#]/)[0];
    return stripped.toLowerCase();
  }
}

/**
 * Resolves the effective source kind. Institutional .gov / .mil sources default to
 * OFFICIAL_STATEMENT unless explicitly classified as a PRIMARY_RECORD (e.g. court docket,
 * statute text, gazette dataset) or REFERENCE — OR residing at a clear archival/mission/
 * dataset path while NOT residing at a press/news/speech path.
 */
export function resolveEffectiveSourceKind(s: RichSource): SourceRole {
  const explicit = (s as any)?.sourceKind as SourceRole | undefined;
  const rawUrl = sourceUrl(s);
  const host = hostOf(rawUrl);
  const inst = classifyInstitutionalHost(host);
  if (inst === "gov") {
    const pathname = extractPathname(rawUrl);
    if (GOV_OFFICIAL_STATEMENT_PATH_RX.test(pathname)) {
      return "OFFICIAL_STATEMENT";
    }
    if (explicit === "PRIMARY_RECORD" || explicit === "REFERENCE") {
      return explicit;
    }
    if (explicit !== "OFFICIAL_STATEMENT") {
      if (GOV_PRIMARY_RECORD_PATH_RX.test(pathname)) {
        return "PRIMARY_RECORD";
      }
      if (GOV_ARCHIVAL_REFERENCE_PATH_RX.test(pathname)) {
        return "REFERENCE";
      }
    }
    return "OFFICIAL_STATEMENT";
  }
  return explicit || "OTHER";
}

/** Tokenizes text into a normalized word set for text similarity & syndication deduplication. */
export function extractTextTokens(text: string): Set<string> {
  const words = String(text || "")
    .toLowerCase()
    .normalize("NFKC")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2);
  return new Set(words);
}

/** Extracts contiguous n-grams from normalized text for verbatim phrase / shingle matching. */
export function extractNGrams(text: string, n = 4): Set<string> {
  const words = String(text || "")
    .toLowerCase()
    .normalize("NFKC")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .split(/\s+/)
    .filter((w) => w.length > 1);
  const grams = new Set<string>();
  for (let i = 0; i <= words.length - n; i++) {
    grams.add(words.slice(i, i + n).join(" "));
  }
  return grams;
}

const WIRE_BYLINE_RX = /\b(reuters|associated press|\bap\b|afp|bloomberg|press trust of india|\bpti\b|\bani\b|\bians\b|\bupi\b)\b/i;

/**
 * Returns true if two texts share substantial token overlap (>= 60%), identical contiguous
 * wire shingles (>= 4 four-grams), or a shared wire byline + moderate overlap (>= 40%),
 * indicating syndicated news-wire copy, identical press releases, or republished content.
 */
export function areSyndicatedCopies(textA: string, textB: string, threshold = 0.60): boolean {
  const cleanA = String(textA || "").trim();
  const cleanB = String(textB || "").trim();
  if (!cleanA || !cleanB) return false;

  // 1. Shingle / 4-gram phrase matching (verbatim wire sentences)
  // Uses containment ratio against the shorter text to prevent a single short 7-word quote
  // from falsely triggering syndication between independent journalists.
  const gramsA = extractNGrams(cleanA, 4);
  const gramsB = extractNGrams(cleanB, 4);
  const minGrams = Math.min(gramsA.size, gramsB.size);
  if (minGrams >= 8) {
    let sharedGrams = 0;
    for (const g of gramsA) {
      if (gramsB.has(g)) sharedGrams++;
    }
    const containment = sharedGrams / minGrams;
    if (sharedGrams >= 8 && containment >= 0.18) return true;
  }

  const setA = extractTextTokens(cleanA);
  const setB = extractTextTokens(cleanB);
  if (setA.size === 0 || setB.size === 0) return false;

  let intersection = 0;
  for (const token of setA) {
    if (setB.has(token)) intersection++;
  }
  const union = setA.size + setB.size - intersection;
  const jaccard = union > 0 ? intersection / union : 0;

  // 2. Wire-byline detection: same wire service byline + moderate overlap (>= 0.40)
  // Guarded by min 15 tokens to avoid spurious triggers on micro-snippets.
  const hasSharedWireByline = WIRE_BYLINE_RX.test(cleanA) && WIRE_BYLINE_RX.test(cleanB);
  if (hasSharedWireByline && Math.min(setA.size, setB.size) >= 15 && jaccard >= 0.40) {
    return true;
  }

  // 3. High unigram token overlap (>= 0.60)
  // Length guard: snippets under 30 tokens should not be merged by unigram bag-of-words alone
  if (setA.size < 30 || setB.size < 30) {
    return false;
  }

  return jaccard >= threshold;
}

/** Extracts comparable text from a RichSource (own fetched text, excerpt, or snippet). */
export function sourceComparableText(s: RichSource): string {
  const uv: any = s?.urlVerification || {};
  return String(uv.evidenceText || uv.excerpt || s?.snippet || "").trim();
}

/**
 * Groups sources into independent publisher clusters, deduplicating both:
 *  1. Same registrable domain.
 *  2. Syndicated copy (wire stories or identical releases across different domains).
 */
export function countIndependentPublisherClusters(sources: RichSource[]): number {
  interface Cluster {
    domains: Set<string>;
    sampleTexts: string[];
  }
  const clusters: Cluster[] = [];

  for (const s of sources) {
    const domain = sourceTrustService.registrableDomain(sourceUrl(s));
    if (!domain) continue;
    const text = sourceComparableText(s);

    let matchedCluster: Cluster | undefined;
    for (const c of clusters) {
      if (c.domains.has(domain)) {
        matchedCluster = c;
        break;
      }
      if (text.length >= 80 && c.sampleTexts.some((st) => areSyndicatedCopies(text, st))) {
        matchedCluster = c;
        break;
      }
    }

    if (matchedCluster) {
      matchedCluster.domains.add(domain);
      if (text.length >= 80) matchedCluster.sampleTexts.push(text);
    } else {
      clusters.push({
        domains: new Set([domain]),
        sampleTexts: text.length >= 80 ? [text] : [],
      });
    }
  }

  return clusters.length;
}

const ANNOUNCEMENT_CLAIM_RX = /\b(announced|states? that|declared|confirmed that it|unveiled|launched|proclaimed|issued|published guidelines|introduced a policy)\b/i;

export function isAnnouncementMetaClaim(claimText?: string): boolean {
  return Boolean(claimText && ANNOUNCEMENT_CLAIM_RX.test(claimText));
}

/**
 * VERIFIED / FALSE bar, applied to sources whose explicit stance points the right way:
 * - One live Tier A/B source (excluding uncorroborated official self-serving statements).
 * - Or >= 2 independent, non-syndicated live Tier C/D publishers that are VETTED.
 *
 * Self-serving official statements (press releases, official spokespersons) cannot verify or refute
 * an empirical assertion alone; they require independent corroboration (PRIMARY_RECORD,
 * INDEPENDENT_REPORTING, REFERENCE) or at least two distinct independent publisher clusters.
 * Exemption: If the claim is specifically about the announcement itself (meta-claim), the official
 * statement is primary proof of the announcement.
 */
export function meetsStrongEvidenceBar(
  sources: RichSource[],
  direction: "SUPPORTS" | "CONTRADICTS" = "SUPPORTS",
  claimText?: string
): boolean {
  const directional = sources.filter((s) => explicitStance(s) === direction);

  // 1. Authoritative Tier A/B:
  const hasAuthoritative = directional.some(isAuthoritative);
  if (hasAuthoritative) {
    const isAnnouncement = direction === "SUPPORTS" && isAnnouncementMetaClaim(claimText);
    if (!isAnnouncement) {
      const allOfficial = directional.every((s) => resolveEffectiveSourceKind(s) === "OFFICIAL_STATEMENT");
      if (allOfficial) {
        // Uncorroborated official statements require >= 2 independent publisher clusters
        const officialClusters = countIndependentPublisherClusters(directional);
        if (officialClusters >= 2) return true;
        return false;
      }
    }
    return true;
  }

  // 2. Vetted Tier C/D publishers (must have >= 2 independent, non-syndicated publisher clusters):
  const cdSources = directional
    .filter((s) => ["C", "D"].includes(String(s.tier || "").toUpperCase()))
    .filter((s) => sourceTrustService.isVettedPublisher(sourceUrl(s)));

  return countIndependentPublisherClusters(cdSources) >= 2;
}

/** True when a live Tier A/B source's stance points the opposite way to `direction`. */
export function hasAuthoritativeConflict(sources: RichSource[], direction: "SUPPORTS" | "CONTRADICTS"): boolean {
  const opposite = direction === "SUPPORTS" ? "CONTRADICTS" : "SUPPORTS";
  return sources.some((s) => explicitStance(s) === opposite && isAuthoritative(s));
}

/** Sources that carry an explicit stance toward the claim (supports / contradicts / mixed). */
export function weightedSources(sources: RichSource[]): RichSource[] {
  return sources.filter((s) => explicitStance(s) !== undefined);
}

export interface GateDecision {
  publicVerdict: PublicVerdict;
  cautionType?: CautionType;
  /** Internal status after the gate (unchanged unless the gate demoted it). */
  status: string;
  demoted: boolean;
  reason?: string;
  opinionEvidence?: OpinionEvidence;
}

export function decidePublicVerdict(claim: any): GateDecision {
  const status = String(claim?.status || "").toLowerCase();
  if (IN_PROGRESS_STATUSES.has(status)) {
    return { publicVerdict: "UNPROVEN", status, demoted: false };
  }
  const sources = liveSources(claim);
  const demote = (reason: string): GateDecision => ({ publicVerdict: "UNPROVEN", status: "unproven", demoted: status !== "unproven", reason });
  const claimText = String(claim?.claim || claim?.text || claim?.claimText || "");

  if (VERIFIED_STATUSES.has(status) || FALSE_STATUSES.has(status)) {
    const direction = VERIFIED_STATUSES.has(status) ? "SUPPORTS" : "CONTRADICTS";
    if (!meetsStrongEvidenceBar(sources, direction, claimText)) {
      return demote(`'${status}' needs one live Tier A/B source or two independent vetted Tier C/D publishers whose content ${direction === "SUPPORTS" ? "supports" : "refutes"} the claim; found ${weightedSources(sources).length} live source(s) with a stance.`);
    }
    if (hasAuthoritativeConflict(sources, direction)) {
      return {
        publicVerdict: "CAUTION",
        cautionType: "DISPUTED",
        status: "disputed",
        demoted: true,
        reason: `'${status}' is contradicted by a live Tier A/B source pointing the other way; authoritative sources disagree.`,
      };
    }
    return { publicVerdict: VERIFIED_STATUSES.has(status) ? "VERIFIED" : "FALSE", status, demoted: false };
  }

  if (status in CAUTION_STATUS_TYPE) {
    if (weightedSources(sources).length === 0) return demote(`'${status}' (Caution) needs at least one live source with a stance on the claim; found none.`);
    return { publicVerdict: "CAUTION", cautionType: CAUTION_STATUS_TYPE[status], status, demoted: false };
  }

  if (OPINION_STATUSES.has(status)) {
    const check = validateOpinionEvidence(claim);
    if (check.ok) return { publicVerdict: "OPINION_BELIEF", status, demoted: false, opinionEvidence: check.evidence };
    const failReason = !check.ok ? check.reason : "unsupported opinion";
    // Not provably an opinion → it is a fact claim and needs evidence like any other.
    if (meetsStrongEvidenceBar(sources, "SUPPORTS", claimText) || meetsStrongEvidenceBar(sources, "CONTRADICTS", claimText)) {
      return { publicVerdict: "UNPROVEN", status: "unproven", demoted: true, reason: `Opinion label rejected (${failReason}); has sources but no factual verdict yet.` };
    }
    return demote(`Opinion label rejected: ${failReason}`);
  }

  // Everything else (unproven, inconclusive, unsupported, unverified, timeout, unknown) fails closed.
  return { publicVerdict: "UNPROVEN", status: "unproven", demoted: status !== "unproven", reason: status && status !== "unproven" ? `Status '${status}' is not a supported verdict.` : undefined };
}

/** Applies the gate to one claim object (report/explainable shape), returning a new object. */
export function applyVerdictGateToClaim(claim: any): any {
  // Only verdict-bearing objects are gated (explainability cards etc. carry no status).
  if (!claim || typeof claim !== "object" || !("status" in claim)) return claim;
  const d = decidePublicVerdict(claim);
  const out: any = { ...claim, publicVerdict: d.publicVerdict };
  if (Array.isArray(out.richSources)) out.richSources = stripEvidenceText(out.richSources);
  if (Array.isArray(out.quarantinedSources)) out.quarantinedSources = stripEvidenceText(out.quarantinedSources);
  if (d.cautionType) out.cautionType = d.cautionType;
  else delete out.cautionType;
  if (d.opinionEvidence) out.opinionEvidence = d.opinionEvidence;

  if (d.publicVerdict === "UNPROVEN" && d.status === "unproven") {
    // Fail closed: no generated factual commentary on an unproven claim.
    out.status = "unproven";
    out.reasoning = NO_EVIDENCE_MESSAGE;
    out.response = NO_EVIDENCE_MESSAGE;
    out.explanation = NO_EVIDENCE_MESSAGE;
    out.verificationSummary = NO_EVIDENCE_MESSAGE;
    out.verifiedFacts = [];
    delete out.publicNote;
    delete out.whyWrong;
    delete out.correction;
    delete out.severity;
    delete out.severityLabel;
    const rawText = String(out.claim || out.text || "").trim() ||
      String(out.displayLabel || "").trim();
    const cleanText = rawText.replace(/^[\p{Extended_Pictographic}\uFE0F\u200D\s]+/u, "").trim();
    out.displayLabel = `🔍 ${cleanText || rawText}`;
    out.confidence = Math.min(Number(out.confidence ?? 0.35), 0.35);
    out.verificationConfidence = Math.min(Number(out.verificationConfidence ?? 0.35), 0.35);
    if (d.demoted) {
      out.gateDemotion = { from: claim.status, reason: d.reason, at: new Date().toISOString() };
    }
  } else if (d.publicVerdict === "CAUTION" && d.demoted) {
    // VERIFIED/FALSE turned into DISPUTED by conflicting authoritative sources: the model's
    // one-sided commentary no longer matches the verdict, so it is replaced.
    out.status = d.status;
    out.reasoning = CONFLICTING_EVIDENCE_MESSAGE;
    out.response = CONFLICTING_EVIDENCE_MESSAGE;
    out.explanation = CONFLICTING_EVIDENCE_MESSAGE;
    out.verificationSummary = CONFLICTING_EVIDENCE_MESSAGE;
    delete out.whyWrong;
    delete out.correction;
    out.gateDemotion = { from: claim.status, reason: d.reason, at: new Date().toISOString() };
  } else if (d.publicVerdict === "OPINION_BELIEF") {
    delete out.whyWrong;
    delete out.correction;
    delete out.severity;
    delete out.severityLabel;
    const rawText = String(out.claim || out.text || "").trim() ||
      String(out.displayLabel || "").trim();
    const cleanText = rawText.replace(/^[\p{Extended_Pictographic}\uFE0F\u200D\s]+/u, "").trim();
    out.displayLabel = `💭 ${cleanText || rawText}`;
  }
  return out;
}

const CONTEXTUAL_STATUSES = new Set(["opinion_claim", "religious_belief", "satire_claim"]);

/**
 * Rebuilds the status counters of a report's factCheckStats from gated claims. Totals that
 * describe extraction (totalClaims, extractedClaims, filtered, ratios, cache hit rate) are kept.
 */
export function recomputeFactCheckStats(stats: Record<string, any>, gatedClaims: any[]): Record<string, any> {
  const byStatus = (wanted: string) => gatedClaims.filter((c) => String(c?.status || "").toLowerCase() === wanted).length;
  const out: Record<string, any> = { ...stats };
  out.evaluatedClaims = gatedClaims.filter((c) => !CONTEXTUAL_STATUSES.has(String(c?.status || "").toLowerCase())).length;
  out.correct = byStatus("verified_true");
  out.mostly_correct = byStatus("mostly_true");
  out.incorrect = byStatus("false_claim");
  out.unsupported = byStatus("unproven");
  out.religious_belief = byStatus("religious_belief");
  out.opinion_claim = byStatus("opinion_claim");
  out.satire_claim = byStatus("satire_claim");
  out.verification_timeout = byStatus("verification_timeout");
  // Same counts under their status names, where a report carries them.
  for (const key of ["verified_true", "mostly_true", "false_claim", "disputed", "misleading", "unproven"]) {
    if (key in out) out[key] = byStatus(key);
  }
  return out;
}

/**
 * Runs the gate over every claim list in a report and recomputes the headline counts,
 * factCheckStats, claim ledger, conclusion and human review flags so the summary can never disagree
 * with the claims.
 */
export function applyVerdictGateToReport<T = any>(report: T): T {
  if (!report || typeof report !== "object") return report;
  const r: any = { ...(report as any) };
  for (const key of ["claims", "verifiedClaims", "claimsLedger"]) {
    if (Array.isArray(r[key])) r[key] = r[key].map(applyVerdictGateToClaim);
  }
  const list: any[] = Array.isArray(r.claims) ? r.claims : [];
  const counts = { VERIFIED: 0, FALSE: 0, CAUTION: 0, OPINION_BELIEF: 0, UNPROVEN: 0 } as Record<PublicVerdict, number>;
  for (const c of list) counts[(c?.publicVerdict as PublicVerdict) || "UNPROVEN"]++;
  r.publicVerdictCounts = counts;
  r.verdictGateVersion = 1;

  // Recompute the per-status counters in factCheckStats from the gated claims, so the
  // "correct / incorrect" numbers shown and propagated can never disagree with the verdicts.
  if (Array.isArray(r.claims) && r.factCheckStats && typeof r.factCheckStats === "object") {
    r.factCheckStats = recomputeFactCheckStats(r.factCheckStats, list);
  }

  // Recompute claimLedger so summary headline and counters never disagree with gated claims
  const confirmedCount = counts.VERIFIED;
  const falseCount = counts.FALSE;
  const disputedCount = counts.CAUTION;
  const unprovenCount = counts.UNPROVEN;
  const contextualCount = counts.OPINION_BELIEF;
  const totalClaimsChecked = list.length;

  let highestSeverityVerdict: 'verified_true' | 'mostly_true' | 'disputed' | 'false_claim' | 'unproven' | 'none' = 'none';
  if (falseCount > 0) highestSeverityVerdict = 'false_claim';
  else if (disputedCount > 0) highestSeverityVerdict = 'disputed';
  else if (unprovenCount > 0) highestSeverityVerdict = 'unproven';
  else if (confirmedCount > 0) highestSeverityVerdict = 'verified_true';

  const verdictHeadline = `${confirmedCount} Confirmed • ${disputedCount} Disputed • ${falseCount} False`;
  const priorityNotice = falseCount > 0
    ? `Notice: ${falseCount} claim(s) contradicted by documented evidence.`
    : disputedCount > 0
      ? `Notice: ${disputedCount} claim(s) have conflicting or inconclusive evidence.`
      : undefined;

  r.claimLedger = {
    totalClaimsChecked,
    confirmedCount,
    disputedCount,
    unprovenCount,
    falseCount,
    contextualCount,
    highestSeverityVerdict,
    verdictHeadline,
    priorityNotice,
    verifiableRatio: totalClaimsChecked > 0 ? Number((confirmedCount / totalClaimsChecked).toFixed(3)) : 0,
  };

  // Recompute reviewTriggered and reviewReason
  if (r.reviewTriggered !== undefined || r.reviewReason !== undefined) {
    const shouldReview = falseCount > 0 && highestSeverityVerdict === 'false_claim';
    r.reviewTriggered = shouldReview;
    if (shouldReview) {
      r.reviewReason = `Flagged for human review: ${falseCount} high-severity claim(s) contradicted by documented evidence.`;
    } else {
      delete r.reviewReason;
    }
  }

  // Recompute conclusion text so overview cannot state claims were backed when 0 were backed
  if (r.conclusion && typeof r.conclusion === 'object') {
    const conc = { ...r.conclusion };
    if (typeof conc.text === "string" && /\b\d+\s+of\s+\d+\s+claims\s+were\s+backed\s+up\b/i.test(conc.text)) {
      if (confirmedCount > 0) {
        conc.text = conc.text.replace(
          /\b\d+\s+of\s+\d+\s+claims\s+were\s+backed\s+up/i,
          `${confirmedCount} of ${totalClaimsChecked} claims were backed up`
        );
      } else {
        conc.text = conc.text.replace(
          /\b\d+\s+of\s+\d+\s+claims\s+were\s+backed\s+up\s+by\s+reliable\s+proof\./i,
          `No claims were backed up by reliable proof yet.`
        );
        conc.text = conc.text.replace(
          /\b\d+\s+of\s+\d+\s+claims\s+were\s+backed\s+up/i,
          `0 of ${totalClaimsChecked} claims were backed up`
        );
      }
    }
    r.conclusion = conc;
  }

  return r as T;
}
