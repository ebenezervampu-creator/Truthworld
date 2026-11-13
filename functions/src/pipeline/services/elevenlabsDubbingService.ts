import axios from "axios";
import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import { PIPELINE_CONFIG } from "../config";
import { audioIdentityService } from "./audio-identity";

export interface ElevenLabsDubRequest {
  jobId: string;
  userId: string;
  mediaUrl: string;
  targetLang: string;
  sourceLang?: string;
  numSpeakers?: number;
  highestResolution?: boolean;
  onProgress?: (progress: number, stageTitle: string, stageStep: number) => Promise<void>;
}

export interface ElevenLabsDubResult {
  audioUrl: string;
  directAudioUrl: string;
  srtContent?: string;
  srtUrl?: string;
  dubbingId: string;
}

export class ElevenLabsDubbingService {
  private readonly baseUrl = "https://api.elevenlabs.io/v1/dubbing";

  private getApiKey(): string {
    return PIPELINE_CONFIG.ELEVENLABS_API_KEY || process.env.ELEVENLABS_API_KEY || "";
  }

  public isAvailable(): boolean {
    const key = this.getApiKey();
    return Boolean(key && key.trim().length > 0 && !key.includes("YOUR_") && !key.includes("placeholder"));
  }

  /**
   * Translates 2-letter ISO codes to ElevenLabs target language codes if needed.
   */
  public normalizeTargetLanguage(lang: string): string {
    const clean = lang.trim().toLowerCase();
    const map: Record<string, string> = {
      hi: "hi",
      te: "te",
      ta: "ta",
      es: "es",
      de: "de",
      fr: "fr",
      it: "it",
      pt: "pt",
      pl: "pl",
      tr: "tr",
      ru: "ru",
      nl: "nl",
      cs: "cs",
      ar: "ar",
      zh: "zh",
      ja: "ja",
      ko: "ko",
      id: "id",
      vi: "vi",
      uk: "uk",
      el: "el",
      sv: "sv",
      ms: "ms",
      ro: "ro",
      da: "da",
      fi: "fi",
      bg: "bg",
      hr: "hr",
      sk: "sk",
      tl: "fil",
      fil: "fil",
    };
    return map[clean] || clean;
  }

  /**
   * Initiates a native ElevenLabs Dubbing job.
   */
  async createDubbing(params: {
    sourceUrl: string;
    targetLang: string;
    sourceLang?: string;
    numSpeakers?: number;
    highestResolution?: boolean;
  }): Promise<{ dubbingId: string; expectedDurationSec: number }> {
    const apiKey = this.getApiKey();
    if (!apiKey) {
      throw new Error("[ElevenLabsDubbing] API key missing for ElevenLabs Dubbing");
    }

    const normTarget = this.normalizeTargetLanguage(params.targetLang);
    const normSource = params.sourceLang && params.sourceLang !== "auto"
      ? this.normalizeTargetLanguage(params.sourceLang)
      : undefined;

    const formData = new FormData();
    formData.append("mode", "automatic");
    formData.append("source_url", params.sourceUrl);
    formData.append("target_lang", normTarget);
    if (normSource) {
      formData.append("source_lang", normSource);
    }
    formData.append("num_speakers", String(params.numSpeakers ?? 0));
    formData.append("watermark", "false");
    formData.append("drop_background_audio", "false");
    if (params.highestResolution) {
      formData.append("highest_resolution", "true");
    }

    logger.info("[ElevenLabsDubbing] Creating dubbing job", {
      targetLang: normTarget,
      sourceLang: normSource || "auto",
      sourceUrlLength: params.sourceUrl.length,
    });

    const response = await axios.post(this.baseUrl, formData, {
      headers: {
        "xi-api-key": apiKey,
      },
      timeout: 45000,
    });

    const data = response.data || {};
    if (!data.dubbing_id) {
      throw new Error(`[ElevenLabsDubbing] Invalid response from ElevenLabs: ${JSON.stringify(data)}`);
    }

    return {
      dubbingId: data.dubbing_id,
      expectedDurationSec: Number(data.expected_duration_sec ?? 30),
    };
  }

