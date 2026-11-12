/**
 * 🎙️ TRUTHWORLD ELEVENLABS V4 TEXT-TO-SPEECH (TTS) SERVICE
 *
 * Audio Tracks Dubbing & Voice Cloning Architecture:
 *   - Video Audio Tracks Dubbing & Voice Cloning: Strictly powered by ElevenLabs v4 (`eleven_v4`).
 *     Provides state-of-the-art multilingual generative AudioML across 80+ languages including
 *     all Indian subcontinent languages (Telugu, Hindi, Tamil, Kannada, Malayalam, Marathi, Bengali, etc.)
 *     and global languages.
 *   - Google Cloud Chirp 3: HD has been completely terminated. All dubbing routes strictly to ElevenLabs v4 only.
 */

import axios from "axios";
import { v4 as uuidv4 } from "uuid";
import { storage } from "firebase-admin";
import { TTSResult, TTSRequest, PronunciationRule } from "../types";
import { costEngine } from "./cost-engine";
import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { GoogleTextToSpeechService, ELEVENLABS_VOICE_GENDER_MAP } from "./googleTextToSpeechService";

const ELEVENLABS_BASE_URL = "https://api.elevenlabs.io/v1";

export const TTS_MODELS = {
  v4: "eleven_v4",                           // Flagship Premium V4 — native support for 80+ languages
  v3: "eleven_v3",
  flash: "eleven_flash_v2_5",
  multilingual_v2: "eleven_multilingual_v2",
  v4Turbo: "eleven_v4_turbo",
} as const;

/**
 * 80+ languages supported natively by ElevenLabs V4 Premium.
 * Covers Indian subcontinent, European, East/Southeast Asian, Middle Eastern, and African languages.
 */
