/**
 * 🎙️ GOOGLE CLOUD TEXT-TO-SPEECH SERVICE
 *
 * Industry-Standard TTS Engine leveraging Google Cloud Text-to-Speech:
 *   - Cutting-edge Neural2, Studio, Journey, and Standard voices.
 *   - Native subcontinent regional accent phoneme accuracy (Telugu, Hindi, Tamil, Kannada, Marathi, Bengali, Gujarati, etc.).
 *   - 50%-75% unit cost reduction ($0.000016 vs $0.000030/char) with 4M free characters/month.
 *   - Zero egress latency within Google Cloud asia-south1.
 */

import { TextToSpeechClient, protos } from "@google-cloud/text-to-speech";
import { v4 as uuidv4 } from "uuid";
import { storage } from "firebase-admin";
import { TTSRequest, TTSResult } from "../types";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
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
  modelType: "journey" | "studio" | "neural2" | "wavenet" | "standard";
}

/**
 * High-fidelity voice catalog organized by locale and gender.
 */
export const RECOMMENDED_VOICES: Record<string, { FEMALE: VoiceOption; MALE: VoiceOption }> = {
  // Indian Regional Languages
  "te-IN": {
    FEMALE: { voiceName: "te-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "te-IN-Standard-B", modelType: "standard" },
  },
  "hi-IN": {
    FEMALE: { voiceName: "hi-IN-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "hi-IN-Neural2-B", modelType: "neural2" },
  },
  "ta-IN": {
    FEMALE: { voiceName: "ta-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "ta-IN-Standard-B", modelType: "standard" },
  },
  "kn-IN": {
    FEMALE: { voiceName: "kn-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "kn-IN-Standard-B", modelType: "standard" },
  },
  "ml-IN": {
    FEMALE: { voiceName: "ml-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "ml-IN-Standard-B", modelType: "standard" },
  },
  "mr-IN": {
    FEMALE: { voiceName: "mr-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "mr-IN-Standard-B", modelType: "standard" },
  },
  "bn-IN": {
    FEMALE: { voiceName: "bn-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "bn-IN-Standard-B", modelType: "standard" },
  },
  "gu-IN": {
    FEMALE: { voiceName: "gu-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "gu-IN-Standard-B", modelType: "standard" },
  },
  "pa-IN": {
    FEMALE: { voiceName: "pa-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "pa-IN-Standard-B", modelType: "standard" },
  },
  "ur-IN": {
    FEMALE: { voiceName: "ur-IN-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "ur-IN-Standard-B", modelType: "standard" },
  },
  "en-IN": {
    FEMALE: { voiceName: "en-IN-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "en-IN-Neural2-B", modelType: "neural2" },
  },

  // Global Core Languages
  "en-US": {
    FEMALE: { voiceName: "en-US-Journey-F", modelType: "journey" },
    MALE:   { voiceName: "en-US-Journey-D", modelType: "journey" },
  },
  "en-GB": {
    FEMALE: { voiceName: "en-GB-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "en-GB-Neural2-B", modelType: "neural2" },
  },
  "es-US": {
    FEMALE: { voiceName: "es-US-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "es-US-Neural2-B", modelType: "neural2" },
  },
  "es-ES": {
    FEMALE: { voiceName: "es-ES-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "es-ES-Neural2-B", modelType: "neural2" },
  },
  "fr-FR": {
    FEMALE: { voiceName: "fr-FR-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "fr-FR-Neural2-B", modelType: "neural2" },
  },
  "de-DE": {
    FEMALE: { voiceName: "de-DE-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "de-DE-Neural2-B", modelType: "neural2" },
  },
  "it-IT": {
    FEMALE: { voiceName: "it-IT-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "it-IT-Neural2-C", modelType: "neural2" },
  },
  "pt-BR": {
    FEMALE: { voiceName: "pt-BR-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "pt-BR-Neural2-B", modelType: "neural2" },
  },
  "ja-JP": {
    FEMALE: { voiceName: "ja-JP-Neural2-B", modelType: "neural2" },
    MALE:   { voiceName: "ja-JP-Neural2-C", modelType: "neural2" },
  },
  "ko-KR": {
    FEMALE: { voiceName: "ko-KR-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "ko-KR-Neural2-C", modelType: "neural2" },
  },
  "cmn-CN": {
    FEMALE: { voiceName: "cmn-CN-Wavenet-A", modelType: "wavenet" },
    MALE:   { voiceName: "cmn-CN-Wavenet-B", modelType: "wavenet" },
  },
  "ar-XA": {
    FEMALE: { voiceName: "ar-XA-Wavenet-A", modelType: "wavenet" },
    MALE:   { voiceName: "ar-XA-Wavenet-B", modelType: "wavenet" },
  },
  "ru-RU": {
    FEMALE: { voiceName: "ru-RU-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "ru-RU-Neural2-B", modelType: "neural2" },
  },
  "id-ID": {
    FEMALE: { voiceName: "id-ID-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "id-ID-Neural2-B", modelType: "neural2" },
  },
  "th-TH": {
    FEMALE: { voiceName: "th-TH-Neural2-C", modelType: "neural2" },
    MALE:   { voiceName: "th-TH-Standard-A", modelType: "standard" },
  },
  "tr-TR": {
    FEMALE: { voiceName: "tr-TR-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "tr-TR-Neural2-B", modelType: "neural2" },
  },
  "vi-VN": {
    FEMALE: { voiceName: "vi-VN-Neural2-A", modelType: "neural2" },
    MALE:   { voiceName: "vi-VN-Neural2-D", modelType: "neural2" },
  },
  "nl-NL": {
    FEMALE: { voiceName: "nl-NL-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "nl-NL-Standard-B", modelType: "standard" },
  },
  "pl-PL": {
    FEMALE: { voiceName: "pl-PL-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "pl-PL-Standard-B", modelType: "standard" },
  },
  "sv-SE": {
    FEMALE: { voiceName: "sv-SE-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "sv-SE-Standard-A", modelType: "standard" },
  },
  "uk-UA": {
    FEMALE: { voiceName: "uk-UA-Standard-A", modelType: "standard" },
    MALE:   { voiceName: "uk-UA-Standard-A", modelType: "standard" },
  },
};

// Known ElevenLabs preset voice mappings to gender for seamless translation
const ELEVENLABS_VOICE_GENDER_MAP: Record<string, "MALE" | "FEMALE"> = {
  "pNInz6obpgDQGcFmaJgB": "MALE",   // Adam
  "ErXwobaYiN019PkySvjV": "MALE",   // Antoni
  "hpp4J3VqNfWAUOO0d1Us": "FEMALE", // Bella
  "EXAVITQu4vr4xnSDxMaL": "FEMALE", // Sarah
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
      const apiKey = PIPELINE_CONFIG.GOOGLE_TTS_API_KEY;
      if (apiKey) {
        this.client = new TextToSpeechClient({ apiKey });
      } else {
        // Fall back to ADC (Application Default Credentials)
        this.client = new TextToSpeechClient();
      }
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
    modelType: "journey" | "studio" | "neural2" | "wavenet" | "standard";
  } {
    const locale = this.resolveLocale(request.language);

    // 1. Determine gender: explicit request.gender > voiceId mapping > default FEMALE
    let gender: "MALE" | "FEMALE" | "NEUTRAL" = request.gender || "FEMALE";
    if (!request.gender && request.voiceId && ELEVENLABS_VOICE_GENDER_MAP[request.voiceId]) {
      gender = ELEVENLABS_VOICE_GENDER_MAP[request.voiceId];
    }

    const ssmlGender =
      gender === "MALE"
        ? protos.google.cloud.texttospeech.v1.SsmlVoiceGender.MALE
        : gender === "FEMALE"
        ? protos.google.cloud.texttospeech.v1.SsmlVoiceGender.FEMALE
        : protos.google.cloud.texttospeech.v1.SsmlVoiceGender.SSML_VOICE_GENDER_UNSPECIFIED;

    // 2. Check if a native Google Cloud voice ID was passed directly
    if (request.voiceId && (
      request.voiceId.includes("-Standard-") ||
      request.voiceId.includes("-Neural2-") ||
      request.voiceId.includes("-Journey-") ||
      request.voiceId.includes("-Studio-") ||
      request.voiceId.includes("-Wavenet-")
    )) {
      const isStandard = request.voiceId.includes("-Standard-");
      return {
        locale,
        voiceName: request.voiceId,
        ssmlGender,
        modelType: isStandard ? "standard" : "neural2",
      };
    }

    // 3. Look up in catalog
    const catalogEntry = RECOMMENDED_VOICES[locale];
    if (catalogEntry) {
      const selected = gender === "MALE" ? catalogEntry.MALE : catalogEntry.FEMALE;
      return {
        locale,
        voiceName: selected.voiceName,
        ssmlGender,
        modelType: selected.modelType,
      };
    }

    // 4. Default fallback: synthesize using languageCode and standard voice
    return {
      locale,
      voiceName: `${locale}-Standard-A`,
      ssmlGender,
      modelType: "standard",
    };
  }

  /**
   * Synthesize speech segment using Google Cloud Text-to-Speech.
   */
  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const client = this.getClient();
    const voiceConfig = this.resolveVoice(request);

    logger.info("[GoogleTTS] Synthesizing segment", {
      jobId: request.jobId,
      language: request.language,
      locale: voiceConfig.locale,
      voiceName: voiceConfig.voiceName,
      modelType: voiceConfig.modelType,
      textLength: request.text.length,
      textPreview: request.text.substring(0, 60),
    });

    const synthesizeRequest: protos.google.cloud.texttospeech.v1.ISynthesizeSpeechRequest = {
      input: { text: request.text },
      voice: {
        languageCode: voiceConfig.locale,
        name: voiceConfig.voiceName,
        ssmlGender: voiceConfig.ssmlGender,
      },
      audioConfig: {
        audioEncoding: protos.google.cloud.texttospeech.v1.AudioEncoding.MP3,
        speakingRate: request.speakingRate ?? 1.0,
        pitch: request.pitch ?? 0.0,
      },
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
        const providerRateTier = voiceConfig.modelType === "standard"
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
          voiceName: voiceConfig.voiceName,
        });

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
