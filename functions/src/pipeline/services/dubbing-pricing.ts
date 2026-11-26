/**
 * Character-based dubbing price (dependency-free, unit-tested).
 *
 * Price per language = the higher of
 *   - $0.30 per minute of video (60-second minimum) — the familiar "$3 for 10 minutes", and
 *   - $0.30 per 1,000 characters of DUBBED speech in that language.
 * ElevenLabs bills the voiced (target-language) characters, so the price follows the same unit:
 * talk-heavy videos and long-script languages cost more; most videos stay at the minute price.
 * With GST inside the price and a 2% gateway fee this keeps the profit share (dubbing-economics.ts)
 * on every simulated case, including a talk-heavy English→Malayalam video.
 *
 * Quotes are made from the transcript (every upload is transcribed): the source speech's
 * characters × how long the target language's text is relative to the source's
 * (CHAR_LENGTH_FACTOR). The same transcript always gives the same quote, so the price shown to the
 * creator and the price charged by the server match. The factors are starting estimates —
 * calibrate them from job_pacing_telemetry (ttsCharsInitial per language vs source characters).
 */

export const DUB_PRICE_PER_1K_CHARS_USD = 0.3;
export const DUB_PRICE_PER_MINUTE_USD = 0.3;
export const DUB_MIN_BILLED_SECONDS = 60;

/**
 * Characters of text for the same speech, relative to English (= 1). Rough starting values,
 * deliberately on the high side for long-script languages; unknown languages use
 * UNKNOWN_LENGTH_FACTOR so they are never under-quoted.
 */
export const CHAR_LENGTH_FACTOR: Readonly<Record<string, number>> = {
  en: 1.0,
  // Indic
  hi: 1.1, mr: 1.15, bn: 1.1, gu: 1.1, pa: 1.1, or: 1.2, as: 1.15, ur: 1.05, ne: 1.15,
  sa: 1.2, ks: 1.1, sd: 1.05, te: 1.25, kn: 1.3, ta: 1.4, ml: 1.45, si: 1.3,
  // European
  es: 1.2, fr: 1.2, de: 1.2, it: 1.15, pt: 1.2, nl: 1.2, ru: 1.15, pl: 1.15, sv: 1.1, no: 1.05,
  nn: 1.05, da: 1.1, fi: 1.2, cs: 1.1, sk: 1.1, el: 1.2, hu: 1.2, ro: 1.15, bg: 1.15, hr: 1.1,
  sr: 1.1, uk: 1.15, sl: 1.1, lt: 1.15, lv: 1.15, et: 1.15, ga: 1.3, cy: 1.2, ca: 1.2, gl: 1.2,
  eu: 1.3, is: 1.2, sq: 1.2, mk: 1.15, bs: 1.1,
  // Asian
  zh: 0.4, yue: 0.4, ja: 0.55, ko: 0.6, id: 1.25, ms: 1.25, vi: 1.25, th: 1.1, fil: 1.3, tl: 1.3,
  my: 1.4, km: 1.4, lo: 1.3, ka: 1.3, hy: 1.25, az: 1.2, kk: 1.2, uz: 1.25, mn: 1.25,
  // Middle East
  ar: 1.0, he: 0.9, fa: 1.0, tr: 1.15, ku: 1.2, ps: 1.1,
  // African
  sw: 1.25, af: 1.1, zu: 1.35, xh: 1.35, ha: 1.25, yo: 1.3, ig: 1.3, am: 0.9, so: 1.3,
};
export const UNKNOWN_LENGTH_FACTOR = 1.45;

function factor(lang: string): number {
  const base = (lang || "").toLowerCase().trim().split(/[-_]/)[0];
  return CHAR_LENGTH_FACTOR[base] ?? UNKNOWN_LENGTH_FACTOR;
}

/** Billable characters of a transcript: the spoken text, whitespace collapsed (spaces count, as for ElevenLabs). */
export function transcriptCharacters(transcript: { text?: unknown; utterances?: Array<{ text?: unknown }> } | null | undefined): number {
  if (!transcript) return 0;
  const parts = Array.isArray(transcript.utterances) && transcript.utterances.length > 0
    ? transcript.utterances.map((u) => (typeof u?.text === "string" ? u.text : ""))
    : [typeof transcript.text === "string" ? transcript.text : ""];
  return parts.join(" ").replace(/\s+/g, " ").trim().length;
}

/** Estimated characters of dubbed speech in targetLang for sourceChars of sourceLang speech. */
export function estimateDubbedChars(sourceChars: number, sourceLang: string, targetLang: string): number {
  if (!(sourceChars > 0)) return 0;
  return Math.ceil((sourceChars * factor(targetLang)) / factor(sourceLang));
}

const cents = (usd: number) => Math.round(usd * 100) / 100;
/** Rounds up to the cent, so a quote never under-charges by a fraction. */
const centsUp = (usd: number) => Math.ceil(Math.round(usd * 10000) / 100) / 100;

export function minutePriceUsd(durationSec: number): number {
  const billed = Math.max(DUB_MIN_BILLED_SECONDS, Number(durationSec) > 0 ? Number(durationSec) : 0);
  return cents((billed / 60) * DUB_PRICE_PER_MINUTE_USD);
}

