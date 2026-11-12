/**
 * 🌍 TRANSLATION SERVICE — Google Cloud Translation v3 (Advanced) + Vertex AI Gemini
 *
 * ✅ WORLD-CLASS PRODUCTION GRADE (Tier-1 Enterprise / Netflix / YouTube Standard):
 *   1. Zero HTML entity leakage: Automatic sanitization & decoding across all engines (v3, v2, Gemini).
 *   2. Native Gemini Structured Outputs (JSON Schema enforcement) with defensive fallback repair.
 *   3. Real-time Dubbing Sync & Audio Pacing constraints (durationSeconds & maxWords).
 *   4. Bounded concurrent batch processing (mapConcurrent pool) eliminating serialization bottlenecks.
 *   5. Resilient transient error & quota retries with exponential backoff & jitter (429/503/RESOURCE_EXHAUSTED).
 *   6. Multi-tier fallback hierarchy: Google v3 -> Google v2 -> Vertex AI Gemini -> Safe original text.
 */

import type { v3, v2 } from "@google-cloud/translate";
import type { VertexAI } from "../utils/ai-client";
import { TranslationResult, TranslatedSegment, CreatorDNA } from "../types";
import { SpeakerProfile } from "./speaker-profiling";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";
import { normalizeLanguageCode } from "../../shared/language-normalizer";

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT_ID || "truthworld-1";

/**
 * Preferred location for v3 requests.
 * "global" is safest default; can be overridden to "asia-south1" for data residency.
 */
const TRANSLATION_LOCATION = process.env.TRANSLATION_LOCATION || "global";

/** Max segments per v3 batch call (API limit is 128 content items per request) */
const V3_BATCH_SIZE = 100;

/** Default concurrency limit for parallel batch requests */
const DEFAULT_CONCURRENCY = 3;

// ─── UTILITY HELPERS ────────────────────────────────────────────────────────

/**
 * Robust, zero-dependency HTML entity decoder.
 * Prevents Google Cloud Translation entity leaks (&#39;, &quot;, &amp;, etc.)
 * from polluting video subtitles (.srt, .vtt) or being vocalized by TTS engines.
 */
export function decodeHtmlEntities(text: string): string {
  if (!text || typeof text !== "string") return text || "";

  const namedEntities: Record<string, string> = {
    "&quot;": '"',
    "&amp;": "&",
    "&apos;": "'",
    "&lt;": "<",
    "&gt;": ">",
    "&nbsp;": " ",
    "&iexcl;": "¡",
    "&cent;": "¢",
    "&pound;": "£",
    "&curren;": "¤",
    "&yen;": "¥",
    "&brvbar;": "¦",
    "&sect;": "§",
    "&uml;": "¨",
    "&copy;": "©",
    "&ordf;": "ª",
    "&laquo;": "«",
    "&not;": "¬",
    "&reg;": "®",
    "&macr;": "¯",
    "&deg;": "°",
    "&plusmn;": "±",
    "&sup2;": "²",
    "&sup3;": "³",
    "&acute;": "´",
    "&micro;": "µ",
    "&para;": "¶",
    "&middot;": "·",
    "&cedil;": "¸",
    "&sup1;": "¹",
    "&ordm;": "º",
    "&raquo;": "»",
    "&frac14;": "¼",
    "&frac12;": "½",
    "&frac34;": "¾",
    "&iquest;": "¿",
    "&times;": "×",
    "&divide;": "÷",
    "&ndash;": "–",
    "&mdash;": "—",
    "&lsquo;": "‘",
    "&rsquo;": "’",
    "&sbquo;": "‚",
    "&ldquo;": "“",
    "&rdquo;": "”",
    "&bdquo;": "„",
    "&dagger;": "†",
    "&Dagger;": "‡",
    "&bull;": "•",
    "&hellip;": "…",
    "&permil;": "‰",
    "&prime;": "′",
    "&Prime;": "″",
    "&lsaquo;": "‹",
    "&rsaquo;": "›",
    "&euro;": "€",
    "&trade;": "™",
    // Accented vowels and European multilingual characters
    "&aacute;": "á",
    "&eacute;": "é",
    "&iacute;": "í",
    "&oacute;": "ó",
    "&uacute;": "ú",
    "&Aacute;": "Á",
    "&Eacute;": "É",
    "&Iacute;": "Í",
    "&Oacute;": "Ó",
    "&Uacute;": "Ú",
    "&ntilde;": "ñ",
    "&Ntilde;": "Ñ",
    "&uuml;": "ü",
    "&Uuml;": "Ü",
    "&agrave;": "à",
    "&egrave;": "è",
    "&igrave;": "ì",
    "&ograve;": "ò",
    "&ugrave;": "ù",
    "&acirc;": "â",
    "&ecirc;": "ê",
    "&icirc;": "î",
    "&ocirc;": "ô",
    "&ucirc;": "û",
    "&ccedil;": "ç",
    "&Ccedil;": "Ç",
    "&auml;": "ä",
    "&Auml;": "Ä",
    "&ouml;": "ö",
    "&Ouml;": "Ö",
    "&szlig;": "ß",
  };

  return text.replace(/&[a-zA-Z0-9#xX]+;/g, (entity) => {
    if (namedEntities[entity]) return namedEntities[entity];
    if (entity.startsWith("&#x") || entity.startsWith("&#X")) {
      const code = parseInt(entity.slice(3, -1), 16);
      if (!isNaN(code)) return String.fromCharCode(code);
    } else if (entity.startsWith("&#")) {
      const code = parseInt(entity.slice(2, -1), 10);
      if (!isNaN(code)) return String.fromCharCode(code);
    }
    return entity;
  });
}