  /**
   * Polls the status of an ongoing ElevenLabs dubbing job.
   */
  async getDubbingStatus(dubbingId: string): Promise<{
    status: "dubbing" | "dubbed" | "failed";
    error?: string;
  }> {
    const apiKey = this.getApiKey();
    const response = await axios.get(`${this.baseUrl}/${dubbingId}`, {
      headers: {
        "xi-api-key": apiKey,
      },
      timeout: 15000,
    });

    const data = response.data || {};
    const rawStatus = String(data.status || "dubbing").toLowerCase();
    const status: "dubbing" | "dubbed" | "failed" =
      rawStatus === "dubbed" ? "dubbed" : (rawStatus === "failed" ? "failed" : "dubbing");

    return {
      status,
      error: data.error || (status === "failed" ? "Dubbing processing failed on ElevenLabs cloud" : undefined),
    };
  }

  /**
   * Downloads the completed dubbed audio track directly from ElevenLabs.
   */
  async downloadDubbedAudio(dubbingId: string, targetLang: string): Promise<Buffer> {
    const apiKey = this.getApiKey();
    const normLang = this.normalizeTargetLanguage(targetLang);
    const url = `${this.baseUrl}/${dubbingId}/audio/${normLang}`;

    logger.info("[ElevenLabsDubbing] Downloading dubbed audio track", { dubbingId, targetLang: normLang });
    const response = await axios.get(url, {
      headers: {
        "xi-api-key": apiKey,
      },
      responseType: "arraybuffer",
      timeout: 60000,
    });

    if (!response.data || response.data.byteLength === 0) {
      throw new Error(`[ElevenLabsDubbing] Received empty audio track for ${targetLang}`);
    }

    return Buffer.from(response.data);
  }

  /**
   * Downloads the aligned dubbed transcript/subtitles (SRT or VTT).
   */
  async downloadDubbedTranscript(
    dubbingId: string,
    targetLang: string,
    format: "srt" | "vtt" = "srt"
  ): Promise<string | null> {
    const apiKey = this.getApiKey();
    const normLang = this.normalizeTargetLanguage(targetLang);
    const url = `${this.baseUrl}/${dubbingId}/transcript/${normLang}?format_type=${format}`;

    try {
      const response = await axios.get(url, {
        headers: {
          "xi-api-key": apiKey,
        },
        responseType: "text",
        timeout: 20000,
      });
      return response.data && typeof response.data === "string" && response.data.trim().length > 0
        ? response.data
        : null;
    } catch (err: any) {
      logger.warn("[ElevenLabsDubbing] Transcript download notice:", {
        dubbingId,
        targetLang,
        error: err?.message || String(err),
      });
      return null;
    }
  }

  /**
   * Cleans up the temporary ElevenLabs dubbing project to keep storage hygienic.
   */
  async deleteDubbingProject(dubbingId: string): Promise<void> {
    const apiKey = this.getApiKey();
    if (!apiKey || !dubbingId) return;
    try {
      await axios.delete(`${this.baseUrl}/${dubbingId}`, {
        headers: { "xi-api-key": apiKey },
        timeout: 10000,
      });
      logger.info("[ElevenLabsDubbing] Deleted temporary dubbing project", { dubbingId });
    } catch (_) {}
  }

