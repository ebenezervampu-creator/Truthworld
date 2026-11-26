/**
 * Screen content analyzer for Netflix-style subtitles.
 *
 * One Gemini call per video (cached on the job) that finds:
 *   - songs: time ranges where someone is SINGING (lyrics are styled as lyrics, not dialogue)
 *   - on-screen text: plot-relevant text in the picture (signs, captions, messages, chyrons),
 *     which becomes "forced narrative" subtitles at the top of the frame for viewers who
 *     cannot read the original language
 *
 * Best-effort: any failure returns empty results and subtitles are produced without these
 * extras. Disable with SUBTITLE_SCREEN_ANALYSIS=off.
 */

import * as admin from "firebase-admin";
import { Type } from "@google/genai";
import { GEMINI_MODELS } from "../config";
import { getVertexClient } from "../utils/ai-client";
import { normalizeToGcsUri } from "../utils/ai-utils";
import { logger } from "../utils/logger";

export interface OnScreenTextEvent {
  startMs: number;
  endMs: number;
  text: string;
  /** ISO 639-1 language of the on-screen text. */
  language: string;
}

export interface ScreenContentResult {
  songIntervalsMs: Array<{ startMs: number; endMs: number }>;
  onScreenText: OnScreenTextEvent[];
  /** Video shot cuts in milliseconds from start of video. */
  shotChangesMs?: number[];
}

const EMPTY: ScreenContentResult = { songIntervalsMs: [], onScreenText: [], shotChangesMs: [] };
const MODEL = process.env.SUBTITLE_SCREEN_MODEL || "gemini-3.5-flash-lite";
const inFlight = new Map<string, Promise<ScreenContentResult>>();

const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    songs: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: { start_seconds: { type: Type.NUMBER }, end_seconds: { type: Type.NUMBER } },
        required: ["start_seconds", "end_seconds"],
      },
    },
    on_screen_text: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          start_seconds: { type: Type.NUMBER },
          end_seconds: { type: Type.NUMBER },
          text: { type: Type.STRING },
          language: { type: Type.STRING },
        },
        required: ["start_seconds", "end_seconds", "text", "language"],
      },
    },
  },
  required: ["songs", "on_screen_text"],
};

const PROMPT = `You prepare a video for professional subtitling. Watch and listen to the whole video and return JSON.

"songs": every time range where a person is SINGING lyrics (not background instrumental music, not speech over music). Use seconds from the start of the video.

"on_screen_text": text visible in the picture that a viewer needs to follow the story or the facts: signs, captions, text messages, letters, labels, chart titles, news tickers or name captions that matter. Skip logos, watermarks, credits, subtitles already burned into the video, and text that is only decoration. Give the exact text as written, its ISO 639-1 language code, and when it is visible (seconds).

Return empty arrays when there is nothing. Do not invent anything you cannot see or hear.`;

function toGcsUri(url: string): string | null {
  return normalizeToGcsUri(url);
}

/** Parses and sanity-checks Gemini's reply. Exported for tests. */
export function parseScreenContent(raw: string, durationMs?: number): ScreenContentResult {
  const parsed = JSON.parse((raw || "").trim().replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, ""));
  const limit = durationMs && durationMs > 0 ? durationMs : Number.POSITIVE_INFINITY;
  const clampMs = (sec: unknown) => Math.max(0, Math.min(limit, Math.round(Number(sec) * 1000)));

  const songIntervalsMs = (Array.isArray(parsed?.songs) ? parsed.songs : [])
    .map((s: any) => ({ startMs: clampMs(s.start_seconds), endMs: clampMs(s.end_seconds) }))
    .filter((s: any) => Number.isFinite(s.startMs) && Number.isFinite(s.endMs) && s.endMs - s.startMs >= 1000);

  const onScreenText = (Array.isArray(parsed?.on_screen_text) ? parsed.on_screen_text : [])
    .map((t: any) => ({
      startMs: clampMs(t.start_seconds),
      endMs: clampMs(t.end_seconds),
      text: String(t.text || "").replace(/\s+/g, " ").trim(),
      language: String(t.language || "").toLowerCase().split(/[-_]/)[0],
    }))
    .filter((t: OnScreenTextEvent) => t.text.length > 0 && t.text.length <= 200 && t.endMs > t.startMs);

  const shotChangesMs = (Array.isArray(parsed?.shot_changes) ? parsed.shot_changes : (Array.isArray(parsed?.scenes) ? parsed.scenes : []))
    .map((s: any) => (typeof s === "number" ? clampMs(s) : clampMs(s?.time_seconds ?? s?.start_seconds)))
    .filter((ms: number) => Number.isFinite(ms) && ms >= 0);

  return { songIntervalsMs, onScreenText, shotChangesMs: shotChangesMs.length > 0 ? shotChangesMs : undefined };
}