/**
 * Resilient retry wrapper with exponential backoff & jitter for transient API / quota errors.
 */
export async function withTransientRetry<T>(
  fn: () => Promise<T>,
  options: { maxAttempts?: number; baseDelayMs?: number; label?: string } = {}
): Promise<T> {
  const maxAttempts = options.maxAttempts ?? 3;
  const baseDelay = options.baseDelayMs ?? 400;
  let lastError: any;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      lastError = err;
      const status = err?.status || err?.code;
      const message = String(err?.message || "").toLowerCase();
      const isTransient =
        status === 429 ||
        status === 503 ||
        status === "RESOURCE_EXHAUSTED" ||
        status === "UNAVAILABLE" ||
        message.includes("429") ||
        message.includes("503") ||
        message.includes("resource exhausted") ||
        message.includes("quota") ||
        message.includes("rate limit") ||
        message.includes("etimedout") ||
        message.includes("econnreset") ||
        message.includes("overloaded") ||
        message.includes("unavailable");

      if (!isTransient || attempt === maxAttempts) {
        throw err;
      }

      const jitter = Math.random() * 200;
      const delay = Math.min(baseDelay * Math.pow(2, attempt - 1) + jitter, 8000);
      console.warn(
        `[Translation Retry] ${options.label || "Call"} failed with transient error (${err?.message || err}). Retrying attempt ${attempt + 1}/${maxAttempts} in ${Math.round(delay)}ms...`
      );
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastError;
}

/**
 * Bounded concurrency mapper: executes an async task across an array of items
 * while preserving strict index ordering and capping parallel in-flight requests.
 */
export async function mapConcurrent<T, R>(
  items: T[],
  concurrency: number,
  fn: (item: T, index: number) => Promise<R>
): Promise<R[]> {
  if (items.length === 0) return [];
  const results: R[] = new Array(items.length);
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const idx = nextIndex++;
      results[idx] = await fn(items[idx], idx);
    }
  }

  const poolSize = Math.max(1, Math.min(concurrency, items.length));
  const workers = Array.from({ length: poolSize }, () => worker());
  await Promise.all(workers);
  return results;
}

/**
 * Target-language syllable expansion ratios relative to English baseline (1.0),
 * reflecting agglutinative/polysyllabic expansion (e.g. Telugu, Tamil, German) vs compact CJK.
 */
export const LANG_SYLLABLE_RATIOS: Record<string, number> = {
  en: 1.0,
  zh: 0.9,
  vi: 0.95,
  sv: 1.1,
  th: 1.1,
  ru: 1.12,
  hi: 1.15,
  pa: 1.15,
  ur: 1.15,
  ar: 1.15,
  id: 1.15,
  nl: 1.15,
  gu: 1.18,
  fr: 1.18,
  pl: 1.18,
  mr: 1.2,
  pt: 1.2,
  bn: 1.22,
  es: 1.22,
  it: 1.22,
  de: 1.25,
  tr: 1.25,
  ko: 1.3,
  ta: 1.35,
  kn: 1.35,
  te: 1.38,
  ml: 1.4,
  ja: 1.45,
};

/**
 * Estimates spoken syllable count for Latin, Indic abugida, CJK/Kana/Hangul, and other scripts
 * while ignoring bracketed ElevenLabs audio performance tags such as `[whispers]`.
 */
export function countSourceSyllables(text: string, language?: string): number {
  const clean = (text || "").replace(/\[[^\]]+\]/g, " ").trim();
  if (!clean) return 0;

  const lang = (language || "").toLowerCase().split(/[-_]/)[0];

  // CJK / Japanese Kana / Korean Hangul character-syllable counting
  const cjkMatches = clean.match(/[\u4E00-\u9FFF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]/g);
  if (cjkMatches && (lang === "zh" || lang === "ja" || lang === "ko" || cjkMatches.length >= clean.length * 0.35)) {
    const kanjiCount = (clean.match(/[\u4E00-\u9FFF]/g) || []).length;
    const kanaHangulCount = cjkMatches.length - kanjiCount;
    const jpKanjiWeight = lang === "ja" ? 1.5 : 1.0;
    const latinWords = clean.replace(/[\u4E00-\u9FFF\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF]/g, " ").trim().split(/\s+/).filter(Boolean);
    return Math.max(1, Math.round(kanjiCount * jpKanjiWeight + kanaHangulCount + latinWords.length * 1.4));
  }

  // Indic abugidas (Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu, Kannada, Malayalam)
  const indicConsonantOrVowel = clean.match(/[\u0904-\u0939\u0958-\u0961\u0985-\u09B9\u0A05-\u0A39\u0A85-\u0AB9\u0B05-\u0B39\u0B85-\u0BB9\u0C05-\u0C39\u0C85-\u0CB9\u0D05-\u0D39]/g);
  if (indicConsonantOrVowel && indicConsonantOrVowel.length > 0) {
    const viramas = (clean.match(/[\u094D\u09CD\u0A4D\u0ACD\u0B4D\u0BCD\u0C4D\u0CCD\u0D4D]/g) || []).length;
    const indicSyllables = Math.max(1, indicConsonantOrVowel.length - viramas);
    const nonIndicLatin = clean.replace(/[\u0900-\u0D7F]/g, " ").trim().split(/\s+/).filter(Boolean);
    const nonIndicSyllables = nonIndicLatin.reduce((sum, w) => sum + countLatinWordSyllables(w), 0);
    return indicSyllables + nonIndicSyllables;
  }

  // Arabic / Cyrillic / Thai / Latin fallback per word
  const words = clean.split(/\s+/).filter(Boolean);
  if (words.length === 0) return 0;

  return words.reduce((sum, raw) => {
    // Arabic/Hebrew abjads: approximate from word length (~2.3 chars/syllable)
    if (/[\u0600-\u06FF\u0590-\u05FF]/.test(raw)) {
      const letters = raw.replace(/[^\u0600-\u06FF\u0590-\u05FF]/g, "").length;
      return sum + Math.max(1, Math.round(letters / 2.3));
    }
    return sum + countLatinWordSyllables(raw);
  }, 0);
}