  /**
   * End-to-End Orchestration of Native ElevenLabs Dubbing:
   * 1. Generates accessible Signed URL.
   * 2. Calls POST /v1/dubbing.
   * 3. Polls status with real-time progressive Firestore updates.
   * 4. Downloads audio and uploads to Cloud Storage (`audio/${jobId}/${targetLang}/master.mp3`).
   * 5. Downloads and saves SRT subtitles.
   * 6. Cleans up project and returns result.
   */
  async dubMedia(params: ElevenLabsDubRequest): Promise<ElevenLabsDubResult> {
    const { jobId, mediaUrl, targetLang, sourceLang, onProgress } = params;
    const t0 = Date.now();

    logger.info("[ElevenLabsDubbing] Starting end-to-end native dubbing", {
      jobId,
      targetLang,
      sourceLang,
      mediaUrlPreview: mediaUrl.slice(0, 60),
    });

    if (onProgress) {
      await onProgress(15, "Analyzing audio & transcribing dialogue", 1);
    }

    // 1. Get an accessible URL for ElevenLabs
    const accessibleUrl = await audioIdentityService.getAccessibleUrl(mediaUrl);

    // 2. Create the Dubbing Project
    const { dubbingId, expectedDurationSec } = await this.createDubbing({
      sourceUrl: accessibleUrl,
      targetLang,
      sourceLang,
      numSpeakers: params.numSpeakers ?? 0,
      highestResolution: params.highestResolution ?? false,
    });

    logger.info("[ElevenLabsDubbing] Project created — waiting for completion", {
      jobId,
      dubbingId,
      expectedDurationSec,
    });

    if (onProgress) {
      await onProgress(25, "Transcribing original dialogue", 1);
    }

    // 3. Poll for status with progressive real-time feedback
    const maxPollMs = Math.max(180000, expectedDurationSec * 3000);
    const pollIntervalMs = 2500;
    let completed = false;
    let attempts = 0;

    while (Date.now() - t0 < maxPollMs) {
      attempts++;
      await new Promise((r) => setTimeout(r, pollIntervalMs));

      const statusRes = await this.getDubbingStatus(dubbingId);
      const elapsedSec = (Date.now() - t0) / 1000;

      if (statusRes.status === "dubbed") {
        completed = true;
        break;
      }

      if (statusRes.status === "failed") {
        await this.deleteDubbingProject(dubbingId).catch(() => {});
        throw new Error(statusRes.error || "ElevenLabs Dubbing failed during processing");
      }

      // Compute dynamic, smooth progress based on elapsed time vs expected duration
      const ratio = Math.min(1.0, elapsedSec / Math.max(15, expectedDurationSec));
      let currentProgress = 25 + Math.round(ratio * 65); // Scales from 25% to 90%
      currentProgress = Math.min(94, Math.max(25, currentProgress));

      let stageTitle = "Analyzing speech & transcribing dialogue";
      let stageStep = 1;
      if (currentProgress >= 85) {
        stageStep = 4;
        stageTitle = "Mastering audio ducking & synchronization";
      } else if (currentProgress >= 55) {
        stageStep = 3;
        stageTitle = `Synthesizing AI voice & cloning timbre`;
      } else if (currentProgress >= 30) {
        stageStep = 2;
        stageTitle = `Translating speech to ${targetLang}`;
      }

      if (onProgress) {
        await onProgress(currentProgress, stageTitle, stageStep);
      }
    }

    if (!completed) {
      await this.deleteDubbingProject(dubbingId).catch(() => {});
      throw new Error(`[ElevenLabsDubbing] Dubbing timed out after ${Math.round((Date.now() - t0) / 1000)}s`);
    }

    if (onProgress) {
      await onProgress(95, "Syncing audio track to cloud...", 4);
    }

    // 4. Download finalized audio track
    const audioBuffer = await this.downloadDubbedAudio(dubbingId, targetLang);

    // 5. Save to Cloud Storage
    const bucket = admin.storage().bucket();
    const storagePath = `audio/${jobId}/${targetLang}/master.mp3`;
    const file = bucket.file(storagePath);

    await file.save(audioBuffer, {
      metadata: {
        contentType: "audio/mpeg",
        metadata: {
          jobId,
          language: targetLang,
          provider: "elevenlabs_dubbing_native",
          dubbingId,
          createdAt: String(Date.now()),
        },
      },
    });

    const audioUrl = `gs://${bucket.name}/${storagePath}`;
    const directAudioUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;

    // 6. Optionally fetch and persist SRT subtitles
    let srtContent: string | undefined;
    let srtUrl: string | undefined;
    try {
      const srt = await this.downloadDubbedTranscript(dubbingId, targetLang, "srt");
      if (srt) {
        srtContent = srt;
        const srtPath = `subtitles/${jobId}/${targetLang}.srt`;
        const srtFile = bucket.file(srtPath);
        await srtFile.save(srt, {
          metadata: {
            contentType: "text/plain",
            metadata: {
              jobId,
              language: targetLang,
              provider: "elevenlabs_dubbing_native",
            },
          },
        });
        srtUrl = `gs://${bucket.name}/${srtPath}`;
      }
    } catch (_) {}

    // 7. Cleanup project on ElevenLabs
    await this.deleteDubbingProject(dubbingId).catch(() => {});

    logger.info("[ElevenLabsDubbing] ✅ Native dubbing completed successfully", {
      jobId,
      targetLang,
      durationMs: Date.now() - t0,
      audioBytes: audioBuffer.length,
      directAudioUrl,
    });

    return {
      audioUrl,
      directAudioUrl,
      srtContent,
      srtUrl,
      dubbingId,
    };
  }
}

export const elevenLabsDubbingService = new ElevenLabsDubbingService();
