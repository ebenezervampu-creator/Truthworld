/**
 * 🎯 ADVERTISER AI PIPELINE — Subtitles & Audio Dubbing Engine
 *
 * Provides production-ready, cost-effective processing for advertiser campaigns:
 *   1. AI Subtitles translation from source VTT/cues to multiple target languages
 *   2. AI Audio dubbing with voice synthesis via ElevenLabs Flash v2.5 / Multilingual
 *   3. Real-time Firestore stage updates (stages.ai)
 *   4. Direct Firebase Storage integration with playable download tokens
 *   5. Cost engine governance tracking
 */

import * as admin from "firebase-admin";
import axios from "axios";
import { v4 as uuidv4 } from "uuid";
import { PIPELINE_CONFIG } from "../pipeline/config";
import { translationService } from "../pipeline/services/translation";
import { ttsService } from "../pipeline/services/tts";
import { costEngine } from "../pipeline/services/cost-engine";
import { logger } from "../pipeline/utils/logger";
import { normalizeLanguageCode } from "../shared/language-normalizer";

const db = () => admin.firestore();

export interface CueItem {
  id: string;
  startTime: string;
  endTime: string;
  text: string;
}

export interface AdAIFeaturesRequest {
  campaignId: string;
  userId: string;
  features: string[]; // ["subtitles", "dubbing"]
  targetLanguages: string[]; // ["hi", "ta", "te", "es", "fr", "de", ...]
  voiceStyle?: string; // "natural", "deep", "high", or voice ID
  sourceLang?: string; // default "en"
}

export class AdPipelineService {
  /**
   * Parse a WebVTT formatted string into CueItems.
   */
  static parseVtt(vttContent: string): CueItem[] {
    if (!vttContent || !vttContent.trim()) return [];

    // Strip UTF-8 BOM, normalize CRLF to LF
    const normalized = vttContent.replace(/^\uFEFF/, "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    const lines = normalized.split("\n");
    const cues: CueItem[] = [];
    let pendingStart = "";
    let pendingEnd = "";
    const pendingText: string[] = [];

    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.includes("-->")) {
        if (pendingStart && pendingText.length > 0) {
          cues.push({
            id: `${Date.now()}_${cues.length}`,
            startTime: pendingStart,
            endTime: pendingEnd,
            text: pendingText.join(" ").trim(),
          });
          pendingText.length = 0;
        }
        const parts = trimmed.split("-->");
        pendingStart = parts[0].trim().split(/\s+/)[0];
        // Strip any cue settings (e.g. line:0 position:50%) from end timestamp
        const rawEnd = parts[1] ? parts[1].trim() : "00:00:05.000";
        pendingEnd = rawEnd.split(/\s+/)[0] || "00:00:05.000";
      } else if (trimmed.length > 0 && !trimmed.startsWith("WEBVTT") && !trimmed.startsWith("NOTE")) {
        // IMPORTANT: Ignore any header metadata lines that appear before the first cue timestamp
        if (!pendingStart) {
          continue;
        }
        // Exclude numerical cue identifiers if preceding timestamp
        if (/^\d+$/.test(trimmed) && pendingText.length === 0) {
          continue;
        }
        pendingText.push(trimmed);
      }
    }

    if (pendingStart && pendingText.length > 0) {
      cues.push({
        id: `${Date.now()}_${cues.length}`,
        startTime: pendingStart,
        endTime: pendingEnd,
        text: pendingText.join(" ").trim(),
      });
    }