function countLatinWordSyllables(word: string): number {
  const cleaned = word.toLowerCase().replace(/[^a-z\u00C0-\u024F\u0400-\u04FF]/g, "");
  if (!cleaned) return 0;
  if (cleaned.length <= 3) return 1;

  // Cyrillic vowels + Latin vowels
  const normalized = cleaned.replace(/(?:[^laeiouy\u0430\u0435\u0451\u0438\u043E\u0443\u044B\u044D\u044E\u044F]es|ed|[^laeiouy]e)$/, "")
    .replace(/^y/, "");
  const groups = normalized.match(/[aeiouy\u00E0-\u00FF\u0430\u0435\u0451\u0438\u043E\u0443\u044B\u044D\u044E\u044F]+/g);
  return Math.max(1, groups ? groups.length : 1);
}

/**
 * Computes normalized syllable-budget compliance score (0.0 to 1.0) for a dubbed segment.
 * Scores 1.0 when translated syllable count fits within the timing & language expansion budget.
 */
export function computeSyllableBudgetCompliance(
  sourceText: string,
  translatedText: string,
  sourceLanguage: string,
  targetLanguage: string,
  durationMs?: number
): number {
  const srcSyllables = Math.max(1, countSourceSyllables(sourceText, sourceLanguage));
  const tgtSyllables = Math.max(1, countSourceSyllables(translatedText, targetLanguage));
  const srcLang = (sourceLanguage || "en").toLowerCase().split(/[-_]/)[0];
  const tgtLang = (targetLanguage || "en").toLowerCase().split(/[-_]/)[0];
  const srcRatio = LANG_SYLLABLE_RATIOS[srcLang] ?? 1.1;
  const tgtRatio = LANG_SYLLABLE_RATIOS[tgtLang] ?? 1.2;
  const langExpansionRatio = tgtRatio / Math.max(0.7, srcRatio);

  const durSec = durationMs && durationMs > 0 ? durationMs / 1000 : null;
  const targetBudget = durSec
    ? Math.max(4, Math.round(durSec * 3.8 * Math.min(1.35, Math.max(0.85, tgtRatio))))
    : Math.max(2, Math.round(srcSyllables * langExpansionRatio * 1.15));

  if (tgtSyllables <= targetBudget) return 1.0;
  return Number(Math.max(0.1, Math.min(1.0, targetBudget / tgtSyllables)).toFixed(3));
}

// ─── TRANSLATION SERVICE ───────────────────────────────────────────────────

export class TranslationService {
  private _v3Client: v3.TranslationServiceClient | null | undefined = undefined;
  private _v2Client: v2.Translate | null | undefined = undefined;
  private _gemini:   VertexAI | null = null;

  private get v3Client(): v3.TranslationServiceClient | null {
    if (this._v3Client === undefined) {
      try {
        // ✅ Always use ADC. The Cloud Translation v3 gRPC client does NOT support
        // API keys — passing { apiKey } causes UNAUTHENTICATED (code 16) on every
        // call. Cloud Functions / Cloud Run provide ADC automatically via the
        // service account, so no extra configuration is needed.
        const { v3 } = require("@google-cloud/translate");
        this._v3Client = new v3.TranslationServiceClient();
      } catch (err) {
        console.warn("[Translation] v3 client init failed — falling back to v2", err);
        this._v3Client = null;
      }
    }
    return this._v3Client ?? null;
  }

  private get v2Client(): v2.Translate | null {
    if (this._v2Client === undefined) {
      const key = PIPELINE_CONFIG.GOOGLE_TRANSLATION_API_KEY;
      try {
        const { v2 } = require("@google-cloud/translate");
        this._v2Client = key 
          ? new v2.Translate({ projectId, key }) 
          : new v2.Translate({ projectId });
      } catch (err) {
        console.warn("[Translation] v2 client init failed", err);
        this._v2Client = null;
      }
    }
    return this._v2Client ?? null;
  }

  private get gemini(): VertexAI | null {
    if (!this._gemini) {
      this._gemini = getVertexAI();
    }
    return this._gemini;
  }

  /** v3 parent path: projects/{project}/locations/{location} */
  private get parent(): string {
    return `projects/${projectId}/locations/${TRANSLATION_LOCATION}`;
  }

  constructor() {}

  // ─── Single text translation ───────────────────────────────────────────────

