/**
 * 👁️ LAYER 08 — AUXILIARY LAYER
 */

import type { ImageAnnotatorClient } from "@google-cloud/vision";
import { PIPELINE_CONFIG } from "../config";
import * as admin from "firebase-admin";
import {
  VisualContext,
  FrameAnalysis,
  SceneInfo,
  OCRResult,
} from "../types";
import { logger } from "../utils/logger";

const db = () => admin.firestore();

/** Sample one frame every N seconds (max 30 frames total) */
const FRAME_INTERVAL_S = 10;
const MAX_FRAMES       = 30;

/** Vision API batch size */
const VISION_BATCH = 5;

/** Jaccard similarity threshold for scene-change detection */
const SCENE_CHANGE_THRESHOLD = 0.30;

/** Minimum non-whitespace characters to consider OCR text meaningful */
const MIN_OCR_LENGTH = 3;

export class AuxiliaryLayer {
  private _visionClient?: ImageAnnotatorClient;

  private get visionClient(): ImageAnnotatorClient {
    if (!this._visionClient) {
      const { ImageAnnotatorClient } = require("@google-cloud/vision");
      this._visionClient = new ImageAnnotatorClient();
    }
    return this._visionClient!;
  }

  constructor() {}

  async extractVisualContext(
    jobId:         string,
    videoUrl:      string,
    videoDuration: number
  ): Promise<VisualContext> {
    const t0 = Date.now();
    logger.info("[Auxiliary] Starting visual analysis", { jobId });

    const existing = await this.loadExisting(jobId);
    if (existing) {
      logger.info("[Auxiliary] Returning cached result", { jobId });
      return existing;
    }

    const ffmpegUrl = PIPELINE_CONFIG.FFMPEG_SERVICE_URL;
    if (!ffmpegUrl) {
      logger.info("[Auxiliary] No FFmpeg service — skipping visual analysis", { jobId });
      return this.emptyContext(jobId, false);
    }

    try {
      const interval = Math.max(FRAME_INTERVAL_S, videoDuration / MAX_FRAMES);
      const timestamps: number[] = [];
      for (let t = 0; t < videoDuration && timestamps.length < MAX_FRAMES; t += interval) {
        timestamps.push(t * 1000);
      }

      const probeTimestamps = timestamps.slice(0, 3);
      const probeUrls = await this.extractFrames(ffmpegUrl, videoUrl, jobId, probeTimestamps);
      const probeOCR  = await this.runOCR(probeUrls, probeTimestamps);

      if (probeOCR.length === 0) {
        logger.info("[Auxiliary] No on-screen text in probe — skipping full OCR", { jobId });
        const ctx = this.emptyContext(jobId, false);
        await this.storeContext(ctx, Date.now() - t0);
        return ctx;
      }

      const frameUrls   = await this.extractFrames(ffmpegUrl, videoUrl, jobId, timestamps);
      const frameResults = await this.analyseFrames(frameUrls, timestamps);
      const scenes       = this.detectScenes(frameResults);

      const ocrTimestamps = timestamps.filter((_, i) => i % 3 === 0);
      const ocrUrls       = await this.extractFrames(ffmpegUrl, videoUrl, jobId, ocrTimestamps);
      const ocrResults    = await this.runOCR(ocrUrls, ocrTimestamps);

      const context: VisualContext = {
        jobId,
        frames:               frameResults,
        scenes,
        ocrTexts:             ocrResults,
        hasOnScreenText:      ocrResults.length > 0,
        totalFramesAnalyzed:  frameResults.length,
      };

      await this.storeContext(context, Date.now() - t0);
      return context;

    } catch (error) {
      logger.error("[Auxiliary] Error — returning empty context", { jobId, error });
      return this.emptyContext(jobId, false);
    }
  }

  async enrichContext(jobId: string, transcriptText: string): Promise<string> {
    const doc = await db().collection("visual_context").doc(jobId).get();
    if (!doc.exists) return transcriptText;

    const ctx = doc.data() as VisualContext;
    if (!ctx.hasOnScreenText) return transcriptText;

    let enriched = transcriptText;
    if (ctx.ocrTexts.length > 0) {
      const ocrSection = ctx.ocrTexts
        .map((o) => `[On-screen at ${Math.round(o.timestamp / 1000)}s]: ${o.text}`)
        .join("\n");
      enriched += `\n\n--- On-Screen Text ---\n${ocrSection}`;
    }
    return enriched;
  }

