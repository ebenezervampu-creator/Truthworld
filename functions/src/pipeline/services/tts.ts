/**
 * 🎙️ TRUTHWORLD HYBRID TEXT-TO-SPEECH (TTS) SERVICE
 *
 * Audio Tracks Dubbing & Voice Cloning Architecture:
 *   - Video Audio Tracks Dubbing (Default): Powered by Google Cloud Chirp 3: HD
 *     (state-of-the-art generative AudioML model providing ultra-natural prosody and emotional cadence
 *     across 40+ languages including Telugu, Hindi, Tamil, Kannada, Malayalam, Marathi, Bengali, and global languages).
 *     Completely eliminates legacy robotic/standard voices. Zero Gemini API key required (uses Google Cloud IAM ADC).
 *   - Voice Cloning ONLY: Strictly powered by ElevenLabs (`eleven_v4` / `eleven_v3`) for creator voice cloning.
 *   - Resilient Fallback: If ElevenLabs encounters rate limits or quota exhaustion during voice cloning,
 *     seamlessly falls back to high-fidelity Google Cloud Chirp 3: HD.
 */

import axios from "axios";
import { v4 as uuidv4 } from "uuid";
import { storage } from "firebase-admin";
import { TTSResult, TTSRequest } from "../types";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { GoogleTextToSpeechService, googleTextToSpeechService, ELEVENLABS_VOICE_GENDER_MAP } from "./googleTextToSpeechService";

const ELEVENLABS_BASE_URL = "https://api.elevenlabs.io/v1";

const TTS_MODELS = {
  v4: "eleven_v4",                           // Tier 1 (First): Flagship Premium V4 — native support for 80+ languages
  v3: "eleven_v3",                           // Tier 2 (Fallback 1): Expressive narration & emotional dubbing
  flash: "eleven_flash_v2_5",                // Tier 3 (Fallback 2): Fast batch dubbing
  multilingual_v2: "eleven_multilingual_v2", // Long-form fallback
  v4Turbo: "eleven_v4_turbo",                // Fast low-latency V4
} as const;

/**
 * 80+ languages supported natively by ElevenLabs V4 Premium.
 * Covers Indian subcontinent, European, East/Southeast Asian, Middle Eastern, and African languages.
 */