export interface LanguageQuote {
  language: string;
  estimatedChars: number;
  minutePriceUsd: number;
  characterPriceUsd: number;
  priceUsd: number;
  basis: "minutes" | "characters";
}

export interface DubbingQuote {
  sourceLanguage: string;
  sourceChars: number;
  durationSec: number;
  languages: LanguageQuote[];
  subtotalUsd: number;
  discountPercent: number;
  totalUsd: number;
  pricePer1kCharsUsd: number;
  pricePerMinuteUsd: number;
}

export function quoteLanguage(durationSec: number, sourceChars: number, sourceLang: string, targetLang: string): LanguageQuote {
  const estimatedChars = estimateDubbedChars(sourceChars, sourceLang, targetLang);
  const byMinutes = minutePriceUsd(durationSec);
  const byChars = centsUp((estimatedChars / 1000) * DUB_PRICE_PER_1K_CHARS_USD);
  return {
    language: targetLang,
    estimatedChars,
    minutePriceUsd: byMinutes,
    characterPriceUsd: byChars,
    priceUsd: Math.max(byMinutes, byChars),
    basis: byChars > byMinutes ? "characters" : "minutes",
  };
}

/**
 * Dubbing discount for a channel, from fields only TruthWorld admins set on the channel document.
 * Never read from the request: a client-sent "free" flag let anyone dub for $0.
 */
export function channelDubbingDiscountPercent(channel: Record<string, any> | undefined, isAdmin: boolean): number {
  if (isAdmin) return 100;
  const ch = channel || {};
  const free =
    ch.isDubbingFree === true ||
    ch.dubbingDiscountType === "free" ||
    Number(ch.dubbingDiscountPercent) >= 100 ||
    ch.aiDiscounts?.dubbing?.type === "free" ||
    Number(ch.aiDiscounts?.dubbing?.percent) >= 100;
  if (free) return 100;
  const pct = Number(ch.dubbingDiscountPercent ?? ch.aiDiscounts?.dubbing?.percent ?? 0);
  return Number.isFinite(pct) ? Math.max(0, Math.min(100, pct)) : 0;
}

export interface DubbingCharge {
  /** What the server charges for dubbing (USD, after discount). */
  chargedUsd: number;
  /** Per language, after discount (feeds the margin budget in 07-dubbing.ts). */
  priceByLanguage: Record<string, number>;
  basis: "minutes" | "characters";
}

/**
 * THE dubbing charge. Used by both getDubbingQuote (what the creator sees) and
 * triggerVideoAIFeatures (what is charged), so the two can never differ.
 *  - Character pricing on and a quote available → the quote's total.
 *  - Otherwise → the per-minute price per language (the server's audio_track rate).
 */
export function dubbingCharge(input: {
  targetLanguages: string[];
  minutePricePerLanguageUsd: number;
  discountPercent: number;
  quote: DubbingQuote | null;
  characterPricing: boolean;
}): DubbingCharge {
  const pct = Math.max(0, Math.min(100, Number(input.discountPercent) || 0));
  const factor = (100 - pct) / 100;
  const priceByLanguage: Record<string, number> = {};
  if (input.characterPricing && input.quote) {
    for (const q of input.quote.languages) priceByLanguage[q.language] = cents(q.priceUsd * factor);
    return { chargedUsd: input.quote.totalUsd, priceByLanguage, basis: "characters" };
  }
  const flat = Math.max(0, Number(input.minutePricePerLanguageUsd) || 0);
  const base = cents(input.targetLanguages.length * flat);
  for (const l of input.targetLanguages) priceByLanguage[l] = cents(flat * factor);
  return { chargedUsd: pct > 0 ? cents(base * factor) : base, priceByLanguage, basis: "minutes" };
}

/** Quote for dubbing into every target language (excluding the source language). */
export function quoteDubbing(input: {
  durationSec: number;
  sourceChars: number;
  sourceLanguage: string;
  targetLanguages: string[];
  discountPercent?: number;
}): DubbingQuote {
  const src = (input.sourceLanguage || "").toLowerCase();
  const targets = Array.from(new Set(input.targetLanguages.map((l) => (l || "").toLowerCase()).filter((l) => l && l !== src)));
  const languages = targets.map((t) => quoteLanguage(input.durationSec, input.sourceChars, src, t));
  const subtotalUsd = cents(languages.reduce((sum, q) => sum + q.priceUsd, 0));
  const discountPercent = Math.max(0, Math.min(100, Number(input.discountPercent) || 0));
  return {
    sourceLanguage: src,
    sourceChars: Math.max(0, Math.floor(input.sourceChars || 0)),
    durationSec: Math.max(0, input.durationSec || 0),
    languages,
    subtotalUsd,
    discountPercent,
    totalUsd: cents(subtotalUsd * (100 - discountPercent) / 100),
    pricePer1kCharsUsd: DUB_PRICE_PER_1K_CHARS_USD,
    pricePerMinuteUsd: DUB_PRICE_PER_MINUTE_USD,
  };
}