    return cues;
  }

  /**
   * Format an array of CueItems into standard WebVTT format.
   */
  static formatVtt(cues: CueItem[]): string {
    const lines = ["WEBVTT", ""];
    for (const cue of cues) {
      lines.push(`${cue.startTime} --> ${cue.endTime}`);
      lines.push(cue.text);
      lines.push("");
    }
    return lines.join("\n");
  }

  /**
   * Generate default baseline cues from campaign metadata if no source transcript exists.
   */
  static generateDefaultCues(adData: any): CueItem[] {
    const advertiser = adData.advertiser || "our brand";
    const description = adData.description || adData.title || "Special promotion";
    const ctaText = adData.ctaText || "Learn More";

    return [
      {
        id: "1",
        startTime: "00:00:01.000",
        endTime: "00:00:05.000",
        text: `Welcome to ${advertiser}!`,
      },
      {
        id: "2",
        startTime: "00:00:05.000",
        endTime: "00:00:10.000",
        text: description,
      },
      {
        id: "3",
        startTime: "00:00:10.000",
        endTime: "00:00:15.000",
        text: `Click the link to ${ctaText}!`,
      },
    ];
  }

  /**
   * Map user voice style selection to ElevenLabs voice ID.
   */
  static resolveVoiceId(voiceStyle?: string): string {
    switch (voiceStyle?.toLowerCase()) {
      case "deep":
        return "pNInz6obpgDQGcFmaJgB"; // Adam (deep narration)
      case "high":
        return "hpp4J3VqNfWAUOO0d1Us"; // Bella (high tone)
      case "natural":
      default:
        return "EXAVITQu4vr4xnSDxMaL"; // Sarah (natural, balanced)
    }
  }

  /**
   * Resolve an accessible public/signed URL for audio/video processing.
   */
  static async getAccessibleUrl(url: string): Promise<string> {
    if (!url) return "";
    if (url.startsWith("http://") || url.startsWith("https://")) {
      return url;
    }
    if (url.startsWith("gs://")) {
      try {
        const parts = url.replace("gs://", "").split("/");
        const bucketName = parts[0];
        const filePath = parts.slice(1).join("/");
        const bucket = admin.storage().bucket(bucketName);
        const file = bucket.file(filePath);
        const [signedUrl] = await file.getSignedUrl({
          action: "read",
          expires: Date.now() + 1000 * 60 * 60, // 1 hour
        });
        return signedUrl;
      } catch (err) {
        logger.warn("[AdPipeline] Could not get signed URL for gs:// path", { url, error: err });
        return url;
      }
    }
    return url;
  }

  /**
   * Transcribe speech from a video URL using AssemblyAI.
   * Returns a WebVTT formatted string or null if failed, empty, or unconfigured.
   */
  static async transcribeVideoAudio(videoUrl: string): Promise<string | null> {
    try {
      const apiKey = PIPELINE_CONFIG.ASSEMBLYAI_KEY || process.env.ASSEMBLYAI_KEY;
      if (!apiKey) {
        logger.info("[AdPipeline] ASSEMBLYAI_KEY not configured, skipping STT");
        return null;
      }

      const accessibleUrl = await this.getAccessibleUrl(videoUrl);
      if (!accessibleUrl) return null;

      const headers = {
        authorization: apiKey,
        "content-type": "application/json",
      };

      logger.info("[AdPipeline] Submitting video to AssemblyAI for speech transcription...", { videoUrl });
      const submitResp = await axios.post(
        "https://api.assemblyai.com/v2/transcript",
        {
          audio_url: accessibleUrl,
          punctuate: true,
          format_text: true,
        },
        { headers, timeout: 20000 }
      );

      const transcriptId = submitResp.data?.id;
      if (!transcriptId) return null;

      // Poll for completion (up to 30 attempts, 2.5s interval = 75s max for short video ads)
      for (let attempt = 0; attempt < 30; attempt++) {
        await new Promise((resolve) => setTimeout(resolve, 2500));
        const pollResp = await axios.get(
          `https://api.assemblyai.com/v2/transcript/${transcriptId}`,
          { headers, timeout: 15000 }
        );

        const status = pollResp.data?.status;
        if (status === "completed") {
          // Fetch native VTT from AssemblyAI
          const vttResp = await axios.get(
            `https://api.assemblyai.com/v2/transcript/${transcriptId}/vtt`,
            { headers, timeout: 15000 }
          );
          const vtt = vttResp.data;
          if (typeof vtt === "string" && vtt.includes("-->")) {
            logger.info("[AdPipeline] Successfully transcribed video speech to native VTT", {
              transcriptId,
              vttLength: vtt.length,
            });
            return vtt;
          }
          break;
        } else if (status === "error") {
          logger.warn("[AdPipeline] AssemblyAI transcript returned error status", {
            error: pollResp.data?.error,
          });
          break;
        }
      }
      return null;
    } catch (err) {
      logger.warn("[AdPipeline] Audio transcription non-fatal failure, falling back to default cues", {
        error: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }

  /**
   * Main entry point for processing advertiser AI features.
   */
  static async processAdAIFeatures(req: AdAIFeaturesRequest): Promise<void> {
    const { campaignId, userId, features, targetLanguages, voiceStyle, sourceLang = "en" } = req;
    const adDocRef = db().collection("ad_campaigns").doc(campaignId);

    logger.info("[AdPipeline] Starting AI features processing", {
      campaignId,
      userId,
      features,
      targetLanguages,
      voiceStyle,
    });

    const now = Date.now();
    await adDocRef.set(
      {
        stages: {
          ai: {
            status: "running",
            progress: 10,
            currentStage: "Initializing AI pipeline...",
            features,
            targetLanguages,
            startedAt: now,
            updatedAt: now,
          },
        },
        updatedAt: now,
      },
      { merge: true }
    );

    try {
      const adSnap = await adDocRef.get();
      if (!adSnap.exists) {
        throw new Error(`Ad campaign ${campaignId} not found`);
      }
      const adData = adSnap.data() || {};

      const existingSubtitles: Record<string, string> = { ...(adData.subtitles || {}) };
      const existingAudioTracks: Record<string, string> = { ...(adData.audioTracks || {}) };

      // Resolve base source cues
      let sourceCues: CueItem[] = [];
      const sourceVtt = existingSubtitles[sourceLang] || existingSubtitles["en"];

      if (sourceVtt && sourceVtt.trim()) {
        sourceCues = this.parseVtt(sourceVtt);
      }

      // If no source cues exist yet, transcribe video audio via AssemblyAI
      if (sourceCues.length === 0) {
        const videoUrlToTranscribe = adData.videoUrl || adData.midrollVideoUrl;
        if (videoUrlToTranscribe) {
          await adDocRef.set(
            {
              stages: {
                ai: {
                  currentStage: "Transcribing speech from video ad...",
                  updatedAt: Date.now(),
                },
              },
            },
            { merge: true }
          );

          const transcribedVtt = await this.transcribeVideoAudio(videoUrlToTranscribe);
          if (transcribedVtt && transcribedVtt.trim()) {
            sourceCues = this.parseVtt(transcribedVtt);
            if (sourceCues.length > 0) {
              existingSubtitles[sourceLang] = transcribedVtt;
            }
          }
        }
      }

      // If still no cues (silent video, fallback, or no transcript), use structured campaign metadata cues
      if (sourceCues.length === 0) {
        sourceCues = this.generateDefaultCues(adData);
        // Save baseline VTT
        const defaultSourceVtt = this.formatVtt(sourceCues);
        existingSubtitles[sourceLang] = defaultSourceVtt;
      }

      const wantSubtitles = features.includes("subtitles") || features.length === 0;
      const wantDubbing = features.includes("dubbing");
      const bucket = admin.storage().bucket();

      const totalSteps = (wantSubtitles ? targetLanguages.length : 0) + (wantDubbing ? targetLanguages.length : 0);
      let completedSteps = 0;

      // ── 1. SUBTITLES PIPELINE ──────────────────────────────────────────────
      if (wantSubtitles) {
        for (const rawLang of targetLanguages) {
          const lang = normalizeLanguageCode(rawLang);
          completedSteps++;
          const progressPercent = Math.min(Math.round((completedSteps / (totalSteps + 1)) * 90), 90);

          await adDocRef.set(
            {
              stages: {
                ai: {
                  progress: progressPercent,
                  currentStage: `Translating subtitles to ${lang.toUpperCase()}...`,
                  updatedAt: Date.now(),
                },
              },
            },
            { merge: true }
          );

          if (lang === sourceLang) {
            existingSubtitles[lang] = this.formatVtt(sourceCues);
            continue;
          }

          // Translate cues in batch for speed, consistency, and fallback
          const translatedCues: CueItem[] = [];
          try {
            const batchResult = await translationService.translateSegments(
              campaignId,
              sourceCues.map((c) => ({ start: 0, end: 0, text: c.text })),
              sourceLang,
              lang,
              { model: "dynamic" }
            );

            sourceCues.forEach((cue, idx) => {
              const text = batchResult.segments[idx]?.translated || cue.text;
              translatedCues.push({
                id: cue.id,
                startTime: cue.startTime,
                endTime: cue.endTime,
                text,
              });
            });
          } catch (batchErr) {
            logger.warn(`[AdPipeline] Batch segment translation fallback to individual translation for ${lang}`, { error: batchErr });
            for (const cue of sourceCues) {
              const translatedText = await translationService.translateText(cue.text, sourceLang, lang);
              translatedCues.push({
                id: cue.id,
                startTime: cue.startTime,
                endTime: cue.endTime,
                text: translatedText || cue.text,
              });
            }
          }

          const translatedVtt = this.formatVtt(translatedCues);
          existingSubtitles[lang] = translatedVtt;

          // Save VTT to Cloud Storage with direct download token
          try {
            const vttPath = `ad_subtitles/${campaignId}/${lang}.vtt`;
            const downloadToken = uuidv4();
            await bucket.file(vttPath).save("\uFEFF" + translatedVtt, {
              metadata: {
                contentType: "text/vtt; charset=utf-8",
                metadata: { firebaseStorageDownloadTokens: downloadToken },
              },
            });
          } catch (storageErr) {
            logger.warn("[AdPipeline] Storage save non-fatal error for VTT", { campaignId, lang, error: storageErr });
          }

          // Record translation cost
          const charCount = sourceCues.reduce((sum, c) => sum + c.text.length, 0);
          costEngine.recordTranslationCost(campaignId, userId, charCount).catch(() => {});
        }
      }

      // ── 2. AUDIO DUBBING PIPELINE ───────────────────────────────────────────
      const newlyGeneratedAiAudio: Record<string, string> = {};
      if (wantDubbing) {
        const voiceId = this.resolveVoiceId(voiceStyle);

        for (const rawLang of targetLanguages) {
          const lang = normalizeLanguageCode(rawLang);
          completedSteps++;
          const progressPercent = Math.min(Math.round((completedSteps / (totalSteps + 1)) * 90), 90);

          await adDocRef.set(
            {
              stages: {
                ai: {
                  progress: progressPercent,
                  currentStage: `Synthesizing AI audio dub in ${lang.toUpperCase()}...`,
                  updatedAt: Date.now(),
                },
              },
            },
            { merge: true }
          );

          // Build speech text from translated subtitles or translate ad text directly
          let speechText = "";
          if (existingSubtitles[lang]) {
            const cues = this.parseVtt(existingSubtitles[lang]);
            speechText = cues.map((c) => c.text).join(". ");
          } else {
            const defaultScript = `${adData.advertiser || ""}. ${adData.description || adData.title || ""}. ${adData.ctaText || ""}`;
            speechText = lang === sourceLang ? defaultScript : await translationService.translateText(defaultScript, sourceLang, lang);
          }

          if (!speechText.trim()) {
            speechText = `Welcome to ${adData.advertiser || "Truthworld"}. Explore our latest updates today.`;
          }

          // Synthesize audio with ElevenLabs Flash v2.5 / Multilingual
          const ttsResult = await ttsService.synthesize({
            jobId: campaignId,
            language: lang,
            text: speechText,
            voiceId,
          });

          // Generate playable Firebase Storage download URL
          const bucketName = bucket.name;
          const rawFilePath = ttsResult.audioUrl.replace(`gs://${bucketName}/`, "");
          const downloadToken = uuidv4();

          await bucket.file(rawFilePath).setMetadata({
            metadata: {
              firebaseStorageDownloadTokens: downloadToken,
              campaignId,
              language: lang,
              voiceId,
            },
          });

          const directDownloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(rawFilePath)}?alt=media&token=${downloadToken}`;

          existingAudioTracks[lang] = directDownloadUrl;
          newlyGeneratedAiAudio[lang] = directDownloadUrl;

          // Record TTS cost
          costEngine.recordTTSCost(campaignId, userId, speechText.length).catch(() => {});
        }
      }

      // ── 3. UPDATE FIRESTORE AND COMPLETE STAGE ─────────────────────────────
      const completionTime = Date.now();
      const existingAiDubbed = (adData.aiDubbedAudio || {}) as Record<string, string>;
      const mergedAiDubbedAudio = {
        ...existingAiDubbed,
        ...newlyGeneratedAiAudio,
      };

      await adDocRef.set(
        {
          subtitles: existingSubtitles,
          audioTracks: existingAudioTracks,
          aiDubbedAudio: mergedAiDubbedAudio,
          stages: {
            ai: {
              status: "completed",
              progress: 100,
              currentStage: "AI Processing completed successfully.",
              completedAt: completionTime,
              updatedAt: completionTime,
            },
          },
          updatedAt: completionTime,
        },
        { merge: true }
      );

      logger.info("[AdPipeline] AI processing finished successfully", {
        campaignId,
        subtitlesCount: Object.keys(existingSubtitles).length,
        audioTracksCount: Object.keys(existingAudioTracks).length,
      });
    } catch (err: any) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      logger.error("[AdPipeline] AI processing failed", { campaignId, error: errorMsg });

      await adDocRef.set(
        {
          stages: {
            ai: {
              status: "failed",
              progress: 0,
              currentStage: `AI processing failed: ${errorMsg}`,
              error: errorMsg,
              failedAt: Date.now(),
              updatedAt: Date.now(),
            },
          },
          updatedAt: Date.now(),
        },
        { merge: true }
      );

      throw err;
    }
  }

  /**
   * Batch process AI dubbing and subtitles for all video ads in Truthworld.
   * Scans ad_campaigns for video assets and processes them.
   */
  static async processAllVideoAds(options: {
    targetLanguages?: string[];
    features?: string[];
    voiceStyle?: string;
    sourceLang?: string;
    forceRegenerate?: boolean;
  } = {}): Promise<{
    totalFound: number;
    processedCount: number;
    skippedCount: number;
    campaignIds: string[];
  }> {
    const {
      targetLanguages = ["te", "hi", "ta", "es"],
      features = ["subtitles", "dubbing"],
      voiceStyle = "natural",
      sourceLang = "en",
      forceRegenerate = false,
    } = options;

    const snapshot = await db().collection("ad_campaigns").get();
    const videoAds: { id: string; data: any }[] = [];

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const hasVideo = !!(
        data.videoUrl ||
        data.midrollVideoUrl ||
        (data.resolutions && Array.isArray(data.resolutions) && data.resolutions.length > 0)
      );

      if (!hasVideo) continue;

      // Skip already processed video ads unless forceRegenerate is true
      if (!forceRegenerate) {
        const subs = data.subtitles || {};
        const dubs = data.audioTracks || {};
        const wantSubs = features.includes("subtitles");
        const wantDubs = features.includes("dubbing");

        const hasAllSubs = !wantSubs || targetLanguages.every((l) => !!subs[normalizeLanguageCode(l)]);
        const hasAllDubs = !wantDubs || targetLanguages.every((l) => !!dubs[normalizeLanguageCode(l)]);

        if (hasAllSubs && hasAllDubs) {
          continue;
        }
      }

      videoAds.push({ id: doc.id, data });
    }

    logger.info(`[AdPipeline] Found ${videoAds.length} video ads to process for AI dubbing/subtitles. (Total docs: ${snapshot.size})`);

    const campaignIds: string[] = [];
    for (const item of videoAds) {
      campaignIds.push(item.id);
      try {
        await this.processAdAIFeatures({
          campaignId: item.id,
          userId: item.data.userId || "system",
          features,
          targetLanguages,
          voiceStyle,
          sourceLang,
        });
      } catch (err) {
        logger.error(`[AdPipeline] Error processing video ad ${item.id} in batch:`, err);
      }
    }

    return {
      totalFound: snapshot.size,
      processedCount: campaignIds.length,
      skippedCount: snapshot.size - campaignIds.length,
      campaignIds,
    };
  }
}
