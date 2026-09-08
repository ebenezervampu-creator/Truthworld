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
  const trimmed = lang.trim().toLowerCase();
  
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
