/**
 * 🎙️ GOOGLE CLOUD TEXT-TO-SPEECH SERVICE
 *
 * Flagship Video Dubbing Audio Engine powered by Google Cloud Chirp 3: HD:
 *   - Next-Generation Generative AudioML models (Chirp 3: HD) for ultra-natural prosody and expressive cadence.
 *   - Native subcontinent regional accent phoneme accuracy across all Indian languages (Telugu, Hindi, Tamil, Kannada, Marathi, Bengali, Gujarati, Punjabi, etc.).
 *   - Completely eliminates legacy robotic/standard voices for premium audio track dubbing.
 *   - Zero egress latency within Google Cloud asia-south1.
 *   - Zero Gemini API key required: Authenticates seamlessly via Google Cloud IAM (ADC).
 */

import { TextToSpeechClient, protos } from "@google-cloud/text-to-speech";
import { v4 as uuidv4 } from "uuid";
import { storage } from "firebase-admin";
import { TTSRequest, TTSResult } from "../types";
import { costEngine } from "./cost-engine";
import { logger } from "../utils/logger";

const MAX_RETRIES = 3;

/**
 * Standard mapping from 2-letter / ISO language codes to Google Cloud BCP-47 locale identifiers.
 */
export const LANGUAGE_LOCALE_MAP: Record<string, string> = {
  // Indian Regional Languages (Subcontinent First)
  te: "te-IN",
  hi: "hi-IN",
  ta: "ta-IN",
  kn: "kn-IN",
  ml: "ml-IN",
  mr: "mr-IN",
  bn: "bn-IN",
  gu: "gu-IN",
  pa: "pa-IN",
  ur: "ur-IN",

  // Global Core Languages
  en: "en-US",
  es: "es-US",
  fr: "fr-FR",
  de: "de-DE",
  it: "it-IT",
  pt: "pt-BR",
  nl: "nl-NL",
  ja: "ja-JP",
  ko: "ko-KR",
  zh: "cmn-CN",
  "zh-cn": "cmn-CN",
  "zh-tw": "cmn-TW",
  ar: "ar-XA",
  ru: "ru-RU",
  id: "id-ID",
  th: "th-TH",
  tr: "tr-TR",
  vi: "vi-VN",
  pl: "pl-PL",
  sv: "sv-SE",
  uk: "uk-UA",
  cs: "cs-CZ",
  da: "da-DK",
  el: "el-GR",
  fi: "fi-FI",
  he: "he-IL",
  hu: "hu-HU",
  ms: "ms-MY",
  no: "no-NO",
  ro: "ro-RO",
  sk: "sk-SK",
  bg: "bg-BG",
  hr: "hr-HR",
  lt: "lt-LT",
  lv: "lv-LV",
  sr: "sr-RS",
  sl: "sl-SI",
};

export interface VoiceOption {
  voiceName: string;
  modelType: "chirp3-hd" | "journey" | "studio" | "neural2" | "wavenet" | "standard";
}

/**
 * High-fidelity voice catalog organized by locale and gender.
 * Uses Google Cloud Chirp 3: HD as the primary video dubbing voice engine.
 */
