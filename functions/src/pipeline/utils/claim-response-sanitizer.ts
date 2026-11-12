import { ClaimStatus } from "../types";

/**
 * Normalizes and simplifies claim response explanations so every explanation:
 * - Reads like clear, everyday English a 10-year-old can easily understand.
 * - Contains zero AI meta-talk ("from internal data", "from my memory", "as an AI", "indexed institutional public archives").
 * - Never uses meta labels like "this claim" or "this statement".
 */
export function sanitizeClaimResponse(
  text: string | undefined | null,
  status?: ClaimStatus | string
): string {
  if (!text || typeof text !== "string") {
    return buildSimpleFallbackForStatus(status);
  }

  let clean = text.trim();
  if (!clean) {
    return buildSimpleFallbackForStatus(status);
  }

  // 1. Strip internal pipeline prefixes & bracket annotations
  clean = clean
    .replace(/^\[RECOVERY PASS\]\s*/i, "")
    .replace(/^\[FAST KNOWLEDGE RECOVERY\]\s*/i, "")
    .replace(/^\[GROUNDING\]\s*/i, "")
    .replace(/^\[FAST PASS\]\s*/i, "")
    .replace(/^\[LLM\]\s*/i, "")
    .replace(/^\[RECOVERY\]\s*/i, "")
    .replace(/^\[OFFLINE FALLBACK\]\s*/i, "")
    .replace(/\s*\[Corroborated by Wikipedia:\s*([^\]]+?)(?:\.\.\.)?\]/gi, " Official info notes: $1.")
    .replace(/\s*\(Live web search timed out;\s*flagged for async background re-grounding\)\.?\s*/gi, "")
    .replace(/^[?❔✅❌🟢⏳🔍📎💭👤⚖️❤️🗣️🕊📜💡⚠️\s]+/, "")
    .trim();

  // 2. Replace legacy robotic / institutional fallback sentences verbatim or by pattern
  const legacyReplacements: Array<[RegExp, string]> = [
    [
      /^Authoritative corroboration could not be recovered from indexed institutional public archives\.?$/i,
      "No clear outside sources or news reports were found to back this up yet.",
    ],
    [
      /^No accessible verified sources passed URL health checks to support this (?:claim|statement)\.?$/i,
      "We couldn't find working, trusted links to back this up yet.",
    ],
    [
      /^Recovered sources did not meet institutional authority standards for factual verification\.?$/i,
      "The links found were not from trusted news or official sources, so this cannot be confirmed yet.",
    ],
    [
      /^No admissible, high-authority sources could be recovered to corroborate this (?:claim|statement)\.?$/i,
      "No trusted news or official records were found to back this up yet.",
    ],
    [
      /^No independent documentation, official police records, or accredited news reports currently corroborate this (?:claim|statement) in indexed public archives\.?$/i,
      "No trusted news reports or official records have been found yet to back this up.",
    ],
    [
      /^Confirmed by official police reports, medical records, and accredited regional news coverage\.?$/i,
      "Official reports and trusted news stories back this up.",
    ],
    [
      /^Contradicted by verified public records and primary documentation;\s*the asserted details are inaccurate\.?$/i,
      "Trusted records and facts show this is not true.",
    ],
    [
      /^Verified via institutional claim cache\.?$/i,
      "Trusted records and outside reports back this up.",
    ],
    [
      /^Claim ID mismatch during verification\s*[—–-]\s*marked for re-analysis\.?$/i,
      "We are still double-checking the facts on this. Please check back soon.",
    ],
    [
      /^Claim evaluated against recovered documentary evidence\.?$/i,
      "Checked using trusted documents and outside reports.",
    ],
    [
      /^We retrieved potential sources, but conclusive evaluation could not be completed at this time\.?$/i,
      "We found a few possible links, but couldn't finish checking all the facts yet.",
    ],
    [
      /^Independent records and accredited news reports provide the authoritative context for this (?:claim|statement)\.?$/i,
      "Trusted records and news reports help explain the facts here.",
    ],
  ];

  for (const [pattern, replacement] of legacyReplacements) {
    if (pattern.test(clean)) {
      return replacement;
    }
  }

  // 3. Strip conversational AI, memory, internal-data, and archive jargon
  const strippedPatterns: RegExp[] = [
    /I looked through all my stories and general knowledge[^.]*\.?/gi,
    /I looked through all my stories[^.]*\.?/gi,
    /It'?s not something lots of people know about from my memory\.?/gi,
    /I couldn'?t find any common or famous story[^.]*\.?/gi,
    /I don'?t have this in my memory\.?/gi,
    /\b(?:based on|from|using|according to|drawn from|in)\s+(?:my\s+|our\s+|the\s+)?(?:internal\s+)?(?:training\s+)?(?:data|knowledge|memory)\b[,.]?/gi,
    /\b(?:my\s+|our\s+)?(?:internal\s+training\s+(?:data|knowledge)|internal\s+(?:data|knowledge|memory)|training\s+(?:data|knowledge))\b\s*(?:shows?|says?|indicates?|confirms?|suggests?|states?)?,?\s*/gi,
    /\b(?:from|in)\s+my\s+memory\.?/gi,
    /\b(?:from|in)\s+indexed\s+(?:institutional\s+)?public\s+archives\b/gi,
    /\b(?:as an AI|as a language model|I am an AI|I'?m an AI)[^.]*[,.]?\s*/gi,
    /^Deterministically verified:\s*/i,
  ];

  let strippedAiMeta = false;
  for (const pattern of strippedPatterns) {
    const before = clean;
    clean = clean.replace(pattern, " ").trim();
    if (clean !== before) {
      strippedAiMeta = true;
    }
  }

  // 4. Replace stiff academic & robotic wording with everyday 10-year-old language
  clean = clean
    .replace(
      /^(?:Upon\s+)?(?:comprehensive\s+)?empirical\s+(?:investigation|verification|analysis)\s+(?:of\s+available\s+records\s+)?(?:indicates|demonstrates|confirms)\s+that\s+/i,
      "Real facts and records show that "
    )
    .replace(
      /^(?:Upon\s+)?investigative\s+synthesis\s+of\s+(?:this|the)\s+(?:claim|statement),?\s*/i,
      "After checking the facts, "
    )
    .replace(
      /^(?:Corroborative|Substantiating)\s+documentation\s+(?:confirms|indicates)\s+that\s+/i,
      "Trusted records show that "
    )
    .replace(/\b(?:the\s+asserted\s+(?:claim|proposition)|the\s+claimant'?s\s+assertion)\b/gi, "what was said")
    .replace(/\bthe\s+claimant\s+posited\s+that\b/gi, "the speaker said that")
    .replace(/\bempirical\s+(?:assertion|evidence|corroboration)\b/gi, "real proof")
    .replace(/\bauthoritative\s+corroboration\b/gi, "trusted proof")
    .replace(/\bbacks?\s+up\s+(?:this|the)\s+(?:claim|statement)\b/gi, (m) =>
      /^backs/i.test(m) ? "backs this up" : "back this up"
    )
    .replace(/\b(?:supports?|corroborates?|substantiates?|confirms?|proves?|verifies?|refutes?|contradicts?|disputes?|debunks?|disproves?|evaluat(?:es?|ing)|check(?:s|ing)?)\s+(?:this|the)\s+(?:claim|statement)\b/gi, (m) => {
      const verb = m.replace(/\s+(?:this|the)\s+(?:claim|statement)$/i, "");
      return `${verb} it`;
    })
    .replace(/\bin\s+(?:this|the)\s+(?:claim|statement)\b/gi, "shared here")
    .replace(/\b(for|about|of|to|on|against|with|regarding|concerning)\s+(?:this|the)\s+(?:claim|statement)\b/gi, "$1 this")
    .replace(/(?:^|([.!?]\s+))(?:This|The)\s+(?:claim|statement)\b/g, "$1It")
    .replace(/\b(?:this|the)\s+(?:claim|statement)\b/gi, "it");

  // 5. Clean leftover punctuation / spacing and restore leading capitalization
  clean = clean
    .replace(/\s{2,}/g, " ")
    .replace(/\s+([,.;!?])/g, "$1")
    .replace(/^[,;.\s]+/, "")
    .trim();

  if (clean.length > 0) {
    clean = clean.charAt(0).toUpperCase() + clean.slice(1);
  }

  // 6. Safety fallback if stripped text became empty or still leaks internal/AI phrasing
  if (
    clean.length === 0 ||
    (strippedAiMeta && clean.length < 25) ||
    /\b(?:from my memory|all my stories|in my memory|internal data|training data|indexed institutional)\b/i.test(clean) ||
    /^(?:I\s+|as an AI)/i.test(clean)
  ) {
    return buildSimpleFallbackForStatus(status);
  }

  return clean;
}

function buildSimpleFallbackForStatus(status?: ClaimStatus | string): string {
  const s = (status || "").toString().toLowerCase();
  if (s === "verified_true" || s === "mostly_true" || s === "verified" || s === "true" || s === "correct") {
    return "Official reports and trusted news stories back this up.";
  }
  if (s === "false_claim" || s === "verified_false" || s === "false" || s === "incorrect") {
    return "Trusted records and facts show this is not true.";
  }
  if (s === "misleading" || s === "distorted" || s === "deceptive") {
    return "Important facts are left out here, making things sound different from what really happened.";
  }
  if (s === "disputed" || s === "contested") {
    return "Experts and different sources disagree on this, and there is evidence on both sides.";
  }
  if (s === "opinion_claim" || s === "opinion") {
    return "This is a personal opinion or feeling, not a fact you can test or prove right or wrong.";
  }
  return "No trusted news reports or official records have been found yet to back this up.";
}