async function runAnalysis(jobId: string, videoUrl: string, durationMs?: number): Promise<{ res: ScreenContentResult; model: string }> {
  const uri = toGcsUri(videoUrl);
  if (!uri) return { res: EMPTY, model: MODEL };
  const ai = getVertexClient();

  const fallbackModel = GEMINI_MODELS.verification?.model || "gemini-3.8-flash";
  const attempts: Array<{ model: string; includeMediaResolution: boolean }> = [
    { model: MODEL, includeMediaResolution: true },
    ...(fallbackModel !== MODEL ? [{ model: fallbackModel, includeMediaResolution: true }] : []),
    { model: fallbackModel, includeMediaResolution: false },
  ];

  let result: any = null;
  let usedModel = MODEL;
  let lastErr: any = null;

  for (const attempt of attempts) {
    try {
      const config: Record<string, any> = {
        temperature: 0.1,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA as any,
        thinkingConfig: { thinkingBudget: 0 },
      };
      if (attempt.includeMediaResolution) {
        config.mediaResolution = "MEDIA_RESOLUTION_LOW";
      }
      result = await ai.models.generateContent({
        model: attempt.model,
        contents: [{
          role: "user",
          parts: [
            { fileData: { mimeType: "video/mp4", fileUri: uri } },
            { text: PROMPT },
          ],
        }],
        config: config as any,
      });
      usedModel = attempt.model;
      break;
    } catch (err: any) {
      lastErr = err;
      const msg = String(err?.message || err);
      const isModelOrArgErr =
        err?.status === 404 ||
        err?.status === 400 ||
        msg.includes("404") ||
        msg.includes("NOT_FOUND") ||
        msg.includes("INVALID_ARGUMENT") ||
        msg.includes("mediaResolution");
      if (!isModelOrArgErr) throw err;
    }
  }

  if (!result) {
    throw lastErr || new Error("Screen content analysis failed");
  }

  const text = typeof result?.text === "string"
    ? result.text
    : (result?.candidates?.[0]?.content?.parts || []).map((p: any) => p?.text || "").join("");

  try {
    const { costEngine } = require("./cost-engine");
    costEngine.recordGeminiCost(
      jobId, "system", "subtitle_screen_analysis", usedModel === fallbackModel ? "flash" : "flash-lite",
      Number(result?.usageMetadata?.promptTokenCount || 0),
      Number(result?.usageMetadata?.candidatesTokenCount || 0)
    ).catch(() => {});
  } catch (_) { /* best-effort */ }

  return { res: parseScreenContent(text, durationMs), model: usedModel };
}

/**
 * Returns songs and on-screen text for a video, analysing it once per job.
 * Never throws.
 */
export async function getScreenContent(jobId: string, videoUrl: string, durationMs?: number): Promise<ScreenContentResult> {
  if ((process.env.SUBTITLE_SCREEN_ANALYSIS || "on").toLowerCase() === "off" || !videoUrl) return EMPTY;

  const existing = inFlight.get(jobId);
  if (existing) return existing;

  const task = (async (): Promise<ScreenContentResult> => {
    const ref = admin.firestore().collection("video_jobs").doc(jobId);
    try {
      const snap = await ref.get();
      const cached = snap.exists ? snap.data()?.artifacts?.screenContent : null;
      if (cached && Array.isArray(cached.songIntervalsMs) && Array.isArray(cached.onScreenText)) {
        return cached as ScreenContentResult;
      }
    } catch (_) { /* fall through to analysis */ }

    try {
      const { res, model } = await runAnalysis(jobId, videoUrl, durationMs);
      await ref.set({ artifacts: { screenContent: { ...res, model, analyzedAt: Date.now() } } }, { merge: true }).catch(() => {});
      logger.info("[ScreenContent] Analysed video for subtitles", {
        jobId, model, songs: res.songIntervalsMs.length, onScreenText: res.onScreenText.length,
      });
      return res;
    } catch (err: any) {
      logger.warn("[ScreenContent] Analysis failed — subtitles continue without song and on-screen text marking", {
        jobId, model: MODEL, uri: toGcsUri(videoUrl), error: String(err?.message || err),
      });
      return EMPTY;
    }
  })();

  inFlight.set(jobId, task);
  try {
    return await task;
  } finally {
    // Keep the result for concurrent languages of this run only.
    setTimeout(() => inFlight.delete(jobId), 10 * 60 * 1000).unref?.();
  }
}
