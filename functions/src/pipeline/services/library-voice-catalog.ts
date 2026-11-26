/**
 * Curated ElevenLabs Voice Library catalog, per language.
 *
 * Built by scripts/build_voice_catalog.js from GET /v1/shared-voices and committed to
 * registry/library_voice_catalog.json. Voices are used directly by voice_id (paid plans can use
 * Voice Library voices without saving them to My Voices), so nothing is added to the ElevenLabs
 * account and the monthly voice-operations quota is not touched.
 *
 * If a library owner withdraws a voice, synthesis falls back to the speaker's preset voice
 * (see registerVoiceFallback in tts.ts).
 */
import * as catalogJson from "../registry/library_voice_catalog.json";
import {
  AGE_BUCKET_ANCHORS,
  normalizeElevenLabsAgeLabel,
  VERIFIED_PRESET_CALIBRATIONS,
  type AgeBucket,
  type ElevenLabsVoiceCandidate,
  type SpeakerGender,
} from "./voice-matcher";
import { INDIC_LANGUAGES } from "./voice-locale-policy";

export interface LibraryVoice {
  voiceId: string;
  publicOwnerId: string;
  name: string;
  gender: "male" | "female";
  age: string;
  accent?: string;
  verifiedForLanguage: boolean;
  noticePeriodDays: number;
  previewUrl?: string;
  /** ElevenLabs "descriptive" label, e.g. "calm", "deep", "warm" (catalogs built after Nov 2026). */
  descriptive?: string;
  /** ElevenLabs use case, e.g. "narrative_story", "conversational". */
  useCase?: string;
}

const NAME_STOPWORDS = new Set(["and", "the", "with", "for", "voice", "voices", "male", "female", "man", "woman", "telugu", "hindi", "tamil", "indian"]);

/** Descriptive words from names like "Seeta - Rich Telugu Story Narrator" → ["rich", "story", "narrator"]. */
export function nameDescriptors(name: string): string[] {
  const i = (name || "").search(/\s[-–—|:]\s/);
  if (i < 0) return [];
  return name
    .slice(i + 3)
    .toLowerCase()
    .split(/[^a-z]+/)
    .filter((w) => w.length >= 4 && !NAME_STOPWORDS.has(w));
}

export interface LibraryVoiceCatalog {
  version: number;
  generatedAt: string | null;
  languages: Record<string, LibraryVoice[]>;
}

const LANGUAGE_TAG: Record<string, string> = {
  te: "telugu", hi: "hindi", ta: "tamil", kn: "kannada", ml: "malayalam",
  bn: "bengali", mr: "marathi", gu: "gujarati", pa: "punjabi", or: "odia",
  as: "assamese", ur: "urdu", sd: "sindhi", ne: "nepali", sa: "sanskrit", ks: "kashmiri",
};

function baseLanguage(lang: string): string {
  const b = (lang || "").toLowerCase().trim().split(/[-_]/)[0];
  return b === "tl" ? "fil" : b;
}

export function loadLibraryCatalog(): LibraryVoiceCatalog {
  const raw: any = (catalogJson as any).default ?? catalogJson;
  return {
    version: Number(raw?.version) || 1,
    generatedAt: raw?.generatedAt ?? null,
    languages: raw?.languages && typeof raw.languages === "object" ? raw.languages : {},
  };
}

export function libraryVoicesFor(catalog: LibraryVoiceCatalog, lang: string): LibraryVoice[] {
  const base = baseLanguage(lang);
  const direct = catalog.languages[base] || [];
  if (direct.length > 0) return direct;

  // If this is an Indic language without dedicated catalog voices (e.g. sd, sa, ks),
  // provide curated Indic voices from other languages (hi, te, ta, etc.) so nativeTier
  // can assign them as Tier 1 Indian voices.
  if (INDIC_LANGUAGES.has(base)) {
    const fallbackIndic: LibraryVoice[] = [];
    const used = new Set<string>();
    for (const indicLang of ["hi", "te", "ta", "kn", "ml", "bn", "mr", "gu", "pa"]) {
      for (const v of catalog.languages[indicLang] || []) {
        if (!used.has(v.voiceId)) {
          used.add(v.voiceId);
          fallbackIndic.push(v);
        }
      }
    }
    return fallbackIndic;
  }

  return [];
}

export function toAgeBucket(age?: string): AgeBucket {
  return normalizeElevenLabsAgeLabel(age);
}

/** Shape the matcher's distance score understands. */
export function libraryVoiceToCandidate(v: LibraryVoice, lang: string): ElevenLabsVoiceCandidate {
  const cal = VERIFIED_PRESET_CALIBRATIONS[v.voiceId];
  const ageBucket = cal?.ageBucket ?? toAgeBucket(v.age);
  const repAge = cal?.representativeAge ?? AGE_BUCKET_ANCHORS[ageBucket];
  const typicalPitch = cal?.typicalPitchHz ?? (v.gender === "female" ? 205 : 118);
  const base = baseLanguage(lang);
  const tag = LANGUAGE_TAG[base];
  const isIndic = INDIC_LANGUAGES.has(base);
  return {
    voiceId: v.voiceId,
    name: cal?.name ?? v.name,
    gender: (cal?.gender as SpeakerGender) ?? v.gender,
    ageBucket,
    representativeAge: repAge,
    // When calibrated, typicalPitch is real calibrated pitch.
    typicalPitchHz: typicalPitch,
    // cal exists means it's a calibrated preset, so pitch is calibrated (pitchMeasured can be undefined).
    // Otherwise, false = gender default only.
    pitchMeasured: cal ? undefined : false,
    previewUrl: v.previewUrl,
    // "lang:<code>" marks the language this voice was curated for (voice-locale-policy.ts).
    timbreTags: Array.from(
      new Set(
        [
          v.accent === "standard" ? "" : v.accent,
          tag,
          isIndic ? "indian" : "",
          `lang:${base}`,
          v.descriptive,
          v.useCase,
          ...nameDescriptors(v.name),
          ...(cal?.timbreTags ?? []),
        ]
          .filter(Boolean)
          .map((t) => String(t).toLowerCase())
      )
    ),
    indicVerified: cal?.indicVerified ?? Boolean(tag || isIndic),
  };
}