  async translateText(
    text: string,
    sourceLanguage: string,
    targetLanguage: string
  ): Promise<string> {
    const src = normalizeLanguageCode(sourceLanguage);
    const tgt = normalizeLanguageCode(targetLanguage);

    // ── v3 path (with retry & HTML entity sanitization) ────────────────────
    if (this.v3Client) {
      try {
        const translated = await withTransientRetry(async () => {
          const [response] = await this.v3Client!.translateText({
            parent: this.parent,
            contents: [text],
            mimeType: "text/plain",
            sourceLanguageCode: src,
            targetLanguageCode: tgt,
          });
          return response.translations?.[0]?.translatedText;
        }, { maxAttempts: 2, label: "Google v3 translateText" });

        if (translated) return decodeHtmlEntities(translated);
      } catch (error) {
        console.error("[Translation] v3 translateText error — falling back to v2:", error);
      }
    }

    // ── v2 fallback (with retry & HTML entity sanitization) ────────────────
    if (this.v2Client) {
      try {
        const translated = await withTransientRetry(async () => {
          const [translations] = await this.v2Client!.translate(text, {
            from: src,
            to: tgt,
          });
          return Array.isArray(translations) ? translations[0] : translations;
        }, { maxAttempts: 2, label: "Google v2 translateText" });

        if (translated) return decodeHtmlEntities(translated);
      } catch (error) {
        console.error("[Translation] v2 translateText error — falling back to Gemini:", error);
      }
    }

    // ── Gemini fallback ────────────────────────────────────────────────────
    if (this.gemini) {
      try {
        const geminiRes = await this.translatePremiumBatch([text], src, tgt, "formal", "neutral", "youtube");
        if (geminiRes.translations?.[0]) return decodeHtmlEntities(geminiRes.translations[0]);
      } catch (error) {
        console.error("[Translation] Gemini fallback translateText error:", error);
      }
    }

    // Graceful fallback to original text (sanitized)
    console.warn("[Translation] All translation engines failed — returning original text");
    return decodeHtmlEntities(text);
  }

  // ─── Batch segment translation ─────────────────────────────────────────────

  async translateSegments(
    jobId: string,
    segments: Array<{
      start: number;
      end: number;
      text: string;
      speaker?: string;
      isHook?: boolean;
      duration?: number;
      emotionTag?: string;
      energyDb?: number;
      stabilityOverride?: number;
      similarityBoostOverride?: number;
      pitchRangeSemitones?: number;
      voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
    }>,
    sourceLanguage: string,
    targetLanguage: string,
    options?: { 
      model?: "standard" | "premium" | "dynamic"; 
      dubbingTier?: "audio_track";
      subtitleTier?: "ultra" | "starter" | "pro";
      isCinemaGrade?: boolean;
      tone?: "casual" | "formal"; 
      localeStyle?: "neutral" | "hinglish" | "hinglish_urban" | "hinglish_professional" | "slang";
      targetPlatform?: "youtube" | "reels" | "shorts" | "linkedin" | "tiktok";
      creatorDNA?: CreatorDNA;
      enableABHooks?: boolean;
      speakerProfiles?: SpeakerProfile[];
      targetDurations?: number[];
      userId?: string;
    }
  ): Promise<TranslationResult> {
    const normSourceLang = normalizeLanguageCode(sourceLanguage);
    const normTargetLang = normalizeLanguageCode(targetLanguage);
    try {
      const texts = segments.map((s) => s.text);
      const durations = segments.map((s, idx) => {
        if (options?.targetDurations?.[idx]) return options.targetDurations[idx];
        if (s.duration && s.duration > 0) return s.duration;
        if (s.end > s.start) return s.end - s.start;
        return 0;
      });

      const translatedTexts: string[] = new Array(texts.length);
      const confidenceScores: number[] = new Array(texts.length).fill(0.95);
      const segmentVariants: any[] = new Array(texts.length).fill(undefined);

      const isKnownDubbingTier = Boolean(options?.dubbingTier);
      const requestedModel = (isKnownDubbingTier || options?.model === "premium") ? "premium" : (options?.model || "standard");

      // ── Lane Routing Logic ───────────────────────────────────────────────
      const premiumIndices: number[] = [];
      const standardIndices: number[] = [];

      if (requestedModel === "dynamic") {
        texts.forEach((text, i) => {
          // Dynamic escalation: Hook Priority, tight audio pacing, or high-complexity brands/terms
          if (segments[i].isHook || this.shouldEscalateToPremium(text, durations[i])) {
            premiumIndices.push(i);
          } else {
            standardIndices.push(i);
          }
        });
        console.log(`[Translation] Dynamic routing: ${premiumIndices.length} premium (including hooks & tight pacing), ${standardIndices.length} standard`);
      } else if (requestedModel === "premium") {
        texts.forEach((_, i) => premiumIndices.push(i));
      } else {
        texts.forEach((_, i) => standardIndices.push(i));
      }

      // ── Execution: Standard Lane (Google Cloud Translation v3/v2) ────────
      if (standardIndices.length > 0) {
        const standardTexts = standardIndices.map((i) => texts[i]);
        const standardTranslated = await this.batchTranslateStandard(standardTexts, normSourceLang, normTargetLang);
        standardIndices.forEach((idx, i) => {
          translatedTexts[idx] = decodeHtmlEntities(standardTranslated[i]);
          confidenceScores[idx] = 0.90;
        });
      }

      // ── Execution: Premium Lane (Vertex AI Gemini Structured Outputs) ───
      if (premiumIndices.length > 0 && this.gemini) {
        try {
          const premiumSegments = premiumIndices.map((i) => ({
            text: texts[i],
            speaker: segments[i].speaker,
            isHook: segments[i].isHook,
            duration: durations[i],
            emotionTag: segments[i].emotionTag,
          }));

          const isUltraSubtitle = options?.subtitleTier === "ultra" || options?.subtitleTier === "pro";
          const isCinema = Boolean(options?.isCinemaGrade) || isUltraSubtitle;

          const premiumResult = await this.translatePremiumBatch(
            premiumSegments.map((s) => s.text), 
            normSourceLang, 
            normTargetLang, 
            options?.tone || "formal",
            options?.localeStyle || "neutral",
            options?.targetPlatform || "youtube",
            options?.creatorDNA,
            options?.enableABHooks,
            options?.speakerProfiles,
            premiumSegments.map((s) => s.speaker),
            premiumSegments.map((s) => s.isHook),
            premiumSegments.map((s) => s.duration),
            isCinema,
            options?.subtitleTier,
            options?.dubbingTier,
            premiumSegments.map((s) => s.emotionTag)
          );

          premiumIndices.forEach((idx, i) => {
            translatedTexts[idx] = decodeHtmlEntities(premiumResult.translations[i] || texts[idx]);
            confidenceScores[idx] = premiumResult.confidences[i] ?? 0.95;
            segmentVariants[idx] = premiumResult.variants?.[i] || undefined;
          });
        } catch (error) {
          console.error("[Translation] Premium lane failed — falling back to standard:", error);
          const remainingTexts = premiumIndices.map((i) => texts[i]);
          const fallbackTranslated = await this.batchTranslateStandard(remainingTexts, normSourceLang, normTargetLang);
          premiumIndices.forEach((idx, i) => {
            translatedTexts[idx] = decodeHtmlEntities(fallbackTranslated[i] || texts[idx]);
          });
        }
      }

      // ✅ Cost tracking: record actual character count translated
      const totalChars = texts.reduce((sum, t) => sum + t.length, 0);
      const targetUserId = options?.userId || "system";
      costEngine.recordTranslationCost(jobId, targetUserId, totalChars).catch((err) => {
        console.warn("[Translation] Non-blocking cost recording error:", err);
      });

      const translatedSegments: TranslatedSegment[] = segments.map(
        (segment, index) => {
          const decodedText = decodeHtmlEntities(translatedTexts[index] || segment.text);
          const segDurationMs = durations[index] > 0
            ? (durations[index] > 1000 ? durations[index] : durations[index] * 1000)
            : Math.max(0, segment.end - segment.start);
          const syllableBudgetCompliance = computeSyllableBudgetCompliance(
            segment.text,
            decodedText,
            normSourceLang,
            normTargetLang,
            segDurationMs
          );
          return {
            original: segment.text,
            translated: decodedText,
            start: segment.start,
            end: segment.end,
            confidence: confidenceScores?.[index],
            isHook: segment.isHook,
            variants: segmentVariants[index],
            emotionTag: segment.emotionTag,
            energyDb: segment.energyDb,
            stabilityOverride: segment.stabilityOverride,
            similarityBoostOverride: segment.similarityBoostOverride,
            pitchRangeSemitones: segment.pitchRangeSemitones,
            voiceQuality: segment.voiceQuality,
            syllableBudgetCompliance,
          };
        }
      );

      return {
        jobId,
        sourceLanguage,
        targetLanguage,
        segments: translatedSegments,
      };
    } catch (error) {
      console.error(`[Translation] translateSegments error for job ${jobId}:`, error);
      throw error;
    }
  }