  private async analyseFrames(frameUrls: string[], timestamps: number[]): Promise<FrameAnalysis[]> {
    const results: FrameAnalysis[] = [];
    for (let i = 0; i < frameUrls.length; i += VISION_BATCH) {
      const batch = frameUrls.slice(i, i + VISION_BATCH);
      const batchResults = await Promise.allSettled(
        batch.map(async (url, bi) => {
          const [resp] = await this.visionClient.labelDetection(url);
          return {
            timestamp:  timestamps[i + bi],
            labels:     (resp.labelAnnotations ?? []).map((l) => l.description ?? ""),
            objects:    (resp.localizedObjectAnnotations ?? []).map((o) => o.name ?? ""),
            confidence: resp.labelAnnotations?.[0]?.score ?? 0,
          } as FrameAnalysis;
        })
      );
      for (const r of batchResults) {
        if (r.status === "fulfilled") results.push(r.value);
      }
    }
    return results;
  }

  private async runOCR(frameUrls: string[], timestamps: number[]): Promise<OCRResult[]> {
    const results: OCRResult[] = [];
    for (let i = 0; i < frameUrls.length; i++) {
      try {
        const [resp] = await this.visionClient.textDetection(frameUrls[i]);
        const text   = resp.fullTextAnnotation?.text ?? resp.textAnnotations?.[0]?.description ?? "";
        if (text.trim().length >= MIN_OCR_LENGTH) {
          results.push({ timestamp: timestamps[i], text: text.trim(), confidence: 0.8 });
        }
      } catch {}
    }
    return results;
  }

  private detectScenes(frames: FrameAnalysis[]): SceneInfo[] {
    if (frames.length < 2) return [];
    const scenes: SceneInfo[] = [];
    let cur: SceneInfo = {
      sceneIndex:     0,
      start:          frames[0]?.timestamp ?? 0,
      end:            0,
      description:    "",
      dominantLabels: frames[0]?.labels.slice(0, 3) ?? [],
    };
    for (let i = 1; i < frames.length; i++) {
      const prev = new Set(frames[i - 1].labels);
      const curr = new Set(frames[i].labels);
      const inter = new Set([...prev].filter((l) => curr.has(l)));
      const union = new Set([...prev, ...curr]);
      const sim   = union.size > 0 ? inter.size / union.size : 1;
      if (sim < SCENE_CHANGE_THRESHOLD) {
        cur.end = frames[i - 1].timestamp;
        cur.description = `Scene with: ${cur.dominantLabels.join(", ")}`;
        scenes.push(cur);
        cur = { sceneIndex: scenes.length, start: frames[i].timestamp, end: 0, description: "", dominantLabels: frames[i].labels.slice(0, 3) };
      }
    }
    cur.end = frames[frames.length - 1]?.timestamp ?? 0;
    cur.description = `Scene with: ${cur.dominantLabels.join(", ")}`;
    scenes.push(cur);
    return scenes;
  }

  private async extractFrames(ffmpegUrl: string, videoUrl: string, jobId: string, timestamps: number[]): Promise<string[]> {
    try {
      const axios = require("axios");
      const resp  = await axios.post(`${ffmpegUrl}/extract-frames`, {
        videoUrl, jobId,
        timestamps: timestamps.map((t) => t / 1000),
        format: "jpg",
        quality: 80,
      });
      return resp.data.frameUrls ?? [];
    } catch (err) {
      logger.warn("[Auxiliary] Frame extraction failed", { err });
      return [];
    }
  }

  private async storeContext(context: VisualContext, processingTimeMs: number): Promise<void> {
    await db().collection("visual_context").doc(context.jobId).set({ ...context, processingTimeMs, createdAt: Date.now() });
  }

  private async loadExisting(jobId: string): Promise<VisualContext | null> {
    const doc = await db().collection("visual_context").doc(jobId).get();
    return doc.exists ? (doc.data() as VisualContext) : null;
  }

  private emptyContext(jobId: string, hasText: boolean): VisualContext {
    return { jobId, frames: [], scenes: [], ocrTexts: [], hasOnScreenText: hasText, totalFramesAnalyzed: 0 };
  }
}

export const auxiliaryLayer = new AuxiliaryLayer();
