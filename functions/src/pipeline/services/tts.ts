/**
 * 🎙️ HYBRID TEXT-TO-SPEECH (TTS) SERVICE
 *
 * Industry-Standard Architecture combining Google Cloud Text-to-Speech & ElevenLabs:
 *   - Google Cloud Text-to-Speech (Default): Neural2, Journey, Studio, and Standard voices.
 *     Cuts unit cost by 50%-75%, offers 4M free characters/month, and delivers native
 *     subcontinent phoneme pronunciation across Indian languages (Telugu, Hindi, Tamil, etc.).
 *   - ElevenLabs: Reserved for explicit creator voice cloning requests (preferVoiceCloning: true).
 *   - Resilient Fallback: If ElevenLabs encounters rate limits, quota exhaustion, or failures,
 *     the pipeline automatically and seamlessly falls back to Google Cloud Text-to-Speech.
 */

import axios from "axios";
import { v4 as uuidv4 } from "uuid";
import { storage } from "firebase-admin";
import { TTSResult, TTSRequest } from "../types";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { GoogleTextToSpeechService, googleTextToSpeechService } from "./googleTextToSpeechService";

const ELEVENLABS_BASE_URL = "https://api.elevenlabs.io/v1";

const TTS_MODELS = {
  flash: "eleven_flash_v2_5",                // Best for batch dubbing (low latency)
  multilingual_v2: "eleven_multilingual_v2", // Stable fallback
  v3: "eleven_v3",                           // Premium narration
} as const;

/** Languages supported by ElevenLabs Flash v2.5 (32 languages) */
const FLASH_SUPPORTED = new Set([
  "en", "hi", "te", "ta", "ml", "kn", "bn", "gu", "mr", "pa",
  "zh", "ja", "ko", "ar", "cs", "da", "nl", "fi", "fr", "de",
  "el", "he", "hu", "id", "it", "ms", "no", "pl", "pt", "ro",
  "ru", "sk", "es", "sv", "th", "tr", "uk", "vi",
]);

/** Languages supported by ElevenLabs Multilingual v2 (29 languages) */
const MULTILINGUAL_V2_SUPPORTED = new Set([
  "en", "ja", "zh", "de", "hi", "fr", "ko", "pt", "it", "es",
  "id", "nl", "tr", "fil", "tl", "pl", "sv", "bg", "ro", "ar",
  "cs", "el", "fi", "hr", "ms", "sk", "ta", "uk", "ru",
]);

const MAX_RETRIES = 3;

interface VoiceSettings {
  stability: number;
  similarity_boost: number;
  style?: number;
  use_speaker_boost?: boolean;
}

export class ElevenLabsTTSService {
  private apiKey: string;
  private defaultVoiceSettings: VoiceSettings = {
    stability: 0.5,
    similarity_boost: 0.75,
    style: 0.3,
    use_speaker_boost: true,
  };

  constructor(apiKey?: string) {
    this.apiKey = apiKey || "";
  }

  public getApiKey(): string {
    return this.apiKey || PIPELINE_CONFIG.ELEVENLABS_API_KEY;
  }

  private selectModel(language: string): string {
    const langLower = language.toLowerCase().split("-")[0];
    if (FLASH_SUPPORTED.has(langLower)) {
      return TTS_MODELS.flash;
    }
    if (MULTILINGUAL_V2_SUPPORTED.has(langLower)) {
      return TTS_MODELS.multilingual_v2;
    }
    return TTS_MODELS.v3;
  }

  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const voiceId = request.voiceCloneId || request.voiceId || "EXAVITQu4vr4xnSDxMaL";
    const model = this.selectModel(request.language);
    const apiKey = this.getApiKey();

    if (!apiKey) {
      throw new Error("[ElevenLabsTTS] No ElevenLabs API key configured");
    }

    logger.info("[ElevenLabsTTS] Synthesizing segment", {
      jobId: request.jobId,
      language: request.language,
      model,
      voiceId,
      isVoiceClone: Boolean(request.voiceCloneId || request.preferVoiceCloning),
      textLength: request.text.length,
      textPreview: request.text.substring(0, 60),
    });

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const response = await axios.post(
          `${ELEVENLABS_BASE_URL}/text-to-speech/${voiceId}`,
          {
            text: request.text,
            model_id: model,
            voice_settings: this.defaultVoiceSettings,
          },
          {
            headers: {
              "xi-api-key": apiKey,
              "Content-Type": "application/json",
            },
            responseType: "arraybuffer",
            timeout: 60000,
          }
        );

        if (!response.data || response.data.byteLength === 0) {
          throw new Error("[ElevenLabsTTS] Empty audio response from ElevenLabs");
        }

        const bucket = storage().bucket();
        const filePath = `audio/${request.jobId}/${request.language}/chunk-${uuidv4()}.mp3`;
        const file = bucket.file(filePath);

        await file.save(response.data, {
          metadata: {
            contentType: "audio/mpeg",
            metadata: {
              provider: "elevenlabs",
              model,
              voiceId,
              language: request.language,
              isVoiceClone: String(Boolean(request.voiceCloneId || request.preferVoiceCloning)),
            },
          },
        });