  // ─── Language detection ────────────────────────────────────────────────────

  async detectLanguage(text: string): Promise<string> {
    // ── v3 path (with retry) ────────────────────────────────────────────────
    if (this.v3Client) {
      try {
        const best = await withTransientRetry(async () => {
          const [response] = await this.v3Client!.detectLanguage({
            parent: this.parent,
            content: text,
            mimeType: "text/plain",
          });
          return response.languages?.[0]?.languageCode;
        }, { maxAttempts: 2, label: "Google v3 detectLanguage" });

        if (best) return best;
      } catch (error) {
        console.error("[Translation] v3 detectLanguage error — falling back:", error);
      }
    }

    // ── v2 fallback (with retry) ────────────────────────────────────────────
    if (this.v2Client) {
      try {
        const detection = await withTransientRetry(async () => {
          const [detections] = await this.v2Client!.detect(text);
          return Array.isArray(detections) ? detections[0] : detections;
        }, { maxAttempts: 2, label: "Google v2 detectLanguage" });

        return detection?.language || "en";
      } catch (error) {
        console.error("[Translation] v2 detectLanguage error:", error);
      }
    }

    return "en"; // fallback
  }

  // ─── Batch language detection ──────────────────────────────────────────────

  async detectLanguages(texts: string[]): Promise<string[]> {
    if (this.v2Client) {
      try {
        const detections = await withTransientRetry(async () => {
          const [results] = await this.v2Client!.detect(texts);
          return results;
        }, { maxAttempts: 2, label: "Google v2 detectLanguages batch" });

        return detections.map((d: any) => d.language || "en");
      } catch (error) {
        console.error("[Translation] Batch language detection error:", error);
      }
    }

    // Fallback: iterate with v3 using bounded concurrency
    if (this.v3Client) {
      return await mapConcurrent(texts, DEFAULT_CONCURRENCY, (text) => this.detectLanguage(text));
    }

    return texts.map(() => "en");
  }

  // ─── Private: v3 batched translation ───────────────────────────────────────

  /**
   * Translate texts in batches via v3 API with bounded concurrency & retry.
   * V3_BATCH_SIZE is set to 100 (API limit: 128 items).
   */
  private async batchTranslateV3(
    texts: string[],
    sourceLanguage: string,
    targetLanguage: string
  ): Promise<string[]> {
    const batches: string[][] = [];
    for (let i = 0; i < texts.length; i += V3_BATCH_SIZE) {
      batches.push(texts.slice(i, i + V3_BATCH_SIZE));
    }

    const batchResults = await mapConcurrent(batches, DEFAULT_CONCURRENCY, async (batch, batchIdx) => {
      return await withTransientRetry(async () => {
        const [response] = await this.v3Client!.translateText({
          parent: this.parent,
          contents: batch,
          mimeType: "text/plain",
          sourceLanguageCode: sourceLanguage,
          targetLanguageCode: targetLanguage,
        });

        return (response.translations ?? []).map((t) => decodeHtmlEntities(t.translatedText ?? ""));
      }, { maxAttempts: 3, label: `Google v3 batchTranslate #${batchIdx}` });
    });

    return batchResults.flat();
  }

