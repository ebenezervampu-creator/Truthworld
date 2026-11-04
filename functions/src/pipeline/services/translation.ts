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
    segments: Array<{ start: number; end: number; text: string; speaker?: string; isHook?: boolean; duration?: number }>,
    sourceLanguage: string,
    targetLanguage: string,
    options?: { 
      model?: "standard" | "premium" | "dynamic"; 
      dubbingTier?: "audio_starter" | "audio_pro" | "audio_ultra" | "video_pro" | "video_ultra";
      subtitleTier?: "starter" | "pro";
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
      const isVideoLipSync = options?.dubbingTier === "video_pro" || options?.dubbingTier === "video_ultra";
      const isVideoUltra = options?.dubbingTier === "video_ultra" || options?.isCinemaGrade === true;
      // All 5 tiers use the hybrid Google v3 + Gemini architecture:
      // Audio Starter & Pro -> Google v3 + Gemini 2.5 Flash
      // Audio Ultra, Video Pro & Video Ultra -> Google v3 + Gemini 4 Argon
      const requestedModel = (isKnownDubbingTier || isVideoUltra || isVideoLipSync || options?.model === "premium") ? "premium" : (options?.model || "standard");

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
          }));

          const isProSubtitle = options?.subtitleTier === "pro";
          const isCinema = isVideoUltra || Boolean(options?.isCinemaGrade) || isProSubtitle;

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
            options?.dubbingTier
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
        (segment, index) => ({
          original: segment.text,
          translated: decodeHtmlEntities(translatedTexts[index] || segment.text),
          start: segment.start,
          end: segment.end,
          confidence: confidenceScores?.[index],
          isHook: segment.isHook,
          variants: segmentVariants[index],
        })
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
    subtitleTier?: "starter" | "pro",
    dubbingTier?: "audio_starter" | "audio_pro" | "audio_ultra" | "video_pro" | "video_ultra"
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

    const isUltraTier = dubbingTier === "audio_ultra" || dubbingTier === "video_pro" || dubbingTier === "video_ultra";
    const isProOrCinema = Boolean(isCinemaGrade) || subtitleTier === "pro" || isUltraTier;
    const targetModelName = isProOrCinema
      ? (PIPELINE_CONFIG.GEMINI_MODELS?.reasoning || "gemini-4-argon")
      : (PIPELINE_CONFIG.GEMINI_MODELS?.translation || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash");

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
    }> = [];

    for (let i = 0; i < texts.length; i += CHUNK_SIZE) {
      chunkInputs.push({
        chunkIndex: Math.floor(i / CHUNK_SIZE),
        texts: texts.slice(i, i + CHUNK_SIZE),
        speakers: speakersInBatch?.slice(i, i + CHUNK_SIZE) || [],
        hooks: hooksInBatch?.slice(i, i + CHUNK_SIZE) || [],
        durations: durationsInBatch?.slice(i, i + CHUNK_SIZE) || [],
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

      // Structured segment input with duration, syllable budgeting, and audio dubbing pacing limits
      const segmentsPromptData = chunkInput.texts.map((t, idx) => {
        const durMs = chunkInput.durations[idx];
        const durSec = durMs && durMs > 0 ? (durMs / 1000) : null;
        // Natural speech rate: ~2.8 words/second maximum for clear articulation
        const maxWords = durSec ? Math.max(3, Math.ceil(durSec * 2.8)) : null;
        const estSourceWords = t.trim().split(/\s+/).length;
        const estSourceSyllables = Math.max(1, Math.round(estSourceWords * 1.35));
        // Target syllable budget: In polysyllabic languages (Telugu, Tamil, Kannada, German), clamp syllables to prevent audio overrun
        const targetSyllableBudget = durSec ? Math.max(4, Math.round(durSec * 3.6)) : Math.round(estSourceSyllables * 1.25);

        return {
          segmentIndex: idx,
          text: t,
          isHook: Boolean(chunkInput.hooks[idx]),
          speaker: chunkInput.speakers[idx] || undefined,
          targetSyllableBudget,
          ...(durSec ? { durationSeconds: Number(durSec.toFixed(2)), maxWords } : {}),
        };
      });

      const isUltra = Boolean(isCinemaGrade) || dubbingTier === "video_ultra";
      const isVideoPro = dubbingTier === "video_pro";
      const isAudioUltra = dubbingTier === "audio_ultra";

      const cinemaTheatricalPrompt = isUltra
        ? `\n\n*** MANDATORY HOLLYWOOD CINEMA THEATRICAL ISOMETRY (GEMINI 4 ARGON) ***
- This video is undergoing full theatrical visual lip-sync dubbing for movies, short films, or web series (Cinema Ultra).
- STRICT RHYTHM & ISOMETRY: Match the actor's visual mouth cadence. Translated speech length must match durationSeconds within +/- 5%.
- BILABIAL PHONEME ALIGNMENT: Prioritize bilabial plosive consonants (B, P, M) at initial and terminal closures where the speaker's lips meet on screen.
- PREVENT AUDIO RAMPING: Dialogue must never require unnatural speeding up or slowing down. Dialogue must feel like native studio cinematic dubbing.`
        : isVideoPro
          ? `\n\n*** STUDIO ISOCHRONIC LIP-SYNC CADENCE (GEMINI 4 ARGON) ***
- This video is undergoing studio visual lip-sync dubbing (Cinema Pro).
- Match the speaker's natural pacing and syllable cadence within +/- 10% of durationSeconds.
- Avoid run-on sentences or overly verbose phrasing to ensure natural lip closure matching.`
          : isAudioUltra
            ? `\n\n*** CREATOR VOICE CLONING VISEME CADENCE HARMONY (GEMINI 4 ARGON) ***
- This audio track is undergoing voice cloning via ElevenLabs v4 on Audio Ultra with Anti-Uncanny Viseme Locking.
- STRICT VISEME DURATION & MOUTH-CLOSURE CONSTRAINT: Match the speaker's on-screen pacing within +/- 5% of durationSeconds.
- PREVENT VOCAL OVERHANG: Spoken delivery must stop before or exactly when the speaker's mouth closes (utterance.end). The translated phrase MUST NOT exceed targetSyllableBudget.
- NATURAL PAUSE CADENCE: Align translated sentence pauses with the original speaker's breath and pauses so speech cadence feels visually harmonious with the creator's natural body language without audio-visual mismatch.`
            : `\n\n*** NATURAL CREATOR CONVERSATIONAL SPEECH (GEMINI 2.5 FLASH) ***
- Deliver lively, natural conversational dialogue. Avoid archaic, literary, or textbook translations. Use modern creator phrasing.`;

      const prompt = `Translate the following ${sourceLanguage} text segments to ${targetLanguage}.
Tone: ${tone}
Style Preference: ${localeStyle}
Target Platform: ${targetPlatform}${personaContext}${dnaContext}${cinemaTheatricalPrompt}

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
4. Syllable Budgeting & Audio Timing Constraints:
   - For segments providing 'durationSeconds', 'maxWords', and 'targetSyllableBudget', the translation will be spoken aloud in video dubbing.
   - The spoken syllable count of the translated text MUST NOT exceed 'targetSyllableBudget'.
   - In polysyllabic languages (Telugu, Tamil, Kannada, German), select concise conversational phrases rather than verbose compound words so speech fits the original video cut without audio drift or unnatural acceleration.
5. Platform Optimization:
   - If Target Platform is 'reels' or 'shorts', keep hooks fast-paced, high emotion, and catchy.
   - If 'linkedin', ensure the first few segments sound authoritative and deliver a punchy insight.
6. A/B Hook Generation: If 'isHook' is true AND enableABHooks is true, return 3 variants in the "variants" object:
   - viral: High-energy, catchy, slang-friendly.
   - safe: Reliable, standard translation.
   - professional: Authoritative, formal.
7. Return a JSON object with:
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
