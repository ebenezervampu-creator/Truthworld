/**
 * ElevenLabs plan limits used by the pipeline (dependency-free, unit-tested).
 */

/**
 * Parallel ElevenLabs text-to-speech requests allowed per function instance, when
 * ELEVENLABS_MAX_CONCURRENCY is not set. ElevenLabs' per-plan limit for eleven_v4
 * ("all other models"): Free 2, Starter 3, Creator 5, Pro 10, Scale/Business 15.
 * Defaults to Starter (3); raise it with the env var after upgrading — no code change.
 * The limit is per instance, so keep dubbing functions at maxInstances 1 on small plans
 * (pipelineTriggers.ts: handleDubbing, handleDubbingReel).
 */
export const DEFAULT_MAX_ELEVENLABS_CONCURRENCY = 3;

/** ELEVENLABS_MAX_CONCURRENCY if it is a positive integer, otherwise the default. */
export function readMaxElevenLabsConcurrency(): number {
  const parsed = parseInt(process.env.ELEVENLABS_MAX_CONCURRENCY || "", 10);
  return Number.isFinite(parsed) && parsed >= 1 ? parsed : DEFAULT_MAX_ELEVENLABS_CONCURRENCY;
}