  /**
   * Internal helper for batching standard translations with fallback logic.
   * Multi-tier hierarchy: Google v3 -> Google v2 -> Vertex AI Gemini -> Safe fallback
   */
  private async batchTranslateStandard(texts: string[], source: string, target: string): Promise<string[]> {
    if (this.v3Client) {
      try {
        return await this.batchTranslateV3(texts, source, target);
      } catch (err) {
        console.warn("[Translation] v3 batch fallback to v2", err);
      }
    }
    if (this.v2Client) {
      try {
        const translations = await withTransientRetry(async () => {
          const [res] = await this.v2Client!.translate(texts, { from: source, to: target });
          return Array.isArray(res) ? res : [res];
        }, { maxAttempts: 2, label: "Google v2 batchTranslate" });

        return translations.map((t) => decodeHtmlEntities(t));
      } catch (err) {
        console.warn("[Translation] v2 batch fallback to Gemini", err);
      }
    }
    if (this.gemini) {
      try {
        console.info(`[Translation] Using Gemini Vertex AI translation fallback for ${texts.length} segments (${source} -> ${target})`);
        const geminiRes = await this.translatePremiumBatch(texts, source, target, "formal", "neutral", "youtube");
        if (geminiRes.translations && geminiRes.translations.length === texts.length) {
          return geminiRes.translations.map((t) => decodeHtmlEntities(t));
        }
      } catch (err) {
        console.error("[Translation] Gemini standard translation fallback failed:", err);
      }
    }
    console.warn("[Translation] All translation services failed — returning original texts as graceful fallback");
    return texts.map((t) => decodeHtmlEntities(t));
  }

  /**
   * Complexity Scouter: Determines if a segment requires premium Gemini processing
   * based on high-value keywords, tech terms, emotion, or tight dubbing speech rate constraints.
   */
  private shouldEscalateToPremium(text: string, durationMs?: number): boolean {
    const regexPatterns = [
      /\b(?:Anthropic|Claude|Figma|Adobe|Nvidia|OpenAI|Google|Apple|Microsoft)\b/i, // Brands
      /\b(?:launched|announced|released|revealed|exclusive|breaking)\b/i,            // High-value keywords
      /[!?.]{2,}/,                                                                   // High emotion / punctuation
      /\b(?:UI|UX|API|SDK|LLM|GPU|AI|Interface)\b/i,                                 // Tech terms
      /\w{20,}/,                                                                     // Very long words (likely tech/medical)
    ];
    
    const isLong = text.length > 150;
    const matchesRegex = regexPatterns.some((p) => p.test(text));

    // Dubbing audio sync constraint: if segment speech rate exceeds 18 chars/sec, escalate to Gemini for concise localization
    const isTightPacing = durationMs && durationMs > 0 ? (text.length / (durationMs / 1000)) > 18 : false;

    return isLong || matchesRegex || isTightPacing;
  }

  // ─── Private: Premium Gemini translation (Structured Outputs & Concurrency) ─