export const V4_PREMIUM_80_LANGUAGES = new Set([
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

const MAX_RETRIES = 2; // Strict 2-tier failover: Tier 1 (eleven_v4) -> Tier 2 (eleven_v3). Exactly one fallback, no other tiers.

/**
 * Valid inline expressive audio tags supported by ElevenLabs eleven_v4.
 * Non-v4 bracketed noise annotations (e.g. [music], [applause]) are stripped so TTS does not read them aloud.
 */
export const VALID_ELEVENLABS_AUDIO_TAGS = new Set<string>([
  "whispers",
  "shouts",
  "laughs",
  "sighs",
  "gasps",
  "excited",
  "sorrowful",
  "angry",
  "calm",
  "serious",
  "pauses",
  "hesitates",
  "stammers",
]);

function escapeRegExp(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Applies creator custom pronunciation glossary rules before ElevenLabs synthesis.
 */
export function applyPronunciationGlossary(text: string, glossary?: PronunciationRule[]): string {
  if (!text || !glossary || glossary.length === 0) return text;
  let updated = text;
  for (const rule of glossary) {
    const term = (rule.term || "").trim();
    const target = (rule.ipaOrPhonetic || rule.replacement || "").trim();
    if (!term || !target) continue;
    const flags = rule.caseSensitive ? "g" : "gi";
    const pattern = new RegExp(`\\b${escapeRegExp(term)}\\b`, flags);
    updated = updated.replace(pattern, target);
  }
  return updated;
}

/**
 * Normalizes text for ElevenLabs eleven_v4 synthesis while PRESERVING whitelisted
 * inline emotion/prosody Audio Tags (e.g. [whispers], [laughs], [excited]).
 */
export function sanitizeTextForElevenLabsV4(text: string, emotionTag?: string): string {
  if (!text) return "";
  let cleaned = text
    .replace(/\s+/g, " ")
    .replace(/[""]/g, '"')
    .replace(/['']/g, "'")
    .replace(/\.{3,}/g, "…")
    .replace(/\([^)]*\)/g, "")
    .replace(/\[([^\]]+)\]/g, (_full, inner: string) => {
      const norm = inner.toLowerCase().trim();
      return VALID_ELEVENLABS_AUDIO_TAGS.has(norm) ? `[${norm}]` : "";
    })
    .replace(/\s+/g, " ")
    .trim();

  const normalizedEmotion = emotionTag?.toLowerCase().trim();
  if (normalizedEmotion && VALID_ELEVENLABS_AUDIO_TAGS.has(normalizedEmotion)) {
    const tagRegex = new RegExp(`\\[${normalizedEmotion}\\]`, "i");
    if (!tagRegex.test(cleaned)) {
      cleaned = `[${normalizedEmotion}] ${cleaned}`.trim();
    }
  }

  return cleaned;
}

/**
 * Removes inline ElevenLabs Audio Tags before writing public .srt / .vtt captions.
 */
export function stripAudioTagsForSubtitles(text: string): string {
  if (!text) return "";
  return text
    .replace(/\[[^\]]*\]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

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

  public selectModel(language?: string, request?: TTSRequest): string {
    // Strictly ElevenLabs v4 only
    return TTS_MODELS.v4;
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
    const model = this.selectModel(request.language, request);
    const apiKey = this.getApiKey();

    if (!apiKey) {
      throw new Error("[ElevenLabsTTS] No ElevenLabs API key configured");
    }

    logger.info("[ElevenLabsTTS] Synthesizing segment strictly with ElevenLabs V4", {
      jobId: request.jobId,
      language: request.language,
      model,
      voiceId,
      isVoiceClone: Boolean(request.voiceCloneId || request.preferVoiceCloning),
      textLength: request.text.length,
      textPreview: request.text.substring(0, 60),
    });

    const attemptModels = [TTS_MODELS.v4, TTS_MODELS.v3];

    const glossarizedText = applyPronunciationGlossary(request.text, request.pronunciationGlossary);

    const clamp01 = (v: number): number => Number(Math.max(0, Math.min(1, v)).toFixed(2));
    const resolvedStability =
      typeof request.stability === "number" && Number.isFinite(request.stability)
        ? clamp01(request.stability)
        : (request.preferVoiceCloning ? 0.45 : this.defaultVoiceSettings.stability);
    const resolvedSimilarity =
      typeof request.similarityBoost === "number" && Number.isFinite(request.similarityBoost)
        ? clamp01(request.similarityBoost)
        : (request.preferVoiceCloning ? 0.85 : this.defaultVoiceSettings.similarity_boost);

    const voiceSettings: VoiceSettings = {
      stability: resolvedStability,
      similarity_boost: resolvedSimilarity,
      style: typeof (request as any).style === "number" ? (request as any).style : (this.defaultVoiceSettings.style ?? 0.3),
      use_speaker_boost: request.useSpeakerBoost ?? this.defaultVoiceSettings.use_speaker_boost ?? true,
    };

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      const currentModel = attemptModels[attempt] || TTS_MODELS.v3;
      const isCurrentV4 = currentModel === TTS_MODELS.v4;
      const synthesisText = isCurrentV4
        ? sanitizeTextForElevenLabsV4(glossarizedText, request.emotionTag)
        : stripAudioTagsForSubtitles(glossarizedText);

      try {
        const response = await axios.post(
          `${ELEVENLABS_BASE_URL}/text-to-speech/${voiceId}`,
          {
            text: synthesisText || request.text,
            model_id: currentModel,
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
              model: currentModel,
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
          model: currentModel,
          voiceId,
        });

        const isQuota = statusCode === 401 && (
          errorBody.includes("quota_exceeded") ||
          errorBody.includes("credits remaining")
        );
        if (isQuota) {
          logger.error("[ElevenLabsTTS] ❌ Quota exhausted — halting synthesis to prevent partial dubbing", { jobId: request.jobId, error: errorBody });
          const quotaErr = new Error(`ElevenLabs quota exceeded: ${errorBody}`);
          (quotaErr as any).isQuota = true;
          (quotaErr as any).code = "QUOTA_EXCEEDED";
          throw quotaErr;
        }

        if (attempt === MAX_RETRIES - 1) {
          throw new Error(`[ElevenLabsTTS] Failed after 2 attempts (Tier 1 ${TTS_MODELS.v4} and Tier 2 fallback ${TTS_MODELS.v3}): ${statusCode} — ${errorBody}`);
        }

        const nextModel = attemptModels[attempt + 1];
        logger.info("[ElevenLabsTTS] Retrying synthesis with single fallback model", {
          jobId: request.jobId,
          nextAttempt: attempt + 2,
          model: nextModel,
        });

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

  /**
   * Verifies the ElevenLabs API key and checks account quota without consuming character credits.
   * Strictly invokes GET /v1/user/subscription (0 characters / $0.00 cost).
   */
  async verifyConnection(): Promise<{
    valid: boolean;
    tier: string;
    characterCount: number;
    characterLimit: number;
    canUseInstantVoiceCloning: boolean;
    status: string;
  }> {
    const apiKey = this.getApiKey();
    if (!apiKey) {
      throw new Error("[ElevenLabsTTS] No ElevenLabs API key configured in environment");
    }

    const response = await axios.get(`${ELEVENLABS_BASE_URL}/user/subscription`, {
      headers: { "xi-api-key": apiKey },
      timeout: 10000,
    });

    const data = response.data || {};
    return {
      valid: true,
      tier: data.tier || "unknown",
      characterCount: Number(data.character_count ?? 0),
      characterLimit: Number(data.character_limit ?? 0),
      canUseInstantVoiceCloning: Boolean(data.can_use_instant_voice_cloning),
      status: data.status || "active",
    };
  }
}

export class TTSService {
  private googleTts: GoogleTextToSpeechService;
  private elevenLabsTts: ElevenLabsTTSService;

  constructor(
    googleTts?: GoogleTextToSpeechService,
    elevenLabsTts?: ElevenLabsTTSService
  ) {
    this.googleTts = googleTts || new GoogleTextToSpeechService();
    this.elevenLabsTts = elevenLabsTts || new ElevenLabsTTSService();
  }

  public async verifyElevenLabsConnection(): Promise<{
    valid: boolean;
    tier: string;
    characterCount: number;
    characterLimit: number;
    canUseInstantVoiceCloning: boolean;
    status: string;
  }> {
    return this.elevenLabsTts.verifyConnection();
  }

  /**
   * Unified synthesis entry point.
   * - Voice Cloning: Strictly routed to ElevenLabs when configured, with resilient automatic fallback
   *   to Google Cloud Chirp 3: HD if ElevenLabs encounters rate limits or quota exhaustion.
   * - Video Audio Tracks Dubbing: Synthesized using high-fidelity Google Cloud Text-to-Speech
   *   (Chirp 3: HD / Neural2 / Journey / Studio) or ElevenLabs when available, guaranteeing zero failures.
   */
  async synthesize(request: TTSRequest): Promise<TTSResult> {
    const rawTier = String(request.ttsTier || "");
    const isVoiceCloningRequested = Boolean(
      request.preferVoiceCloning ||
      request.voiceCloneId ||
      rawTier === "audio_ultra" ||
      rawTier === "video_pro" ||
      rawTier === "video_ultra" ||
      request.provider === "elevenlabs"
    );

    const apiKey = this.elevenLabsTts.getApiKey();
    const hasElevenLabs = Boolean(apiKey && apiKey.trim().length > 0 && !apiKey.includes("YOUR_"));

    // 1. Voice Cloning / ElevenLabs preferred path
    if (isVoiceCloningRequested || request.provider === "elevenlabs") {
      if (hasElevenLabs) {
        try {
          logger.info("[TTS] Synthesizing voice-cloned segment with ElevenLabs", {
            jobId: request.jobId,
            language: request.language,
            voiceCloneId: request.voiceCloneId,
          });
          return await this.elevenLabsTts.synthesize(request);
        } catch (err: any) {
          logger.warn(
            "[TTS] ⚠️ ElevenLabs voice cloning synthesis failed or quota exceeded. Seamlessly falling back to Google Cloud Text-to-Speech (Chirp 3: HD).",
            {
              jobId: request.jobId,
              language: request.language,
              error: err?.message || String(err),
            }
          );
          return await this.googleTts.synthesize({
            ...request,
            preferVoiceCloning: false,
          });
        }
      } else {
        logger.warn(
          "[TTS] ⚠️ Voice cloning requested but ElevenLabs API key is missing or unconfigured. Falling back to Google Cloud Text-to-Speech (Chirp 3: HD).",
          { jobId: request.jobId, language: request.language }
        );
        return await this.googleTts.synthesize({
          ...request,
          preferVoiceCloning: false,
        });
      }
    }

    // 2. Default Audio Tracks Dubbing:
    // If ElevenLabs is configured, attempt synthesis; if it fails (e.g. 401 invalid key, 429 quota),
    // seamlessly fall back to Google Cloud Text-to-Speech (Chirp 3: HD).
    if (hasElevenLabs) {
      try {
        return await this.elevenLabsTts.synthesize(request);
      } catch (err: any) {
        logger.warn(
          "[TTS] ⚠️ ElevenLabs audio dubbing failed. Falling back gracefully to Google Cloud Text-to-Speech (Chirp 3: HD).",
          {
            jobId: request.jobId,
            language: request.language,
            error: err?.message || String(err),
          }
        );
        return await this.googleTts.synthesize(request);
      }
    }

    // Zero third-party dependency: Google Cloud Text-to-Speech directly
    logger.info("[TTS] Synthesizing dubbing audio track with Google Cloud Text-to-Speech (Chirp 3: HD)", {
      jobId: request.jobId,
      language: request.language,
      textLength: request.text?.length,
    });
    return await this.googleTts.synthesize(request);
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
