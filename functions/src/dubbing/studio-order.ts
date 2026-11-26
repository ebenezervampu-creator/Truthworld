/**
 * Dubbing Studio order rules (pure, no Firestore / network).
 *
 * Used by createDubbingJob and regenerateDubbingSegment in standaloneDubbing.ts. Kept separate so the
 * money and consent rules can be unit-tested without Firebase.
 */

import { dubbingCharge, DubbingQuote } from "../pipeline/services/dubbing-pricing";
import { parseAnyStorageUrl } from "../pipeline/services/media";
import { calculateSubtitleCost, getFlatDubbingPriceForTier } from "../pipeline/services/cost-engine";

/** Longest video the Studio accepts (the app enforces the same limit before upload). */
export const STUDIO_MAX_DURATION_SECONDS = 2 * 60 * 60;

// ── Voice cloning: off unless the creator turns it on AND confirms consent ─────────────────────────

export interface StudioCloneRequest {
  voiceCloningEnabled?: unknown;
  voiceCloneConsent?: unknown;
  saveVoiceProfile?: unknown;
}

export type StudioCloneDecision =
  | { ok: true; dubbingMode: "voice_clone" | "standard"; voiceCloneConsent: boolean; saveAsCreatorProfile: boolean }
  | { ok: false; message: string };

/**
 * Voice cloning is never a default. It runs only when the request explicitly asks for it
 * (`voiceCloningEnabled === true`) and confirms permission (`voiceCloneConsent === true`).
 * Asking for cloning without consent is refused before anything is charged.
 */
export function decideStudioVoiceCloning(req: StudioCloneRequest): StudioCloneDecision {
  const wantsClone = req.voiceCloningEnabled === true;
  if (!wantsClone) {
    return { ok: true, dubbingMode: "standard", voiceCloneConsent: false, saveAsCreatorProfile: false };
  }
  if (req.voiceCloneConsent !== true) {
    return {
      ok: false,
      message:
        "To clone voices, please confirm that you are the speaker or have the speakers' permission, or turn voice cloning off.",
    };
  }
  return {
    ok: true,
    dubbingMode: "voice_clone",
    voiceCloneConsent: true,
    saveAsCreatorProfile: req.saveVoiceProfile === true,
  };
}

// ── Price: dubbing vs subtitles-only ────────────────────────────────────────────────────────────────

/** Subtitle discount from admin-set channel fields only (same rule as triggerVideoAIFeatures). */
export function channelSubtitleDiscountPercent(channelData: Record<string, any>, isAdmin: boolean): number {
  const isFree =
    channelData?.isSubtitlesFree === true ||
    channelData?.subtitlesDiscountType === "free" ||
    Number(channelData?.subtitlesDiscountPercent) >= 100 ||
    channelData?.aiDiscounts?.subtitles?.type === "free" ||
    Number(channelData?.aiDiscounts?.subtitles?.percent) >= 100;
  if (isFree || isAdmin) return 100;
  const pct = Number(channelData?.subtitlesDiscountPercent ?? channelData?.aiDiscounts?.subtitles?.percent ?? 0);
  return Math.max(0, Math.min(100, Number.isFinite(pct) ? pct : 0));
}

export interface StudioChargeInput {
  mode: string;
  targetLanguages: string[];
  durationSeconds: number;
  channelData: Record<string, any>;
  isAdmin: boolean;
  dubbingDiscountPercent: number;
  quote: DubbingQuote | null;
  characterPricing: boolean;
}

export interface StudioCharge {
  kind: "dubbing" | "subtitles";
  chargedUsd: number;
  dubbingUsd: number;
  subtitleUsd: number;
  dubbingPriceByLanguage: Record<string, number>;
  basis?: "minutes" | "characters";
}

/**
 * What a Studio order costs. "Subtitles only" is billed at the subtitle price (it used to be billed
 * as a full dub); dubbing uses the same dubbingCharge as the main order path.
 */
