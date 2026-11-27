import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";
import { logger } from "../utils/logger";
import { PIPELINE_CONFIG } from "../config";
import { wikipediaAdapter } from "../providers/wikipediaAdapter";
import { wikidataAdapter } from "../providers/wikidataAdapter";
import { pubmedAdapter } from "../providers/pubmedAdapter";
import { crossrefAdapter } from "../providers/crossrefAdapter";
import { worldBankAdapter } from "../providers/worldBankAdapter";
import { fredAdapter } from "../providers/fredAdapter";
import type { EvidenceProvider, FilteredClaim, VerifiedSource } from "../types";

export interface MultilingualCanonicalDeps {
  vertexAI?: {
    getGenerativeModel(options: any): {
      generateContent(prompt: any): Promise<any>;
    };
  };
}

export interface DomainWidePreRetrievalOptions {
  timeoutMs?: number;
}

interface RawProviderHit {
  title: string;
  uri: string;
  passage: string;
  provider: EvidenceProvider;
  claimId: string;
}

const DEFAULT_PRE_RETRIEVAL_TIMEOUT_MS = 800;

function getClaimSearchText(claim: { text?: string; normalizedClaim?: string; verbatimQuote?: string }): string {
  return String(claim.text || claim.normalizedClaim || claim.verbatimQuote || "").trim();
}

function truncateSnippet(raw: string, maxLen = 600): string {
  const clean = String(raw || "").replace(/\s+/g, " ").trim();
  if (clean.length <= maxLen) return clean;
  return `${clean.slice(0, maxLen - 3).trim()}...`;
}

async function runWithTimeout<T>(
  fn: (signal: AbortSignal) => Promise<T>,
  timeoutMs: number,
  fallback: T
): Promise<T> {
  const controller = new AbortController();
  let timer: NodeJS.Timeout | undefined;
  try {
    return await Promise.race<T>([
      fn(controller.signal),
      new Promise<T>((resolve) => {
        timer = setTimeout(() => {
          controller.abort();
          resolve(fallback);
        }, timeoutMs);
        if (typeof timer.unref === "function") timer.unref();
      }),
    ]);
  } catch {
    return fallback;
  } finally {
    if (timer) clearTimeout(timer);
  }
}

/**
 * Extracts bracketed English annotations like `[అపోలో 11 / Apollo 11]` from bilingual claim strings.
 */
