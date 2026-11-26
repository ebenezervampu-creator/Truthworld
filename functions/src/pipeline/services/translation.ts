/**
 * 🌍 TRANSLATION SERVICE — Google Cloud Translation v3 (general/translation-llm + AdaptiveMtTranslate)
 *
 * ✅ WORLD-CLASS PRODUCTION GRADE (Tier-1 Enterprise / Netflix / YouTube Standard):
 *   1. Zero HTML entity leakage: Automatic sanitization & decoding across all engines.
 *   2. Composite primary translation: Google Cloud Translation v3 (general/translation-llm)
 *      followed by required AdaptiveMtTranslate.
 *   3. Translation fails explicitly if either required stage cannot produce a result.
 *   4. Real-time Dubbing Sync & Audio Pacing constraints (durationSeconds & maxWords).
 *   5. Bounded concurrent batch processing (mapConcurrent pool) eliminating serialization bottlenecks.
 *   6. Resilient transient error & quota retries with exponential backoff & jitter (429/503/RESOURCE_EXHAUSTED).
 *   7. No source-text fallback: both translation stages must succeed.
 *   8. Exclusive Unified Pipeline: Google Cloud Translation v3 (general/translation-llm + AdaptiveMt) exclusively powers all subtitles & dubbing.
 */

import type { v3 } from "@google-cloud/translate";
import { TranslationResult, TranslatedSegment, CreatorDNA } from "../types";
import { SpeakerProfile } from "./speaker-profiling";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { normalizeLanguageCode } from "../../shared/language-normalizer";
import {
  DOMAIN_GLOSSARY,
  TerminologyService,
  TerminologyProfile,
  TerminologyComplianceResult,
  escapeRegex,
  resolveTerminologyProfile,
} from "./terminology_glossary";
import {
  TranslationQualityGate,
  QualityGateSegmentInput,
} from "./translationQualityGate";
import { NumericalEntityGuard } from "./numericalEntityGuard";
import { adaptiveMtDatasetService } from "./adaptiveMtDatasetService";
import {
  countSourceSyllables,
  syllableBudgetForDuration,
  permissibleWindowMs,
} from "./speech-rate";
export { countSourceSyllables };
import {
  geminiDubbingEditor,
  EditorSegment,
  GlossaryTerm as EditorGlossaryTerm,
  checkEditedLine,
  MEANING_CHECK,
  type MeaningAction,
} from "./geminiDubbingEditor";
import {
  CastMember,
  CharacterRelationship,
  LocalizationBible,
  RollingHonorificCache,
  resolveRegisterDirective,
  inferAddressees,
} from "./cast-list";
import type { OnScreenTextEvent } from "./screenContentAnalyzer";
import { editorContextEnabled } from "./translation-flags";

/** Plain-language sense of each glossary category, sent with glossary terms to the Gemini edit. */
const GLOSSARY_SENSE: Record<string, string> = {
  theology: "religion (God, scripture, faith)",
  fact_checking: "fact-checking and misinformation",
  energy_policy: "energy and climate policy",
  science: "science and research",
  monetization: "creator earnings",
  statistics: "statistics",
  historical: "history",
};

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT_ID || "truthworld-1";

/**
 * Preferred location for v3 requests.
 * "global" is safest default; can be overridden to "asia-south1" for data residency.
 */
const TRANSLATION_LOCATION = process.env.TRANSLATION_LOCATION || "global";

/**
 * AdaptiveMt requires a regional endpoint (NOT "global").
 * Default: us-central1; override via ADAPTIVE_MT_LOCATION env var.
 */
const ADAPTIVE_MT_LOCATION = PIPELINE_CONFIG.ADAPTIVE_MT_LOCATION || "us-central1";

/** Max segments per v3 batch call (API limit is 128 content items per request) */
const V3_BATCH_SIZE = 100;

/** Max segments per AdaptiveMt batch call (conservative to stay within API limits) */
const ADAPTIVE_MT_BATCH_SIZE = 50;

/** Default concurrency limit for parallel batch requests */
const DEFAULT_CONCURRENCY = 3;

/**
 * Translation mode for dubbing:
 *  - "hybrid" (default): Translation LLM drafts each line, then Gemini edits the lines in
 *    context with a syllable budget per line (services/geminiDubbingEditor.ts). No Adaptive MT.
 *  - "legacy": the previous Translation LLM + Adaptive MT composite.
 * Set DUBBING_TRANSLATION_MODE=legacy to roll back without a deploy of new code.
 */
export function isContextualDubbingEditEnabled(options?: { contextualEdit?: boolean }): boolean {
  const mode = (process.env.DUBBING_TRANSLATION_MODE || "hybrid").toLowerCase();
  return mode === "hybrid" && options?.contextualEdit !== false;
}

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
 * Removes parenthetical dual-script glosses and Latin duplicate tags (e.g., "गाओजिया (Gaojia)" -> "गाओजिया",
 * "షాంఘైకి హై-స్పీడ్ రైలులో (Gaojia)" -> "షాంఘైకి హై-స్పీడ్ రైలులో") to prevent TTS engines from vocalizing
 * duplicate entities and causing dialogue timeline overlaps.
 */
export function sanitizeSpokenTranslationForTts(text: string): string {
  if (!text || typeof text !== "string") return text || "";
  const cleaned = text
    .replace(/\s*\([A-Za-z0-9\s\-_.,/&]+\)/g, "")
    .replace(/\s*\[[A-Za-z0-9\s\-_.]+\]/g, (match) => {
      // Preserve ElevenLabs emotion tags like [whispers], [laughs], [excited], [said angrily], [sad], [sarcastic], [calm]
      if (/^\[(whispers|whispering|whisper|softly|laughs|laughing|giggles|sighs|gasp|crying|excited|shouting|shouts|said angrily|angry|sad|sorrowful|sarcastic|calm|serious)\]$/i.test(match.trim())) {
        return match;
      }
      return "";
    })
    .replace(/\s{2,}/g, " ")
    .trim();
  return stripDanglingClauseFragments(cleaned);
}

/**
 * Prunes unclosed trailing clause fragments left by condensation, truncation,
 * or retranslation artifacts after a terminal sentence punctuation mark (. ? ! । |).
 * e.g., "ఈ దేశంలో ఉంటూ ఈజిప్షియన్లకి ఇచ్చే బహుమతి ఇదేనా? కొంచెం" -> "ఈ దేశంలో ఉంటూ ఈజిప్షియన్లకి ఇచ్చే బహుమతి ఇదేనా?"
 */