export function studioCharge(input: StudioChargeInput): StudioCharge {
  if (input.mode === "subtitles_only") {
    const channelType: "standard" | "custom" = input.channelData?.channelType === "custom" ? "custom" : "standard";
    const subtitleUsd = calculateSubtitleCost(
      input.targetLanguages.length,
      input.durationSeconds,
      channelType,
      channelSubtitleDiscountPercent(input.channelData, input.isAdmin),
      "ultra"
    );
    return { kind: "subtitles", chargedUsd: subtitleUsd, dubbingUsd: 0, subtitleUsd, dubbingPriceByLanguage: {} };
  }
  const charge = dubbingCharge({
    targetLanguages: input.targetLanguages,
    minutePricePerLanguageUsd: getFlatDubbingPriceForTier(input.durationSeconds, "audio_track"),
    discountPercent: input.dubbingDiscountPercent,
    quote: input.quote,
    characterPricing: input.characterPricing,
  });
  return {
    kind: "dubbing",
    chargedUsd: charge.chargedUsd,
    dubbingUsd: charge.chargedUsd,
    subtitleUsd: 0,
    dubbingPriceByLanguage: charge.priceByLanguage,
    basis: charge.basis,
  };
}

// ── Duration: measured by the server, never taken from the app ──────────────────────────────────────

export type StudioDurationDecision = { ok: true; seconds: number } | { ok: false; message: string };

/**
 * The billed length. Prefer the video document's stored duration (set at ingestion); otherwise the
 * server-measured duration of the media file. The app-sent duration is never used for billing.
 */
export function decideStudioDuration(storedSeconds: unknown, probedMs: number): StudioDurationDecision {
  const stored = Number(storedSeconds);
  const seconds = Number.isFinite(stored) && stored > 0 ? stored : probedMs > 0 ? probedMs / 1000 : 0;
  if (!(seconds > 0)) {
    return {
      ok: false,
      message: "We couldn't read the length of this video. Please check the file and upload it again.",
    };
  }
  if (seconds > STUDIO_MAX_DURATION_SECONDS) {
    return { ok: false, message: "Videos longer than 2 hours can't be dubbed yet. Please trim the video and try again." };
  }
  return { ok: true, seconds: Math.ceil(seconds) };
}

// ── Line regeneration: which line the app means ─────────────────────────────────────────────────────

/**
 * The editable-track line index (0-based, as stored in the dubbing manifest).
 * An explicit numeric `segmentIndex` is already 0-based. Studio line ids are `seg_1`, `seg_2`, …
 * (1-based, built by the app), so `seg_N` is line N − 1. Returns null when nothing identifies a line
 * (it used to fall back to line 0, silently editing the wrong line).
 */
export function studioSegmentIndex(segmentIndex: unknown, segmentId: unknown): number | null {
  if (typeof segmentIndex === "number" && Number.isInteger(segmentIndex) && segmentIndex >= 0) return segmentIndex;
  const match = typeof segmentId === "string" ? segmentId.match(/^seg(?:ment)?[_-]?(\d+)$/i) : null;
  if (match) {
    const n = parseInt(match[1], 10);
    if (n >= 1) return n - 1;
  }
  return null;
}

// ── Export: never offer the original upload as a dubbed video ───────────────────────────────────────

/**
 * True only for a dubbed MP4 built by the pipeline's remux step (`videos/{jobId}/{lang}-dubbed.mp4`),
 * and never for the original upload. The editable manifest falls back to the original video when no
 * dubbed MP4 exists, which used to be exported as the "dubbed video".
 */
export function isDubbedVideoUrl(url: unknown, originalUrl: unknown): boolean {
  if (typeof url !== "string" || !url) return false;
  const filePath = parseAnyStorageUrl(url)?.filePath;
  if (!filePath || !/-dubbed\.mp4$/i.test(filePath)) return false;
  const originalPath = typeof originalUrl === "string" ? parseAnyStorageUrl(originalUrl)?.filePath : undefined;
  return filePath !== originalPath;
}