  private async translatePremiumBatch(
    texts: string[],
    sourceLanguage: string,
    targetLanguage: string,
    tone: "casual" | "formal",
    localeStyle: string,
    targetPlatform: string,
    creatorDNA?: CreatorDNA,
    enableABHooks?: boolean,
    speakerProfiles?: SpeakerProfile[],
    speakersInBatch?: (string | undefined)[],
    hooksInBatch?: (boolean | undefined)[],
    durationsInBatch?: (number | undefined)[],
    isCinemaGrade?: boolean,
    subtitleTier?: "ultra" | "starter" | "pro",
    dubbingTier?: "audio_track",
    emotionsInBatch?: (string | undefined)[]
  ): Promise<{ translations: string[]; confidences: number[]; variants?: any[] }> {
    if (!this.gemini) {
      throw new Error("Gemini client not initialized for premium translation");
    }

    const { Type: SchemaType } = require("@google/genai");

    // Native Structured Output Schema for Gemini
    const responseSchema = {
      type: SchemaType.OBJECT,
      properties: {
        translations: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Array of translated text segments matching input segments index-for-index."
        },
        confidences: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.NUMBER },
          description: "Array of localization quality / confidence scores (0.0 to 1.0) per segment."
        },
        variants: {
          type: SchemaType.ARRAY,
          items: {
            type: SchemaType.OBJECT,
            nullable: true,
            properties: {
              viral: { type: SchemaType.STRING },
              safe: { type: SchemaType.STRING },
              professional: { type: SchemaType.STRING }
            }
          },
          description: "Optional hook variants per segment when requested, or null."
        }
      },
      required: ["translations", "confidences"]
    };

    const isUltraTier = dubbingTier === "audio_track";
    const isProOrCinema = Boolean(isCinemaGrade) || subtitleTier === "ultra" || subtitleTier === "pro" || isUltraTier;
    // Unified on Gemini 2.5 Flash for all dubbing & cinema-grade subtitles
    const targetModelName = PIPELINE_CONFIG.GEMINI_MODELS?.translation || "gemini-2.5-flash";

    const model = this.gemini.getGenerativeModel({
      model: targetModelName,
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema,
        temperature: isProOrCinema ? 0.15 : 0.2,
      } as any,
    });

    const CHUNK_SIZE = 20;
    const chunkInputs: Array<{
      chunkIndex: number;
      texts: string[];
      speakers: (string | undefined)[];
      hooks: (boolean | undefined)[];
      durations: (number | undefined)[];
      emotions: (string | undefined)[];
    }> = [];

    for (let i = 0; i < texts.length; i += CHUNK_SIZE) {
      chunkInputs.push({
        chunkIndex: Math.floor(i / CHUNK_SIZE),
        texts: texts.slice(i, i + CHUNK_SIZE),
        speakers: speakersInBatch?.slice(i, i + CHUNK_SIZE) || [],
        hooks: hooksInBatch?.slice(i, i + CHUNK_SIZE) || [],
        durations: durationsInBatch?.slice(i, i + CHUNK_SIZE) || [],
        emotions: emotionsInBatch?.slice(i, i + CHUNK_SIZE) || [],
      });
    }

    // Process chunks concurrently with bounded concurrency pool (DEFAULT_CONCURRENCY = 3)
    const chunkResults = await mapConcurrent(chunkInputs, DEFAULT_CONCURRENCY, async (chunkInput) => {
      // Inject speaker persona context if available
      let personaContext = "";
      if (speakerProfiles && chunkInput.speakers.length > 0) {
        const uniqueSpeakers = Array.from(new Set(chunkInput.speakers.filter(Boolean)));
        const relevantProfiles = speakerProfiles.filter((p) => uniqueSpeakers.includes(p.speakerId));
        if (relevantProfiles.length > 0) {
          personaContext = "\nSpeaker Personas for this batch:\n" + 
            relevantProfiles.map((p) => `- ${p.speakerId}: ${p.ageTone} ${p.energy} energy, ${p.style} style`).join("\n");
        }
      }

      // Inject Creator DNA if available
      let dnaContext = "";
      if (creatorDNA) {
        dnaContext = `\nCreator DNA Style Memory:\n- Overall Vibe: ${creatorDNA.vibe}\n- Slang Tolerance: ${creatorDNA.slangTolerance}\n- Vocab Preference: ${creatorDNA.vocabPreference}`;
        if (creatorDNA.customInstructions) dnaContext += `\n- Extra Instructions: ${creatorDNA.customInstructions}`;
      }

      // Structured segment input with language-calibrated syllable budgeting, acoustic counts, and audio dubbing pacing limits
      const tgtLangKey = targetLanguage.toLowerCase().split(/[-_]/)[0];
      const srcLangKey = sourceLanguage.toLowerCase().split(/[-_]/)[0];
      const tgtRatio = LANG_SYLLABLE_RATIOS[tgtLangKey] ?? 1.2;
      const srcRatio = LANG_SYLLABLE_RATIOS[srcLangKey] ?? 1.1;

      const segmentsPromptData = chunkInput.texts.map((t, idx) => {
        const durMs = chunkInput.durations[idx];
        const durSec = durMs && durMs > 0 ? (durMs / 1000) : null;
        // Natural speech rate: ~2.8 words/second maximum for clear articulation
        const maxWords = durSec ? Math.max(3, Math.ceil(durSec * 2.8)) : null;
        const sourceSyllableCount = Math.max(1, countSourceSyllables(t, sourceLanguage));
        // Language-calibrated target syllable budget: scales natural speech rate (~3.8 syl/s) or source ratio
        const targetSyllableBudget = durSec
          ? Math.max(4, Math.round(durSec * 3.8 * Math.min(1.35, Math.max(0.85, tgtRatio))))
          : Math.max(4, Math.round(sourceSyllableCount * (tgtRatio / Math.max(0.7, srcRatio)) * 1.15));

        return {
          segmentIndex: idx,
          text: t,
          isHook: Boolean(chunkInput.hooks[idx]),
          speaker: chunkInput.speakers[idx] || undefined,
          emotionTag: chunkInput.emotions[idx] || undefined,
          sourceSyllableCount,
          targetSyllableBudget,
          ...(durSec ? { durationSeconds: Number(durSec.toFixed(2)), maxWords } : {}),
        };
      });

      const isAudioTrack = dubbingTier === "audio_track" || !dubbingTier;

      const cadenceLockPrompt = isAudioTrack
        ? `\n\n*** CREATOR VOICE CLONING VISEME CADENCE HARMONY (GEMINI 2.5 FLASH) ***
- This audio track is undergoing voice cloning via ElevenLabs v4 with Anti-Uncanny Viseme Cadence Locking.
- STRICT VISEME DURATION & MOUTH-CLOSURE CONSTRAINT: Match the speaker's on-screen pacing within +/- 5% of durationSeconds.
- PREVENT VOCAL OVERHANG: Spoken delivery must stop before or exactly when the speaker's mouth closes (utterance.end). The translated phrase MUST NOT exceed targetSyllableBudget.
- NATURAL PAUSE CADENCE: Align translated sentence pauses with the original speaker's breath and pauses so speech cadence feels visually harmonious with the creator's natural body language without audio-visual mismatch.`
        : `\n\n*** NATURAL CREATOR CONVERSATIONAL SPEECH (GEMINI 2.5 FLASH) ***
- Deliver lively, natural conversational dialogue. Avoid archaic, literary, or textbook translations. Use modern creator phrasing.`;

      const prompt = `Translate the following ${sourceLanguage} text segments to ${targetLanguage}.
Tone: ${tone}
Style Preference: ${localeStyle}
Target Platform: ${targetPlatform}${personaContext}${dnaContext}${cadenceLockPrompt}

Special Rules for World-Class Localization:
1. Preserve Brand Names & Tech Entities: Keep brand names and technical terms in English or accurate phonetic transliteration (e.g., Anthropic, Claude, Figma, Adobe, Gemini, ChatGPT, API, UI, GPU).
2. Audience & Regional Dialect Adaptation:
   - Telugu (te): Speak like a contemporary YouTube/podcast creator from Hyderabad or AP. Use conversational Telugu naturally blended with familiar English creator/tech terminology ("scene", "concept", "clarity", "point", "bro", "super hit", "content", "feel"). Absolutely avoid archaic literary Telugu or Sanskrit compounds (e.g. use "clarity vachindi" or "clear ga undi" instead of archaic "spashtata labhinchindi").
   - Hindi (hi): Blend natural urban Hinglish. Use conversational vocabulary ("vibe", "scene", "next level", "tension mat lo", "solid logic") unless formal tone is strictly requested.
   - Tamil (ta): Speak like a contemporary Chennai social media creator. Blend popular conversational vernacular ("pakka", "semma", "mass", "clarity", "concept"). Avoid archaic classical Tamil in dubbing.
   - Kannada (kn): Use lively Bengaluru creator conversational style ("sakkath", "chindi", "concept"), blending modern tech words.
   - Malayalam (ml): Use vibrant Kerala creator conversational Malayalam ("poli", "kidu", "scene").
   - Spanish (es): Use clean, expressive Latin American creator Spanish, avoiding stiff peninsular archaisms.
   - If Style Preference is 'hinglish', use natural code-switching.
   - If 'hinglish_urban', use Gen-Z slang and very casual Mumbai/Delhi urban Hinglish.
   - If 'hinglish_professional', use a sophisticated Bangalore/Corporate Hinglish (mix of English professional terms with formal Hindi structure).
3. Idiomatic Transcreation (No Literal Word-for-Word Metaphors):
   - NEVER translate idioms, colloquial metaphors, or comedic punchlines word-for-word (e.g. "bite the bullet", "cost an arm and a leg", "hit the nail on the head", "piece of cake", "game changer", "touch grass", "spill the beans").
   - Transcreate the true emotional intent and punchline into the equivalent native cultural saying or punchy conversational phrase.
4. Syllable Budgeting, Phonetic Difficulty Avoidance & Audio Timing Constraints:
   - Each segment provides 'sourceSyllableCount' and a language-calibrated 'targetSyllableBudget' (based on target expansion ratio ${tgtRatio.toFixed(2)} vs source ${srcRatio.toFixed(2)}).
   - The spoken syllable count of the translated text MUST NOT exceed 'targetSyllableBudget'.
   - In polysyllabic/agglutinative languages (Telugu, Tamil, Kannada, Malayalam, German, Japanese), select concise conversational phrases rather than verbose compound words so speech fits the original video cut cleanly.
   - Phonetic Difficulty Avoidance for TTS Clarity: avoid dense consonant clusters, tongue-twister alliterations, or unnaturally long agglutinative compounds when speaking duration is tight (< 2.5s); prefer crisp vowel-balanced natural spoken phrasing.
5. Platform Optimization:
   - If Target Platform is 'reels' or 'shorts', keep hooks fast-paced, high emotion, and catchy.
   - If 'linkedin', ensure the first few segments sound authoritative and deliver a punchy insight.
6. Expressive ElevenLabs v4 Prosody & Performance Audio Tags (Critical for Dubbing):
   - When an input segment specifies an "emotionTag" (e.g., "whispers", "shouts", "laughs", "sighs", "gasps", "excited", "sorrowful", "angry", "calm", "serious"), preserve or prepend that exact bracketed English tag (e.g. "[whispers] ...") inside the translated string so the ElevenLabs v4 voice actor performs with matching vocal emotion. NEVER translate the English keyword inside [...] brackets.
7. A/B Hook Generation: If 'isHook' is true AND enableABHooks is true, return 3 variants in the "variants" object:
   - viral: High-energy, catchy, slang-friendly.
   - safe: Reliable, standard translation.
   - professional: Authoritative, formal.
8. Return a JSON object with:
   - translations: array of strings matching input length exactly (${chunkInput.texts.length} items)
   - confidences: array of numbers (0.0 to 1.0)
   - variants: array of objects (one per segment, null if no variants)

Input Segments:
${JSON.stringify(segmentsPromptData, null, 2)}`;

      const result = await withTransientRetry(async () => {
        return await model.generateContent(prompt);
      }, { maxAttempts: 3, label: `Gemini premium translation chunk ${chunkInput.chunkIndex}` });

      const responseText = extractCandidateText(result.response.candidates?.[0]) || result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      
      let parsed: any = null;
      try {
        const clean = responseText.trim().replace(/^```(?:json)?\s*/i, "").replace(/```$/i, "").trim();
        parsed = JSON.parse(clean);
      } catch (parseErr) {
        // Defensive fallback: attempt regex extraction
        const jsonMatch = responseText.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          try {
            parsed = JSON.parse(jsonMatch[0]);
          } catch (_) {}
        }
      }

      const chunkTranslations: string[] = [];
      const chunkConfidences: number[] = [];
      const chunkVariants: any[] = [];

      for (let i = 0; i < chunkInput.texts.length; i++) {
        const rawTranslated = parsed?.translations?.[i] || chunkInput.texts[i];
        chunkTranslations.push(decodeHtmlEntities(rawTranslated));
        chunkConfidences.push(typeof parsed?.confidences?.[i] === "number" ? parsed.confidences[i] : 0.95);
        chunkVariants.push(parsed?.variants?.[i] || null);
      }

      return {
        chunkIndex: chunkInput.chunkIndex,
        translations: chunkTranslations,
        confidences: chunkConfidences,
        variants: chunkVariants,
      };
    });

    // Reassemble ordered results
    chunkResults.sort((a, b) => a.chunkIndex - b.chunkIndex);

    const allTranslations: string[] = [];
    const allConfidences: number[] = [];
    const allVariants: any[] = [];

    for (const res of chunkResults) {
      allTranslations.push(...res.translations);
      allConfidences.push(...res.confidences);
      allVariants.push(...res.variants);
    }

    return { translations: allTranslations, confidences: allConfidences, variants: allVariants };
  }
}

export const translationService = new TranslationService();
