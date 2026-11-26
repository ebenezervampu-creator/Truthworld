/**
 * Pure planning helpers for the resolution service (no Firebase calls), so the
 * retry, tier-selection and reset decisions can be unit-tested.
 */

/**
 * How many times the reconciler may re-send one variant before giving up.
 * A worker that dies (timeout / out of memory) leaves its variant "processing";
 * without a cap that variant was re-sent every 15-25 minutes forever (re-audit R1).
 */
export const MAX_VARIANT_DISPATCH_ATTEMPTS = 3;

/**
 * Sources a few pixels short of a tier (e.g. 1918x1078) still get that tier.
 * Matches the worker's no-upscale gate, which also allows +16 px.
 */
export const TIER_TOLERANCE_PX = 16;

export interface VariantRetryPlan {
  /** Variant labels to send to the worker again. */
  retry: string[];
  /** Variant labels that used up their attempts and must be marked failed. */
  giveUp: string[];
}

/**
 * Splits unfinished variants (pending / processing) into ones to re-send and
 * ones to give up on, using each variant's `dispatchAttempts` counter.
 */
export function planVariantRetries(
  variants: Record<string, any> | null | undefined,
  maxAttempts: number = MAX_VARIANT_DISPATCH_ATTEMPTS
): VariantRetryPlan {
  const plan: VariantRetryPlan = { retry: [], giveUp: [] };
  if (!variants || typeof variants !== "object") return plan;

  for (const [label, variant] of Object.entries(variants)) {
    if (!variant || typeof variant !== "object") continue;
    if (variant.status !== "pending" && variant.status !== "processing") continue;
    const attempts = Number(variant.dispatchAttempts) || 0;
    if (attempts >= maxAttempts) {
      plan.giveUp.push(label);
    } else {
      plan.retry.push(label);
    }
  }
  return plan;
}

/** True when a source whose shorter side is `sourceShortSide` px should get a tier of `tierShortSide` px. */
export function tierFitsSource(tierShortSide: number, sourceShortSide: number): boolean {
  if (!(sourceShortSide > 0)) return false;
  return tierShortSide <= sourceShortSide + TIER_TOLERANCE_PX;
}

/**
 * Fields to write on videos/{videoId} when a new source upload starts processing.
 * Clears every playback field the resolution service owns, so a re-upload never
 * leaves `media.playbackReady: true` pointing at an emptied ladder (re-audit R5).
 * `hlsUrl` is cleared only when it points at this service's Transcoder output;
 * the dubbing HLS packager writes its own master playlist there too.
 */
export function playbackResetFields(
  videoId: string,
  videoData: Record<string, any> | null | undefined,
  deleteSentinel: unknown
): Record<string, unknown> {
  const fields: Record<string, unknown> = {
    "adaptiveResolutions": [],
    "media.adaptiveResolutions": [],
    "media.variants": {},
    "media.playbackReady": false,
    "media.isHls": false,
    "media.hlsUrl": deleteSentinel,
    "media.abrHlsUrl": deleteSentinel,
    "media.abrHlsHdUrl": deleteSentinel,
    "media.transcodeFailed": deleteSentinel,
    "media.transcodeError": deleteSentinel,
  };

  const hlsUrl = videoData?.hlsUrl;
  if (typeof hlsUrl === "string" && isResolutionHlsUrl(hlsUrl, videoId)) {
    fields.hlsUrl = deleteSentinel;
  }
  return fields;
}

/** True when the URL points at resolutions/{videoId}/hls/ (Transcoder output). */
export function isResolutionHlsUrl(url: string, videoId: string): boolean {
  const plain = `resolutions/${videoId}/hls/`;
  const encoded = encodeURIComponent(plain);
  return url.includes(plain) || url.includes(encoded);
}

/** Event id for the low-tier batch; includes the source generation so re-uploads aren't skipped (re-audit R3). */
export function secondaryBatchEventId(videoId: string, generation: unknown): string {
  const gen = generation === undefined || generation === null || generation === "" ? "1" : String(generation);
  return `${videoId}_secondary_${gen}`;
}

/** Shorter side of a variant: its quality class, the same for portrait and landscape. */
export function variantShortSide(variant: { width?: number; height?: number }): number {
  const w = Number(variant?.width) || 0;
  const h = Number(variant?.height) || 0;
  return w > 0 && h > 0 ? Math.min(w, h) : h;
}

/** Quality made first so a new upload is playable quickly on any network (YouTube-style). */
export const FIRST_PLAYABLE_SHORT_SIDE = 360;

export interface UploadBatchPlan<T> {
  /** Sent first, in this order. Starts with the quick low quality, then 720p and up (lowest first). */
  primary: T[];
  /** Remaining low qualities, made later from the finished 720p/1080p file (cheaper than the original). */
  secondary: T[];
}

/**
 * Orders the qualities of a new upload so it becomes playable as soon as possible.
 *
 * Previously the highest quality (e.g. 1080p/1440p) was made first and the video
 * couldn't play until it finished. Now 360p is made first from the original,
 * then 720p and up in ascending order, and the remaining low qualities follow
 * in the secondary batch, downscaled from the finished 720p file.
 *
 * Tiers are classified by their shorter side, so portrait videos (e.g. 480x854)
 * count as 480p, not as a high tier.
 */
export function planUploadBatches<T extends { width?: number; height?: number }>(applicable: T[]): UploadBatchPlan<T> {
  const ascending = [...applicable].sort((a, b) => variantShortSide(a) - variantShortSide(b));
  const high = ascending.filter((v) => variantShortSide(v) >= 720);
  const low = ascending.filter((v) => variantShortSide(v) < 720);

  // Quick first quality: 360p if the ladder has it, else the largest low tier below 360p,
  // else (no low tiers at all) nothing extra.
  const firstPlayable =
    low.find((v) => variantShortSide(v) === FIRST_PLAYABLE_SHORT_SIDE) ??
    [...low].reverse().find((v) => variantShortSide(v) < FIRST_PLAYABLE_SHORT_SIDE) ??
    low[0];

  if (high.length === 0) {
    // Source below 720p: everything comes from the original in one batch, quick quality first.
    const rest = ascending.filter((v) => v !== firstPlayable);
    return { primary: firstPlayable ? [firstPlayable, ...rest] : rest, secondary: [] };
  }

  return {
    primary: firstPlayable ? [firstPlayable, ...high] : high,
    secondary: low.filter((v) => v !== firstPlayable),
  };
}

/**
 * Message shown to creators when no quality could be prepared (media.transcodeError).
 * Plain, actionable English only: the raw error stays on resolution_jobs.error
 * for engineers (CLAUDE.md "Zero Raw Developer Error Policy").
 */
export const TRANSCODE_FAILED_MESSAGE =
  "We couldn't prepare the streaming versions of this video. It still plays in its original quality. Uploading the video again usually fixes this.";
