/**
 * Unified speech-rate, syllable-counting, and permissible-window model (Fix 3.1, 3.2, 3.6).
 *
 * Shared by both `geminiDubbingEditor.ts` (budgeting) and `07-dubbing.ts` (pre/post-TTS pacing)
 * so the two stages never disagree on how long a line takes to speak.
 *
 * Pure functions only — must NOT import `translation.ts` or `geminiDubbingEditor.ts`.
 */

/**
 * Spoken syllables per second, in the units `countSourceSyllables` counts
 * (vowel groups for Latin scripts, aksharas for Indic scripts).
 */
export const SYLLABLES_PER_SECOND: Record<string, number> = {
  en: 4.8, // not measured
  hi: 5.8, // not measured
  mr: 5.8, // not measured
  bn: 5.8, // not measured
  gu: 5.8, // not measured
  pa: 5.8, // not measured
  or: 5.8, // not measured
  as: 5.8, // not measured
  // te: measured 4.85 syl/s median on ElevenLabs v4 (local dub test dub-test-te-1795516992008,
  // "[Dubbing:Pacing] Measured speaking rate"). One run, ≤5 lines: re-check as more runs log it.
  te: 4.8,
  kn: 5.8, // not measured
  ta: 6.5, // not measured
  ml: 6.5, // not measured
  es: 6.2, // not measured
  it: 6.2, // not measured
  pt: 6.0, // not measured
  fr: 5.6, // not measured
  de: 4.6, // not measured
  ja: 7.0, // not measured
  zh: 4.4, // not measured
  ko: 6.0, // not measured
  ar: 5.0, // not measured
};

export const DEFAULT_SYLLABLES_PER_SECOND = 5.2;

/** The mixer may speed a line up to 1.15x; budget for 1.10x to keep headroom. */
export const TEMPO_HEADROOM = 1.1;

function baseLang(lang: string): string {
  return (lang || "").toLowerCase().split(/[-_]/)[0];
}

function countLatinWordSyllables(word: string): number {
  const cleaned = word.toLowerCase().replace(/[^a-z\u00C0-\u024F\u0400-\u04FF]/g, "");
  if (!cleaned) return 0;
  if (cleaned.length <= 3) return 1;

  // Cyrillic vowels + Latin vowels
  const normalized = cleaned
    .replace(/(?:[^laeiouy\u0430\u0435\u0451\u0438\u043E\u0443\u044B\u044D\u044E\u044F]es|ed|[^laeiouy]e)$/, "")
    .replace(/^y/, "");
  const groups = normalized.match(/[aeiouy\u00E0-\u00FF\u0430\u0435\u0451\u0438\u043E\u0443\u044B\u044D\u044E\u044F]+/g);
  return Math.max(1, groups ? groups.length : 1);
}

/**
 * Estimates spoken syllable count for Latin, Indic abugida, CJK/Kana/Hangul, and other scripts
 * while ignoring bracketed ElevenLabs audio performance tags such as `[whispers]`.
 */
export function countSourceSyllables(text: string, language?: string): number {
  const clean = (text || "").replace(/\[[^\]]+\]/g, " ").trim();
  if (!clean) return 0;

  const lang = baseLang(language || "");

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

/** Speaking rate (syllables per second) for `language`, preferring a valid `measuredRate`. */
export function syllablesPerSecond(language: string, measuredRate?: number): number {
  if (typeof measuredRate === "number" && Number.isFinite(measuredRate) && measuredRate > 0) {
    return measuredRate;
  }
  return SYLLABLES_PER_SECOND[baseLang(language)] ?? DEFAULT_SYLLABLES_PER_SECOND;
}

/**
 * Unified speech duration estimator (ms): syllable count / speaking rate + punctuation pause allowance.
 */
export function estimateSpeechDurationMs(
  text: string,
  language: string = "en",
  measuredRate?: number
): number {
  const clean = (text || "").replace(/\[[^\]]+\]/g, " ").trim();
  if (!clean) return 0;
  const syl = countSourceSyllables(clean, language);
  const rate = syllablesPerSecond(language, measuredRate);
  let durationMs = (syl / rate) * 1000;
  const commas = (clean.match(/[,،]/g) || []).length;
  const stops = (clean.match(/[.!?।]/g) || []).length;
  durationMs += commas * 120 + stops * 300;
  return Math.round(durationMs);
}

/** Maximum syllables that fit `windowMs` of speech in `language`. */
export function syllableBudgetForDuration(
  windowMs: number,
  language: string,
  measuredRate?: number
): number {
  const rate = syllablesPerSecond(language, measuredRate);
  const seconds = Math.max(0.2, windowMs / 1000);
  return Math.max(2, Math.floor(seconds * rate * TEMPO_HEADROOM));
}

/**
 * Time a line may occupy: its own window plus part of the pause after it,
 * never crossing into the next line (120 ms gap), and capping only the extra
 * trailing buffer at any scene cut (Fix 3.2 & 3.6).
 */
export function permissibleWindowMs(
  startMs: number,
  endMs: number,
  nextStartMs: number | null,
  totalDurationMs?: number,
  shotChangesMs?: number[]
): number {
  const segWindow = Math.max(0, endMs - startMs);
  const hardCeiling = nextStartMs !== null
    ? Math.max(startMs + 200, nextStartMs - 120)
    : (totalDurationMs && totalDurationMs > 0
      ? Math.max(startMs + 200, totalDurationMs - 150)
      : startMs + segWindow + 1000);
  const gap = nextStartMs !== null ? Math.max(0, nextStartMs - endMs) : 1000;
  const buffer = Math.max(0, Math.min(gap - 250, 1500));
  let maxEnd = Math.max(startMs + segWindow, Math.min(startMs + segWindow + buffer, hardCeiling));
  if (shotChangesMs && shotChangesMs.length > 0 && endMs > startMs) {
    for (const t of shotChangesMs) {
      if (t > endMs && t < hardCeiling) {
        maxEnd = Math.min(maxEnd, Math.max(endMs, t - 80));
      }
    }
  }
  return Math.max(200, Math.min(hardCeiling - startMs, maxEnd - startMs));
}
