/**
 * Latency & scaling feature flags (dependency-free).
 *
 * Every speed/scale optimization defaults to enabled (`true`) and can be rolled back
 * immediately via environment variables (`"false"`) with zero code deploy.
 */

function flagEnabled(envKey: string, defaultValue = true): boolean {
  const raw = process.env[envKey];
  if (raw === undefined || raw === "") return defaultValue;
  return String(raw).trim().toLowerCase() !== "false";
}

/** Reuse a single job-scoped local `/tmp` media download across pipeline stages. */
export function sharedTmpEnabled(): boolean {
  return flagEnabled("DUBBING_SHARED_TMP", true);
}

/** Sample representative non-speech gaps + single-pass f32le decode instead of full-stream aselect. */
export function fastSeparationProbeEnabled(): boolean {
  return flagEnabled("DUBBING_FAST_SEPARATION_PROBE", true);
}

/** Overlap Google Translate drafts with voices and run bounded-concurrent Gemini editor/meaning chunks. */
export function parallelTranslationEnabled(): boolean {
  return flagEnabled("DUBBING_PARALLEL_TRANSLATION", true);
}

/** Use a bounded sliding-window TTS worker pool instead of lock-step promise batches. */
export function slidingTtsPoolEnabled(): boolean {
  return flagEnabled("DUBBING_SLIDING_TTS_POOL", true);
}

/** Enable multi-hop Pub/Sub step splitting (prep_analysis -> voices/reels -> assembly). */
export function stepHandoffEnabled(): boolean {
  return flagEnabled("DUBBING_STEP_HANDOFF", true);
}

/** Run VideoGateway moderation concurrently with dubbing prep (APPROVED still gates delivery). */
export function parallelModerationEnabled(): boolean {
  return flagEnabled("DUBBING_PARALLEL_MODERATION", true);
}
