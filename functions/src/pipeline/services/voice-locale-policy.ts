/**
 * Native-voice policy for dubbing (dependency-free, unit-tested).
 *
 * Rule: a dubbed track is voiced only by voices native to its language.
 *   - Indic targets (te, hi, ta, …): only Indian voices. A voice of the same language ranks first,
 *     any other Indian voice second. American / British / other voices are never used.
 *   - English: any English-accent voice (American, British, Australian, Irish, Indian English …).
 *   - Every other language: only voices of that language (from the curated Voice Library catalog).
 * A creator's own cloned voice is always allowed — it is their voice.
 * When a language has no native voice for a speaker's gender, that language's dub is skipped and
 * its subtitles stay, rather than shipping a foreign-accented dub.
 *
 * Turn off (old behaviour: foreign presets as fallback) with DUBBING_NATIVE_VOICES_ONLY=false.
 */

export const INDIC_LANGUAGES: ReadonlySet<string> = new Set([
  "te", "hi", "ta", "kn", "ml", "bn", "mr", "gu", "pa", "or", "as", "ur", "sd", "ne", "sa", "ks",
]);

/** Tag words used in voice labels / preset timbre tags → language code. */
const TAG_LANGUAGE: Record<string, string> = {
  telugu: "te", hindi: "hi", tamil: "ta", kannada: "kn", malayalam: "ml", bengali: "bn", bangla: "bn",
  marathi: "mr", gujarati: "gu", punjabi: "pa", odia: "or", oriya: "or", assamese: "as", urdu: "ur",
  sindhi: "sd", nepali: "ne", sanskrit: "sa", kashmiri: "ks",
  chennai: "ta", coimbatore: "ta",
  american: "en", british: "en", australian: "en", irish: "en", transatlantic: "en", southern: "en",
  english: "en", scottish: "en", canadian: "en",
  swedish: "sv", spanish: "es", mexican: "es", french: "fr", german: "de", italian: "it",
  portuguese: "pt", brazilian: "pt", dutch: "nl", russian: "ru", polish: "pl", arabic: "ar",
  turkish: "tr", japanese: "ja", korean: "ko", chinese: "zh", mandarin: "zh", indonesian: "id",
  vietnamese: "vi", thai: "th", filipino: "fil", greek: "el", hebrew: "he", persian: "fa",
};

/** Western and foreign accents that must never be considered native for Indic languages. */
const FOREIGN_ACCENT_PATTERN = /\b(american|british|australian|irish|scottish|canadian|transatlantic|southern|latin\s*american|mexican|spanish|french|german|italian|russian|swedish)\b/i;
const ENGLISH_ACCENT_PATTERN = /\b(american|british|australian|irish|scottish|canadian|transatlantic|southern)\b/i;

export function baseLanguage(lang?: string): string {
  const b = (lang || "").toLowerCase().trim().split(/[-_]/)[0];
  return b === "tl" ? "fil" : b;
}

export function nativeVoicesOnly(): boolean {
  return (process.env.DUBBING_NATIVE_VOICES_ONLY || "true").toLowerCase() !== "false";
}

export interface PolicyVoice {
  voiceId: string;
  gender: "male" | "female" | "neutral";
  timbreTags: string[];
}

/** Languages a voice is native to, from "lang:xx" tags and accent / language words. "indian" → all Indic. */
export function voiceLanguages(voice: PolicyVoice): Set<string> {
  const langs = new Set<string>();
  for (const raw of voice.timbreTags || []) {
    const t = String(raw).toLowerCase().trim();
    if (t.startsWith("lang:")) langs.add(baseLanguage(t.slice(5)));
    for (const word of t.split(/[\s_\-/]+/)) {
      if (word === "indian") langs.add("indic");
      const l = TAG_LANGUAGE[word];
      if (l) langs.add(l);
    }
  }
  return langs;
}

/**
 * 2 = voice of exactly this language (any English accent counts for English),
 * 1 = same region (an Indian voice for another Indic language),
 * 0 = foreign — never used when the policy is on.
 */
export function nativeTier(voice: PolicyVoice, targetLang: string): 0 | 1 | 2 {
  const lang = baseLanguage(targetLang);
  const langs = voiceLanguages(voice);
  const tags = voice.timbreTags || [];

  if (INDIC_LANGUAGES.has(lang)) {
    // HARD RULE: American / British / foreign-accented voices are strictly rate 0 (never native) for Indic
    const hasForeign = tags.some((t) => FOREIGN_ACCENT_PATTERN.test(String(t)));
    if (hasForeign) return 0;
    if (langs.has(lang)) return 2;
    if (langs.has("indic")) return 1;
    for (const l of langs) if (INDIC_LANGUAGES.has(l)) return 1;
    return 0;
  }

  // English: any English accent is native
  if (lang === "en") {
    return langs.has("en") ? 2 : 0;
  }

  // Other non-English languages (es, fr, de, ja, etc.): reject foreign English accents
  const hasEnglishAccent = tags.some((t) => ENGLISH_ACCENT_PATTERN.test(String(t)));
  if (hasEnglishAccent) return 0;

  if (langs.has(lang)) return 2;
  return 0;
}

function languageName(lang: string): string {
  try {
    // Intl.DisplayNames exists at runtime (Node 14+) but not in the es2017 type library this repo targets.
    const DisplayNames = (Intl as any).DisplayNames;
    const name: string | undefined = DisplayNames ? new DisplayNames(["en"], { type: "language" }).of(baseLanguage(lang)) : undefined;
    if (name && name.toLowerCase() !== baseLanguage(lang)) return name;
  } catch {
    // Intl.DisplayNames unavailable — fall through.
  }
  return baseLanguage(lang).toUpperCase();
}

/** Polite, creator-facing explanation when a language's dub is skipped (no technical detail). */
export function noNativeVoiceMessage(lang: string): string {
  const name = languageName(lang);
  return `We didn't create a ${name} audio track for this video because we don't yet have a natural-sounding ${name} voice for every speaker. ${name} subtitles are ready, and your dubbing charge for this language has been refunded to your wallet.`;
}

/** Polite, creator-facing explanation when a language is not supported by TTS model. */
export function unsupportedDubbingLanguageMessage(lang: string): string {
  const name = languageName(lang);
  return `We didn't create a ${name} audio track for this video because ${name} audio dubbing is not yet supported. ${name} subtitles are ready, and your dubbing charge for this language has been refunded to your wallet.`;
}