export function extractBracketedEnglish(text: string): string | null {
  if (!text) return null;
  const match = text.match(/\[\s*[^\]]*?\/\s*([A-Za-z0-9][A-Za-z0-9\s.,'&\-:+/]*?)\s*\]/);
  if (match && match[1]) {
    const cleaned = match[1].trim();
    return cleaned.length > 0 ? cleaned : null;
  }
  return null;
}

/**
 * Detects the Wikipedia language subdomain for a non-Latin/non-ASCII claim script.
 */
export function detectScriptWikipediaLang(text: string): string | null {
  if (!text || !/[^\x00-\x7F]/.test(text)) return null;
  if (/[\u0C00-\u0C7F]/.test(text)) return "te"; // Telugu
  if (/[\u0900-\u097F]/.test(text)) return "hi"; // Devanagari (Hindi/Marathi)
  if (/[\u0B80-\u0BFF]/.test(text)) return "ta"; // Tamil
  if (/[\u0C80-\u0CFF]/.test(text)) return "kn"; // Kannada
  if (/[\u0D00-\u0D7F]/.test(text)) return "ml"; // Malayalam
  if (/[\u0980-\u09FF]/.test(text)) return "bn"; // Bengali
  if (/[\u0A80-\u0AFF]/.test(text)) return "gu"; // Gujarati
  if (/[\u0A00-\u0A7F]/.test(text)) return "pa"; // Punjabi (Gurmukhi)
  if (/[\u0B00-\u0B7F]/.test(text)) return "or"; // Odia
  if (/[\u0600-\u06FF]/.test(text)) return "ar"; // Arabic
  if (/[\uAC00-\uD7AF]/.test(text)) return "ko"; // Korean
  if (/[\u3040-\u30FF]/.test(text)) return "ja"; // Japanese
  if (/[\u4E00-\u9FFF]/.test(text)) return "zh"; // Chinese
  if (/[\u0400-\u04FF]/.test(text)) return "ru"; // Cyrillic
  if (/[\u0E00-\u0E7F]/.test(text)) return "th"; // Thai
  if (/[\u0590-\u05FF]/.test(text)) return "he"; // Hebrew
  if (/[\u0370-\u03FF]/.test(text)) return "el"; // Greek
  return null;
}

/**
 * Normalizes non-English factual claims into canonical English phrasing in ONE batched
 * Flash-Lite call at the start of the cascade, so Tier 1 cache, Tier 2 deterministic lookup,
 * and domain-wide `$0` pre-retrieval all share the same English canonical strings cleanly.
 */
export async function batchResolveMultilingualCanonical(
  claims: Array<FilteredClaim | { claimId: string; text?: string; normalizedClaim?: string; verbatimQuote?: string }>,
  deps?: MultilingualCanonicalDeps
): Promise<Map<string, string>> {
  const canonicalMap = new Map<string, string>();
  if (!claims || claims.length === 0) return canonicalMap;

  const nonAsciiClaims = claims.filter((c) => /[^\x00-\x7F]/.test(getClaimSearchText(c)));
  if (nonAsciiClaims.length === 0) return canonicalMap;

  const isMockedVertex = Boolean((getVertexAI as any)?._isMockFunction);
  if (process.env.NODE_ENV === "test" && !deps?.vertexAI && !isMockedVertex) {
    for (const c of nonAsciiClaims) {
      const rawText = getClaimSearchText(c);
      canonicalMap.set(c.claimId, extractBracketedEnglish(rawText) || rawText);
    }
    return canonicalMap;
  }

  try {
    const ai = deps?.vertexAI || getVertexAI();
    const modelId = PIPELINE_CONFIG?.GEMINI_MODELS?.queryDecomposition || "gemini-3.5-flash-lite";
    const model = ai.getGenerativeModel({
      model: modelId,
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.1,
        maxOutputTokens: 1024,
      },
    });

    const prompt = `Translate each non-English factual claim into one literal, complete canonical English sentence or factual search statement.
Preserve exact names, dates, numbers, units, and polarity (positive vs negative) accurately without commentary.

Claims:
${nonAsciiClaims.map((c) => `[ID: ${c.claimId}] "${getClaimSearchText(c)}"`).join("\n")}

Respond ONLY with valid JSON:
{
  "translations": [
    { "claimId": "string", "englishCanonical": "literal canonical English claim" }
  ]
}`;

    const res = await model.generateContent(prompt);
    const text =
      extractCandidateText(res?.candidates?.[0] || res?.response?.candidates?.[0]) ||
      (typeof res?.text === "string" ? res.text : "");
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      const items = Array.isArray(parsed.translations)
        ? parsed.translations
        : Array.isArray(parsed.queries)
        ? parsed.queries
        : [];
      for (const item of items) {
        const resolved = item?.englishCanonical ?? item?.englishQuery;
        if (item?.claimId && typeof resolved === "string" && resolved.trim().length > 0) {
          canonicalMap.set(item.claimId, resolved.trim());
        }
      }
    }
  } catch (err: any) {
    logger.warn("[MultilingualPreRetrieval] Batched canonical translation fallback", {
      err: err?.message,
    });
  }

  // Deterministic bracket fallback for any claim missing from model output
  for (const c of nonAsciiClaims) {
    if (!canonicalMap.has(c.claimId)) {
      const rawText = getClaimSearchText(c);
      const bracketed = extractBracketedEnglish(rawText);
      if (bracketed) canonicalMap.set(c.claimId, bracketed);
    }
  }

  return canonicalMap;
}

/**
 * Domain-wide `$0` pre-retrieval helper reusing the upfront `preResolvedEnglishMap`:
 * - Wikipedia (English + native script when detected) across ALL factual domains
 * - Wikidata entity facts across ALL factual domains
 * - Conditional PubMed & Crossref for medical / clinical / biomedical / quantitative claims
 * - Conditional World Bank & FRED for macroeconomic / financial claims
 */
export async function gatherDomainWidePreRetrieval(
  claims: Array<FilteredClaim | { claimId: string; text?: string; normalizedClaim?: string; verbatimQuote?: string; domain?: string; requiresVerification?: boolean }>,
  preResolvedEnglishMap?: Map<string, string>,
  options: DomainWidePreRetrievalOptions = {}
): Promise<VerifiedSource[]> {
  const verifiable = claims.filter((c) => (c as any).requiresVerification !== false);
  if (verifiable.length === 0) return [];

  const timeoutMs = options.timeoutMs ?? DEFAULT_PRE_RETRIEVAL_TIMEOUT_MS;
  const englishMap = new Map<string, string>(preResolvedEnglishMap || []);

  const missingNonAscii = verifiable.filter((c) => {
    const t = getClaimSearchText(c);
    return /[^\x00-\x7F]/.test(t) && !englishMap.has(c.claimId);
  });
  if (missingNonAscii.length > 0) {
    const resolvedMissing = await batchResolveMultilingualCanonical(missingNonAscii);
    for (const [k, v] of resolvedMissing.entries()) {
      englishMap.set(k, v);
    }
  }

  const retrievalTasks = verifiable.flatMap((claim) => {
    const claimText = getClaimSearchText(claim);
    const claimDomain = String((claim as any).domain || "");
    const englishQuery = englishMap.get(claim.claimId) || claimText;
    const combinedText = `${claimText} ${englishQuery}`;

    const tasks: Array<Promise<RawProviderHit[]>> = [
      runWithTimeout(
        (signal) =>
          wikipediaAdapter.searchPassages(englishQuery, { limit: 2, lang: "en", signal }).then((hits) =>
            hits.map((h) => ({
              title: h.title,
              uri: h.url,
              passage: h.extract,
              provider: "WIKIPEDIA" as EvidenceProvider,
              claimId: claim.claimId,
            }))
          ),
        timeoutMs,
        []
      ),
      runWithTimeout(
        (signal) =>
          wikidataAdapter.searchEntities(englishQuery, { signal }).then((hits) =>
            hits.map((h) => ({
              title: h.title,
              uri: h.url,
              passage: h.passage,
              provider: "WIKIDATA" as EvidenceProvider,
              claimId: claim.claimId,
            }))
          ),
        timeoutMs,
        []
      ),
    ];

    const nativeLang = detectScriptWikipediaLang(claimText);
    if (nativeLang && nativeLang !== "en") {
      tasks.push(
        runWithTimeout(
          (signal) =>
            wikipediaAdapter.searchPassages(claimText, { limit: 1, lang: nativeLang, signal }).then((hits) =>
              hits.map((h) => ({
                title: h.title,
                uri: h.url,
                passage: h.extract,
                provider: "WIKIPEDIA" as EvidenceProvider,
                claimId: claim.claimId,
              }))
            ),
          timeoutMs,
          []
        )
      );
    }

    const biomedicalMatch =
      claimDomain === "HEALTH_MEDICAL" ||
      /\d+%|\b(study|trial|clinical|vaccine|drug|disease|cancer|treatment|medical|fda|pharma|meta-analysis|symptom|therapy)\b/i.test(
        combinedText
      );
    if (biomedicalMatch) {
      tasks.push(
        runWithTimeout(
          (signal) =>
            pubmedAdapter.searchAbstracts(englishQuery, { limit: 2, signal }).then((hits) =>
              hits.map((h) => ({
                title: h.title,
                uri: `https://pubmed.ncbi.nlm.nih.gov/${h.pmid}/`,
                passage: h.abstractText,
                provider: "PUBMED" as EvidenceProvider,
                claimId: claim.claimId,
              }))
            ),
          timeoutMs,
          []
        ),
        runWithTimeout(
          (signal) =>
            crossrefAdapter.searchWorks(englishQuery, { limit: 2, signal }).then((hits) =>
              hits.map((h) => ({
                title: h.title,
                uri: h.doiUrl,
                passage: h.abstract || h.subtitle || h.title,
                provider: "CROSSREF" as EvidenceProvider,
                claimId: claim.claimId,
              }))
            ),
          timeoutMs,
          []
        )
      );
    }

    const macroMatch =
      claimDomain === "MACROECONOMICS_FINANCE" ||
      claimDomain === "Economics" ||
      /\b(inflation|cpi|gdp|unemployment|interest rate|repo rate|fed funds|treasury|recession|fiscal deficit|exchange rate)\b/i.test(
        combinedText
      );
    if (macroMatch) {
      tasks.push(
        runWithTimeout(
          (signal) =>
            worldBankAdapter.searchIndicators(englishQuery, { signal }).then((hits) =>
              hits.map((h) => ({
                title: h.title,
                uri: h.url,
                passage: h.passage,
                provider: "WORLDBANK" as EvidenceProvider,
                claimId: claim.claimId,
              }))
            ),
          timeoutMs,
          []
        ),
        runWithTimeout(
          (signal) =>
            fredAdapter.searchObservations(englishQuery, { signal }).then((hits) =>
              hits.map((h) => ({
                title: h.title,
                uri: h.url,
                passage: h.passage,
                provider: "FRED" as EvidenceProvider,
                claimId: claim.claimId,
              }))
            ),
          timeoutMs,
          []
        )
      );
    }

    return tasks;
  });

  const settled = await Promise.allSettled(retrievalTasks);
  const byUri = new Map<string, VerifiedSource>();

  for (const outcome of settled) {
    if (outcome.status !== "fulfilled") continue;
    for (const hit of outcome.value) {
      if (!hit.uri || !hit.passage) continue;
      const key = hit.uri.trim();
      const existing = byUri.get(key);
      if (existing) {
        if (existing.claimIds && !existing.claimIds.includes(hit.claimId)) {
          existing.claimIds.push(hit.claimId);
        }
        continue;
      }

      byUri.set(key, {
        evidenceId: `E${byUri.size + 1}`,
        title: hit.title,
        uri: key,
        snippet: truncateSnippet(hit.passage),
        sourceProvider: hit.provider,
        claimIds: [hit.claimId],
      });
    }
  }

  return Array.from(byUri.values());
}
