import { ClaimStatus, RichSource } from "../types";
import { sourceTrustService } from "./sourceTrustService";
import { isLiveVerificationRecord } from "./urlVerificationService";

/**
 * Keeps a claim's verdict, its explanation and its public note consistent with the
 * evidence that actually survived URL verification.
 *
 * Before this existed, the dual-mass invariant could change the status (e.g. a confirmed
 * fact became "unproven") while the model's explanation still said "confirmed", and the
 * internal reason ("Support mass 0 … threshold (0.8)") leaked into the public note.
 */
export interface ReconciledVerdict {
  status: ClaimStatus;
  reasoning: string;
  publicNote?: string;
  /** Internal, non-user-facing reason recorded for audits when the verdict changed. */
  invariantReason?: string;
  /**
   * Upper bound for the displayed confidence, derived from the evidence itself
   * (number of independent live publishers). Callers apply min(modelConfidence, cap).
   */
  confidenceCap: number;
  /** Number of admitted, live sources the verdict rests on. */
  evidenceCount: number;
}

const NON_EVIDENTIAL_STATUSES = new Set<string>([
  "opinion_claim",
  "religious_belief",
  "satire_claim",
  "faith_based_claim",
  "not_historically_verifiable",
  "historical_tradition",
  "rhetorical_exaggeration",
]);

const POSITIVE = new Set<string>(["verified_true", "mostly_true", "correct", "mostly_correct"]);
const NEGATIVE = new Set<string>(["false_claim", "verified_false", "incorrect"]);

export const UNCONFIRMED_POSITIVE_TEXT =
  "Reports point the same way, but we could not link this to a live, checkable source yet, so we are not marking it as verified for now.";
export const UNCONFIRMED_NEGATIVE_TEXT =
  "We could not find a live, checkable source that clearly shows this is wrong, so we are not calling it false.";

/** Verdicts that assert something about the world and therefore REQUIRE evidence. */
export const EVIDENCE_REQUIRED_STATUSES = new Set<string>([
  ...POSITIVE,
  ...NEGATIVE,
  "partially_true",
  "misleading",
  "disputed",
  "needs_context",
  "outdated",
  "historical_consensus_denial",
  "incorrect_citation",
]);

export const UNCONFIRMED_CONTEXT_TEXT =
  "We could not link the missing context or counter-evidence to a live, checkable source yet, so this stays unconfirmed for now.";

/**
 * The explicit stance a source carries toward the claim, or undefined when none was
 * extracted. Order: stance step (claimStance) → explicit evidence assessment
 * (stance / isContradictory). There is NO default: an unlabelled source is neutral.
 */
export function explicitStance(s: Partial<RichSource>): "SUPPORTS" | "CONTRADICTS" | "MIXED" | undefined {
  const cs = (s as any)?.claimStance;
  if (cs === "SUPPORTS" || cs === "CONTRADICTS" || cs === "MIXED") return cs;
  if (cs === "OFF_TOPIC" || cs === "UNREADABLE") return undefined;
  if ((s as any)?.isContradictory === true || (s as any)?.stance === "CONTRADICTS") return "CONTRADICTS";
  if ((s as any)?.stance === "SUPPORTS") return "SUPPORTS";
  return undefined;
}

/**
 * Drops the fetched page text (urlVerification.evidenceText) from sources before they are
 * saved. It is only needed by the stance step and would bloat reports and cache documents.
 */
export function stripEvidenceText<T extends Partial<RichSource>>(sources: T[] | undefined): T[] | undefined {
  if (!Array.isArray(sources)) return sources;
  return sources.map((s) => {
    const uv: any = (s as any)?.urlVerification;
    if (!uv || uv.evidenceText === undefined) return s;
    const { evidenceText: _drop, ...rest } = uv;
    return { ...s, urlVerification: rest } as T;
  });
}

/** Stance in the form the dual-mass invariant expects (MIXED / unlabelled carry no direction). */
export function toInvariantStance(s: Partial<RichSource>): "SUPPORTS" | "CONTRADICTS" | "CONTEXTUAL" | "NEUTRAL" {
  const st = explicitStance(s);
  return st === "SUPPORTS" ? "SUPPORTS" : st === "CONTRADICTS" ? "CONTRADICTS" : st === "MIXED" ? "CONTEXTUAL" : "NEUTRAL";
}

/**
 * A source counts as evidence only if it has a URL, passed the live check, is not tier E,
 * and carries an explicit stance (supports / contradicts / mixed) toward this claim.
 */
