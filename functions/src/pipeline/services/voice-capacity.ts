/**
 * Can this ElevenLabs account create another voice clone right now? (dependency-free, unit-tested)
 *
 * Read from GET /v1/user/subscription:
 *   voice_slots_used / voice_limit              — custom voice slots (Starter 10, Creator 30, Pro 160)
 *   voice_add_edit_counter / max_voice_add_edits — monthly voice add/edit operations (Starter 65, Creator 95)
 *   can_use_instant_voice_cloning
 * Checked before cloning a creator's voice so a full account gives the creator a clear notice and a
 * matched studio voice, instead of a failed clone call that still costs an operation.
 */

import { estimateDubbedChars } from "./dubbing-pricing";

export type CloneBlockReason = "slots_full" | "monthly_voice_edits_used" | "cloning_not_on_plan";
export type OrderCapacityBlockReason = CloneBlockReason | "insufficient_chars";

export interface VoiceCapacity {
  canClone: boolean;
  reason?: CloneBlockReason;
  slotsUsed?: number;
  slotLimit?: number;
  editsUsed?: number;
  editLimit?: number | null;
}

export interface PlanLimitOverrides {
  charLimit?: number;
  voiceSlots?: number;
  voiceOps?: number;
  charBuffer: number;
}

export interface OrderCapacityNeeded {
  chars: number;
  clones: number;
}

export interface OrderCapacityResult {
  ok: boolean;
  reason?: OrderCapacityBlockReason;
  remainingChars: number | null;
  slotsFree: number | null;
  opsLeft: number | null;
  needed: OrderCapacityNeeded;
}

const num = (v: unknown): number | undefined => (typeof v === "number" && Number.isFinite(v) ? v : undefined);

const envPosInt = (name: string): number | undefined => {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") return undefined;
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0 ? Math.floor(n) : undefined;
};

/** Plan limits configurable by env (no plan names hard-coded). */
export function readPlanLimitOverrides(): PlanLimitOverrides {
  return {
    charLimit: envPosInt("ELEVENLABS_PLAN_CHAR_LIMIT"),
    voiceSlots: envPosInt("ELEVENLABS_PLAN_VOICE_SLOTS"),
    voiceOps: envPosInt("ELEVENLABS_PLAN_VOICE_OPS"),
    charBuffer: envPosInt("ELEVENLABS_CAPACITY_CHAR_BUFFER") ?? 0,
  };
}

/** Estimate TTS characters and voice clones needed for a dubbing order. */
export function estimateOrderRequirements(params: {
  durationSec: number;
  sourceChars?: number;
  sourceLang: string;
  targetLanguages: string[];
  clonesNeeded?: number;
}): OrderCapacityNeeded {
  const baseLang = (params.sourceLang || "en").toLowerCase().trim().split(/[-_]/)[0];
  const srcChars =
    typeof params.sourceChars === "number" && params.sourceChars > 0
      ? params.sourceChars
      : Math.max(0, Math.ceil((Number(params.durationSec) > 0 ? Number(params.durationSec) : 0) * 15));

  let chars = 0;
  for (const lang of params.targetLanguages || []) {
    const norm = (lang || "").toLowerCase().trim().split(/[-_]/)[0];
    if (!norm || norm === baseLang) continue;
    chars += estimateDubbedChars(srcChars, baseLang, norm);
  }
  return {
    chars,
    clones: Math.max(0, Math.floor(params.clonesNeeded ?? 0)),
  };
}

export function evaluateOrderCapacity(
  subscription: Record<string, unknown> | null | undefined,
  needed: OrderCapacityNeeded,
  overrides: PlanLimitOverrides = readPlanLimitOverrides()
): OrderCapacityResult {
  const s = subscription || {};
  const charCount = num(s.character_count);
  const charLimit = overrides.charLimit ?? num(s.character_limit);
  const remainingChars =
    charLimit !== undefined && charCount !== undefined
      ? Math.max(0, charLimit - charCount - overrides.charBuffer)
      : null;

  const slotsUsed = num(s.voice_slots_used);
  const slotLimit = overrides.voiceSlots ?? num(s.voice_limit);
  const slotsFree =
    slotLimit !== undefined && slotsUsed !== undefined
      ? Math.max(0, slotLimit - slotsUsed)
      : null;

  const editsUsed = num(s.voice_add_edit_counter);
  const editLimit =
    overrides.voiceOps !== undefined
      ? overrides.voiceOps
      : s.max_voice_add_edits === null
        ? null
        : num(s.max_voice_add_edits);
  const opsLeft =
    editLimit === null
      ? null
      : editLimit !== undefined && editsUsed !== undefined
        ? Math.max(0, editLimit - editsUsed)
        : null;

  const base = { remainingChars, slotsFree, opsLeft, needed };

  if (remainingChars !== null && needed.chars > remainingChars) {
    return { ok: false, reason: "insufficient_chars", ...base };
  }
  if (needed.clones > 0) {
    if (s.can_use_instant_voice_cloning === false) {
      return { ok: false, reason: "cloning_not_on_plan", ...base };
    }
    if (slotsFree !== null && needed.clones > slotsFree) {
      return { ok: false, reason: "slots_full", ...base };
    }
    if (opsLeft !== null && needed.clones > opsLeft) {
      return { ok: false, reason: "monthly_voice_edits_used", ...base };
    }
  }
  return { ok: true, ...base };
}

/** Polite, creator-facing explanation when capacity is short before charging. */
export function orderCapacityUnavailableMessage(): string {
  return "We're at dubbing capacity right now and can't start this order. Your wallet has not been charged. Please try again shortly.";
}

export function evaluateCloneCapacity(subscription: Record<string, unknown> | null | undefined): VoiceCapacity {
  const s = subscription || {};
  const slotsUsed = num(s.voice_slots_used);
  const slotLimit = num(s.voice_limit);
  const editsUsed = num(s.voice_add_edit_counter);
  const editLimit = s.max_voice_add_edits === null ? null : num(s.max_voice_add_edits);
  const base = { slotsUsed, slotLimit, editsUsed, editLimit };

  if (s.can_use_instant_voice_cloning === false) return { canClone: false, reason: "cloning_not_on_plan", ...base };
  if (slotsUsed !== undefined && slotLimit !== undefined && slotsUsed >= slotLimit) {
    return { canClone: false, reason: "slots_full", ...base };
  }
  if (editsUsed !== undefined && typeof editLimit === "number" && editsUsed >= editLimit) {
    return { canClone: false, reason: "monthly_voice_edits_used", ...base };
  }
  return { canClone: true, ...base };
}

/** Polite, creator-facing explanation (no technical detail, per TruthWorld's UI rules). */
export function cloneUnavailableMessage(reason: CloneBlockReason | "clone_failed"): string {
  const tail = "We dubbed your video with a closely matched studio voice instead.";
  switch (reason) {
    case "slots_full":
      return `Your own voice couldn't be used this time because our voice-cloning capacity is currently full. ${tail}`;
    case "monthly_voice_edits_used":
      return `Your own voice couldn't be used this time because this month's voice-cloning allowance has been used. It resets next month. ${tail}`;
    case "cloning_not_on_plan":
      return `Voice cloning isn't available right now. ${tail}`;
    default:
      return `We couldn't create your voice for this dub. ${tail}`;
  }
}