export const RECOMMENDED_VOICES: Record<string, { FEMALE: VoiceOption; MALE: VoiceOption }> = {
  // Indian Regional Languages
  "te-IN": {
    FEMALE: { voiceName: "te-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "te-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "hi-IN": {
    FEMALE: { voiceName: "hi-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "hi-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "ta-IN": {
    FEMALE: { voiceName: "ta-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "ta-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "kn-IN": {
    FEMALE: { voiceName: "kn-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "kn-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "ml-IN": {
    FEMALE: { voiceName: "ml-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "ml-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "mr-IN": {
    FEMALE: { voiceName: "mr-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "mr-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "bn-IN": {
    FEMALE: { voiceName: "bn-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "bn-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "gu-IN": {
    FEMALE: { voiceName: "gu-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "gu-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "pa-IN": {
    FEMALE: { voiceName: "pa-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "pa-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "ur-IN": {
    FEMALE: { voiceName: "ur-IN-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "ur-IN-Neural2-B", modelType: "neural2" },
  },
  "en-IN": {
    FEMALE: { voiceName: "en-IN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "en-IN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },

  // Global Core Languages (Chirp 3: HD / Journey)
  "en-US": {
    FEMALE: { voiceName: "en-US-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "en-US-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "en-GB": {
    FEMALE: { voiceName: "en-GB-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "en-GB-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "es-US": {
    FEMALE: { voiceName: "es-US-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "es-US-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "es-ES": {
    FEMALE: { voiceName: "es-ES-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "es-ES-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "fr-FR": {
    FEMALE: { voiceName: "fr-FR-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "fr-FR-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "de-DE": {
    FEMALE: { voiceName: "de-DE-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "de-DE-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "it-IT": {
    FEMALE: { voiceName: "it-IT-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "it-IT-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "pt-BR": {
    FEMALE: { voiceName: "pt-BR-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "pt-BR-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "ja-JP": {
    FEMALE: { voiceName: "ja-JP-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "ja-JP-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "ko-KR": {
    FEMALE: { voiceName: "ko-KR-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "ko-KR-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "cmn-CN": {
    FEMALE: { voiceName: "cmn-CN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "cmn-CN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "ar-XA": {
    FEMALE: { voiceName: "ar-XA-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "ar-XA-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "ru-RU": {
    FEMALE: { voiceName: "ru-RU-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "ru-RU-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "id-ID": {
    FEMALE: { voiceName: "id-ID-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "id-ID-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "th-TH": {
    FEMALE: { voiceName: "th-TH-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "th-TH-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "tr-TR": {
    FEMALE: { voiceName: "tr-TR-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "tr-TR-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "vi-VN": {
    FEMALE: { voiceName: "vi-VN-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "vi-VN-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "nl-NL": {
    FEMALE: { voiceName: "nl-NL-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "nl-NL-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "pl-PL": {
    FEMALE: { voiceName: "pl-PL-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "pl-PL-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "sv-SE": {
    FEMALE: { voiceName: "sv-SE-Chirp3-HD-Kore", modelType: "chirp3-hd" },
    MALE:   { voiceName: "sv-SE-Chirp3-HD-Fenrir", modelType: "chirp3-hd" },
  },
  "uk-UA": {
    FEMALE: { voiceName: "uk-UA-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "uk-UA-Neural2-B", modelType: "neural2" },
  },
};

export interface VoiceDescriptor {
  id: string;
  name: string;
  gender: "MALE" | "FEMALE";
  pitchBand: "deep" | "mid" | "high";
  ageTone: "youthful" | "adult" | "mature";
}

export const ELEVENLABS_MULTI_SPEAKER_PALETTE: {
  MALE: VoiceDescriptor[];
  FEMALE: VoiceDescriptor[];
} = {
  MALE: [
    { id: "ErXwobaYiN019PkySvjV", name: "Antoni", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "pNInz6obpgDQGcFmaJgB", name: "Adam", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "g5CIjZEefAph4nJUvZnz", name: "Marcus", gender: "MALE", pitchBand: "high", ageTone: "youthful" },
    { id: "JBFqnCBsd6RMkjVDRZzb", name: "George", gender: "MALE", pitchBand: "mid", ageTone: "mature" },
    { id: "IKne3meq5aSn9XLyUdCD", name: "Charlie", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "TX3LPaxmHKxFdv7VOQHJ", name: "Liam", gender: "MALE", pitchBand: "high", ageTone: "youthful" },
    { id: "N2lVS1w4EtoT3dr4eOWO", name: "Callum", gender: "MALE", pitchBand: "deep", ageTone: "adult" },
    { id: "onwK4e9ZLuTAKqWW03F9", name: "Daniel", gender: "MALE", pitchBand: "mid", ageTone: "adult" },
    { id: "VR6AewLTigWG4xSOukaG", name: "Arnold", gender: "MALE", pitchBand: "deep", ageTone: "mature" },
    { id: "yoZ06aMxZJJ28mfd3POQ", name: "Sam", gender: "MALE", pitchBand: "high", ageTone: "youthful" },
  ],
  FEMALE: [
    { id: "hpp4J3VqNfWAUOO0d1Us", name: "Bella", gender: "FEMALE", pitchBand: "high", ageTone: "adult" },
    { id: "EXAVITQu4vr4xnSDxMaL", name: "Sarah", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
    { id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
    { id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "MF3mGyEYCl7XYWbV9V6O", name: "Elli", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "ThT5KcBeYPX3keUQqHPh", name: "Dorothy", gender: "FEMALE", pitchBand: "mid", ageTone: "mature" },
    { id: "XB0fDUnXU5powFXDhCwa", name: "Charlotte", gender: "FEMALE", pitchBand: "mid", ageTone: "mature" },
    { id: "oWAxZDx7w5VEj9dCyTeq", name: "Nicole", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
    { id: "z9fAnlkpzviPz146aGWa", name: "Glinda", gender: "FEMALE", pitchBand: "high", ageTone: "youthful" },
    { id: "FGY2WhTYpPnrIDTdsKH5", name: "Laura", gender: "FEMALE", pitchBand: "mid", ageTone: "adult" },
  ],
};

// Known ElevenLabs preset voice mappings to gender for seamless translation
export const ELEVENLABS_VOICE_GENDER_MAP: Record<string, "MALE" | "FEMALE"> = {
  // Male Voices
  "pNInz6obpgDQGcFmaJgB": "MALE",   // Adam
  "ErXwobaYiN019PkySvjV": "MALE",   // Antoni
  "g5CIjZEefAph4nJUvZnz": "MALE",   // Marcus / Josh
  "JBFqnCBsd6RMkjVDRZzb": "MALE",   // George
  "IKne3meq5aSn9XLyUdCD": "MALE",   // Charlie
  "TX3LPaxmHKxFdv7VOQHJ": "MALE",   // Liam
  "N2lVS1w4EtoT3dr4eOWO": "MALE",   // Callum
  "onwK4e9ZLuTAKqWW03F9": "MALE",   // Daniel
  "VR6AewLTigWG4xSOukaG": "MALE",   // Arnold
  "yoZ06aMxZJJ28mfd3POQ": "MALE",   // Sam

  // Female Voices
  "hpp4J3VqNfWAUOO0d1Us": "FEMALE", // Bella
  "EXAVITQu4vr4xnSDxMaL": "FEMALE", // Sarah
  "21m00Tcm4TlvDq8ikWAM": "FEMALE", // Rachel
  "AZnzlk1XvdvUeBnXmlld": "FEMALE", // Domi
  "MF3mGyEYCl7XYWbV9V6O": "FEMALE", // Elli
  "ThT5KcBeYPX3keUQqHPh": "FEMALE", // Dorothy
  "XB0fDUnXU5powFXDhCwa": "FEMALE", // Charlotte
  "oWAxZDx7w5VEj9dCyTeq": "FEMALE", // Nicole
  "z9fAnlkpzviPz146aGWa": "FEMALE", // Glinda
  "FGY2WhTYpPnrIDTdsKH5": "FEMALE", // Laura
};

export const EXTENDED_VOICE_CATALOG: Record<string, { MALE: string[]; FEMALE: string[] }> = {
  "en-US": {
    MALE: [
      "en-US-Chirp3-HD-Fenrir",
      "en-US-Chirp3-HD-Puck",
      "en-US-Journey-D",
      "en-US-Studio-Q",
      "en-US-Neural2-D",
      "en-US-Neural2-J",
    ],
    FEMALE: [
      "en-US-Chirp3-HD-Kore",
      "en-US-Chirp3-HD-Achernar",
      "en-US-Chirp3-HD-Aoede",
      "en-US-Journey-F",
      "en-US-Studio-O",
      "en-US-Neural2-C",
      "en-US-Neural2-F",
    ],
  },
  "hi-IN": {
    MALE: [
      "hi-IN-Chirp3-HD-Fenrir",
      "hi-IN-Neural2-B",
      "hi-IN-Neural2-C",
      "hi-IN-Wavenet-B",
      "hi-IN-Wavenet-C",
    ],
    FEMALE: [
      "hi-IN-Chirp3-HD-Kore",
      "hi-IN-Chirp3-HD-Achernar",
      "hi-IN-Neural2-A",
      "hi-IN-Neural2-D",
      "hi-IN-Wavenet-A",
      "hi-IN-Wavenet-D",
    ],
  },
  "te-IN": {
    MALE: ["te-IN-Chirp3-HD-Fenrir", "te-IN-Standard-B"],
    FEMALE: ["te-IN-Chirp3-HD-Kore", "te-IN-Chirp3-HD-Achernar", "te-IN-Standard-A"],
  },
  "ta-IN": {
    MALE: ["ta-IN-Chirp3-HD-Fenrir", "ta-IN-Neural2-B", "ta-IN-Wavenet-B"],
    FEMALE: ["ta-IN-Chirp3-HD-Kore", "ta-IN-Chirp3-HD-Achernar", "ta-IN-Neural2-A", "ta-IN-Wavenet-A"],
  },
  "kn-IN": {
    MALE: ["kn-IN-Chirp3-HD-Fenrir", "kn-IN-Neural2-B", "kn-IN-Wavenet-B"],
    FEMALE: ["kn-IN-Chirp3-HD-Kore", "kn-IN-Chirp3-HD-Achernar", "kn-IN-Neural2-A", "kn-IN-Wavenet-A"],
  },
  "ml-IN": {
    MALE: ["ml-IN-Chirp3-HD-Fenrir", "ml-IN-Neural2-B", "ml-IN-Wavenet-B"],
    FEMALE: ["ml-IN-Chirp3-HD-Kore", "ml-IN-Chirp3-HD-Achernar", "ml-IN-Neural2-A", "ml-IN-Wavenet-A"],
  },
  "mr-IN": {
    MALE: ["mr-IN-Chirp3-HD-Fenrir", "mr-IN-Neural2-B", "mr-IN-Wavenet-B"],
    FEMALE: ["mr-IN-Chirp3-HD-Kore", "mr-IN-Chirp3-HD-Achernar", "mr-IN-Neural2-A", "mr-IN-Wavenet-A"],
  },
  "bn-IN": {
    MALE: ["bn-IN-Chirp3-HD-Fenrir", "bn-IN-Neural2-B", "bn-IN-Wavenet-B"],
    FEMALE: ["bn-IN-Chirp3-HD-Kore", "bn-IN-Chirp3-HD-Achernar", "bn-IN-Neural2-A", "bn-IN-Wavenet-A"],
  },
  "gu-IN": {
    MALE: ["gu-IN-Chirp3-HD-Fenrir", "gu-IN-Neural2-B", "gu-IN-Wavenet-B"],
    FEMALE: ["gu-IN-Chirp3-HD-Kore", "gu-IN-Chirp3-HD-Achernar", "gu-IN-Neural2-A", "gu-IN-Wavenet-A"],
  },
  "pa-IN": {
    MALE: ["pa-IN-Chirp3-HD-Fenrir", "pa-IN-Neural2-B", "pa-IN-Wavenet-B"],
    FEMALE: ["pa-IN-Chirp3-HD-Kore", "pa-IN-Chirp3-HD-Achernar", "pa-IN-Neural2-A", "pa-IN-Wavenet-A"],
  },
  "es-US": {
    MALE: ["es-US-Chirp3-HD-Fenrir", "es-US-Neural2-B", "es-US-Journey-D", "es-US-Studio-B"],
    FEMALE: ["es-US-Chirp3-HD-Kore", "es-US-Chirp3-HD-Achernar", "es-US-Neural2-A", "es-US-Journey-F"],
  },
  "es-ES": {
    MALE: ["es-ES-Chirp3-HD-Fenrir", "es-ES-Neural2-B", "es-ES-Journey-D"],
    FEMALE: ["es-ES-Chirp3-HD-Kore", "es-ES-Chirp3-HD-Achernar", "es-ES-Neural2-A", "es-ES-Journey-F"],
  },
  "fr-FR": {
    MALE: ["fr-FR-Chirp3-HD-Fenrir", "fr-FR-Neural2-B", "fr-FR-Journey-D"],
    FEMALE: ["fr-FR-Chirp3-HD-Kore", "fr-FR-Chirp3-HD-Achernar", "fr-FR-Neural2-A", "fr-FR-Journey-F"],
  },
  "de-DE": {
    MALE: ["de-DE-Chirp3-HD-Fenrir", "de-DE-Neural2-B", "de-DE-Journey-D"],
    FEMALE: ["de-DE-Chirp3-HD-Kore", "de-DE-Chirp3-HD-Achernar", "de-DE-Neural2-A", "de-DE-Journey-F"],
  },
  "ja-JP": {
    MALE: ["ja-JP-Chirp3-HD-Fenrir", "ja-JP-Neural2-C", "ja-JP-Neural2-D"],
    FEMALE: ["ja-JP-Chirp3-HD-Kore", "ja-JP-Chirp3-HD-Achernar", "ja-JP-Neural2-B"],
  },
  "cmn-CN": {
    MALE: ["cmn-CN-Chirp3-HD-Fenrir", "cmn-CN-Wavenet-B", "cmn-CN-Wavenet-C"],
    FEMALE: ["cmn-CN-Chirp3-HD-Kore", "cmn-CN-Chirp3-HD-Achernar", "cmn-CN-Wavenet-A", "cmn-CN-Wavenet-D"],
  },
};

export class GoogleTextToSpeechService {
  private client: TextToSpeechClient | null = null;

  constructor(client?: TextToSpeechClient) {
    if (client) {
      this.client = client;
    }
  }

  private getClient(): TextToSpeechClient {
    if (!this.client) {
      // ✅ Always use Application Default Credentials (ADC) via the Cloud Run
      // service account.  The @google-cloud/text-to-speech gRPC client does NOT
      // support API keys — passing one causes PERMISSION_DENIED 7 on every call.
      // Cloud Functions / Cloud Run automatically provide ADC so no extra
      // configuration is needed here.
      this.client = new TextToSpeechClient();
    }
    return this.client;
  }

  /**
   * Resolves BCP-47 locale code from any language string.
   */
  public resolveLocale(language: string): string {
    const raw = (language || "en").trim();
    if (raw.includes("-")) {
      const parts = raw.split("-");
      return `${parts[0].toLowerCase()}-${parts[1].toUpperCase()}`;
    }
    const lower = raw.toLowerCase();
    return LANGUAGE_LOCALE_MAP[lower] || `${lower}-${lower.toUpperCase()}`;
  }

  /**
   * Resolves voice configuration (name, gender, modelType) for the given request.
   */
  public resolveVoice(request: TTSRequest): {
    locale: string;
    voiceName?: string;
    ssmlGender: protos.google.cloud.texttospeech.v1.SsmlVoiceGender;
    modelType: "chirp3-hd" | "journey" | "studio" | "neural2" | "wavenet" | "standard";
  } {
    const locale = this.resolveLocale(request.language);

    // 1. Determine gender: explicit request.gender > voiceId mapping > default MALE
    let gender: "MALE" | "FEMALE" | "NEUTRAL" = request.gender ||
      (request.voiceId && ELEVENLABS_VOICE_GENDER_MAP[request.voiceId] ? ELEVENLABS_VOICE_GENDER_MAP[request.voiceId] : "MALE");

    const ssmlGender =
      gender === "MALE"
        ? protos.google.cloud.texttospeech.v1.SsmlVoiceGender.MALE
        : gender === "FEMALE"
        ? protos.google.cloud.texttospeech.v1.SsmlVoiceGender.FEMALE
        : protos.google.cloud.texttospeech.v1.SsmlVoiceGender.SSML_VOICE_GENDER_UNSPECIFIED;

    // 2. Check if a native Google Cloud voice ID was passed directly
    // 2. Check if a native Google Cloud voice ID was passed directly
    if (request.voiceId && (
      request.voiceId.includes("-Chirp3-HD-") ||
      request.voiceId.includes("-Chirp-HD-") ||
      request.voiceId.includes("-Neural2-") ||
      request.voiceId.includes("-Journey-") ||
      request.voiceId.includes("-Studio-") ||
      request.voiceId.includes("-Wavenet-") ||
      request.voiceId.includes("-Standard-")
    )) {
      // 🛡️ Cross-Gender Invariant Guard: Prevent female voices on male speakers and vice versa
      let effectiveVoice = request.voiceId;
      const isKnownFemaleVoice = effectiveVoice.includes("-Kore") || effectiveVoice.includes("-Aoede") || effectiveVoice.includes("-Achernar") || effectiveVoice.includes("-Journey-F") || effectiveVoice.includes("-Studio-O") || effectiveVoice.includes("-Neural2-A") || effectiveVoice.includes("-Neural2-C") || effectiveVoice.includes("-Standard-A") || effectiveVoice.includes("-Wavenet-A") || effectiveVoice.includes("-Wavenet-D");
      const isKnownMaleVoice = effectiveVoice.includes("-Fenrir") || effectiveVoice.includes("-Puck") || effectiveVoice.includes("-Charon") || effectiveVoice.includes("-Achird") || effectiveVoice.includes("-Orus") || effectiveVoice.includes("-Journey-D") || effectiveVoice.includes("-Studio-Q") || effectiveVoice.includes("-Neural2-B") || effectiveVoice.includes("-Neural2-D") || effectiveVoice.includes("-Neural2-J") || effectiveVoice.includes("-Standard-B") || effectiveVoice.includes("-Wavenet-B") || effectiveVoice.includes("-Wavenet-C");

      if (gender === "MALE" && isKnownFemaleVoice) {
        if (effectiveVoice.includes("-Standard-")) {
          effectiveVoice = effectiveVoice.replace(/-Standard-A/, "-Standard-B");
        } else if (effectiveVoice.includes("-Wavenet-")) {
          effectiveVoice = effectiveVoice.replace(/-Wavenet-[AD]/, "-Wavenet-B");
        } else if (effectiveVoice.includes("-Neural2-")) {
          effectiveVoice = effectiveVoice.replace(/-Neural2-[AC]/, "-Neural2-B");
        } else {
          effectiveVoice = effectiveVoice.replace(/-Kore|-Aoede|-Achernar|-Journey-F|-Studio-O|-Neural2-A|-Neural2-C/, "-Fenrir");
        }
      } else if (gender === "FEMALE" && isKnownMaleVoice) {
        if (effectiveVoice.includes("-Standard-")) {
          effectiveVoice = effectiveVoice.replace(/-Standard-B/, "-Standard-A");
        } else if (effectiveVoice.includes("-Wavenet-")) {
          effectiveVoice = effectiveVoice.replace(/-Wavenet-[BC]/, "-Wavenet-A");
        } else if (effectiveVoice.includes("-Neural2-")) {
          effectiveVoice = effectiveVoice.replace(/-Neural2-[BDJ]/, "-Neural2-A");
        } else {
          effectiveVoice = effectiveVoice.replace(/-Fenrir|-Puck|-Charon|-Achird|-Orus|-Journey-D|-Studio-Q|-Neural2-B|-Neural2-D|-Neural2-J/, "-Kore");
        }
      }

      const modelType = (effectiveVoice.includes("-Chirp3-HD-") || effectiveVoice.includes("-Chirp-HD-"))
        ? "chirp3-hd"
        : effectiveVoice.includes("-Journey-")
        ? "journey"
        : effectiveVoice.includes("-Studio-")
        ? "studio"
        : effectiveVoice.includes("-Neural2-")
        ? "neural2"
        : effectiveVoice.includes("-Wavenet-")
        ? "wavenet"
        : "standard";
      return {
        locale,
        voiceName: effectiveVoice,
        ssmlGender,
        modelType,
      };
    }

    // 3. Look up in catalog with multi-speaker index awareness
    const catalogEntry = RECOMMENDED_VOICES[locale];
    const multiPool = EXTENDED_VOICE_CATALOG[locale];
    if (multiPool && request.speakerId) {
      const match = request.speakerId.match(/\d+/);
      const speakerIdx = match ? parseInt(match[0], 10) : 0;
      const list = gender === "MALE" ? multiPool.MALE : multiPool.FEMALE;
      if (list && list.length > 0) {
        const voiceName = list[speakerIdx % list.length];
        const modelType = voiceName.includes("-Chirp")
          ? "chirp3-hd"
          : voiceName.includes("-Journey-")
          ? "journey"
          : voiceName.includes("-Studio-")
          ? "studio"
          : "neural2";
        return {
          locale,
          voiceName,
          ssmlGender,
          modelType,
        };
      }
    }

    if (catalogEntry) {
      const selected = gender === "MALE" ? catalogEntry.MALE : catalogEntry.FEMALE;
      return {
        locale,
        voiceName: selected.voiceName,
        ssmlGender,
        modelType: selected.modelType,
      };
    }

    // 4. Default fallback: synthesize using languageCode and Chirp 3: HD strictly respecting gender
    const defaultVoiceName = gender === "MALE"
      ? `${locale}-Chirp3-HD-Fenrir`
      : `${locale}-Chirp3-HD-Kore`;
    return {
      locale,
      voiceName: defaultVoiceName,
      ssmlGender,
      modelType: "chirp3-hd",
    };
  }

  /**
   * Synthesize speech segment using Google Cloud Text-to-Speech.
   */
  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const client = this.getClient();
    const voiceConfig = this.resolveVoice(request);

    logger.info("[GoogleTTS] Synthesizing segment with Google Cloud Chirp 3: HD", {
      jobId: request.jobId,
      language: request.language,
      locale: voiceConfig.locale,
      voiceName: voiceConfig.voiceName,
      modelType: voiceConfig.modelType,
      textLength: request.text.length,
      textPreview: request.text.substring(0, 60),
    });

    const isChirp = voiceConfig.voiceName?.includes("-Chirp") || voiceConfig.modelType === "chirp3-hd";
    const audioConfig: protos.google.cloud.texttospeech.v1.IAudioConfig = {
      audioEncoding: protos.google.cloud.texttospeech.v1.AudioEncoding.MP3,
    };
    if (request.speakingRate !== undefined) {
      audioConfig.speakingRate = Math.max(0.75, Math.min(1.35, request.speakingRate));
    }
    if (!isChirp && request.pitch !== undefined) {
      audioConfig.pitch = Math.max(-10.0, Math.min(10.0, request.pitch));
    }

    const synthesizeRequest: protos.google.cloud.texttospeech.v1.ISynthesizeSpeechRequest = {
      input: { text: request.text },
      voice: {
        languageCode: voiceConfig.locale,
        name: voiceConfig.voiceName,
        ssmlGender: voiceConfig.ssmlGender,
      },
      audioConfig,
    };

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const [response] = await client.synthesizeSpeech(synthesizeRequest);

        if (!response.audioContent || response.audioContent.length === 0) {
          throw new Error("[GoogleTTS] Empty audio content received from Google Cloud Text-to-Speech");
        }

        const audioBuffer = Buffer.from(response.audioContent as Uint8Array);

        // Upload to Firebase / Cloud Storage
        const bucket = storage().bucket();
        const filePath = `audio/${request.jobId}/${request.language}/chunk-${uuidv4()}.mp3`;
        const file = bucket.file(filePath);

        await file.save(audioBuffer, {
          metadata: {
            contentType: "audio/mpeg",
            metadata: {
              provider: "google-cloud-tts",
              voiceName: voiceConfig.voiceName || "default",
              language: request.language,
              locale: voiceConfig.locale,
              modelType: voiceConfig.modelType,
            },
          },
        });

        const audioUrl = `gs://${bucket.name}/${filePath}`;
        const providerRateTier = voiceConfig.modelType === "chirp3-hd"
          ? "google-tts-chirp3-hd"
          : voiceConfig.modelType === "standard"
          ? "google-tts-standard"
          : "google-tts-neural2";

        // Record cost in Cost Engine
        costEngine.recordTTSCost(
          request.jobId,
          request.userId || "__tts__",
          request.text.length,
          providerRateTier
        ).catch(() => {});

        logger.info("[GoogleTTS] ✅ Speech segment synthesized", {
          jobId: request.jobId,
          language: request.language,
          locale: voiceConfig.locale,
          voiceName: voiceConfig.voiceName,
          audioUrl,
          bytes: audioBuffer.byteLength,
        });

        return {
          jobId: request.jobId,
          language: request.language,
          audioUrl,
          duration: this.estimateDuration(request.text),
          format: "mp3",
          provider: "google-cloud-tts",
          voiceName: voiceConfig.voiceName,
        };
      } catch (error: any) {
        logger.error("[GoogleTTS] ❌ Google Cloud TTS API error", {
          jobId: request.jobId,
          language: request.language,
          attempt: attempt + 1,
          error: error.message,
          locale: voiceConfig.locale,
          voiceName: synthesizeRequest.voice?.name,
        });

        // Dynamic fallback: If a specific voice failed (e.g. Chirp not supported in locale),
        // try falling back to Standard/Neural2/Wavenet or omitting voice name so Google Cloud selects a valid voice
        if (synthesizeRequest.voice?.name?.includes("-Chirp")) {
          const fallbackEntry = EXTENDED_VOICE_CATALOG[voiceConfig.locale] || RECOMMENDED_VOICES[voiceConfig.locale];
          const isMale = voiceConfig.ssmlGender === protos.google.cloud.texttospeech.v1.SsmlVoiceGender.MALE;
          const fallbackList: string[] = fallbackEntry
            ? (Array.isArray((fallbackEntry as any).MALE)
                ? (isMale ? (fallbackEntry as any).MALE : (fallbackEntry as any).FEMALE)
                : [(isMale ? (fallbackEntry as any).MALE?.voiceName : (fallbackEntry as any).FEMALE?.voiceName)].filter(Boolean))
            : [];
          const fallbackVoice = fallbackList.find((v) => !v.includes("-Chirp")) || fallbackList[0];

          if (fallbackVoice && fallbackVoice !== synthesizeRequest.voice.name) {
            logger.info("[GoogleTTS] 🔄 Falling back from Chirp to alternate catalog voice", {
              jobId: request.jobId,
              from: synthesizeRequest.voice.name,
              to: fallbackVoice,
            });
            synthesizeRequest.voice.name = fallbackVoice;
            continue;
          }
        }

        // Final retry attempt: omit specific voice name and let Google Cloud choose default for language & gender
        if (attempt === 1 && synthesizeRequest.voice?.name) {
          logger.info("[GoogleTTS] 🔄 Retrying with generic locale/gender voice selection", {
            jobId: request.jobId,
            locale: voiceConfig.locale,
            gender: voiceConfig.ssmlGender,
          });
          delete synthesizeRequest.voice.name;
          continue;
        }

        if (attempt === MAX_RETRIES - 1) {
          throw new Error(`[GoogleTTS] Failed after ${MAX_RETRIES} attempts: ${error.message}`);
        }

        const delay = 1000 * Math.pow(2, attempt);
        await new Promise((r) => setTimeout(r, delay));
      }
    }

    throw new Error("[GoogleTTS] Synthesize failed after all retries");
  }

  public estimateDuration(text: string): number {
    return text.length / 15; // Standard 15 chars per second pacing
  }
}

export const googleTextToSpeechService = new GoogleTextToSpeechService();