const V4_PREMIUM_80_LANGUAGES = new Set([
  // 15 Indian languages
  "te", "hi", "ta", "kn", "ml", "bn", "mr", "gu", "pa", "or", "as", "ur", "sa", "ks", "sd",
  // Major Global & European languages
  "en", "es", "fr", "de", "it", "pt", "nl", "ru", "pl", "sv", "no", "da", "fi", "cs", "sk",
  "el", "hu", "ro", "bg", "hr", "sr", "uk", "sl", "lt", "lv", "et", "ga", "cy", "ca", "gl",
  "eu", "is", "sq", "mk", "bs",
  // East, Southeast & Central Asian languages
  "zh", "ja", "ko", "id", "ms", "vi", "th", "fil", "tl", "my", "km", "lo", "ka", "hy", "az",
  "kk", "uz", "mn", "ne", "si",
  // Middle Eastern languages
  "ar", "he", "fa", "tr", "ku", "ps",
  // African languages
  "sw", "af", "zu", "xh", "ha", "yo", "ig", "am", "so",
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

  public selectModel(language: string, request?: TTSRequest): string {
    // Audio Pro Tier: Strictly routes to ElevenLabs v4 Turbo (Fast)
    if (request?.ttsTier === "audio_pro" || request?.voiceType === "fast_api") {
      return TTS_MODELS.v4Turbo;
    }

    const langLower = (language || "en").toLowerCase().split("-")[0];

    // Tier 1 (First): ElevenLabs V4 Premium flagship first to support 80+ languages
    if (V4_PREMIUM_80_LANGUAGES.has(langLower) || !langLower || langLower === "en") {
      return TTS_MODELS.v4;
    }

    // Tier 2 (Fallback 1): ElevenLabs V3
    return TTS_MODELS.v3;
  }

  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const isFemale = request.gender === "FEMALE" || (!request.gender && request.voiceId && ELEVENLABS_VOICE_GENDER_MAP[request.voiceId] === "FEMALE");

    let voiceId = request.voiceCloneId || request.voiceId;

    // Check if voiceId is a Google Cloud voice name (e.g. "te-IN-Standard-B" or "en-US-Chirp3-HD-Achernar")
    const isGoogleVoiceName = voiceId && (
      voiceId.includes("-Standard-") ||
      voiceId.includes("-Chirp") ||
      voiceId.includes("-Neural2-") ||
      voiceId.includes("-Wavenet-") ||
      voiceId.includes("-Journey-") ||
      voiceId.includes("-Studio-")
    );

    if (!voiceId || isGoogleVoiceName) {
      voiceId = isFemale ? "EXAVITQu4vr4xnSDxMaL" : "ErXwobaYiN019PkySvjV"; // Female: Sarah, Male: Antoni
    } else if (ELEVENLABS_VOICE_GENDER_MAP[voiceId]) {
      // Invariant: Enforce gender consistency on preset voices
      const knownGender = ELEVENLABS_VOICE_GENDER_MAP[voiceId];
      if (request.gender === "MALE" && knownGender === "FEMALE") {
        voiceId = "ErXwobaYiN019PkySvjV"; // Antoni (Male)
      } else if (request.gender === "FEMALE" && knownGender === "MALE") {
        voiceId = "EXAVITQu4vr4xnSDxMaL"; // Sarah (Female)
      }
    }
    let model = this.selectModel(request.language, request);
    const apiKey = this.getApiKey();

    if (!apiKey) {
      throw new Error("[ElevenLabsTTS] No ElevenLabs API key configured");
    }

    logger.info("[ElevenLabsTTS] Synthesizing segment with ElevenLabs V4 Premium", {
      jobId: request.jobId,
      language: request.language,
      model,
      voiceId,
      isVoiceClone: Boolean(request.voiceCloneId || request.preferVoiceCloning),
      textLength: request.text.length,
      textPreview: request.text.substring(0, 60),
    });

    const voiceSettings: VoiceSettings = {
      stability: request.preferVoiceCloning ? 0.45 : this.defaultVoiceSettings.stability,
      similarity_boost: request.preferVoiceCloning ? 0.85 : this.defaultVoiceSettings.similarity_boost,
      style: request.speakingRate && request.speakingRate > 1.05 ? 0.38 : (this.defaultVoiceSettings.style ?? 0.28),
      use_speaker_boost: this.defaultVoiceSettings.use_speaker_boost ?? true,
    };

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const response = await axios.post(
          `${ELEVENLABS_BASE_URL}/text-to-speech/${voiceId}`,
          {
            text: request.text,
            model_id: model,
            voice_settings: voiceSettings,
          },
          {
            headers: {
              "xi-api-key": apiKey,
              "Content-Type": "application/json",
            },
            params: {
              output_format: "mp3_44100_128",
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

        // Graceful ElevenLabs model fallback chain:
        // Tier 1 (First): eleven_v4 or eleven_v4_turbo
        // Tier 2 (Fallback 1): eleven_v3 (or eleven_flash_v2_5 for turbo)
        // Tier 3 (Fallback 2): eleven_flash_v2_5
        if (attempt === 0 && (model === TTS_MODELS.v4 || model === TTS_MODELS.v4Turbo)) {
          model = model === TTS_MODELS.v4Turbo ? TTS_MODELS.flash : TTS_MODELS.v3;
          logger.info("[ElevenLabsTTS] Falling back to Tier 2 (Fallback 1)", {
            jobId: request.jobId,
            nextAttempt: attempt + 2,
            nextModel: model,
          });
        } else if (attempt === 1) {
          model = TTS_MODELS.flash;
          logger.info("[ElevenLabsTTS] Falling back to Tier 3 (Fallback 2): eleven_flash_v2_5", {
            jobId: request.jobId,
            nextAttempt: attempt + 2,
          });
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

  /**
   * Clones a creator's voice using ElevenLabs Instant Voice Cloning (/v1/voices/add).
   * Downloads the audio sample from GCS or HTTPS, builds multipart/form-data,
   * calls /v1/voices/add, and returns the newly generated voice_id.
   */
  async cloneVoice(name: string, audioUrl: string): Promise<string> {
    const apiKey = this.getApiKey();
    if (!apiKey) {
      throw new Error("[ElevenLabsTTS] API key missing for voice cloning");
    }

    let audioBuffer: Buffer;
    if (audioUrl.startsWith("gs://")) {
      const parts = audioUrl.replace("gs://", "").split("/");
      const bucketName = parts[0];
      const filePath = parts.slice(1).join("/");
      const [downloaded] = await storage().bucket(bucketName).file(filePath).download();
      audioBuffer = downloaded;
    } else {
      const resp = await axios.get(audioUrl, { responseType: "arraybuffer", timeout: 30000 });
      audioBuffer = Buffer.from(resp.data);
    }

    const formData = new FormData();
    formData.append("name", name);
    formData.append("description", `TruthWorld voice clone for ${name}`);
    const blob = new Blob([new Uint8Array(audioBuffer)], { type: "audio/mpeg" });
    formData.append("files", blob, "sample.mp3");

    const response = await axios.post(`${ELEVENLABS_BASE_URL}/voices/add`, formData, {
      headers: {
        "xi-api-key": apiKey,
      },
      timeout: 60000,
    });

    if (!response.data || !response.data.voice_id) {
      throw new Error("[ElevenLabsTTS] Voice cloning failed: missing voice_id in response");
    }

    const voiceId: string = response.data.voice_id;
    logger.info("[ElevenLabsTTS] ✅ Instant voice clone created", { name, voiceId });
    return voiceId;
  }

  /**
   * Cleans up a temporary cloned voice from ElevenLabs.
   */
  async deleteVoice(voiceId: string): Promise<boolean> {
    const apiKey = this.getApiKey();
    if (!apiKey || !voiceId) return false;
    try {
      await axios.delete(`${ELEVENLABS_BASE_URL}/voices/${voiceId}`, {
        headers: { "xi-api-key": apiKey },
        timeout: 10000,
      });
      logger.info("[ElevenLabsTTS] ✅ Cleaned up temporary voice clone", { voiceId });
      return true;
    } catch (err: any) {
      logger.warn("[ElevenLabsTTS] Could not delete voice (preset or already removed)", { voiceId, err: err?.message });
      return false;
    }
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
   * - Voice Cloning ONLY: Strictly routed to ElevenLabs (preferVoiceCloning: true or voiceCloneId).
   * - Audio Tracks Dubbing (Default): Exclusively synthesized using Google Cloud Chirp 3: HD
   *   (flagship generative AudioML models covering 40+ languages including Telugu, Hindi, Tamil, Kannada, etc.).
   *   Eliminates all robotic/standard voices for premium audio dubs.
   * - Resilient Fallback: If ElevenLabs encounters rate limits or quota exhaustion during voice cloning,
   *   gracefully falls back to high-fidelity Google Cloud Chirp 3: HD.
   */
  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const isStarterTier = request.ttsTier === "audio_starter";
    const isAudioPro = request.ttsTier === "audio_pro" || request.voiceType === "fast_api";
    const isVoiceCloningRequested = Boolean(
      !isStarterTier &&
      (request.preferVoiceCloning ||
      request.voiceCloneId ||
      request.ttsTier === "audio_ultra" ||
      request.ttsTier === "video_pro" ||
      request.ttsTier === "video_ultra" ||
      request.provider === "elevenlabs")
    );

    // 1. Voice Cloning (Audio Ultra / Video Pro / Video Ultra) -> ElevenLabs V4
    if (isVoiceCloningRequested) {
      const apiKey = this.elevenLabsTts.getApiKey();
      if (!apiKey) {
        logger.warn(
          "[TTS] ⚠️ Voice cloning requested but ElevenLabs API key is missing. Falling back to Google Cloud Chirp 3: HD.",
          { jobId: request.jobId, language: request.language }
        );
        return await this.googleTts.synthesize({
          ...request,
          preferVoiceCloning: false,
        });
      }

      try {
        logger.info("[TTS] Routing to ElevenLabs exclusively for voice cloning", {
          jobId: request.jobId,
          language: request.language,
          voiceCloneId: request.voiceCloneId,
        });
        return await this.elevenLabsTts.synthesize(request);
      } catch (err: any) {
        logger.warn(
          "[TTS] ⚠️ ElevenLabs voice cloning failed or quota exceeded. Seamlessly falling back to Google Cloud Chirp 3: HD.",
          {
            jobId: request.jobId,
            language: request.language,
            error: err.message,
          }
        );
        return await this.googleTts.synthesize({
          ...request,
          preferVoiceCloning: false,
        });
      }
    }

    // 2. Audio Pro Tier -> ElevenLabs v4 Turbo (Fast)
    if (isAudioPro) {
      const apiKey = this.elevenLabsTts.getApiKey();
      if (apiKey) {
        try {
          logger.info("[TTS] Routing to ElevenLabs v4 Turbo for Audio Pro tier", {
            jobId: request.jobId,
            language: request.language,
          });
          return await this.elevenLabsTts.synthesize({
            ...request,
            ttsTier: "audio_pro",
          });
        } catch (err: any) {
          logger.warn(
            "[TTS] ⚠️ ElevenLabs v4 Turbo unavailable for Audio Pro. Falling back to Google Cloud Chirp 3: HD.",
            { jobId: request.jobId, error: err.message }
          );
        }
      }
    }

    // 3. Audio Starter (Default) -> Google Cloud Chirp 3: HD
    logger.info("[TTS] Synthesizing Audio Starter dubbing track with Google Cloud Chirp 3: HD", {
      jobId: request.jobId,
      language: request.language,
      textLength: request.text.length,
    });
    try {
      return await this.googleTts.synthesize(request);
    } catch (gErr: any) {
      logger.warn("[TTS] ⚠️ Google Cloud TTS synthesis failed. Attempting resilient fallback to ElevenLabs V4 Turbo", {
        jobId: request.jobId,
        language: request.language,
        error: gErr?.message || String(gErr),
      });
      const elKey = this.elevenLabsTts.getApiKey();
      if (elKey) {
        return await this.elevenLabsTts.synthesize(request);
      }
      throw gErr;
    }
  }

  public estimateDuration(text: string): number {
    return text.length / 15;
  }

  public async cloneVoice(name: string, audioUrl: string): Promise<string> {
    return this.elevenLabsTts.cloneVoice(name, audioUrl);
  }

  public async deleteVoice(voiceId: string): Promise<boolean> {
    return this.elevenLabsTts.deleteVoice(voiceId);
  }
}

export const elevenLabsTtsService = new ElevenLabsTTSService();
export const ttsService = new TTSService();
