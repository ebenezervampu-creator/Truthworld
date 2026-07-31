/**
 * 🎙️ TTS SERVICE — ElevenLabs v3 / Multilingual v2
 * 
 * Generates audio speech from translated text segments using ElevenLabs API.
 * Supports 70+ languages via model auto-selection.
 */

import axios from "axios";
import { v4 as uuidv4 } from "uuid";
import { storage } from "firebase-admin";
import { TTSResult, TTSRequest } from "../types";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";

const ELEVENLABS_BASE_URL = "https://api.elevenlabs.io/v1";

/**
 * Model selection:
 *   - eleven_flash_v2_5: Ultra-low latency (~75ms), 32 languages — best for batch dubbing
 *   - eleven_multilingual_v2: Consistent, lifelike quality, 29 languages — fallback
 *   - eleven_v3: Flagship, emotionally rich — for premium tier
 */
const TTS_MODELS = {
  flash: "eleven_flash_v2_5",          // Best for batch dubbing (low latency, good quality)
  multilingual_v2: "eleven_multilingual_v2", // Stable fallback
  v3: "eleven_v3",                     // Premium narration
} as const;

/** Languages supported by Flash v2.5 (32 languages) */
const FLASH_SUPPORTED = new Set([
  "en", "hi", "te", "ta", "ml", "kn", "bn", "gu", "mr", "pa",
  "zh", "ja", "ko", "ar", "cs", "da", "nl", "fi", "fr", "de",
  "el", "he", "hu", "id", "it", "ms", "no", "pl", "pt", "ro",
  "ru", "sk", "es", "sv", "th", "tr", "uk", "vi",
]);

const MAX_RETRIES = 3;

interface VoiceSettings {
  stability: number;
  similarity_boost: number;
  style?: number;
  use_speaker_boost?: boolean;
}

export class TTSService {
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

  private getApiKey(): string {
    return this.apiKey || PIPELINE_CONFIG.ELEVENLABS_API_KEY;
  }

  /**
   * Auto-select the best model for the target language.
   * Flash v2.5 is preferred for batch dubbing (low latency, good quality).
   */
  private selectModel(language: string): string {
    const langLower = language.toLowerCase().split("-")[0]; // "en-us" → "en"
    if (FLASH_SUPPORTED.has(langLower)) {
      return TTS_MODELS.flash;
    }
    return TTS_MODELS.multilingual_v2;
  }

  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const voiceId = request.voiceId || "EXAVITQu4vr4xnSDxMaL"; // Sarah (default valid premade voice)
    const model = this.selectModel(request.language);
    const apiKey = this.getApiKey();

    if (!apiKey) {
      throw new Error("[TTS] No ElevenLabs API key configured");
    }

    logger.info("[TTS] Synthesizing segment", {
      jobId: request.jobId,
      language: request.language,
      model,
      voiceId,
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

        // Verify we got audio data back
        if (!response.data || response.data.byteLength === 0) {
          throw new Error("[TTS] Empty audio response from ElevenLabs");
        }

        const bucket = storage().bucket();
        const filePath = `audio/${request.jobId}/${request.language}/chunk-${uuidv4()}.mp3`;
        const file = bucket.file(filePath);

        await file.save(response.data, {
          metadata: {
            contentType: "audio/mpeg",
            metadata: { model, voiceId, language: request.language },
          },
        });

        const audioUrl = `gs://${bucket.name}/${filePath}`;
        costEngine.recordTTSCost(request.jobId, "__tts__", request.text.length).catch(() => {});

        logger.info("[TTS] ✅ Segment synthesized", {
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
        };
      } catch (error: any) {
        const statusCode = error.response?.status;
        const errorBody = error.response?.data
          ? Buffer.isBuffer(error.response.data) || error.response.data instanceof ArrayBuffer
            ? new TextDecoder().decode(error.response.data)
            : JSON.stringify(error.response.data)
          : error.message;

        logger.error("[TTS] ❌ ElevenLabs API error", {
          jobId: request.jobId,
          language: request.language,
          attempt: attempt + 1,
          statusCode,
          error: errorBody,
          model,
          voiceId,
        });

        if (attempt === MAX_RETRIES - 1) {
          throw new Error(`[TTS] Failed after ${MAX_RETRIES} retries: ${statusCode} — ${errorBody}`);
        }

        // Exponential backoff
        const delay = 1000 * Math.pow(2, attempt);
        logger.info("[TTS] Retrying after delay", { delayMs: delay, attempt: attempt + 1 });
        await new Promise(r => setTimeout(r, delay));
      }
    }
    throw new Error("[TTS] Synthesize failed after all retries");
  }

  private estimateDuration(text: string): number {
    return text.length / 15; // Rough estimate: 15 chars per second
  }
}

export const ttsService = new TTSService();