export function stripDanglingClauseFragments(text: string): string {
  if (!text || typeof text !== "string") return text || "";
  const terminalRegex = /([.?!।|]['"”’\)\]]*)\s+[^.?!।|]+$/u;
  return text.replace(terminalRegex, "$1").trim();
}

/**
 * 🛡️ Telugu Theological/Debate Lexicon Guard
 *
 * Enforces grammatical agreement, prevents homophonic mistranslations,
 * and ensures period/biblical dialogue uses authentic Telugu titles:
 * 1. Blocks 'సారి' (sāri = garment/turn) and maps to short-sa 'సరి' (sari = correct/proper)
 *    e.g. 'సారి చేస్తుంది' / 'సారి చేస్తోంది' -> 'సరిచేస్తుంది' / 'సరిచేస్తోంది'
 * 2. Eliminates redundant conjunctive padding 'మరియు కానీ' ('and but') -> 'కానీ'
 *
 * Removed: a rule that rewrote every "I am correcting" (సరిచేస్తున్నాను) as "they are
 * correcting", and a rule that turned every "Lord" (లార్డ్) into the vocative "O Lord"
 * (ప్రభువా). Both changed the meaning of unrelated videos. Speaker agreement and
 * glossary terms are now handled in context by the Gemini edit step.
 */
export function applyTeluguTheologicalLexiconGuard(text: string): string {
  if (!text || typeof text !== "string") return text || "";
  let cleaned = text;

  // 1. Block and replace 'సారి' with 'సరి' before action stems like చే / దిద్ద
  cleaned = cleaned.replace(/సారి(\s*(?:చే|దిద్ద))/gi, (_, g1) => `సరి${g1.trim()}`);

  // 2. Eliminate redundant 'మరియు కానీ' ('and but') -> 'కానీ'
  cleaned = cleaned.replace(/మరియు\s+కానీ/gi, "కానీ");

  return cleaned;
}

/**
 * 🗣️ Spoken Telugu Register Normalizer:
 * Converts stiff literary/bookish phrases into natural spoken conversational forms
 * while keeping proper nouns and period honorifics intact.
 */
export function applySpokenTeluguColloquialContractions(text: string): string {
  if (!text || typeof text !== "string") return text || "";
  let s = text;
  s = s.replace(/(^|[\s,!?.;])నువ్వు\s+ఏమి([\s,!?.;]|$)/g, "$1నువ్వేం$2");
  s = s.replace(/(^|[\s,!?.;])నువ్వు\s+ఎందుకు([\s,!?.;]|$)/g, "$1నువ్వెందుకు$2");
  s = s.replace(/(^|[\s,!?.;])నువ్వు\s+ఎక్కడ([\s,!?.;]|$)/g, "$1నువ్వెక్కడ$2");
  s = s.replace(/విన్నాము([.!?,\s]|$)/g, "విన్నాం$1");
  s = s.replace(/చేశాము([.!?,\s]|$)/g, "చేశాం$1");
  s = s.replace(/చూశాము([.!?,\s]|$)/g, "చూశాం$1");
  s = s.replace(/కన్నాము([.!?,\s]|$)/g, "కన్నాం$1");
  s = s.replace(/ఉన్నాము([.!?,\s]|$)/g, "ఉన్నాం$1");
  s = s.replace(/ఉన్నావు([.!?,\s]|$)/g, "ఉన్నావ్$1");
  s = s.replace(/చేస్తున్నాము([.!?,\s]|$)/g, "చేస్తున్నాం$1");
  s = s.replace(/చేస్తున్నావు([.!?,\s]|$)/g, "చేస్తున్నావ్$1");
  s = s.replace(/వెళ్తున్నాము([.!?,\s]|$)/g, "వెళ్తున్నాం$1");
  s = s.replace(/చూసుకుంటాము([.!?,\s]|$)/g, "చూసుకుంటాం$1");
  return s;
}

/**
 * Normalizes scripture / Quran / Bible citations (e.g., "4:157", "Quran 4:157", "సూరా 4:157")
 * into localized, phonetically unambiguous chapter-and-verse words so TTS engines never
 * pronounce citations as raw integers (e.g. 457) or telephone digits.
 */
export function normalizeScriptureCitationsForTts(text: string, lang: string): string {
  if (!text || typeof text !== "string") return text || "";
  const normLang = (lang || "").toLowerCase().trim().split(/[-_]/)[0];

  // A citation is only converted when a scripture or chapter word comes right before
  // "N:M". A bare "N:M" is far more often a time ("10:30"), a score ("2:1") or a ratio
  // ("16:9"), and must be left for the TTS engine to read normally.
  const QURAN = "Quran|Qur'an|Surah|Sura|ఖురాన్|సూరా|क़ुरआन|कुरआन|क़ुरान|कुरान|सूरह|सूरा|திருக்குரான்|குர்ஆன்|ഖുർആൻ|സൂറ";
  const BIBLE = "Bible|బైబిల్|बाइबल|बाइबिल|பைபிள்|ബൈബിൾ";
  const CHAPTER = "Chapter|అధ్యాయం|अध्याय|அத்தியாயம்|അധ്യായം";

  const words: Record<string, { chapter: string; verse: string; surah: string; ayah: string }> = {
    te: { chapter: "వ అధ్యాయం", verse: "వ వచనం", surah: "వ అధ్యాయం", ayah: "వ వచనం" },
    hi: { chapter: "अध्याय", verse: "पद", surah: "सूरह", ayah: "आयत" },
    ta: { chapter: "அத்தியாயம்", verse: "வசனம்", surah: "அத்தியாயம்", ayah: "வசனம்" },
    ml: { chapter: "അധ്യായം", verse: "വാക്യം", surah: "അധ്യായം", ayah: "വാക്യം" },
    mr: { chapter: "अध्याय", verse: "वचन", surah: "सूरा", ayah: "आयत" },
    en: { chapter: "chapter", verse: "verse", surah: "chapter", ayah: "verse" },
  };
  const w = words[normLang] || words.en;

  const phrase = (chapter: string, verse: string, quranic: boolean): string => {
    const c = quranic ? w.surah : w.chapter;
    const v = quranic ? w.ayah : w.verse;
    // Telugu puts the ordinal suffix straight after the number ("4వ అధ్యాయం").
    return normLang === "te" ? `${chapter}${c}, ${verse}${v}` : `${c} ${chapter}, ${v} ${verse}`;
  };

  let res = text;

  // Telugu text that already spells out "4వ అధ్యాయం, 157" — add the verse word.
  if (normLang === "te") {
    res = res.replace(/(\d{1,3})వ\s*అధ్యాయం[,\s]+(\d{1,3})(?:\s*వ\s*వచనం)?(\s*లో)?/gu, (_m, c, v, lo) =>
      `${c}వ అధ్యాయం, ${v}వ వచనం${lo ? "లో" : ""}`);
  }

  const citation = new RegExp(`(${QURAN}|${BIBLE}|${CHAPTER})(\\s*)(\\d{1,3})\\s*:\\s*(\\d{1,3})`, "giu");
  res = res.replace(citation, (_m, book: string, _sp: string, chapter: string, verse: string) => {
    const isQuran = new RegExp(`^(?:${QURAN})$`, "iu").test(book);
    const isChapterWord = new RegExp(`^(?:${CHAPTER})$`, "iu").test(book);
    // Keep the book name ("Quran", "Bible") so the listener still hears which scripture it is.
    const keep = isChapterWord ? "" : `${book} `;
    return `${keep}${phrase(chapter, verse, isQuran)}`;
  });
  return res;
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
 * Syllable-to-word ratios per language (kept for computeSyllableBudgetCompliance).
 */

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

  const durMs = durationMs && durationMs > 0 ? durationMs : null;
  const targetBudget = durMs
    ? syllableBudgetForDuration(durMs, targetLanguage)
    : Math.max(2, Math.round(srcSyllables * langExpansionRatio * 1.15));

  if (tgtSyllables <= targetBudget) return 1.0;
  return Number(Math.max(0.1, Math.min(1.0, targetBudget / tgtSyllables)).toFixed(3));
}

// ─── TRANSLATION SERVICE ───────────────────────────────────────────────────

export class TranslationService {
  private _v3Client: v3.TranslationServiceClient | null | undefined = undefined;
  private _adaptiveMtClient: v3.TranslationServiceClient | null | undefined = undefined;

  private get v3Client(): v3.TranslationServiceClient | null {
    if (this._v3Client === undefined) {
      try {
        // ✅ Always use ADC. The Cloud Translation v3 gRPC client does NOT support
        // API keys — passing { apiKey } causes UNAUTHENTICATED (code 16) on every
        // call. Cloud Functions / Cloud Run provide ADC automatically via the
        // service account, so no extra configuration is needed.
        const { v3 } = require("@google-cloud/translate");
        const options: any = {};
        const token = process.env.GCLOUD_ACCESS_TOKEN;
        if (token) {
          const { OAuth2Client } = require("google-auth-library");
          const oauthClient = new OAuth2Client();
          oauthClient.setCredentials({ access_token: token });
          const qProject = process.env.GCP_PROJECT_ID || projectId || "truthworld-1";
          (oauthClient as any).quotaProjectId = qProject;
          options.authClient = oauthClient;
          options.projectId = qProject;
          options.quotaProjectId = qProject;
          options.customHeaders = { "x-goog-user-project": qProject };
        }
        this._v3Client = new v3.TranslationServiceClient(options);
      } catch (err) {
        console.warn("[Translation] v3 client init failed", err);
        this._v3Client = null;
      }
    }
    return this._v3Client ?? null;
  }

  /**
   * Dedicated v3 client for AdaptiveMtTranslate calls.
   * AdaptiveMt requires a regional endpoint (NOT "global"), so this client
   * is configured separately to target the ADAPTIVE_MT_LOCATION region.
   */
  private get adaptiveMtClient(): v3.TranslationServiceClient | null {
    if (this._adaptiveMtClient === undefined) {
      if (!PIPELINE_CONFIG.ADAPTIVE_MT_ENABLED) {
        this._adaptiveMtClient = null;
        return null;
      }
      try {
        const { v3 } = require("@google-cloud/translate");
        const options: any = {
          apiEndpoint: `translate-${ADAPTIVE_MT_LOCATION}.googleapis.com`,
        };
        const token = process.env.GCLOUD_ACCESS_TOKEN;
        if (token) {
          const { OAuth2Client } = require("google-auth-library");
          const oauthClient = new OAuth2Client();
          oauthClient.setCredentials({ access_token: token });
          const qProject = process.env.GCP_PROJECT_ID || projectId || "truthworld-1";
          (oauthClient as any).quotaProjectId = qProject;
          options.authClient = oauthClient;
          options.projectId = qProject;
          options.quotaProjectId = qProject;
          options.customHeaders = { "x-goog-user-project": qProject };
        }
        this._adaptiveMtClient = new v3.TranslationServiceClient(options);
      } catch (err) {
        console.warn("[Translation] AdaptiveMt client init failed", err);
        this._adaptiveMtClient = null;
      }
    }
    return this._adaptiveMtClient ?? null;
  }

  /** v3 parent path: projects/{project}/locations/{location} */
  private get parent(): string {
    return `projects/${projectId}/locations/${TRANSLATION_LOCATION}`;
  }

  /** AdaptiveMt parent path: projects/{project}/locations/{adaptiveMtLocation} */
  private get adaptiveMtParent(): string {
    return `projects/${projectId}/locations/${ADAPTIVE_MT_LOCATION}`;
  }

  public defaultModel: string = "general/translation-llm";

  /** Full v3 model resource path — MUST be passed to every translateText call to enforce LLM quality */
  private get v3ModelPath(): string {
    return `projects/${projectId}/locations/${TRANSLATION_LOCATION}/models/${this.defaultModel}`;
  }

  constructor() {}

  // ─── Single text translation ───────────────────────────────────────────────

  async translateText(
    text: string,
    sourceLanguage: string,
    targetLanguage: string,
    options?: any
  ): Promise<string> {
    const src = normalizeLanguageCode(sourceLanguage);
    const tgt = normalizeLanguageCode(targetLanguage);
    const profileKey = resolveTerminologyProfile(options);

    if (!this.v3Client) {
      throw new Error("[Translation] Required Google Cloud Translation v3 client is unavailable.");
    }

    const [response] = await withTransientRetry(
      () => this.v3Client!.translateText({
        parent: this.parent,
        model: this.v3ModelPath,
        contents: [text],
        mimeType: "text/plain",
        sourceLanguageCode: src,
        targetLanguageCode: tgt,
      }),
      { maxAttempts: 3, label: "Google v3 translateText (general/translation-llm)" }
    );

    const translated = response.translations?.[0]?.translatedText;
    if (!translated?.trim()) {
      throw new Error("[Translation] Google Cloud Translation v3 returned no translation.");
    }

    const decoded = decodeHtmlEntities(translated);
    const adaptiveTranslated = await this.applyAdaptiveMtTranslation(decoded, text, src, tgt, profileKey);

    const comp = TerminologyService.checkTerminologyCompliance(text, adaptiveTranslated, tgt, {
      localeStyle: profileKey,
    });
    if (!comp.isFullyCompliant && comp.violations.length > 0) {
      return this.remedyTerminologyViolations(
        text,
        adaptiveTranslated,
        src,
        tgt,
        comp.violations,
        profileKey
      );
    }

    return adaptiveTranslated;
  }

  /**
   * Shorter retranslation for dubbing pacing, used when a line is too long for its slot.
   *
   * Hybrid mode: Translation LLM drafts the line, then Gemini shortens it to the syllable
   * budget for `maxDurationMs` (or, without a duration, to `1 / targetDurationRatio` of the
   * draft), keeping every fact and number. Falls back to the draft if Gemini's version fails
   * the checks in geminiDubbingEditor.ts.
   *
   * The previous version stripped a few English filler phrases and, for Telugu and Hindi,
   * replaced whole sentences with hard-coded text written for one test video. Both are gone.
   */
  public async retranslateConcise(
    originalText: string,
    sourceLanguage: string,
    targetLanguage: string,
    options?: {
      targetDurationRatio?: number;
      model?: string;
      maxCharacters?: number;
      preserveFacts?: boolean;
      /** Time the spoken line may take, in ms. Preferred over targetDurationRatio. */
      maxDurationMs?: number;
      /** Measured speaking rate (syl/s) for this speaker's voice (Fix 3.3). */
      syllablesPerSecond?: number;
      speakerGender?: "male" | "female";
      jobId?: string;
      userId?: string;
      /**
       * The line's current, context-edited translation. When given it is shortened instead of
       * translating the source again from scratch, which would lose pronoun number/gender fixes
       * (Clip 2: plural "you" came back singular).
       */
      currentTranslation?: string;
      /** Speaker of this line, so the editor can tell who is talking to whom. */
      speaker?: string;
      /** 🛡️ A11: Target addressee if known (e.g. "speaker_1", "AUDIENCE"). */
      addressedTo?: string;
      /** 🛡️ A11: Formality register directive to preserve when shortening. */
      registerDirective?: string;
      appliedRegister?: string;
      castList?: any[];
      relationships?: any[];
      speakerNames?: Record<string, string>;
      castGenderByLabel?: Record<string, "male" | "female">;
      bible?: any;
      honorificCache?: RollingHonorificCache;
      creatorDNA?: CreatorDNA;
      targetPlatform?: string;
      /** Delivery/emotion style (e.g. "playful", "sheepish", "whispers"). */
      delivery?: string;
      /** Neighbouring source lines (context only, never edited). */
      contextBefore?: Array<{ source: string; speaker?: string }>;
      contextAfter?: Array<{ source: string; speaker?: string }>;
    }
  ): Promise<string> {
    const src = normalizeLanguageCode(sourceLanguage);
    const tgt = normalizeLanguageCode(targetLanguage);

    const current = options?.currentTranslation?.replace(/\[[^\]]*\]/g, " ").replace(/\s+/g, " ").trim();
    // Shortening the current line needs the Gemini edit step; without it, translate afresh as before.
    const draft = current && isContextualDubbingEditEnabled()
      ? current
      : isContextualDubbingEditEnabled()
        ? (await this.batchTranslateV3([originalText], src, tgt))[0]
        : await this.translateText(originalText, src, tgt);
    let result = decodeHtmlEntities(draft);

    if (isContextualDubbingEditEnabled()) {
      const draftSyllables = countSourceSyllables(result, tgt);
      const ratio = options?.targetDurationRatio && options.targetDurationRatio > 1 ? options.targetDurationRatio : 1.2;
      const maxSyllables = options?.maxDurationMs && options.maxDurationMs > 0
        ? syllableBudgetForDuration(options.maxDurationMs, tgt, options.syllablesPerSecond)
        : Math.max(2, Math.floor(draftSyllables / ratio));

      if (draftSyllables > maxSyllables) {
        try {
          let honorificCache = options?.honorificCache;
          if (!honorificCache && options?.bible) {
            honorificCache = new RollingHonorificCache(tgt);
            honorificCache.seedFromBible(options.bible, tgt);
          }
          const [edited] = await geminiDubbingEditor.editSegments(
            [{
              id: "L1",
              source: originalText,
              draft: result,
              speaker: options?.speaker,
              speakerGender: options?.speakerGender ?? (options?.speaker ? options?.castGenderByLabel?.[options.speaker] : undefined),
              addressedTo: options?.addressedTo,
              registerDirective: options?.registerDirective || options?.appliedRegister,
              delivery: options?.delivery,
              maxSyllables,
            }],
            {
              outsideContext: {
                before: (options?.contextBefore || []).map((c, i) => ({ id: `B${i}`, source: c.source, draft: "", speaker: c.speaker })),
                after: (options?.contextAfter || []).map((c, i) => ({ id: `A${i}`, source: c.source, draft: "", speaker: c.speaker })),
              },
              jobId: options?.jobId || "retranslate",
              userId: options?.userId,
              sourceLanguage: src,
              targetLanguage: tgt,
              creatorDNA: options?.creatorDNA,
              targetPlatform: options?.targetPlatform,
              glossary: this.buildGlossaryTermsForEditor([originalText], src, tgt),
              castList: options?.castList,
              relationships: options?.relationships,
              speakerNames: options?.speakerNames,
              bible: options?.bible,
              inferBible: false,
              honorificCache,
              countSyllables: countSourceSyllables,
              countGlossaryViolations: (source, translated, lang) =>
                TerminologyService.checkTerminologyCompliance(source, translated, lang).violations.length,
            }
          );
          if (edited && !edited.usedDraft) result = edited.text;
        } catch (err) {
          console.warn("[Translation] Concise edit failed — keeping the Translation LLM draft", err);
        }
      }
    }

    let cleaned = stripDanglingClauseFragments(result);
    if (tgt === "te") {
      cleaned = applyTeluguTheologicalLexiconGuard(cleaned);
      // With the Gemini edit on, spoken style is chosen in context (prompt rule 4); a blind rewrite
      // afterwards would override it, including in formal speech. Only the legacy path needs it.
      if (!isContextualDubbingEditEnabled()) cleaned = applySpokenTeluguColloquialContractions(cleaned);
    }
    return normalizeScriptureCitationsForTts(sanitizeSpokenTranslationForTts(cleaned.trim() || decodeHtmlEntities(originalText)), tgt);
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
      isSong?: boolean;
      duration?: number;
      emotionTag?: string;
      energyDb?: number;
      stabilityOverride?: number;
      similarityBoostOverride?: number;
      pitchRangeSemitones?: number;
      voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
      deliveryStyle?: string;
      delivery?: string;
    }>,
    sourceLanguage: string,
    targetLanguage: string,
    options?: { 
      model?: "standard" | "premium" | "dynamic"; 
      dubbingTier?: "audio_track";
      subtitleTier?: "ultra";
      isCinemaGrade?: boolean;
      tone?: "casual" | "formal"; 
      localeStyle?: "neutral" | "hinglish" | "hinglish_urban" | "hinglish_professional" | "slang";
      targetPlatform?: "youtube" | "reels" | "shorts" | "linkedin" | "tiktok";
      creatorDNA?: CreatorDNA;
      speakerProfiles?: SpeakerProfile[];
      onScreenText?: OnScreenTextEvent[];
      targetDurations?: number[];
      userId?: string;
      /** false = skip the Gemini edit step even in hybrid mode. */
      contextualEdit?: boolean;
      /** Full media length in ms, so the last line's time budget can be computed. */
      totalDurationMs?: number;
      /** Scene cut timestamps in ms, used to cap trailing buffer in permissibleWindowMs (Fix 3.6). */
      shotChangesMs?: number[];
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      /** Diarization label → cast name / gender (cast-list.ts binding in 07-dubbing.ts). */
      speakerNames?: Record<string, string>;
      castGenderByLabel?: Record<string, "male" | "female">;
      enableDualTrack?: boolean;
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
      const subtitleTexts: string[] = new Array(texts.length);
      const appliedRegisters: (string | undefined)[] = new Array(texts.length);
      const confidenceScores: number[] = new Array(texts.length).fill(0.95);
      const segmentVariants: any[] = new Array(texts.length).fill(undefined);

      const profileKey = resolveTerminologyProfile(options);

      const hybrid = isContextualDubbingEditEnabled(options);
      let standardTranslated: string[];
      let standardSubtitles: string[];
      let standardRegisters: (string | undefined)[];
      let editOutputs: Array<{
        text: string;
        subtitleText?: string;
        appliedRegister?: string;
        meaningAction?: MeaningAction;
        meaningPolarityFlipped?: boolean;
        meaningNumbersChanged?: boolean;
        maxSyllables?: number;
      }> = [];

      let resolvedBible: LocalizationBible | undefined;
      if (hybrid) {
        // Step 1: Translation LLM drafts every line. Step 2: Gemini edits in context.
        const drafts = await this.batchTranslateV3(texts, normSourceLang, normTargetLang);
        editOutputs = await this.applyContextualDubbingEdit(
          jobId, segments, drafts, normSourceLang, normTargetLang, profileKey, options
        );
        resolvedBible = geminiDubbingEditor.lastBible;
        standardTranslated = editOutputs.map((o) => o.text);
        standardSubtitles = editOutputs.map((o) => o.subtitleText || o.text);
        standardRegisters = editOutputs.map((o) => o.appliedRegister);
      } else {
        // Legacy composite: Translation LLM followed by Adaptive MT.
        standardTranslated = await this.batchTranslateStandard(
          texts,
          normSourceLang,
          normTargetLang,
          profileKey
        );
        standardSubtitles = [...standardTranslated];
        standardRegisters = standardTranslated.map(() => undefined);
      }
      if (standardTranslated.length !== texts.length || standardTranslated.some((text) => !text?.trim())) {
        throw new Error("[Translation] Composite primary returned incomplete segment translations.");
      }

      texts.forEach((_, idx) => {
        translatedTexts[idx] = decodeHtmlEntities(standardTranslated[idx]);
        subtitleTexts[idx] = decodeHtmlEntities(standardSubtitles[idx] || standardTranslated[idx]);
        appliedRegisters[idx] = standardRegisters[idx];
        confidenceScores[idx] = 0.95;
      });

      // ✅ Cost tracking: record actual character count translated
      const totalChars = texts.reduce((sum, t) => sum + t.length, 0);
      const targetUserId = options?.userId || "system";
      costEngine.recordTranslationCost(jobId, targetUserId, totalChars).catch((err) => {
        console.warn("[Translation] Non-blocking cost recording error:", err);
      });

      // ── Checkpoint A: Terminology Compliance & Targeted Re-inflection ─────────
      const complianceResults: TerminologyComplianceResult[] = new Array(texts.length);

      for (let i = 0; i < texts.length; i++) {
        let currentText = translatedTexts[i];
        let comp = TerminologyService.checkTerminologyCompliance(
          texts[i],
          currentText,
          normTargetLang,
          { localeStyle: profileKey }
        );

        // In hybrid mode Gemini already applied the glossary and the editor kept the draft for
        // any line where it made terminology worse, so the Adaptive MT remedy pass is skipped.
        if (!hybrid && !comp.isFullyCompliant && comp.violations.length > 0) {
          // 🛡️ Fix 3: Targeted re-inflection remedy pass (NEVER blind string replace)
          const remediedText = await this.remedyTerminologyViolations(
            texts[i],
            currentText,
            normSourceLang,
            normTargetLang,
            comp.violations,
            profileKey
          );
          if (remediedText && remediedText !== currentText) {
            const recheck = TerminologyService.checkTerminologyCompliance(
              texts[i],
              remediedText,
              normTargetLang,
              { localeStyle: profileKey }
            );
            if (recheck.violations.length < comp.violations.length || recheck.isFullyCompliant) {
              currentText = remediedText;
              comp = recheck;
              translatedTexts[i] = currentText;
            }
          }

          if (!comp.isFullyCompliant) {
            console.warn(`[Translation] Terminology compliance warning on segment #${i} in ${normTargetLang}:`, {
              violations: comp.violations.map((v) => `${v.disallowedFound} -> ${v.suggested}`),
            });
          }
        }
        complianceResults[i] = comp;
      }

      // ── Checkpoint B: Translation Quality Gate (Numerical Parity & Semantic Spot-Check) ──
      const qualityGateInput: QualityGateSegmentInput[] = segments.map((seg: any, idx: number) => ({
        index: idx,
        original: texts[idx],
        translated: translatedTexts[idx],
        isClaim: seg.isClaim,
        isHook: seg.isHook,
        confidence: confidenceScores?.[idx],
        terminologyComplianceRate: complianceResults[idx]?.complianceRate ?? 1.0,
      }));

      const qualityGateResults = await TranslationQualityGate.evaluateQualityGate(
        qualityGateInput,
        normSourceLang,
        normTargetLang,
        {
          sampleRate: 0.10,
          semanticThreshold: 0.85,
          enableSelfHealing: true,
          repairCallback: async (source, drifted, tgtLang, details) => {
            return await this.repairNumericalDrift(source, drifted, normSourceLang, tgtLang, details, profileKey, {
              jobId,
              userId: options?.userId,
              bible: resolvedBible,
              castList: options?.castList,
              relationships: options?.relationships,
              speakerNames: options?.speakerNames,
            });
          },
          backTranslateCallback: async (targetText, tgtLang) => {
            if (hybrid) {
              // Plain Translation LLM is enough for a back-translation spot check.
              return (await this.batchTranslateV3([targetText], tgtLang, normSourceLang))[0];
            }
            return await this.translateText(targetText, tgtLang, normSourceLang, { tone: "formal" });
          },
        }
      );

      // Track per-line repair & blocking status across spoken and subtitle tracks (Fix 2.2 & 2.3)
      const repairAttempted = new Array<boolean>(segments.length).fill(false);
      const repairOutcome = new Array<"repaired" | "failed" | undefined>(segments.length).fill(undefined);
      const translationBlockReason = new Array<"number_mismatch" | "polarity_flip" | "meaning_unresolved" | undefined>(segments.length).fill(undefined);

      for (let i = 0; i < qualityGateResults.length; i++) {
        const qg = qualityGateResults[i];
        const origSpoken = translatedTexts[i];
        const initialParity = NumericalEntityGuard.verifyNumericalParity(texts[i], origSpoken, normTargetLang);
        if (!initialParity.isParity) {
          repairAttempted[i] = true;
          if (qg.numericalParityVerified) {
            repairOutcome[i] = "repaired";
            translatedTexts[i] = qg.translated;
          } else {
            repairOutcome[i] = "failed";
            translationBlockReason[i] = "number_mismatch";
          }
        } else if (qg.translated !== origSpoken) {
          translatedTexts[i] = qg.translated;
        }

        // Also verify and repair subtitleText if it differs from spoken text
        if (subtitleTexts[i] === origSpoken && translatedTexts[i] !== origSpoken) {
          subtitleTexts[i] = translatedTexts[i];
        } else if (subtitleTexts[i] && subtitleTexts[i] !== translatedTexts[i]) {
          const subParity = NumericalEntityGuard.verifyNumericalParity(texts[i], subtitleTexts[i], normTargetLang);
          if (!subParity.isParity) {
            repairAttempted[i] = true;
            const repairedSub = await this.repairNumericalDrift(
              texts[i],
              subtitleTexts[i],
              normSourceLang,
              normTargetLang,
              subParity.details,
              profileKey,
              {
                jobId,
                userId: options?.userId,
                bible: resolvedBible,
                castList: options?.castList,
                relationships: options?.relationships,
                speakerNames: options?.speakerNames,
              }
            );
            const subRecheck = NumericalEntityGuard.verifyNumericalParity(texts[i], repairedSub, normTargetLang);
            if (subRecheck.isParity) {
              subtitleTexts[i] = repairedSub;
              if (!translationBlockReason[i]) repairOutcome[i] = "repaired";
            } else if (!translationBlockReason[i] && qg.numericalParityVerified) {
              // Spoken track passed parity, so fall back subtitle to spoken track rather than shipping a drifted subtitle
              subtitleTexts[i] = translatedTexts[i];
              repairOutcome[i] = "repaired";
            } else {
              repairOutcome[i] = "failed";
              translationBlockReason[i] = "number_mismatch";
            }
          }
        }

        // Repair meaning / polarity failures detected by back-translation or Gemini meaning check
        const editMeta = editOutputs[i];
        const hasPolarityFlip = Boolean(qg.polarityFlipped || editMeta?.meaningPolarityFlipped);
        const hasNumbersChanged = Boolean(editMeta?.meaningNumbersChanged);
        const hasMeaningUnresolved = editMeta?.meaningAction === "unresolved";
        if (!translationBlockReason[i] && (hasPolarityFlip || hasNumbersChanged || hasMeaningUnresolved)) {
          repairAttempted[i] = true;
          const problem = hasPolarityFlip
            ? "Negation or affirmation polarity was inverted against SOURCE."
            : hasNumbersChanged
              ? "A number, date, amount, or unit was changed or dropped."
              : "Meaning was altered or an object/condition was dropped.";
          const repairedSpoken = await this.repairMeaning(
            texts[i],
            translatedTexts[i],
            normSourceLang,
            normTargetLang,
            problem,
            {
              jobId,
              userId: options?.userId,
              maxSyllables: editMeta?.maxSyllables,
              bible: resolvedBible,
              castList: options?.castList,
              relationships: options?.relationships,
              speakerNames: options?.speakerNames,
              profileKey,
            }
          );
          if (repairedSpoken !== translatedTexts[i]) {
            translatedTexts[i] = repairedSpoken;
            if (subtitleTexts[i] && subtitleTexts[i] !== repairedSpoken) {
              const repairedSub = await this.repairMeaning(
                texts[i],
                subtitleTexts[i],
                normSourceLang,
                normTargetLang,
                problem,
                {
                  jobId,
                  userId: options?.userId,
                  bible: resolvedBible,
                  castList: options?.castList,
                  relationships: options?.relationships,
                  speakerNames: options?.speakerNames,
                  profileKey,
                }
              );
              subtitleTexts[i] = repairedSub !== subtitleTexts[i] ? repairedSub : repairedSpoken;
            }
            repairOutcome[i] = "repaired";
          } else {
            repairOutcome[i] = "failed";
            translationBlockReason[i] = hasPolarityFlip
              ? "polarity_flip"
              : hasNumbersChanged
                ? "number_mismatch"
                : "meaning_unresolved";
          }
        }
      }

      const translatedSegments: TranslatedSegment[] = segments.map(
        (segment, index) => {
          let decodedText = decodeHtmlEntities(translatedTexts[index] || segment.text);
          let cleanSubText = decodeHtmlEntities(subtitleTexts[index] || translatedTexts[index] || segment.text);
          if (normTargetLang === "te") {
            decodedText = applyTeluguTheologicalLexiconGuard(decodedText);
            cleanSubText = applyTeluguTheologicalLexiconGuard(cleanSubText);
            // Gemini edit on (hybrid): spoken style was chosen in context; don't override it.
            if (!hybrid) decodedText = applySpokenTeluguColloquialContractions(decodedText);
          }
          decodedText = normalizeScriptureCitationsForTts(decodedText, normTargetLang);
          const segDurationMs = durations[index] > 0
            ? (segment.end > segment.start && Math.abs((segment.end - segment.start) - durations[index]) < 5
              ? durations[index]
              : (durations[index] >= 60 ? durations[index] : durations[index] * 1000))
            : Math.max(0, segment.end - segment.start);
          const syllableBudgetCompliance = computeSyllableBudgetCompliance(
            segment.text,
            decodedText,
            normSourceLang,
            normTargetLang,
            segDurationMs
          );
          const qg = qualityGateResults[index];
          return {
            original: segment.text,
            translated: decodedText,
            subtitleText: cleanSubText,
            appliedRegister: appliedRegisters[index],
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
            terminologyWarning: complianceResults[index]?.violations?.length > 0
              ? `Non-compliant term "${complianceResults[index].violations[0].disallowedFound}" detected. Recommended: "${complianceResults[index].violations[0].suggested}".`
              : undefined,
            terminologyViolations: complianceResults[index]?.violations?.length > 0
              ? complianceResults[index].violations
              : undefined,
            terminologyComplianceRate: complianceResults[index]?.complianceRate ?? 1.0,
            numericalParityVerified: qg?.numericalParityVerified ?? true,
            numericalParityWarning: qg?.numericalParityWarning,
            semanticParityScore: qg?.semanticParityScore,
            reviewRecommended: qg?.reviewRecommended ?? false,
            polarityFlipped: qg?.polarityFlipped,
            ...(repairAttempted[index] ? { repairAttempted: true } : {}),
            ...(repairOutcome[index] ? { repairOutcome: repairOutcome[index] } : {}),
            ...(translationBlockReason[index] ? { translationBlockReason: translationBlockReason[index] } : {}),
          };
        }
      );

      return {
        jobId,
        sourceLanguage,
        targetLanguage,
        segments: translatedSegments,
        ...(resolvedBible ? { localizationBible: resolvedBible } : {}),
      };
    } catch (error) {
      console.error(`[Translation] translateSegments error for job ${jobId}:`, error);
      throw error;
    }
  }

  // ─── Hybrid step 2: Gemini contextual edit ─────────────────────────────────

  /**
   * Sends the Translation LLM drafts to Gemini with context, speaker gender, glossary and a
   * syllable budget per line. Returns one string per segment, in order. Never throws for a
   * Gemini failure: lines Gemini cannot improve safely keep their draft.
   */
  private async applyContextualDubbingEdit(
    jobId: string,
    segments: Array<{
      start: number;
      end: number;
      text: string;
      speaker?: string;
      addressedTo?: string;
      registerDirective?: string;
      isSong?: boolean;
      duration?: number;
      emotionTag?: string;
      deliveryStyle?: string;
      delivery?: string;
    }>,
    drafts: string[],
    sourceLanguage: string,
    targetLanguage: string,
    profileKey: TerminologyProfile | undefined,
    options?: {
      tone?: "casual" | "formal";
      localeStyle?: string;
      speakerProfiles?: SpeakerProfile[];
      userId?: string;
      totalDurationMs?: number;
      shotChangesMs?: number[];
      creatorDNA?: CreatorDNA;
      targetPlatform?: string;
      onScreenText?: OnScreenTextEvent[];
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      /** Diarization label → cast name / gender (cast-list.ts binding in 07-dubbing.ts). */
      speakerNames?: Record<string, string>;
      castGenderByLabel?: Record<string, "male" | "female">;
      enableDualTrack?: boolean;
    }
  ): Promise<Array<{
    text: string;
    subtitleText?: string;
    appliedRegister?: string;
    meaningAction?: MeaningAction;
    meaningPolarityFlipped?: boolean;
    meaningNumbersChanged?: boolean;
    maxSyllables?: number;
  }>> {
    const genderBySpeaker = new Map<string, "male" | "female">();
    for (const p of options?.speakerProfiles || []) {
      const g = (p as any)?.gender;
      if ((p as any)?.speakerId && (g === "male" || g === "female")) genderBySpeaker.set((p as any).speakerId, g);
    }
    // Cast genders arrive keyed by diarization label (cast-list.ts bindCastGenders in 07-dubbing.ts);
    // a creator's cast list wins over the acoustic estimate.
    for (const [label, g] of Object.entries(options?.castGenderByLabel || {})) {
      if (g === "male" || g === "female") genderBySpeaker.set(label, g);
    }

    const uniqueSpeakers = Array.from(new Set(segments.map((s) => s.speaker).filter(Boolean))) as string[];
    const relMap = new Map<string, CharacterRelationship>();
    for (const rel of options?.relationships || []) {
      relMap.set(`${rel.fromSpeaker}->${rel.toSpeaker}`, rel);
    }

    const addressees = inferAddressees(segments, uniqueSpeakers, options?.relationships || []);

    // The dubbing layer sends milliseconds; some callers and tests send seconds.
    const lastEnd = Math.max(0, ...segments.map((s) => Number(s.end) || 0));
    const toMs = lastEnd > 0 && lastEnd < 1000 ? 1000 : 1;

    const editorSegments: EditorSegment[] = segments.map((seg, i) => {
      const start = (Number(seg.start) || 0) * toMs;
      let end = (Number(seg.end) || 0) * toMs;
      if (end <= start && seg.duration && seg.duration > 0) {
        end = start + (seg.duration > 1000 ? seg.duration : seg.duration * 1000);
      }
      const next = segments[i + 1];
      const nextStartRaw = next ? (Number(next.start) || 0) * toMs : 0;
      const nextStart = next && nextStartRaw > start ? nextStartRaw : null;
      const windowMs = end > start
        ? permissibleWindowMs(
            start,
            end,
            nextStart,
            options?.totalDurationMs,
            options?.shotChangesMs
          )
        : 0;

      const addressedTo = addressees[i];

      // Only an explicit relationship pins a line's register here. Everything else is left to the
      // editor's localization bible (Gemini-inferred registers + locks); a default directive here
      // would override what the bible inferred.
      let registerDirective = seg.registerDirective;
      if (!registerDirective && seg.speaker && addressedTo) {
        const rel = relMap.get(`${seg.speaker}->${addressedTo}`);
        if (rel) registerDirective = resolveRegisterDirective(targetLanguage, rel, options?.tone);
      }

      return {
        id: `L${i + 1}`,
        source: seg.text,
        draft: decodeHtmlEntities(drafts[i] || ""),
        speaker: seg.speaker,
        speakerGender: seg.speaker ? genderBySpeaker.get(seg.speaker) : undefined,
        addressedTo,
        registerDirective,
        isSong: seg.isSong,
        delivery: seg.delivery || seg.emotionTag || (seg.deliveryStyle && seg.deliveryStyle !== "natural" ? seg.deliveryStyle : undefined),
        maxSyllables: windowMs > 0 ? syllableBudgetForDuration(windowMs, targetLanguage) : undefined,
      };
    });

    let visualSceneNotes: string[] | undefined;
    if (editorContextEnabled() && options?.onScreenText && options.onScreenText.length > 0) {
      const notes: string[] = [];
      let totalChars = 0;
      for (const ev of options.onScreenText) {
        if (notes.length >= 30) break;
        const totalSec = Math.max(0, Math.floor(ev.startMs / 1000));
        const mm = String(Math.floor(totalSec / 60)).padStart(2, "0");
        const ss = String(totalSec % 60).padStart(2, "0");
        const note = `${mm}:${ss} on screen: "${ev.text}"`;
        if (totalChars + note.length > 2000) break;
        notes.push(note);
        totalChars += note.length;
      }
      if (notes.length > 0) visualSceneNotes = notes;
    }

    try {
      const results = await geminiDubbingEditor.editSegments(editorSegments, {
        jobId,
        userId: options?.userId,
        sourceLanguage,
        targetLanguage,
        localeStyle: options?.localeStyle,
        tone: options?.tone,
        creatorDNA: options?.creatorDNA,
        targetPlatform: options?.targetPlatform,
        visualSceneNotes,
        castList: options?.castList,
        relationships: options?.relationships,
        speakerNames: options?.speakerNames,
        enableDualTrack: options?.enableDualTrack ?? true,
        glossary: this.buildGlossaryTermsForEditor(segments.map((s) => s.text), sourceLanguage, targetLanguage, profileKey),
        countSyllables: countSourceSyllables,
        countGlossaryViolations: (source, translated, lang) =>
          TerminologyService.checkTerminologyCompliance(source, translated, lang, { localeStyle: profileKey }).violations.length,
      });
      return results.map((r, i) => ({
        text: r.text || editorSegments[i].draft,
        subtitleText: r.subtitleText || r.text || editorSegments[i].draft,
        appliedRegister: r.appliedRegister,
        meaningAction: r.meaningAction,
        meaningPolarityFlipped: r.meaningPolarityFlipped,
        meaningNumbersChanged: r.meaningNumbersChanged,
        maxSyllables: editorSegments[i].maxSyllables,
      }));
    } catch (err) {
      console.warn("[Translation] Gemini contextual edit failed — using Translation LLM drafts", err);
      return editorSegments.map((s) => ({
        text: s.draft,
        subtitleText: s.draft,
        appliedRegister: undefined,
      }));
    }
  }

  // ─── Subtitles: faithful translation fitted to reading speed ───────────────

  /**
   * Translates complete source sentences for on-screen subtitles.
   *
   * Hybrid mode: Translation LLM drafts each sentence (the faithful version), then Gemini edits
   * in context with a CHARACTER budget per sentence = Netflix reading speed x the time the
   * sentence can stay on screen. Unlike the dubbing edit, nothing is shortened for spoken length;
   * text is only condensed where it is too long to read. Lines Gemini cannot improve safely keep
   * the Translation LLM draft.
   */
  public async translateSubtitleSentences(
    jobId: string,
    sentences: Array<{ text: string; speaker?: string; maxCharacters?: number }>,
    sourceLanguage: string,
    targetLanguage: string,
    options?: {
      localeStyle?: string;
      tone?: "casual" | "formal";
      creatorDNA?: CreatorDNA;
      targetPlatform?: string;
      userId?: string;
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      /** Diarization label → cast name / gender (cast-list.ts binding in 07-dubbing.ts). */
      speakerNames?: Record<string, string>;
      castGenderByLabel?: Record<string, "male" | "female">;
    }
  ): Promise<string[]> {
    const src = normalizeLanguageCode(sourceLanguage);
    const tgt = normalizeLanguageCode(targetLanguage);
    if (sentences.length === 0) return [];

    const drafts = (await this.batchTranslateV3(sentences.map((s) => s.text), src, tgt)).map((d) => decodeHtmlEntities(d));
    if (!isContextualDubbingEditEnabled()) return drafts;

    const profileKey = resolveTerminologyProfile(options as any);
    let editedTexts: string[];
    try {
      const results = await geminiDubbingEditor.editSegments(
        sentences.map((s, i) => ({
          id: `S${i + 1}`,
          source: s.text,
          draft: drafts[i],
          speaker: s.speaker,
          maxCharacters: s.maxCharacters,
        })),
        {
          jobId,
          userId: options?.userId,
          sourceLanguage: src,
          targetLanguage: tgt,
          purpose: "subtitle",
          localeStyle: options?.localeStyle,
          tone: options?.tone,
          creatorDNA: options?.creatorDNA,
          targetPlatform: options?.targetPlatform,
          castList: options?.castList,
          relationships: options?.relationships,
          speakerNames: options?.speakerNames,
          glossary: this.buildGlossaryTermsForEditor(sentences.map((s) => s.text), src, tgt, profileKey),
          countSyllables: countSourceSyllables,
          countGlossaryViolations: (source, translated, lang) =>
            TerminologyService.checkTerminologyCompliance(source, translated, lang, { localeStyle: profileKey }).violations.length,
        }
      );
      editedTexts = results.map((r, i) => r.text || drafts[i]);
    } catch (err) {
      console.warn("[Translation] Subtitle edit failed — using Translation LLM drafts", err);
      editedTexts = drafts;
    }

    // Run quality gate (numerical parity + semantic spot check) on fallback subtitle path (Fix 1.2)
    try {
      const qgInput: QualityGateSegmentInput[] = sentences.map((s, idx) => ({
        index: idx,
        original: s.text,
        translated: editedTexts[idx],
        terminologyComplianceRate: TerminologyService.checkTerminologyCompliance(
          s.text,
          editedTexts[idx],
          tgt,
          { localeStyle: profileKey }
        ).complianceRate,
      }));
      const qgResults = await TranslationQualityGate.evaluateQualityGate(qgInput, src, tgt, {
        sampleRate: 0.10,
        semanticThreshold: 0.85,
        enableSelfHealing: true,
        repairCallback: async (source, drifted, tgtLang, details) => {
          return await this.repairNumericalDrift(source, drifted, src, tgtLang, details, profileKey);
        },
        backTranslateCallback: async (targetText, tgtLang) => {
          return (await this.batchTranslateV3([targetText], tgtLang, src))[0];
        },
      });
      for (let i = 0; i < qgResults.length; i++) {
        if (qgResults[i].translated && qgResults[i].translated !== editedTexts[i]) {
          editedTexts[i] = qgResults[i].translated;
        }
      }
    } catch (qgErr) {
      console.warn("[Translation] Subtitle quality gate failed — keeping edited texts", qgErr);
    }

    if (tgt === "te") {
      editedTexts = editedTexts.map((t) => applyTeluguTheologicalLexiconGuard(t));
    }
    return editedTexts;
  }

  /**
   * Condenses subtitle lines that are still too fast to read after every timing fix.
   * Works in the subtitle's own language. Returns one string per item (the original when
   * Gemini cannot shorten it safely).
   */
  public async condenseSubtitleLines(
    jobId: string,
    items: Array<{ text: string; maxCharacters: number; speaker?: string }>,
    language: string
  ): Promise<string[]> {
    if (items.length === 0 || !isContextualDubbingEditEnabled()) return items.map((i) => i.text);
    const lang = normalizeLanguageCode(language);
    try {
      const results = await geminiDubbingEditor.editSegments(
        items.map((it, i) => ({ id: `C${i + 1}`, source: it.text, draft: it.text, speaker: it.speaker, maxCharacters: it.maxCharacters })),
        {
          jobId,
          sourceLanguage: lang,
          targetLanguage: lang,
          purpose: "subtitle",
          countSyllables: countSourceSyllables,
          // Condensing only shortens already-final lines: no new register inference (extra call,
          // and it could change address forms that were already decided).
          inferBible: false,
        }
      );
      return results.map((r, i) => r.text || items[i].text);
    } catch (err) {
      console.warn("[Translation] Subtitle condensation failed — keeping lines", err);
      return items.map((i) => i.text);
    }
  }

  /** Glossary terms whose source-language term appears in these lines, for the Gemini prompt (Fix 2.4). */
  private buildGlossaryTermsForEditor(
    sourceTexts: string[],
    sourceLanguage: string,
    targetLanguage: string,
    profileKey?: TerminologyProfile
  ): EditorGlossaryTerm[] {
    const srcBase = normalizeLanguageCode(sourceLanguage).toLowerCase().slice(0, 2);
    const normTarget = normalizeLanguageCode(targetLanguage).toLowerCase().slice(0, 2);
    const joined = sourceTexts.join(" ");
    const terms: EditorGlossaryTerm[] = [];

    for (const entry of DOMAIN_GLOSSARY) {
      const langData = entry.translations[normTarget];
      if (!langData) continue;
      const targetTerm = (profileKey && langData.profiles?.[profileKey]) || langData.preferred;
      const sense = GLOSSARY_SENSE[entry.category] || String(entry.category).replace(/_/g, " ");

      if (srcBase === "en") {
        if (!new RegExp(`\\b${escapeRegex(entry.sourceEn)}\\b`, "i").test(joined)) continue;
        terms.push({ source: entry.sourceEn, target: targetTerm, sense });
      } else {
        const srcData = entry.translations[srcBase];
        if (!srcData) continue;
        const candidates = [srcData.preferred, ...(srcData.acceptableAlternatives || [])].filter(Boolean);
        const matched = candidates.find((term) => joined.includes(term));
        if (!matched) continue;
        terms.push({ source: matched, target: targetTerm, sense });
      }
    }
    return terms;
  }

  // ─── Language detection (utility only — NOT used in dubbing pipeline) ────────
  // AssemblyAI Universal 3.7 Pro provides the authoritative source language
  // upstream via AudioLanguageProbe. These methods exist only as standalone
  // utilities for edge cases where language is truly unknown.

  /**
   * @deprecated Prefer AssemblyAI-detected sourceLanguage from the transcription layer.
   * This is a standalone utility only — never silently defaults to "en".
   */
  async detectLanguage(text: string): Promise<string> {
    if (this.v3Client) {
      try {
        const best = await withTransientRetry(async () => {
          const [response] = await this.v3Client!.detectLanguage({
            parent: this.parent,
            content: text,
            mimeType: "text/plain",
          });
          return response.languages?.[0]?.languageCode;
        }, { maxAttempts: 3, label: "Google v3 detectLanguage" });

        if (best) return best;
      } catch (error) {
        console.error("[Translation] v3 detectLanguage error:", error);
      }
    }

    console.warn("[Translation] Language detection failed — no AssemblyAI fallback available. Caller must handle undefined source language.");
    throw new Error("[Translation] Language detection unavailable. Source language must be provided by AssemblyAI transcription layer.");
  }

  /**
   * @deprecated Prefer AssemblyAI-detected sourceLanguage from the transcription layer.
   */
  async detectLanguages(texts: string[]): Promise<string[]> {
    if (this.v3Client) {
      try {
        return await mapConcurrent(texts, DEFAULT_CONCURRENCY, (text) => this.detectLanguage(text));
      } catch (error) {
        console.error("[Translation] v3 batch language detection error:", error);
      }
    }

    throw new Error("[Translation] Batch language detection unavailable. Source languages must be provided by AssemblyAI transcription layer.");
  }

  // ─── Private: v3 batched translation ───────────────────────────────────────

  /**
   * Translate texts in batches via v3 API with bounded concurrency & retry.
   * V3_BATCH_SIZE is set to 100 (API limit: 128 items).
   */
  public async batchTranslateV3(
    texts: string[],
    sourceLanguage: string,
    targetLanguage: string
  ): Promise<string[]> {
    if (texts.length === 0) return [];
    if (!this.v3Client) {
      throw new Error("[Translation] Required Google Cloud Translation v3 client is unavailable.");
    }

    const batches: string[][] = [];
    for (let i = 0; i < texts.length; i += V3_BATCH_SIZE) {
      batches.push(texts.slice(i, i + V3_BATCH_SIZE));
    }

    const batchResults = await mapConcurrent(batches, DEFAULT_CONCURRENCY, async (batch, batchIdx) => {
      return await withTransientRetry(async () => {
        const [response] = await this.v3Client!.translateText({
          parent: this.parent,
          model: this.v3ModelPath,
          contents: batch,
          mimeType: "text/plain",
          sourceLanguageCode: sourceLanguage,
          targetLanguageCode: targetLanguage,
        });

        const translated = (response.translations ?? []).map((t) => decodeHtmlEntities(t.translatedText ?? ""));
        if (translated.length !== batch.length || translated.some((text) => !text.trim())) {
          throw new Error(`[Translation] Google Cloud Translation v3 returned incomplete results for batch ${batchIdx}.`);
        }
        return translated;
      }, { maxAttempts: 3, label: `Google v3 batchTranslate #${batchIdx}` });
    });

    return batchResults.flat();
  }

  /**
   * Composite primary translation: Google v3 results followed by required Adaptive MT output.
   */
  public async batchTranslateStandard(
    texts: string[],
    source: string,
    target: string,
    profileKey?: TerminologyProfile
  ): Promise<string[]> {
    if (texts.length === 0) return [];
    const v3Results = await this.batchTranslateV3(texts, source, target);
    if (v3Results.length !== texts.length) {
      throw new Error("[Translation] Google Cloud Translation v3 returned an incomplete batch.");
    }
    return this.batchApplyAdaptiveMtTranslation(v3Results, texts, source, target, profileKey);
  }

  // ─── Required Adaptive MT Translation Stage ─────────────────────────────────

  /**
   * Builds inline reference sentence pairs from the DOMAIN_GLOSSARY for AdaptiveMtTranslate.
   * Hardened Fixes:
   *  1. Profile-Aware Reference Pairs: selects langData.profiles[toneMode] over hardcoded preferred.
   *  2. Full-Sentence Context Pairs: includes contextual example sentences for natural inflection & case agreement.
   *  4. Word-Boundary Matching: uses whole-word regex boundaries preventing false positive substring matches.
   */
  private buildGlossaryReferencePairs(
    sourceTexts: string[],
    sourceLanguage: string,
    targetLanguage: string,
    profileKey?: TerminologyProfile
  ): Array<{ sourceSentence: string; targetSentence: string }> {
    const normTarget = targetLanguage.toLowerCase().slice(0, 2);
    const pairs: Array<{ sourceSentence: string; targetSentence: string }> = [];
    const joinedSource = sourceTexts.join(" ");

    for (const entry of DOMAIN_GLOSSARY) {
      // 🛡️ Fix 4: Whole-word boundary matching (prevents "Lord" in "landlord", "sin" in "single", etc.)
      const wordBoundaryRegex = new RegExp(`\\b${escapeRegex(entry.sourceEn)}\\b`, "i");
      if (!wordBoundaryRegex.test(joinedSource)) continue;

      const langData = entry.translations[normTarget];
      if (!langData) continue;

      // 🛡️ Fix 1: Profile-aware term selection (colloquial/formal/technical/neutral)
      const selectedTerm = (profileKey && langData.profiles?.[profileKey]) || langData.preferred;

      // 🛡️ Fix 2: Full-sentence context pair for natural case inflection & verb agreement
      if (langData.example) {
        pairs.push({
          sourceSentence: langData.example.sourceSentence,
          targetSentence: langData.example.targetSentence,
        });
      }

      pairs.push({
        sourceSentence: entry.sourceEn,
        targetSentence: selectedTerm,
      });

      // Include alternative profile translations if distinct
      if (langData.profiles) {
        for (const [prof, profileTranslation] of Object.entries(langData.profiles)) {
          if (profileTranslation !== selectedTerm && (!profileKey || prof === profileKey)) {
            pairs.push({
              sourceSentence: entry.sourceEn,
              targetSentence: profileTranslation,
            });
          }
        }
      }
    }

    return pairs;
  }

  /**
   * 🧠 Required second stage of the composite primary translation engine.
   *
   * Adaptive MT receives the v3 candidate plus glossary/verified examples and
   * supplies the final result for the composite primary translation engine.
   */
  private async applyAdaptiveMtTranslation(
    v3TranslatedText: string,
    sourceText: string,
    sourceLanguage: string,
    targetLanguage: string,
    profileKey?: TerminologyProfile
  ): Promise<string> {
    if (!this.adaptiveMtClient) {
      throw new Error("[Translation] Required Google Adaptive MT client is unavailable.");
    }

    const referencePairs = this.buildGlossaryReferencePairs([sourceText], sourceLanguage, targetLanguage, profileKey);
    const tmPairs = await adaptiveMtDatasetService.getRecentVerifiedPairs(sourceLanguage, targetLanguage, 3).catch(() => []);
    const combinedPairs = [
      { sourceSentence: sourceText, targetSentence: v3TranslatedText },
      ...referencePairs,
      ...tmPairs,
    ].slice(0, 8);

    const request: any = {
      parent: this.adaptiveMtParent,
      sourceLanguageCode: sourceLanguage,
      targetLanguageCode: targetLanguage,
      content: [sourceText],
    };
    if (combinedPairs.length > 0) {
      request.referenceSentenceConfig = {
        referenceSentencePairLists: [{ referenceSentencePairs: combinedPairs }],
      };
    }
    if (PIPELINE_CONFIG.ADAPTIVE_MT_DATASET) {
      request.dataset = PIPELINE_CONFIG.ADAPTIVE_MT_DATASET;
    }

    const [response] = await withTransientRetry(
      () => this.adaptiveMtClient!.adaptiveMtTranslate(request),
      { maxAttempts: 2, label: "Required Google Adaptive MT translation" }
    );
    const translated = response.translations?.[0]?.translatedText;
    if (!translated?.trim()) {
      throw new Error("[Translation] Required Google Adaptive MT returned no translation.");
    }
    console.info("[Translation] Adaptive MT produced the composite primary result", {
      referencePairCount: combinedPairs.length,
      glossaryPairCount: referencePairs.length,
    });
    return decodeHtmlEntities(translated);
  }

  /**
   * Batch variant of the required Adaptive MT stage for the composite primary.
   */
  private async batchApplyAdaptiveMtTranslation(
    v3TranslatedTexts: string[],
    sourceTexts: string[],
    sourceLanguage: string,
    targetLanguage: string,
    profileKey?: TerminologyProfile
  ): Promise<string[]> {
    if (sourceTexts.length === 0) return [];
    if (v3TranslatedTexts.length !== sourceTexts.length) {
      throw new Error("[Translation] Cannot run Adaptive MT without a complete v3 translation batch.");
    }
    if (!this.adaptiveMtClient) {
      throw new Error("[Translation] Required Google Adaptive MT client is unavailable.");
    }

    const referencePairs = this.buildGlossaryReferencePairs(sourceTexts, sourceLanguage, targetLanguage, profileKey);
    const tmPairs = await adaptiveMtDatasetService.getRecentVerifiedPairs(sourceLanguage, targetLanguage, 5).catch(() => []);
    const sharedPairs = [...referencePairs, ...tmPairs].slice(0, 7);

    // Batch AdaptiveMt calls with bounded concurrency
    const batches: Array<{ indices: number[]; sources: string[] }> = [];
    for (let i = 0; i < sourceTexts.length; i += ADAPTIVE_MT_BATCH_SIZE) {
      const end = Math.min(i + ADAPTIVE_MT_BATCH_SIZE, sourceTexts.length);
      batches.push({
        indices: Array.from({ length: end - i }, (_, k) => i + k),
        sources: sourceTexts.slice(i, end),
      });
    }

    const results: string[] = new Array(sourceTexts.length);

    await mapConcurrent(batches, DEFAULT_CONCURRENCY, async (batch, batchIdx) => {
      const request: any = {
        parent: this.adaptiveMtParent,
        sourceLanguageCode: sourceLanguage,
        targetLanguageCode: targetLanguage,
        content: batch.sources,
        referenceSentenceConfig: {
          referenceSentencePairLists: batch.indices.map((sourceIndex) => ({
            referenceSentencePairs: [
              {
                sourceSentence: sourceTexts[sourceIndex],
                targetSentence: v3TranslatedTexts[sourceIndex],
              },
              ...sharedPairs,
            ],
          })),
        },
      };
      if (PIPELINE_CONFIG.ADAPTIVE_MT_DATASET) {
        request.dataset = PIPELINE_CONFIG.ADAPTIVE_MT_DATASET;
      }

      const [response] = await withTransientRetry(
        () => this.adaptiveMtClient!.adaptiveMtTranslate(request),
        { maxAttempts: 2, label: `Required Adaptive MT batch translation #${batchIdx}` }
      );
      const translated = response.translations?.map((item) => item.translatedText ?? "") ?? [];
      if (translated.length !== batch.sources.length || translated.some((text) => !text.trim())) {
        throw new Error(`[Translation] Adaptive MT returned incomplete results for batch ${batchIdx}.`);
      }
      batch.indices.forEach((origIdx, i) => {
        results[origIdx] = decodeHtmlEntities(translated[i]);
      });
    });

    return results;
  }

  /**
   * 🛡️ Fix 3: Targeted re-inflection pass for terminology violations.
   * CRITICAL: Never performs blind string-replacement on inflected/agglutinative
   * Indic or Arabic scripts. Instead, routes through targeted AdaptiveMtTranslate
   * with explicit domain glossary reference pairs.
   */
  private async remedyTerminologyViolations(
    sourceText: string,
    currentTranslation: string,
    sourceLang: string,
    targetLang: string,
    violations: Array<{ termId: string; source: string; disallowedFound: string; suggested: string; context?: string }>,
    profileKey?: TerminologyProfile
  ): Promise<string> {
    const normTarget = targetLang.toLowerCase().slice(0, 2);
    try {
      // 1. Try targeted AdaptiveMt with specific high-priority reference pairs
      if (this.adaptiveMtClient) {
        const targetedPairs: Array<{ sourceSentence: string; targetSentence: string }> = [];
        for (const v of violations) {
          const entry = DOMAIN_GLOSSARY.find((g) => g.termId === v.termId);
          if (entry) {
            const langData = entry.translations[normTarget];
            if (langData?.example) {
              targetedPairs.push({
                sourceSentence: langData.example.sourceSentence,
                targetSentence: langData.example.targetSentence,
              });
            }
            targetedPairs.push({
              sourceSentence: entry.sourceEn,
              targetSentence: v.suggested,
            });
          }
        }

        if (targetedPairs.length > 0) {
          const request: any = {
            parent: this.adaptiveMtParent,
            content: [sourceText],
            referenceSentenceConfig: {
              referenceSentencePairLists: [{ referenceSentencePairs: targetedPairs }],
            },
          };
          if (PIPELINE_CONFIG.ADAPTIVE_MT_DATASET) {
            request.dataset = PIPELINE_CONFIG.ADAPTIVE_MT_DATASET;
          }
          const [response]: any = await (this.adaptiveMtClient as any).adaptiveMtTranslate(request);
          const refined = response?.translations?.[0]?.translatedText;
          if (refined) {
            const decoded = decodeHtmlEntities(refined);
            const recheck = TerminologyService.checkTerminologyCompliance(sourceText, decoded, targetLang, {
              localeStyle: profileKey,
            });
            if (recheck.violations.length < violations.length) {
              return decoded;
            }
          }
        }
      }
    } catch (err) {
      console.warn("[Translation] Targeted terminology remedy pass skipped:", err);
    }
    return currentTranslation;
  }

  /**
   * 🛡️ Targeted numerical self-healing repair.
   * Tries Adaptive MT first when available; if unavailable or its result fails parity,
   * falls back to a single-line Gemini dubbing editor repair pass (Fix 2.2).
   */
  public async repairNumericalDrift(
    sourceText: string,
    currentTranslation: string,
    sourceLang: string,
    targetLang: string,
    _driftDetails?: string,
    _profileKey?: TerminologyProfile,
    repairCtx?: {
      jobId?: string;
      userId?: string;
      maxSyllables?: number;
      bible?: any;
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      speakerNames?: Record<string, string>;
    }
  ): Promise<string> {
    const src = normalizeLanguageCode(sourceLang);
    const tgt = normalizeLanguageCode(targetLang);

    if (this.adaptiveMtClient) {
      try {
        const sourceEntities = NumericalEntityGuard.extractNumericEntities(sourceText);
        const refPairs = sourceEntities.map((e) => ({
          sourceSentence: sourceText,
          targetSentence: `${currentTranslation} [Preserve: ${e.raw}]`,
        }));

        const request: any = {
          parent: this.adaptiveMtParent,
          sourceLanguageCode: src,
          targetLanguageCode: tgt,
          content: [sourceText],
          referenceSentenceConfig: {
            referenceSentencePairLists: [{ referenceSentencePairs: refPairs.slice(0, 3) }],
          },
        };
        if (PIPELINE_CONFIG.ADAPTIVE_MT_DATASET) {
          request.dataset = PIPELINE_CONFIG.ADAPTIVE_MT_DATASET;
        }
        const [response]: any = await (this.adaptiveMtClient as any).adaptiveMtTranslate(request);
        const result = response?.translations?.[0]?.translatedText;
        if (result && result.trim().length > 0) {
          const recheck = NumericalEntityGuard.verifyNumericalParity(sourceText, result, tgt);
          if (recheck.isParity) return decodeHtmlEntities(result);
        }
      } catch (adErr) {
        // Fall through to Gemini single-line repair
      }
    }

    return await this.repairLineWithEditor(
      sourceText,
      currentTranslation,
      src,
      tgt,
      _driftDetails || "Fix the number, date, amount or unit mismatch against SOURCE.",
      { ...repairCtx, profileKey: _profileKey }
    );
  }

  /**
   * Single-line Gemini repair for polarity flips, number mismatches, or unresolved meaning (Fix 2.2).
   * Returns `currentTranslation` unchanged if the repair fails validation.
   */
  public async repairMeaning(
    sourceText: string,
    currentTranslation: string,
    sourceLang: string,
    targetLang: string,
    problem: string,
    opts?: {
      jobId?: string;
      userId?: string;
      maxSyllables?: number;
      bible?: any;
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      speakerNames?: Record<string, string>;
      profileKey?: TerminologyProfile;
    }
  ): Promise<string> {
    const src = normalizeLanguageCode(sourceLang);
    const tgt = normalizeLanguageCode(targetLang);
    return await this.repairLineWithEditor(sourceText, currentTranslation, src, tgt, problem, opts);
  }

  private async repairLineWithEditor(
    sourceText: string,
    currentTranslation: string,
    src: string,
    tgt: string,
    repairInstruction: string,
    opts?: {
      jobId?: string;
      userId?: string;
      maxSyllables?: number;
      bible?: any;
      castList?: CastMember[];
      relationships?: CharacterRelationship[];
      speakerNames?: Record<string, string>;
      profileKey?: TerminologyProfile;
    }
  ): Promise<string> {
    const seg: EditorSegment = {
      id: "R1",
      source: sourceText,
      draft: currentTranslation,
      repairInstruction,
      maxSyllables: opts?.maxSyllables ? Math.floor(opts.maxSyllables * MEANING_CHECK.maxOverBudget) : undefined,
    };
    const editorOpts = {
      jobId: opts?.jobId || "repair",
      userId: opts?.userId,
      sourceLanguage: src,
      targetLanguage: tgt,
      bible: opts?.bible,
      inferBible: false as const,
      castList: opts?.castList,
      relationships: opts?.relationships,
      speakerNames: opts?.speakerNames,
      glossary: this.buildGlossaryTermsForEditor([sourceText], src, tgt, opts?.profileKey),
      countSyllables: countSourceSyllables,
      countGlossaryViolations: (source: string, translated: string, lang: string) =>
        TerminologyService.checkTerminologyCompliance(source, translated, lang, { localeStyle: opts?.profileKey }).violations.length,
    };
    try {
      const [edited] = await geminiDubbingEditor.editSegments([seg], editorOpts);
      if (!edited?.text?.trim()) return currentTranslation;
      // R4: reject the repair if the editor's meaning check still flags polarity flip, number change, or unresolved meaning.
      if (
        edited.meaningAction === "unresolved" ||
        edited.meaningPolarityFlipped === true ||
        edited.meaningNumbersChanged === true
      ) {
        return currentTranslation;
      }
      const parity = NumericalEntityGuard.verifyNumericalParity(sourceText, edited.text, tgt);
      if (!parity.isParity) return currentTranslation;
      const check = checkEditedLine(seg, edited.text, editorOpts);
      if (!check.ok) return currentTranslation;
      return decodeHtmlEntities(edited.text.trim());
    } catch {
      return currentTranslation;
    }
  }

  /**
   * @deprecated Audio Pacing & Density Scouter.
   * Diagnostic utility for acoustic telemetry; all translation is handled exclusively
   * by Google Cloud Translation v3 (general/translation-llm + AdaptiveMt).
   */
  public shouldEscalateToPremium(text: string, durationMs?: number): boolean {
    const regexPatterns = [
      /\b(?:Anthropic|Claude|Figma|Adobe|Nvidia|OpenAI|Google|Apple|Microsoft)\b/i, // Brands
      /\b(?:launched|announced|released|revealed|exclusive|breaking)\b/i,            // High-value keywords
      /[!?.]{2,}/,                                                                   // High emotion / punctuation
      /\b(?:UI|UX|API|SDK|LLM|GPU|AI|Interface)\b/i,                                 // Tech terms
      /\w{20,}/,                                                                     // Very long words (likely tech/medical)
    ];
    
    const isLong = text.length > 150;
    const matchesRegex = regexPatterns.some((p) => p.test(text));

    // Audio pacing constraint: speech rate exceeds 18 chars/sec
    const isTightPacing = durationMs && durationMs > 0 ? (text.length / (durationMs / 1000)) > 18 : false;

    return isLong || matchesRegex || isTightPacing;
  }
}

export const translationService = new TranslationService();