        const audioUrl = `gs://${bucket.name}/${filePath}`;
        costEngine.recordTTSCost(
          request.jobId,
          request.userId || "__tts__",
          request.text.length,
          "elevenlabs"
        ).catch(() => {});

        logger.info("[ElevenLabsTTS] ✅ Segment synthesized", {
          jobId: request.jobId,
          language: request.language,
          audioUrl,
          bytes: response.data.byteLength,
        });

        return {
          jobId: request.jobId,
          language: request.language,
          audioUrl,
          duration: this.estimateDuration(request.text),
          format: "mp3",
          provider: "elevenlabs",
          voiceName: voiceId,
        };
      } catch (error: any) {
        const statusCode = error.response?.status;
        const errorBody = error.response?.data
          ? Buffer.isBuffer(error.response.data) || error.response.data instanceof ArrayBuffer
            ? new TextDecoder().decode(error.response.data)
            : JSON.stringify(error.response.data)
          : error.message;

        logger.error("[ElevenLabsTTS] ❌ ElevenLabs API error", {
          jobId: request.jobId,
          language: request.language,
          attempt: attempt + 1,
          statusCode,
          error: errorBody,
          model,
          voiceId,
        });

        if (attempt === MAX_RETRIES - 1) {
          throw new Error(`[ElevenLabsTTS] Failed after ${MAX_RETRIES} retries: ${statusCode} — ${errorBody}`);
        }

        const delay = 1000 * Math.pow(2, attempt);
        await new Promise((r) => setTimeout(r, delay));
      }
    }
    throw new Error("[ElevenLabsTTS] Synthesize failed after all retries");
  }

  private estimateDuration(text: string): number {
    return text.length / 15;
  }
}

export class TTSService {
  private googleTts: GoogleTextToSpeechService;
  private elevenLabsTts: ElevenLabsTTSService;

  constructor(
    googleTts?: GoogleTextToSpeechService,
    elevenLabsTts?: ElevenLabsTTSService
  ) {
    this.googleTts = googleTts || googleTextToSpeechService;
    this.elevenLabsTts = elevenLabsTts || new ElevenLabsTTSService();
  }

  /**
   * Unified synthesis entry point.
   * - Defaults to Google Cloud Text-to-Speech for standard dubbing (50%-75% cost savings).
   * - Routes to ElevenLabs if explicit voice cloning is requested.
   * - Automatically falls back to Google Cloud TTS if ElevenLabs fails, lacks quota, or is rate limited.
   */
  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const isVoiceCloningRequested = Boolean(
      request.preferVoiceCloning ||
      request.voiceCloneId ||
      request.provider === "elevenlabs"
    );

    // 1. Voice Cloning Requested -> Attempt ElevenLabs
    if (isVoiceCloningRequested) {
      const apiKey = this.elevenLabsTts.getApiKey();
      if (!apiKey) {
        logger.warn(
          "[TTS] ⚠️ Voice cloning requested but ElevenLabs API key is missing. Falling back to Google Cloud Text-to-Speech.",
          { jobId: request.jobId, language: request.language }
        );
        return this.googleTts.synthesize({
          ...request,
          preferVoiceCloning: false,
        });
      }

      try {
        return await this.elevenLabsTts.synthesize(request);
      } catch (err: any) {
        logger.warn(
          "[TTS] ⚠️ ElevenLabs voice cloning failed or quota exceeded. Seamlessly falling back to Google Cloud Text-to-Speech.",
          {
            jobId: request.jobId,
            language: request.language,
            error: err.message,
          }
        );

        // Resilient Fallback to Google Cloud Text-to-Speech
        return await this.googleTts.synthesize({
          ...request,
          preferVoiceCloning: false,
        });
      }
    }

    // 2. Standard Dubbing -> Google Cloud Text-to-Speech (High quality, native regional accents, cost-effective)
    try {
      return await this.googleTts.synthesize(request);
    } catch (googleErr: any) {
      // If Google Cloud TTS experiences an outage and ElevenLabs key exists, provide emergency fallback
      const elevenKey = this.elevenLabsTts.getApiKey();
      if (elevenKey) {
        logger.warn(
          "[TTS] ⚠️ Google Cloud TTS error — attempting emergency fallback to ElevenLabs.",
          {
            jobId: request.jobId,
            language: request.language,
            error: googleErr.message,
          }
        );
        try {
          return await this.elevenLabsTts.synthesize(request);
        } catch (elevenErr: any) {
          logger.error("[TTS] ❌ Both Google Cloud TTS and ElevenLabs fallback failed.", {
            jobId: request.jobId,
            googleError: googleErr.message,
            elevenError: elevenErr.message,
          });
        }
      }
      throw googleErr;
    }
  }

  public estimateDuration(text: string): number {
    return text.length / 15;
  }
}

export const elevenLabsTtsService = new ElevenLabsTTSService();
export const ttsService = new TTSService();
