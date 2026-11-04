/**
 * 🌐 LANGUAGE NORMALIZER
 * 
 * Maps language names, aliases, and localized strings to canonical ISO 639-1 / 639-2 codes
 * for Google Cloud Translation v3, Speech-to-Text, and Dubbing APIs.
 */

export const LANGUAGE_NAME_TO_CODE: Record<string, string> = {
  // Global / Major
  english: "en",
  spanish: "es",
  french: "fr",
  german: "de",
  chinese: "zh",
  japanese: "ja",
  russian: "ru",
  portuguese: "pt",
  arabic: "ar",
  korean: "ko",
  italian: "it",
  turkish: "tr",
  vietnamese: "vi",
  thai: "th",
  indonesian: "id",
  dutch: "nl",
  polish: "pl",
  swedish: "sv",
  danish: "da",
  norwegian: "no",
  finnish: "fi",
  greek: "el",
  czech: "cs",
  hungarian: "hu",
  romanian: "ro",
  ukrainian: "uk",
  hebrew: "he",
  persian: "fa",
  farsi: "fa",
  filipino: "fil",
  tagalog: "tl",
  malay: "ms",

  // Indian Languages (Crucial for Truthworld)
  hindi: "hi",
  bengali: "bn",
  bangla: "bn",
  telugu: "te",
  tamil: "ta",
  marathi: "mr",
  gujarati: "gu",
  kannada: "kn",
  malayalam: "ml",
  punjabi: "pa",
  odia: "or",
  oriya: "or",
  assamese: "as",
  urdu: "ur",
  kashmiri: "ks",
  sindhi: "sd",
  sanskrit: "sa",
  nepali: "ne",
  sinhala: "si",
  burmese: "my",
  myanmar: "my",

  // European / Others
  afrikaans: "af",
  albanian: "sq",
  amharic: "am",
  armenian: "hy",
  azerbaijani: "az",
  basque: "eu",
  belarusian: "be",
  bosnian: "bs",
  bulgarian: "bg",
  catalan: "ca",
  cebuano: "ceb",
  chichewa: "ny",
  corsican: "co",
  croatian: "hr",
  esperanto: "eo",
  estonian: "et",
  frisian: "fy",
  galician: "gl",
  georgian: "ka",
  gujrati: "gu",
  haitian: "ht",
  hausa: "ha",
  hawaiian: "haw",
  hmong: "hmn",
  icelandic: "is",
  igbo: "ig",
  irish: "ga",
  javanese: "jv",
  kazakh: "kk",
  khmer: "km",
  kinyarwanda: "rw",
  kirghiz: "ky",
  kurdish: "ku",
  kyrgyz: "ky",
  lao: "lo",
  latin: "la",
  latvian: "lv",
  lingala: "ln",
  lithuanian: "lt",
  luxembourgish: "lb",
  macedonian: "mk",
  malagasy: "mg",
  maltese: "mt",
  maori: "mi",
  mongolian: "mn",
  nyanja: "ny",
  pashto: "ps",
  samoan: "sm",
  serbian: "sr",
  sesotho: "st",
  shona: "sn",
  slovak: "sk",
  slovenian: "sl",
  somali: "so",
  sundanese: "su",
  swahili: "sw",
  tajik: "tg",
  tatar: "tt",
  turkmen: "tk",
  uyghur: "ug",
  uzbek: "uz",
  welsh: "cy",
  xhosa: "xh",
  yiddish: "yi",
  yoruba: "yo",
  zulu: "zu",
};

/**
 * Normalizes any language string (full name, mixed-case, code) into a valid ISO code.
 * E.g. "Tamil" -> "ta", "TAMIL" -> "ta", "ta" -> "ta", "Hindi" -> "hi", "en" -> "en"
 */
export function normalizeLanguageCode(lang: string): string {
  if (!lang || typeof lang !== "string") return "en";
  let trimmed = lang.trim().toLowerCase();

  // If contains locale delimiter like en_us or en-US, split to base language code
  if (trimmed.includes("-") || trimmed.includes("_")) {
    const base = trimmed.split(/[-_]/)[0].toLowerCase();
    if (base.length >= 2 && base.length <= 3) {
      trimmed = base;
    }
  }

  // If already a valid 2 or 3 letter code in the values set
  if (trimmed.length >= 2 && trimmed.length <= 3) {
    return trimmed;
  }

  // Look up in name-to-code map
  return LANGUAGE_NAME_TO_CODE[trimmed] || trimmed;
}

/**
 * Normalizes an array of language inputs, ensuring deduplication and fallback.
 */
export function normalizeLanguageCodes(langs: string[]): string[] {
  if (!Array.isArray(langs)) return ["en"];
  const normalized = langs
    .map(normalizeLanguageCode)
    .filter((code) => code && code.length >= 2);
  
  return Array.from(new Set(normalized));
}

/**
 * 📜 Unicode Script Identification
 * Scans text (e.g. video title, description, tags, transcript) for authentic native scripts.
 * Returns candidate ISO 639-1 language codes with matching character count and script name.
 */
export interface ScriptMatchResult {
  language: string;
  script: string;
  matchCount: number;
}

export function detectScriptsFromText(text: string): ScriptMatchResult[] {
  if (!text || typeof text !== "string") return [];

  const scriptPatterns: Array<{ script: string; language: string; regex: RegExp }> = [
    { script: "Telugu", language: "te", regex: /[\u0C00-\u0C7F]/g },
    { script: "Tamil", language: "ta", regex: /[\u0B80-\u0BFF]/g },
    { script: "Kannada", language: "kn", regex: /[\u0C80-\u0CFF]/g },
    { script: "Malayalam", language: "ml", regex: /[\u0D00-\u0D7F]/g },
    { script: "Devanagari", language: "hi", regex: /[\u0900-\u097F]/g },
    { script: "Bengali", language: "bn", regex: /[\u0980-\u09FF]/g },
    { script: "Gujarati", language: "gu", regex: /[\u0A80-\u0AFF]/g },
    { script: "Gurmukhi", language: "pa", regex: /[\u0A00-\u0A7F]/g },
    { script: "Odia", language: "or", regex: /[\u0B00-\u0B7F]/g },
    { script: "Arabic", language: "ar", regex: /[\u0600-\u06FF\u0750-\u077F]/g },
    { script: "Japanese-Kana", language: "ja", regex: /[\u3040-\u309F\u30A0-\u30FF]/g },
    { script: "Hangul", language: "ko", regex: /[\uAC00-\uD7AF\u1100-\u11FF]/g },
    { script: "Hanzi", language: "zh", regex: /[\u4E00-\u9FFF]/g },
    { script: "Cyrillic", language: "ru", regex: /[\u0400-\u04FF]/g },
    { script: "Greek", language: "el", regex: /[\u0370-\u03FF]/g },
    { script: "Hebrew", language: "he", regex: /[\u0590-\u05FF]/g },
    { script: "Thai", language: "th", regex: /[\u0E00-\u0E7F]/g },
  ];

  const results: ScriptMatchResult[] = [];
  for (const { script, language, regex } of scriptPatterns) {
    const matches = text.match(regex);
    if (matches && matches.length >= 2) {
      results.push({
        script,
        language,
        matchCount: matches.length,
      });
    }
  }

  return results.sort((a, b) => b.matchCount - a.matchCount);
}
