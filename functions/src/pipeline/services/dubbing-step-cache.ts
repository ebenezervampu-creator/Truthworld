/**
 * Dubbing step cache (speed, quality-neutral).
 *
 * The analysis steps before translation (diarization check, speaker profiling, separation, acoustic
 * fingerprint, prosody) depend only on the video, its transcript and a few plan options — never on
 * the target language. Their results are stored in Cloud Storage under
 * `dubbing_prep/{jobId}/{step}_{hash}.json`, where the hash covers every input that can change the
 * result. A later run with the same inputs (a retry, a resumed job, another language ordered later,
 * or an order after the analysis was prepared at upload time) reuses the stored result instead of
 * calling Gemini / Demucs again. Same models, same prompts, same inputs → same output.
 *
 * A degraded result (a Gemini call that failed and fell back to defaults) is never stored, so the
 * next run tries again exactly as it did before this cache existed.
 *
 * Rollback: DUBBING_STEP_CACHE=false.
 */
import * as crypto from "crypto";
import { storage } from "firebase-admin";
import { logger } from "../utils/logger";

/** Bump when the stored shape or any cached step's logic changes, so old entries are ignored. */
export const STEP_CACHE_VERSION = 1;
export const STEP_CACHE_PREFIX = "dubbing_prep";

export type CachedStep = "diarization" | "speakers" | "separation" | "fingerprint" | "prosody";

export function stepCacheEnabled(): boolean {
  return String(process.env.DUBBING_STEP_CACHE ?? "true").toLowerCase() !== "false";
}

/** Stable JSON: object keys sorted, so the same inputs always hash the same. Maps become sorted entries. */
export function stableStringify(value: unknown): string {
  const norm = (v: any): any => {
    if (v instanceof Map) return { __map: [...v.entries()].map(([k, x]) => [k, norm(x)]).sort((a, b) => String(a[0]).localeCompare(String(b[0]))) };
    if (Array.isArray(v)) return v.map(norm);
    if (v && typeof v === "object") {
      const out: Record<string, unknown> = {};
      for (const k of Object.keys(v).sort()) if (v[k] !== undefined) out[k] = norm(v[k]);
      return out;
    }
    return v;
  };
  return JSON.stringify(norm(value));
}

export function stepCacheKey(step: CachedStep, inputs: unknown): string {
  return crypto
    .createHash("sha256")
    .update(`${STEP_CACHE_VERSION}|${step}|${stableStringify(inputs)}`)
    .digest("hex")
    .slice(0, 24);
}

export function stepCachePath(jobId: string, step: CachedStep, key: string): string {
  return `${STEP_CACHE_PREFIX}/${jobId}/${step}_${key}.json`;
}

/** JSON with Maps preserved (diarization labels, prosody cues). */
export function encodeCached(value: unknown): string {
  return JSON.stringify(value, (_k, v) => (v instanceof Map ? { __map: [...v.entries()] } : v));
}

export function decodeCached<T>(text: string): T {
  return JSON.parse(text, (_k, v) =>
    v && typeof v === "object" && !Array.isArray(v) && Array.isArray(v.__map) && Object.keys(v).length === 1
      ? new Map(v.__map)
      : v
  ) as T;
}

export interface StepCacheStore {
  read(path: string): Promise<string | null>;
  write(path: string, body: string): Promise<void>;
}

export const gcsStepCacheStore: StepCacheStore = {
  async read(path) {
    const file = storage().bucket().file(path);
    const [exists] = await file.exists();
    if (!exists) return null;
    const [buf] = await file.download();
    return buf.toString("utf8");
  },
  async write(path, body) {
    await storage().bucket().file(path).save(body, {
      contentType: "application/json",
      resumable: false,
      metadata: { cacheControl: "private, max-age=0" },
    });
  },
};

export interface CachedRunResult<T> {
  value: T;
  hit: boolean;
}

/**
 * Returns the stored result for (jobId, step, inputs) or computes and stores it.
 * Cache read/write failures never fail the step: it simply computes as before.
 */
export async function cachedStep<T>(
  jobId: string,
  step: CachedStep,
  inputs: unknown,
  compute: () => Promise<T>,
  opts: { isDegraded?: (value: T) => boolean; store?: StepCacheStore } = {}
): Promise<CachedRunResult<T>> {
  if (!stepCacheEnabled()) return { value: await compute(), hit: false };
  const store = opts.store ?? gcsStepCacheStore;
  const key = stepCacheKey(step, inputs);
  const path = stepCachePath(jobId, step, key);

  try {
    const body = await store.read(path);
    if (body) {
      const value = decodeCached<T>(body);
      logger.info("[Dubbing:StepCache] Reused prepared result", { jobId, step, key });
      return { value, hit: true };
    }
  } catch (err) {
    logger.warn("[Dubbing:StepCache] Read skipped", { jobId, step, err: String(err) });
  }

  const value = await compute();
  if (opts.isDegraded?.(value)) {
    logger.info("[Dubbing:StepCache] Degraded result not stored (next run retries)", { jobId, step });
    return { value, hit: false };
  }
  try {
    await store.write(path, encodeCached(value));
  } catch (err) {
    logger.warn("[Dubbing:StepCache] Write skipped", { jobId, step, err: String(err) });
  }
  return { value, hit: false };
}

/** Short content hash for large inputs (transcripts, utterance lists). */
export function contentHash(value: unknown): string {
  return crypto.createHash("sha256").update(stableStringify(value)).digest("hex").slice(0, 16);
}

// ─── Degraded-result detectors (results that fell back to defaults are not cached) ──────────────

const FINGERPRINT_DEFAULT = {
  micStyle: "warm-broadcast",
  roomTone: "dry-studio",
  compression: "transparent",
  energy: "moderate",
  pacingStyle: "steady-educational",
  pitchBand: "mid",
  pitchSemitones: 0,
  speakingRate: 1,
};

/** The fingerprint service returns exactly this default when Gemini fails. */
export function isDefaultFingerprint(fp: any): boolean {
  if (!fp || typeof fp !== "object") return true;
  return Object.entries(FINGERPRINT_DEFAULT).every(([k, v]) => fp[k] === v) &&
    Object.keys(fp).every((k) => k in FINGERPRINT_DEFAULT);
}

/** The diarization check keeps AssemblyAI labels with this reason when Gemini could not be reached. */
export function isFailedDiarization(result: { reason?: string } | null | undefined): boolean {
  return !result || /failed|not in cloud storage/i.test(String(result.reason || ""));
}

/** Speaker profiling falls back to a heuristic profile (no Gemini fields) when a call fails. */
export function hasFallbackSpeakerProfile(profiles: any[]): boolean {
  if (!Array.isArray(profiles) || profiles.length === 0) return true;
  const heuristicKeys = new Set(["speakerId", "gender", "style", "pitchBand", "energy", "ageTone", "role", "wordCount", "segments"]);
  return profiles.some((p) => p && Object.keys(p).every((k) => heuristicKeys.has(k)));
}

/** Prosody without any Gemini emotion reading means the multimodal call failed. */
export function isAcousticOnlyProsody(cues: Map<number, any>, segmentCount: number): boolean {
  if (segmentCount === 0) return false;
  if (!(cues instanceof Map) || cues.size === 0) return true;
  for (const cue of cues.values()) if (cue && cue.emotionalIntensity) return false;
  return true;
}
