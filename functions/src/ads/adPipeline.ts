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
import { v4 as uuidv4 } from "uuid";
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

    const lines = vttContent.split("\n");
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
        pendingStart = parts[0].trim();
        pendingEnd = parts[1] ? parts[1].trim() : "00:00:05.000";
      } else if (trimmed.length > 0 && !trimmed.startsWith("WEBVTT") && !trimmed.startsWith("NOTE")) {
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

      if (sourceCues.length === 0) {
        sourceCues = this.generateDefaultCues(adData);
        // Save English baseline VTT
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
              "stages.ai.progress": progressPercent,
              "stages.ai.currentStage": `Translating subtitles to ${lang.toUpperCase()}...`,
              "stages.ai.updatedAt": Date.now(),
            },
            { merge: true }
          );

          if (lang === sourceLang) {
            existingSubtitles[lang] = this.formatVtt(sourceCues);
            continue;
          }

          // Translate each cue
          const translatedCues: CueItem[] = [];
          for (const cue of sourceCues) {
            const translatedText = await translationService.translateText(cue.text, sourceLang, lang);
            translatedCues.push({
              id: cue.id,
              startTime: cue.startTime,
              endTime: cue.endTime,
              text: translatedText || cue.text,
            });
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
      if (wantDubbing) {
        const voiceId = this.resolveVoiceId(voiceStyle);

        for (const rawLang of targetLanguages) {
          const lang = normalizeLanguageCode(rawLang);
          completedSteps++;
          const progressPercent = Math.min(Math.round((completedSteps / (totalSteps + 1)) * 90), 90);

          await adDocRef.set(
            {
              "stages.ai.progress": progressPercent,
              "stages.ai.currentStage": `Synthesizing AI audio dub in ${lang.toUpperCase()}...`,
              "stages.ai.updatedAt": Date.now(),
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

          // Record TTS cost
          costEngine.recordTTSCost(campaignId, userId, speechText.length).catch(() => {});
        }
      }

      // ── 3. UPDATE FIRESTORE AND COMPLETE STAGE ─────────────────────────────
      const completionTime = Date.now();
      await adDocRef.set(
        {
          subtitles: existingSubtitles,
          audioTracks: existingAudioTracks,
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
}
