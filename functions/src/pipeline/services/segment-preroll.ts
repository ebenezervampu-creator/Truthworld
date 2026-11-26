/**
 * Start a long dubbed line a little earlier instead of cutting its end (2026-11-24).
 *
 * Why: Telugu lines often run longer than the English turn. After the 1.15x tempo cap, the stitcher
 * trimmed the overflow at the next speaker's turn, clipping the last word (te test, 00:37: segment 7
 * trimmed by 510 ms; the reviewer heard "Peggy's closing word trails off abruptly"). When there is
 * silence before the line, starting it up to MAX_PREROLL_MS early keeps every word. Only the part
 * that still does not fit is trimmed, as before.
 *
 * Pure: MediaService.mergeAudioChunks applies it in line order, after each line's real length is known.
 * Flag: DUBBING_PREROLL=true (off by default until a listening test).
 */

export const PREROLL = {
  /** Largest early start. Beyond ~300 ms a voice audibly leads an on-screen speaker. */
  maxPrerollMs: 300,
  /** Silence kept after the previous dubbed line (matches the stitcher's 120 ms turn separation). */
  separationMs: 120,
  /** Overflow below this is left alone (the stitcher already allows 20 ms). */
  minOverflowMs: 20,
} as const;

export function prerollEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_PREROLL ?? "").toLowerCase() === "true";
}

export interface PrerollPlan {
  /** Where the line now starts (ms). */
  startMs: number;
  /** How much earlier than planned (ms). */
  shiftMs: number;
  /** Trim the line to this length (ms), or null when it now fits. */
  trimToMs: number | null;
}

/**
 * @param startMs      planned start of the dubbed line (the source turn's start)
 * @param durationMs   the dubbed line's real length after tempo
 * @param ceilingMs    latest time the line may end (next speaker's start − separation, or clip end)
 * @param prevEndMs    where the previous dubbed line really ends (null for the first line)
 */
export function planPreroll(params: {
  startMs: number;
  durationMs: number;
  ceilingMs: number;
  prevEndMs: number | null;
  maxPrerollMs?: number;
  separationMs?: number;
}): PrerollPlan {
  const maxPreroll = params.maxPrerollMs ?? PREROLL.maxPrerollMs;
  const separation = params.separationMs ?? PREROLL.separationMs;
  const overflow = params.startMs + params.durationMs - params.ceilingMs;
  if (!(overflow > PREROLL.minOverflowMs)) {
    return { startMs: params.startMs, shiftMs: 0, trimToMs: null };
  }
  const earliest = params.prevEndMs === null ? 0 : params.prevEndMs + separation;
  const room = Math.max(0, params.startMs - earliest);
  const shiftMs = Math.round(Math.min(overflow, room, maxPreroll));
  const startMs = params.startMs - shiftMs;
  const remaining = startMs + params.durationMs - params.ceilingMs;
  const trimToMs = remaining > PREROLL.minOverflowMs ? Math.max(200, Math.round(params.ceilingMs - startMs)) : null;
  return { startMs, shiftMs, trimToMs };
}