function admittedEvidence(sources: Array<Partial<RichSource>>): Array<Partial<RichSource>> {
  return (sources || []).filter((s) => {
    const url = String(s?.url || s?.directUrl || "");
    if (!/^https?:\/\//i.test(url)) return false;
    if ((s?.tier as string) === "E") return false;
    if (s?.urlVerification && !isLiveVerificationRecord(s.urlVerification as any)) return false;
    return explicitStance(s) !== undefined;
  });
}

/**
 * Confidence can never exceed what the evidence supports:
 * 0 independent publishers → 0.35, 1 → 0.75, 2 → 0.88, 3+ → 0.97.
 */
export function evidenceConfidenceCap(sources: Array<Partial<RichSource>>): number {
  const publishers = new Set(
    admittedEvidence(sources).map((s) => String(s.domain || s.publisher || s.url || "").toLowerCase())
  );
  const n = publishers.size;
  return n === 0 ? 0.35 : n === 1 ? 0.75 : n === 2 ? 0.88 : 0.97;
}

/**
 * The single rule that turns (proposed verdict, evidence) into the published verdict.
 * Every path — first fact-check, cached reuse, source healing, approved community
 * evidence — goes through here, so the same evidence always yields the same outcome
 * regardless of who made the claim or who submitted the evidence.
 *
 *  1. Opinions, beliefs, satire and rhetoric are not fact claims: kept as classified.
 *  2. 100% evidence rule: a factual verdict with ZERO admitted live sources is published
 *     as "unproven", with an explanation that says so (never a contradicting "confirmed").
 *  3. With evidence, the dual-mass invariant arbitrates source weight and stance.
 *  4. Confidence is capped by the number of independent live publishers.
 */
export function reconcileVerdictWithEvidence(params: {
  proposedStatus: ClaimStatus;
  reasoning?: string;
  publicNote?: string;
  sources: Array<Pick<RichSource, "tier" | "isContradictory"> & Partial<RichSource>>;
}): ReconciledVerdict {
  const { proposedStatus } = params;
  const reasoning = (params.reasoning || "").trim();
  const evidence = admittedEvidence(params.sources);
  const confidenceCap = evidenceConfidenceCap(evidence);
  const base = { confidenceCap, evidenceCount: evidence.length };

  if (NON_EVIDENTIAL_STATUSES.has(proposedStatus)) {
    return { ...base, status: proposedStatus, reasoning, publicNote: params.publicNote };
  }

  if (evidence.length === 0 && EVIDENCE_REQUIRED_STATUSES.has(proposedStatus)) {
    const text = POSITIVE.has(proposedStatus)
      ? UNCONFIRMED_POSITIVE_TEXT
      : NEGATIVE.has(proposedStatus)
      ? UNCONFIRMED_NEGATIVE_TEXT
      : UNCONFIRMED_CONTEXT_TEXT;
    return {
      ...base,
      status: "unproven",
      reasoning: text,
      publicNote: params.publicNote,
      invariantReason: `Evidence required: verdict '${proposedStatus}' had no admitted live source.`,
    };
  }

  // #2 Official statements are disputable: if a "verified" verdict rests ONLY on official
  // statements (press releases, spokespeople) and credible independent reporting or a
  // primary record contradicts it, the honest verdict is "disputed".
  const supporting = evidence.filter((s) => explicitStance(s) === "SUPPORTS");
  const contradicting = evidence.filter((s) => explicitStance(s) === "CONTRADICTS");
  if (POSITIVE.has(proposedStatus) && supporting.length > 0 &&
      supporting.every((s) => (s as any).sourceKind === "OFFICIAL_STATEMENT") &&
      contradicting.some((s) => ["A", "B", "C"].includes(String(s.tier)) &&
        ["INDEPENDENT_REPORTING", "PRIMARY_RECORD"].includes(String((s as any).sourceKind)))) {
    return {
      ...base,
      status: "disputed",
      reasoning: "Official statements support this, but credible independent evidence contradicts it.",
      publicNote: params.publicNote,
      invariantReason: "Official-statement-only support contested by independent reporting or a primary record.",
    };
  }

  const evaluation = sourceTrustService.evaluateDualMassInvariants(
    evidence.map((s: any) => ({
      evidentiaryCapacity: s.evidentiaryCapacity ?? 0.5,
      stance: toInvariantStance(s),
      tier: s.tier,
      role: s.sourceKind === "PRIMARY_RECORD" ? ("primary_record" as any) : s.evidenceRole,
      isContradictory: explicitStance(s) === "CONTRADICTS",
    })),
    proposedStatus
  );

  if (!evaluation.isOverridden) {
    return { ...base, status: proposedStatus, reasoning, publicNote: params.publicNote };
  }

  const next = evaluation.invariantVerdict as ClaimStatus;
  let nextReasoning = reasoning;
  if (next === "unproven" && POSITIVE.has(proposedStatus)) {
    nextReasoning = UNCONFIRMED_POSITIVE_TEXT;
  } else if (next === "unproven" && NEGATIVE.has(proposedStatus)) {
    nextReasoning = UNCONFIRMED_NEGATIVE_TEXT;
  } else if (next === "unproven" && EVIDENCE_REQUIRED_STATUSES.has(proposedStatus)) {
    nextReasoning = UNCONFIRMED_CONTEXT_TEXT;
  }

  return {
    ...base,
    status: next,
    reasoning: nextReasoning,
    // Keep the original public note; never expose the internal invariant arithmetic.
    publicNote: params.publicNote,
    invariantReason: evaluation.reason,
  };
}

/**
 * Maps a free-text model label to a canonical ClaimStatus.
 *
 * The previous mapper only matched exact phrases with spaces, so very common model
 * outputs such as "VERIFIED", "VERIFIED_TRUE", "MOSTLY_TRUE", "LIMITED SUPPORT",
 * "NEEDS CONTEXT" and "RHETORICAL EXAGGERATION" (which the prompt itself asks for) all
 * fell through to "inconclusive" and were shown to viewers as Caution.
 */
export function mapVerificationLabelToStatus(label: string | undefined | null): ClaimStatus {
  const l = String(label || "")
    .toUpperCase()
    .replace(/[_\-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!l) return "inconclusive";

  // Order matters: more specific phrases first.
  if (l.includes("NOT HISTORICALLY VERIFIABLE")) return "not_historically_verifiable";
  if (l.includes("HISTORICAL TRADITION")) return "historical_tradition";
  if (l.includes("RELIGIOUS BELIEF")) return "religious_belief";
  if (l.includes("FAITH BASED") || l.includes("FAITH")) return "faith_based_claim";
  if (l.includes("RHETORICAL") || l.includes("EXAGGERATION") || l.includes("HYPERBOLE")) {
    return "rhetorical_exaggeration";
  }
  if (l.includes("SATIRE")) return "satire_claim";
  if (l.includes("OPINION")) return "opinion_claim";
  if (l.includes("MISLEADING")) return "misleading";
  if (l.includes("MOSTLY FALSE")) return "misleading";
  if (l.includes("MOSTLY TRUE") || l.includes("MOSTLY CORRECT") || l.includes("PARTIALLY TRUE")) return "mostly_true";
  if (l.includes("DISPUTED") || l.includes("CONTESTED")) return "disputed";
  if (l.includes("NEEDS CONTEXT") || l.includes("MISSING CONTEXT")) return "needs_context";
  if (l.includes("OUTDATED")) return "outdated";
  if (l.includes("UNPROVEN") || l.includes("UNSUPPORTED") || l.includes("LIMITED SUPPORT") || l.includes("INSUFFICIENT")) {
    return "unsupported";
  }
  if (l.includes("INCONCLUSIVE") || l.includes("UNVERIFIABLE")) return "inconclusive";
  if (l === "FALSE" || l.includes("FALSE CLAIM") || l.includes("VERIFIED FALSE") || l === "INCORRECT" || l.startsWith("FALSE")) {
    return "false_claim";
  }
  if (l === "TRUE" || l === "VERIFIED" || l === "CORRECT" || l === "ACCURATE" || l.includes("VERIFIED TRUE") || l === "CONFIRMED") {
    return "verified_true";
  }
  return "inconclusive";
}

const SCRIPT_LANGUAGES: Array<{ name: string; rx: RegExp }> = [
  { name: "Telugu", rx: /[ఀ-౿]/g },
  { name: "Hindi", rx: /[ऀ-ॿ]/g },
  { name: "Tamil", rx: /[஀-௿]/g },
  { name: "Kannada", rx: /[ಀ-೿]/g },
  { name: "Malayalam", rx: /[ഀ-ൿ]/g },
  { name: "Bengali", rx: /[ঀ-৿]/g },
  { name: "Gujarati", rx: /[઀-૿]/g },
  { name: "Punjabi", rx: /[਀-੿]/g },
  { name: "Odia", rx: /[଀-୿]/g },
  { name: "Urdu", rx: /[؀-ۿ]/g },
];

/**
 * Picks ONE language for all verdict explanations in a batch: the script that holds the
 * majority of letters across the claim texts, defaulting to English.
 */
export function detectDominantClaimLanguage(texts: string[]): string {
  const joined = texts.join(" ");
  const latin = (joined.match(/[A-Za-z]/g) || []).length;
  let best = { name: "English", count: latin };
  for (const { name, rx } of SCRIPT_LANGUAGES) {
    const count = (joined.match(rx) || []).length;
    if (count > best.count) best = { name, count };
  }
  return best.name;
}
