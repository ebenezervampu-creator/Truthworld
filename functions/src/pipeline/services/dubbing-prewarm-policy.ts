/**
 * Upload-time dubbing preparation policy (speed).
 *
 * When a video finishes transcription without a dubbing order, its language-independent dubbing
 * analysis (diarization check, speaker profiling, background separation, fingerprint, prosody) can be
 * prepared right away, so a dubbing order placed later starts at voice matching and translation.
 * Preparing costs Gemini calls and, for videos with music, one Demucs separation — paid even if the
 * video is never dubbed — so it is gated:
 *
 *   DUBBING_PREWARM=off               never prepare
 *   DUBBING_PREWARM=previous_dubbers  (default) only for creators who have ordered dubbing before
 *   DUBBING_PREWARM=all               every video in a supported source language
 *
 * DUBBING_PREWARM_MAX_MINUTES (default 60) skips longer videos.
 */
import * as admin from "firebase-admin";
import { logger } from "../utils/logger";

export type PrewarmMode = "off" | "previous_dubbers" | "all";

export function readPrewarmMode(): PrewarmMode {
  const raw = String(process.env.DUBBING_PREWARM ?? "previous_dubbers").trim().toLowerCase();
  return raw === "off" || raw === "all" ? raw : "previous_dubbers";
}

export function prewarmMaxSeconds(): number {
  const minutes = Number(process.env.DUBBING_PREWARM_MAX_MINUTES ?? 60);
  return (Number.isFinite(minutes) && minutes > 0 ? minutes : 60) * 60;
}

export interface PrewarmInput {
  dubbingRequested: boolean;
  sourceLanguageSupported: boolean;
  durationSeconds?: number;
}

/** Pure part of the decision; `hasDubbedBefore` is only consulted in previous_dubbers mode. */
export function prewarmDecision(
  input: PrewarmInput,
  mode: PrewarmMode,
  hasDubbedBefore: boolean | null
): { prewarm: boolean; reason: string } {
  if (mode === "off") return { prewarm: false, reason: "disabled" };
  // An order already exists: the dubbing run itself does the analysis now.
  if (input.dubbingRequested) return { prewarm: false, reason: "dubbing already ordered" };
  if (!input.sourceLanguageSupported) return { prewarm: false, reason: "source language not supported for dubbing" };
  const dur = Number(input.durationSeconds);
  if (Number.isFinite(dur) && dur > prewarmMaxSeconds()) return { prewarm: false, reason: "video longer than the preparation limit" };
  if (mode === "all") return { prewarm: true, reason: "all videos" };
  return hasDubbedBefore ? { prewarm: true, reason: "creator has ordered dubbing before" } : { prewarm: false, reason: "creator has not ordered dubbing before" };
}

/** Whether this creator has any earlier job with a dubbing order. Equality filters only (no composite index). */
export async function creatorHasDubbedBefore(userId: string): Promise<boolean> {
  if (!userId) return false;
  try {
    const snap = await admin.firestore()
      .collection("video_jobs")
      .where("userId", "==", userId)
      .where("executionPlan.generateDubbing", "==", true)
      .limit(1)
      .get();
    return !snap.empty;
  } catch (err) {
    logger.warn("[Dubbing:Prewarm] Creator history lookup failed — not preparing", { userId, err: String(err) });
    return false;
  }
}

export async function shouldPrewarmDubbing(userId: string, input: PrewarmInput): Promise<{ prewarm: boolean; reason: string }> {
  const mode = readPrewarmMode();
  const first = prewarmDecision(input, mode, null);
  if (mode !== "previous_dubbers" || first.reason !== "creator has not ordered dubbing before") return first;
  return prewarmDecision(input, mode, await creatorHasDubbedBefore(userId));
}
