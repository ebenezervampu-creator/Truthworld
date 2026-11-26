import { logger } from "./logger";

export interface DubbingTimingMeta {
  jobId: string;
  lang?: string;
  durationSec?: number;
  [key: string]: unknown;
}

/**
 * Emits a structured `[Dubbing:Timing]` log span and optionally accumulates `ms` into `timingsMap`.
 */
export function emitDubbingTiming(
  stage: string,
  startMs: number,
  meta: DubbingTimingMeta,
  timingsMap?: Record<string, number>,
  explicitMs?: number
): number {
  const ms =
    typeof explicitMs === "number" && Number.isFinite(explicitMs)
      ? Math.max(0, Math.round(explicitMs))
      : Math.max(0, Date.now() - startMs);

  if (timingsMap) {
    timingsMap[stage] = (timingsMap[stage] || 0) + ms;
  }

  const { jobId, lang, durationSec, ...extra } = meta;
  logger.info("[Dubbing:Timing]", {
    stage,
    ms,
    jobId,
    lang: lang || null,
    durationSec:
      typeof durationSec === "number" && Number.isFinite(durationSec)
        ? Math.round(durationSec * 100) / 100
        : null,
    ...extra,
  });

  return ms;
}
