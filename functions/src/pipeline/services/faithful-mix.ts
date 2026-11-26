/**
 * Faithful dub mix — the dub must sound like the original video, apart from the language.
 *
 * Rule (decided 2026-11-21, measured on the 30.8 s English → Telugu sample; see the project doc
 * "dubbing-indistinguishable-mix.md"):
 *   1. Outside the dialogue regions the output IS the original audio. No separation, filtering,
 *      ducking or loudness normalisation touches it, so songs, singing, effects, ambience and the
 *      stereo image stay exactly as they were.
 *   2. Inside the dialogue regions the output is the original's background stem (only when it is a
 *      clean neural stem) plus the dubbed voice. Without a clean stem the dubbed voice plays alone
 *      there, as before — a degraded stem carries the original voice, which must never ship.
 *   3. Each speaker's dubbed voice is set to the level of that speaker's original voice, so the
 *      dialogue/background balance is the original's.
 *   4. The finished track keeps the original's integrated loudness (no −14 LUFS re-target).
 *
 * Pure functions only — decoding and FFmpeg live in MediaService.mixDubFaithful.
 * Rollback: DUBBING_FAITHFUL_MIX=false restores the previous mixer (mixDubWithMne).
 */

export interface TimeSpanMs {
  startMs: number;
  endMs: number;
}

export interface SpeakerSpanMs extends TimeSpanMs {
  speaker: string;
  sceneId?: number;
}

export interface GainSpan extends TimeSpanMs {
  gain: number; // linear
  speaker?: string;
  sceneId?: number;
  branchIndex?: number;
}

export const FAITHFUL_MIX = {
  /** Added around every spoken line so word edges and breaths stay inside the region. */
  padMs: 150,
  /** Regions closer than this are merged (a crossfade pair needs room, and short gaps hold breaths). */
  mergeGapMs: 400,
  /** Crossfade between the original audio and the dubbed region at each edge. */
  fadeMs: 80,
  /** Largest level correction applied to a dubbed voice. */
  maxVoiceGainDb: 12,
  /** Dub activity detection: frames louder than this (dBFS) count as speech. */
  activityThresholdDb: -45,
  /** …or this far below the dub's loudest frame, whichever is higher. */
  activityRelativeDb: 30,
  /** A dubbed line may run this long past its source line; activity further away is ignored. */
  maxDubOverrunMs: 2000,
  /** Dub activity detection frame length. */
  activityFrameMs: 20,
  /** Outside the dialogue regions the output must match the original within this (dB). */
  maxOutsideDiffDb: 0.5,
  /** Share of the audible dubbed speech that must fall inside the dialogue regions. */
  minDubCoverage: 0.9,
} as const;

/** DUBBING_FAITHFUL_MIX=false switches back to the previous mixer. On by default. */
export function faithfulMixEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_FAITHFUL_MIX ?? "true").toLowerCase() !== "false";
}

/** DUBBING_ROOM_MATCH=true enables room measurement and synthetic reverb matching. Off by default. */
export function roomMatchEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_ROOM_MATCH ?? "false").toLowerCase() === "true";
}

/** DUBBING_SCENE_TONE=true enables per-scene tone matching. Off by default. */
export function sceneToneEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_SCENE_TONE ?? "false").toLowerCase() === "true";
}

/**
 * DUBBING_BED_MATCH=true corrects the separated background (Demucs bed) toward the original before
 * mixing: its level and tone are measured where nobody speaks (original = pure background there) and
 * a bounded correction is applied to the bed. Off by default. Added 2026-11-25: on run …4954895 the bed
 * measured −1.61 dB overall and up to −12.7 dB at 1250 Hz against the original in the gaps (agent's
 * measure-bgm-clips.ts), and the background was −2.39 dB under dialogue.
 */
export function bedMatchEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_BED_MATCH ?? "false").toLowerCase() === "true";
}

export const BED_MATCH = {
  /** Least speech-free audio (s) to measure from; less and no correction is made. */
  minGapSec: 3,
  /** Shortest speech-free span used (ms). */
  minGapSpanMs: 300,
  /** Margin kept around any speech or voice activity (ms). */
  speechGuardMs: 150,
  /** Largest correction per band (dB), either way. */
  maxGainDb: 6,
  /** Bands more than this far below the original's loudest band are left alone (dB). */
  bandFloorDb: 40,
  /** Corrections smaller than this are not applied (dB). */
  minGainDb: 0.5,
  /** Most gap audio analysed (s). */
  maxAnalysisSec: 90,
} as const;

export interface BedMatchPlan {
  applied: boolean;
  reason: string;
  gapSeconds: number;
  gainDb: number;
  bandsDb: number[] | null;
  filter: string | null;
}

/**
 * Speech-free spans of the whole video: everything outside the spoken lines, the source words and
 * any voice activity (including non-verbal sounds), each padded by speechGuardMs.
 */
export function speechFreeSpans(totalMs: number, speech: TimeSpanMs[], guardMs: number = BED_MATCH.speechGuardMs, minMs: number = BED_MATCH.minGapSpanMs): TimeSpanMs[] {
  const padded = speech
    .filter((s) => s.endMs > s.startMs)
    .map((s) => ({ startMs: Math.max(0, s.startMs - guardMs), endMs: Math.min(totalMs, s.endMs + guardMs) }));
  return subtractSpans([{ startMs: 0, endMs: totalMs }], padded, minMs);
}

/**
 * Correction for the bed from the original's and the bed's band profiles (dB, EQ_BAND_EDGES) over the
 * same speech-free spans. Each band that carries sound in the original (within bandFloorDb of its
 * loudest band) is moved by original − bed, bounded to ±maxGainDb; near-empty bands are left alone
 * (their level is codec noise, not music). One filter corrects level and tone together.
 * gainDb reports the overall level change (power-weighted over the corrected bands).
 */
export function planBedMatch(params: {
  gapSeconds: number;
  originalProfile: number[] | null;
  bedProfile: number[] | null;
  originalDb: number | null;
  bedDb: number | null;
}): BedMatchPlan {
  const gapSeconds = Number(params.gapSeconds.toFixed(2));
  const none = (reason: string, bandsDb: number[] | null = null, gainDb = 0): BedMatchPlan => ({ applied: false, reason, gapSeconds, gainDb, bandsDb, filter: null });
  if (gapSeconds < BED_MATCH.minGapSec) return none(`only ${gapSeconds} s without speech (needs ${BED_MATCH.minGapSec} s)`);
  if (params.originalDb === null || params.bedDb === null) return none("level not measurable");
  const o = params.originalProfile;
  const b = params.bedProfile;
  if (!o || !b || o.length !== b.length) return none("spectrum not measurable");
  const valid = o.map((v, i) => Number.isFinite(v) && Number.isFinite(b[i]) && v > -150 && b[i] > -150);
  const loudest = Math.max(...o.filter((_, i) => valid[i]));
  if (!Number.isFinite(loudest)) return none("spectrum not measurable");
  const bandsDb = o.map((v, i) =>
    valid[i] && v >= loudest - BED_MATCH.bandFloorDb
      ? Number(Math.max(-BED_MATCH.maxGainDb, Math.min(BED_MATCH.maxGainDb, v - b[i])).toFixed(1))
      : 0
  );
  let wSum = 0;
  let pSum = 0;
  bandsDb.forEach((g, i) => {
    if (!valid[i] || o[i] < loudest - BED_MATCH.bandFloorDb) return;
    const w = Math.pow(10, o[i] / 10);
    wSum += w;
    pSum += w * Math.pow(10, g / 10);
  });
  const gainDb = wSum > 0 ? Number((10 * Math.log10(pSum / wSum)).toFixed(1)) : 0;
  if (bandsDb.every((g) => Math.abs(g) < BED_MATCH.minGainDb)) return none("bed already matches the original", bandsDb, gainDb);
  const filter = eqFilterFor(bandsDb);
  if (!filter) return none("bed already matches the original", bandsDb, gainDb);
  return { applied: true, reason: "matched", gapSeconds, gainDb, bandsDb, filter };
}

/** DUBBING_TIGHT_STEM=true uses the background stem only where original voice is active. Off by default. */
export function tightStemEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_TIGHT_STEM ?? "false").toLowerCase() === "true";
}

/** DUBBING_VOICE_RIDE=true rides the dubbed voice with background music swells within ±3 dB. Off by default. */
export function voiceRideEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_VOICE_RIDE ?? "false").toLowerCase() === "true";
}

/** DUBBING_KEEP_NONVERBAL=true keeps non-verbal vocal sounds (gasps, grunts, laughs) from the original. Off by default. */
export function keepNonVerbalEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_KEEP_NONVERBAL ?? "false").toLowerCase() === "true";
}

/** DUBBING_FIDELITY_STEM_SELECT=true picks between best-of-2 stems by gap fidelity, not only bleed. Off by default. */
export function fidelityStemSelectEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_FIDELITY_STEM_SELECT ?? "false").toLowerCase() === "true";
}

/**
 * Whether the background stem may be used under the dubbed dialogue. Only a clean neural stem,
 * and only when the isolated original voice exists for the source-bleed check (without it, the
 * delivery check compares against the full original and would read the original music as bleed).
 */
export function canUseBedUnderDialogue(params: {
  bedUrl?: string | null;
  isolatedVocalUrl?: string | null;
  validationStatus?: string | null;
  source?: string | null;
}): boolean {
  if (!params.bedUrl || !params.isolatedVocalUrl) return false;
  if (params.validationStatus === "failed" || params.validationStatus === "degraded") return false;
  // MneValidationResult sources produced by FFmpeg filtering, not by a separation model.
  const degradedSources = new Set(["dsp_fallback", "fallback_crossover"]);
  return !degradedSources.has(String(params.source || ""));
}

/** Union of spans, each padded, clamped to [0, totalMs], merged when the gap is below mergeGapMs. */
export function planDialogueRegions(
  spans: TimeSpanMs[],
  totalMs: number,
  opts: { padMs?: number; mergeGapMs?: number } = {}
): TimeSpanMs[] {
  const pad = opts.padMs ?? FAITHFUL_MIX.padMs;
  const mergeGap = opts.mergeGapMs ?? FAITHFUL_MIX.mergeGapMs;
  const limit = Number.isFinite(totalMs) && totalMs > 0 ? totalMs : Infinity;
  const padded = spans
    .filter((s) => Number.isFinite(s.startMs) && Number.isFinite(s.endMs) && s.endMs > s.startMs)
    .map((s) => ({ startMs: Math.max(0, s.startMs - pad), endMs: Math.min(limit, s.endMs + pad) }))
    .filter((s) => s.endMs > s.startMs)
    .sort((a, b) => a.startMs - b.startMs);
  const merged: TimeSpanMs[] = [];
  for (const s of padded) {
    const last = merged[merged.length - 1];
    if (last && s.startMs - last.endMs < mergeGap) {
      last.endMs = Math.max(last.endMs, s.endMs);
    } else {
      merged.push({ ...s });
    }
  }
  return merged;
}

/** Complement of the regions inside [0, totalMs]. */
export function outsideRegions(regions: TimeSpanMs[], totalMs: number): TimeSpanMs[] {
  const out: TimeSpanMs[] = [];
  let cursor = 0;
  for (const r of [...regions].sort((a, b) => a.startMs - b.startMs)) {
    if (r.startMs > cursor) out.push({ startMs: cursor, endMs: r.startMs });
    cursor = Math.max(cursor, r.endMs);
  }
  if (totalMs > cursor) out.push({ startMs: cursor, endMs: totalMs });
  return out;
}

/**
 * Spans where the dubbed track is audible (mono PCM, any sample rate). Gaps shorter than
 * minGapMs are bridged so a line with short pauses stays one span.
 */
export function detectActiveSpans(
  pcm: Float32Array,
  sampleRate: number,
  opts: { thresholdDb?: number; relativeDb?: number; frameMs?: number; minGapMs?: number } = {}
): TimeSpanMs[] {
  const frameMs = opts.frameMs ?? FAITHFUL_MIX.activityFrameMs;
  const minGap = opts.minGapMs ?? 300;
  const frame = Math.max(1, Math.round((sampleRate * frameMs) / 1000));
  const frameDb: number[] = [];
  for (let i = 0; i + frame <= pcm.length; i += frame) {
    let sum = 0;
    for (let j = i; j < i + frame; j++) sum += pcm[j] * pcm[j];
    frameDb.push(10 * Math.log10(sum / frame + 1e-12));
  }
  // Absolute floor, raised to (loudest frame − relativeDb) so faint residue never counts as speech.
  const loudest = frameDb.length > 0 ? Math.max(...frameDb) : -120;
  const threshold = Math.max(opts.thresholdDb ?? FAITHFUL_MIX.activityThresholdDb, loudest - (opts.relativeDb ?? FAITHFUL_MIX.activityRelativeDb));
  const spans: TimeSpanMs[] = [];
  let open: number | null = null;
  let lastActiveEnd = 0;
  for (let k = 0; k < frameDb.length; k++) {
    const db = frameDb[k];
    const tMs = k * frameMs;
    if (db > threshold) {
      if (open === null) open = tMs;
      lastActiveEnd = tMs + frameMs;
    } else if (open !== null && tMs - lastActiveEnd >= minGap) {
      spans.push({ startMs: open, endMs: lastActiveEnd });
      open = null;
    }
  }
  if (open !== null) spans.push({ startMs: open, endMs: lastActiveEnd });
  return spans;
}

/**
 * Dub activity that belongs to a spoken line: it must overlap the window from 500 ms before a
 * source line to maxDubOverrunMs after it. Anything else (residue, noise) is ignored, and kept
 * spans are clipped to that window, so the original audio is never replaced far from dialogue.
 */
export function dubSpansNearLines(active: TimeSpanMs[], lines: TimeSpanMs[], maxOverrunMs: number = FAITHFUL_MIX.maxDubOverrunMs): TimeSpanMs[] {
  const windows = lines
    .filter((l) => l.endMs > l.startMs)
    .map((l) => ({ startMs: Math.max(0, l.startMs - 500), endMs: l.endMs + maxOverrunMs }));
  const out: TimeSpanMs[] = [];
  for (const a of active) {
    for (const w of windows) {
      const startMs = Math.max(a.startMs, w.startMs);
      const endMs = Math.min(a.endMs, w.endMs);
      if (endMs > startMs) out.push({ startMs, endMs });
    }
  }
  return out;
}

/**
 * Level of the original voice from measurements over the same spans: the isolated voice when
 * available; otherwise the source mix with the background's power removed.
 */
export function estimateOriginalVoiceDb(params: {
  isolatedVoiceDb?: number | null;
  sourceDb?: number | null;
  bedDb?: number | null;
}): number | null {
  const ok = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v) && v > -90;
  if (ok(params.isolatedVoiceDb)) return params.isolatedVoiceDb;
  if (!ok(params.sourceDb)) return null;
  if (ok(params.bedDb)) {
    const voicePower = 10 ** (params.sourceDb / 10) - 10 ** (params.bedDb / 10);
    if (voicePower > 10 ** (params.sourceDb / 10) * 0.1) return 10 * Math.log10(voicePower);
  }
  return params.sourceDb;
}

/** Gain (dB) that brings a dubbed voice to its original voice's level, clamped. 0 when unknown. */
export function voiceGainDb(originalDb: number | null | undefined, dubDb: number | null | undefined, maxDb: number = FAITHFUL_MIX.maxVoiceGainDb): number {
  if (typeof originalDb !== "number" || typeof dubDb !== "number" || !Number.isFinite(originalDb) || !Number.isFinite(dubDb) || dubDb < -90) {
    return 0;
  }
  return Number(Math.max(-maxDb, Math.min(maxDb, originalDb - dubDb)).toFixed(2));
}

/** Lines in time order, as every per-line function here indexes them. */
export function sortedLines<T extends SpeakerSpanMs>(lines: T[]): T[] {
  return [...lines].filter((l) => l.endMs > l.startMs).sort((a, b) => a.startMs - b.startMs);
}

/**
 * Per-line gain spans for the dubbed track. Each line's span runs from its start to the next
 * line's start (or +1.5 s for the last), so a dubbed line that runs past its source window keeps
 * its gain. `lineGainDb` (in sortedLines order) overrides the speaker's gain line by line.
 */
export function buildGainSpans(
  lines: SpeakerSpanMs[],
  gainDbBySpeaker: Record<string, number>,
  totalMs: number,
  lineGainDb?: Array<number | null | undefined>
): GainSpan[] {
  const sorted = sortedLines(lines);
  return sorted.map((l, i) => {
    const next = sorted[i + 1];
    const end = next ? next.startMs : Math.min(totalMs > 0 ? totalMs : Infinity, l.endMs + 1500);
    const perLine = lineGainDb?.[i];
    const db = typeof perLine === "number" && Number.isFinite(perLine) ? perLine : gainDbBySpeaker[l.speaker] ?? 0;
    return { startMs: Math.max(0, l.startMs - 50), endMs: Math.max(l.startMs, end), gain: 10 ** (db / 20), speaker: l.speaker };
  });
}

// ── Line-by-line level (2026-11-24) ────────────────────────────────────────────────────────────────
// One gain per speaker matched the whole scene on average, but ElevenLabs reads some lines much more
// softly: in the 60 s five-language test, single lines came out 3–8 dB below the same English line and
// were lost under the music. Each line is now matched to its English line, measured only where speech
// is present, within ±maxDeviationDb of the speaker's gain.

export const LINE_LEVEL = {
  /** Largest per-line correction on top of the speaker's gain. */
  maxDeviationDb: 6,
  /** Less speech than this inside a line → keep the speaker's gain for that line. */
  minActiveMs: 300,
} as const;

/**
 * Extra dB for every dubbed line (DUBBING_VOICE_LIFT_DB, default 2, 0–6). A dubbed voice without
 * lip sync needs a little more presence than the original to be followed over the same music.
 */
export function dubVoiceLiftDb(env: Record<string, string | undefined> = process.env): number {
  const raw = Number(env.DUBBING_VOICE_LIFT_DB);
  if (env.DUBBING_VOICE_LIFT_DB === undefined || env.DUBBING_VOICE_LIFT_DB === "" || !Number.isFinite(raw)) return 2;
  return Math.max(0, Math.min(6, raw));
}

/** RMS (dB) over the part of `span` where `active` says speech is present; null when too little. */
export function activeRmsDb(
  pcm: Float32Array,
  sampleRate: number,
  span: TimeSpanMs,
  active: TimeSpanMs[],
  minActiveMs: number = LINE_LEVEL.minActiveMs
): number | null {
  let sum = 0;
  let n = 0;
  let ms = 0;
  for (const a of active) {
    const startMs = Math.max(a.startMs, span.startMs);
    const endMs = Math.min(a.endMs, span.endMs);
    if (endMs <= startMs) continue;
    ms += endMs - startMs;
    const from = Math.max(0, Math.floor((startMs / 1000) * sampleRate));
    const to = Math.min(pcm.length, Math.ceil((endMs / 1000) * sampleRate));
    for (let i = from; i < to; i++) {
      sum += pcm[i] * pcm[i];
      n++;
    }
  }
  if (ms < minActiveMs || n === 0) return null;
  return 10 * Math.log10(sum / n + 1e-12);
}

/**
 * Gain (dB) for each line, in sortedLines order: the speaker's gain, corrected so the dubbed line
 * reaches the level of the same English line (within ±maxDeviationDb), plus the lift; overall within
 * ±maxVoiceGainDb (+ lift). A line that can't be measured keeps the speaker's gain + lift.
 */
export function planLineGainsDb(params: {
  lines: SpeakerSpanMs[];
  totalMs: number;
  speakerGainDb: Record<string, number>;
  originalLineDb: (line: SpeakerSpanMs) => number | null;
  dubLineDb: (extent: TimeSpanMs) => number | null;
  liftDb?: number;
  maxDeviationDb?: number;
  maxDb?: number;
}): number[] {
  const lift = params.liftDb ?? 0;
  const dev = params.maxDeviationDb ?? LINE_LEVEL.maxDeviationDb;
  const maxDb = params.maxDb ?? FAITHFUL_MIX.maxVoiceGainDb;
  const sorted = sortedLines(params.lines);
  const extents = buildGainSpans(sorted, {}, params.totalMs);
  return sorted.map((line, i) => {
    const speakerDb = params.speakerGainDb[line.speaker] ?? 0;
    const original = params.originalLineDb(line);
    const dub = params.dubLineDb(extents[i]);
    let db = speakerDb;
    if (typeof original === "number" && Number.isFinite(original) && typeof dub === "number" && Number.isFinite(dub) && dub > -90) {
      const wanted = original - dub;
      db = Math.max(speakerDb - dev, Math.min(speakerDb + dev, wanted));
    }
    db = Math.max(-maxDb, Math.min(maxDb, db)) + lift;
    return Number(db.toFixed(2));
  });
}

/**
 * Share of the audible dub (ms) that lies inside the regions. A low value means the line timings do
 * not match the dubbed track (wrong units, stale transcript): masking would cut the dub and let the
 * original language through, so the faithful mix must not run.
 */
export function dubCoverage(active: TimeSpanMs[], regions: TimeSpanMs[]): number {
  let total = 0;
  let inside = 0;
  for (const a of active) {
    total += Math.max(0, a.endMs - a.startMs);
    for (const r of regions) {
      inside += Math.max(0, Math.min(a.endMs, r.endMs) - Math.max(a.startMs, r.startMs));
    }
  }
  return total > 0 ? inside / total : 1;
}

const sec = (ms: number) => (ms / 1000).toFixed(3);

// ─── Gain curves ─────────────────────────────────────────────────────────────────────────────
// The mix is driven by gain curves (mono float32 at ENVELOPE_RATE) that FFmpeg resamples and
// multiplies into each input (amultiply). Cost grows with the media length only, so a two-hour film
// with thousands of lines mixes as easily as a short clip.

/** Gain-curve sample rate (Hz). 1 ms resolution; FFmpeg resamples it to the audio rate. */
export const ENVELOPE_RATE = 1000;
/** Gain changes between lines are smoothed over this long, so they never click. */
export const GAIN_RAMP_MS = 20;
/** Tone-matching branches (one per speaker with a clean reference); the rest share a flat branch. */
export const MAX_EQ_BRANCHES = 6;
/** Silence kept after the last sample of the curves, so they always outlast the audio. */
const ENVELOPE_TAIL_MS = 5000;

export interface DubBranch {
  /** Speakers voiced through this branch. */
  speakers: string[];
  /** FFmpeg filter for this branch's tone match, or null for none. */
  eqFilter: string | null;
  /** Index of input in FFmpeg arguments for synthetic IR (for afir), or undefined for none. */
  irInputIndex?: number;
  /** Scene ID associated with this branch, if scene-specific. */
  sceneId?: number;
}

export interface MixEnvelopes {
  /** Gain for the original audio: 1 outside the dialogue, 0 inside, linear fades. */
  orig: Float32Array;
  /** Gain for the background stem: the complement of `orig`. */
  bed: Float32Array;
  /** Gain for the dubbed track, one curve per branch (speaker gain × dialogue mask). */
  dub: Float32Array[];
}

/** Moving average over `width` samples (odd), used to turn gain steps into short ramps. */
function boxSmooth(x: Float32Array, width: number): Float32Array {
  const w = Math.max(1, width | 1);
  if (w === 1 || x.length <= 1) return x;
  const half = (w - 1) / 2;
  const len = x.length;
  const out = new Float32Array(len);
  const invW = 1 / w;
  let acc = 0;

  for (let i = 0; i < Math.min(half, len); i++) acc += x[i];

  const b1 = Math.min(half + 1, len);
  for (let i = 0; i < b1; i++) {
    const add = i + half;
    const drop = i - half - 1;
    if (add < len) acc += x[add];
    if (drop >= 0) acc -= x[drop];
    const lo = Math.max(0, i - half);
    const hi = Math.min(len - 1, i + half);
    out[i] = acc / (hi - lo + 1);
  }

  const b2 = Math.max(b1, len - half - 1);
  for (let i = b1; i < b2; i++) {
    acc += x[i + half] - x[i - half - 1];
    out[i] = acc * invW;
  }

  for (let i = b2; i < len; i++) {
    const add = i + half;
    const drop = i - half - 1;
    if (add < len) acc += x[add];
    if (drop >= 0) acc -= x[drop];
    const lo = Math.max(0, i - half);
    const hi = Math.min(len - 1, i + half);
    out[i] = acc / (hi - lo + 1);
  }

  return out;
}

/**
 * Gain curves for the faithful mix. `branches` decides which speakers share a dubbed-voice branch;
 * a speaker missing from every branch is voiced through the last one.
 */
export function buildEnvelopes(params: {
  regions: TimeSpanMs[];
  gainSpans: GainSpan[];
  totalMs: number;
  branches: DubBranch[];
  rate?: number;
  fadeMs?: number;
  rampMs?: number;
  tightStemSpans?: TimeSpanMs[];
  stemFadesMs?: { startFadeMs?: number; endFadeMs?: number }[];
  equalPowerTightFade?: boolean;
  nonVerbalKeepSpans?: TimeSpanMs[];
  voiceRideCurves?: { spanIndex: number; curve: Float32Array }[];
}): MixEnvelopes {
  const rate = params.rate ?? ENVELOPE_RATE;
  const fade = Math.max(1, Math.round(((params.fadeMs ?? FAITHFUL_MIX.fadeMs) * rate) / 1000));
  const n = Math.ceil(((params.totalMs + ENVELOPE_TAIL_MS) * rate) / 1000) + 1;
  const at = (ms: number) => Math.round((ms * rate) / 1000);

  const mask = new Float32Array(n);
  const invFade = 1 / fade;
  for (const r of params.regions) {
    const a = at(r.startMs);
    const b = at(r.endMs);

    const kInStart = Math.max(0, a - fade);
    const kInEnd = Math.min(n, a);
    for (let k = kInStart; k < kInEnd; k++) {
      const val = (k - (a - fade)) * invFade;
      if (val > mask[k]) mask[k] = val;
    }

    const kPlatStart = Math.max(0, a);
    const kPlatEnd = Math.min(n, b);
    for (let k = kPlatStart; k < kPlatEnd; k++) {
      mask[k] = 1.0;
    }

    const kOutStart = Math.max(0, b);
    const kOutEnd = Math.min(n, b + fade);
    for (let k = kOutStart; k < kOutEnd; k++) {
      const val = (b + fade - k) * invFade;
      if (val > mask[k]) mask[k] = val;
    }
  }

  const branchOf = new Map<string, number>();
  params.branches.forEach((b, i) => {
    b.speakers.forEach((spk) => {
      branchOf.set(spk, i);
      if (b.sceneId !== undefined) {
        branchOf.set(`${spk}_scene_${b.sceneId}`, i);
      }
    });
  });
  const fallbackBranch = Math.max(0, params.branches.length - 1);
  const ramp = Math.max(1, Math.round(((params.rampMs ?? GAIN_RAMP_MS) * rate) / 1000));
  const raw = params.branches.map(() => new Float32Array(n));

  const hasVoiceRide = Boolean(params.voiceRideCurves && params.voiceRideCurves.length > 0);
  const rideMap = hasVoiceRide ? new Map<number, Float32Array>() : null;
  if (hasVoiceRide && params.voiceRideCurves) {
    for (const vrc of params.voiceRideCurves) rideMap!.set(vrc.spanIndex, vrc.curve);
  }

  for (let sIdx = 0; sIdx < params.gainSpans.length; sIdx++) {
    const s = params.gainSpans[sIdx];
    let bi: number;
    if (s.branchIndex !== undefined && s.branchIndex >= 0 && s.branchIndex < params.branches.length) {
      bi = s.branchIndex;
    } else if (s.sceneId !== undefined && s.speaker !== undefined && branchOf.has(`${s.speaker}_scene_${s.sceneId}`)) {
      bi = branchOf.get(`${s.speaker}_scene_${s.sceneId}`)!;
    } else if (s.speaker !== undefined && branchOf.has(s.speaker)) {
      bi = branchOf.get(s.speaker)!;
    } else {
      bi = fallbackBranch;
    }
    if (!raw[bi]) continue;

    const rideCurve = rideMap?.get(sIdx);
    const a = Math.max(0, at(s.startMs));
    const b = Math.min(n, at(s.endMs));
    const gain = s.gain;
    if (rideCurve) {
      for (let k = a; k < b; k++) {
        raw[bi][k] = gain * (rideCurve[k - a] ?? 1.0);
      }
    } else {
      for (let k = a; k < b; k++) {
        raw[bi][k] = gain;
      }
    }
  }

  const orig = new Float32Array(n);
  const bed = new Float32Array(n);

  if (params.tightStemSpans && params.tightStemSpans.length > 0) {
    // Tight stem: background stem is active ONLY where original voice is active within dialogue regions
    const useEqPower = Boolean(params.equalPowerTightFade);
    for (let idx = 0; idx < params.tightStemSpans.length; idx++) {
      const sp = params.tightStemSpans[idx];
      const defaultFade = useEqPower ? Math.min(30, params.fadeMs ?? 25) : (params.fadeMs ?? FAITHFUL_MIX.fadeMs);
      const sFade = Math.max(1, Math.round(((params.stemFadesMs?.[idx]?.startFadeMs ?? defaultFade) * rate) / 1000));
      const eFade = Math.max(1, Math.round(((params.stemFadesMs?.[idx]?.endFadeMs ?? defaultFade) * rate) / 1000));
      const a = at(sp.startMs);
      const b = at(sp.endMs);
      for (let k = Math.max(0, a - sFade); k < Math.min(n, b + eFade); k++) {
        const up = Math.min(1, Math.max(0, (k - (a - sFade)) / sFade));
        const down = Math.min(1, Math.max(0, (b + eFade - k) / eFade));
        const lin = Math.min(up, down);
        const val = useEqPower ? Math.sin((lin * Math.PI) / 2) : lin;
        bed[k] = Math.max(bed[k], val);
      }
    }
    for (let k = 0; k < n; k++) {
      const m = useEqPower ? Math.sin((mask[k] * Math.PI) / 2) : mask[k];
      bed[k] = Math.min(bed[k], m);
      orig[k] = useEqPower ? Math.sqrt(Math.max(0, 1 - bed[k] * bed[k])) : 1 - bed[k];
    }
  } else {
    for (let k = 0; k < n; k++) {
      orig[k] = 1 - mask[k];
      bed[k] = mask[k];
    }
  }

  if (params.nonVerbalKeepSpans && params.nonVerbalKeepSpans.length > 0) {
    // Carve out non-verbal original vocal spans (gasps, grunts, laughs) with a <= 25 ms linear crossfade
    // (original and bed are correlated, so gains sum to 1; equal-power would lift the music mid-fade).
    const nvFade = Math.max(1, Math.round((25 * rate) / 1000));
    const keepMask = new Float32Array(n);
    for (const nv of params.nonVerbalKeepSpans) {
      const a = at(nv.startMs);
      const b = at(nv.endMs);
      for (let k = Math.max(0, a - nvFade); k < Math.min(n, b + nvFade); k++) {
        const up = Math.min(1, Math.max(0, (k - (a - nvFade)) / nvFade));
        const down = Math.min(1, Math.max(0, (b + nvFade - k) / nvFade));
        keepMask[k] = Math.max(keepMask[k], Math.min(up, down));
      }
    }
    for (let k = 0; k < n; k++) {
      if (keepMask[k] > 0) {
        bed[k] = Math.min(bed[k], 1 - keepMask[k]);
        orig[k] = 1 - bed[k];
      }
    }
  }

  const dub = raw.map((g) => {
    const smooth = boxSmooth(g, ramp);
    for (let k = 0; k < n; k++) smooth[k] *= mask[k];
    return smooth;
  });
  return { orig, bed, dub };
}

/**
 * filter_complex for the faithful mix. Inputs, in order: [0] original audio, [1] dubbed dialogue,
 * [2] background stem when `hasBed`, then synthetic IR inputs if any, then the gain curves:
 * original, background (when hasBed), one per dub branch. Output label [out].
 */
export function buildFaithfulMixGraph(params: {
  hasBed: boolean;
  branches: DubBranch[];
  sampleRate?: number;
  firstEnvIndex?: number;
  /** DUBBING_BED_MATCH: correction applied to the bed before its gain curve. */
  bedFilter?: string | null;
}): string {
  const sr = params.sampleRate ?? 44100;
  const fmt = `aresample=${sr},aformat=sample_fmts=fltp:sample_rates=${sr}:channel_layouts=stereo`;
  const env = (idx: number, label: string) =>
    `[${idx}:a]aresample=${sr},aformat=sample_fmts=fltp:sample_rates=${sr}:channel_layouts=mono,pan=stereo|c0=c0|c1=c0[${label}];`;
  const lines: string[] = [];
  let next = params.firstEnvIndex ?? (params.hasBed ? 3 : 2);
  lines.push(env(next++, "e_orig"));
  lines.push(`[0:a]${fmt}[s_orig];`, `[s_orig][e_orig]amultiply[orig];`);
  const mixInputs = ["[orig]"];
  if (params.hasBed) {
    lines.push(env(next++, "e_bed"));
    lines.push(`[2:a]${fmt}${params.bedFilter ? `,${params.bedFilter}` : ""}[s_bed];`, `[s_bed][e_bed]amultiply[bed];`);
    mixInputs.push("[bed]");
  }
  const count = Math.max(1, params.branches.length);
  const splits = Array.from({ length: count }, (_, i) => `[s_dub${i}]`).join("");
  lines.push(`[1:a]${fmt}${count > 1 ? `,asplit=${count}` : ""}${splits};`);
  for (let i = 0; i < count; i++) {
    lines.push(env(next++, `e_dub${i}`));
    const branch = params.branches[i];
    const eq = branch?.eqFilter;
    let curr = `[s_dub${i}]`;
    if (eq) {
      lines.push(`${curr}${eq}[q_dub${i}];`);
      curr = `[q_dub${i}]`;
    }
    if (branch?.irInputIndex !== undefined) {
      lines.push(`${curr}[${branch.irInputIndex}:a]afir=gtype=none[r_dub${i}];`);
      curr = `[r_dub${i}]`;
    }
    lines.push(`${curr}[e_dub${i}]amultiply[dub${i}];`);
    mixInputs.push(`[dub${i}]`);
  }
  lines.push(`${mixInputs.join("")}amix=inputs=${mixInputs.length}:normalize=0:duration=first[out]`);
  return lines.join("\n");
}

// ─── Tone match ──────────────────────────────────────────────────────────────────────────────
// The TTS voice is a dry studio recording; the original voice carries its microphone and room.
// Each dubbed speaker gets an EQ that moves its spectrum toward that speaker's original voice.

/** Band edges (Hz) for tone matching. */
export const EQ_BAND_EDGES = [80, 160, 315, 630, 1250, 2500, 5000, 8000, 12000, 16000];
/** Largest correction per band. */
export const MAX_EQ_DB = 6;
/** A speaker needs this much clean reference speech before an EQ is fitted. */
export const MIN_EQ_REFERENCE_SEC = 3;

/** In-place radix-2 FFT (re, im length must be a power of two). */
export function fft(re: Float64Array, im: Float64Array): void {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    const wr = Math.cos(ang);
    const wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1;
      let ci = 0;
      for (let j = 0; j < len / 2; j++) {
        const ar = re[i + j + len / 2] * cr - im[i + j + len / 2] * ci;
        const ai = re[i + j + len / 2] * ci + im[i + j + len / 2] * cr;
        re[i + j + len / 2] = re[i + j] - ar;
        im[i + j + len / 2] = im[i + j] - ai;
        re[i + j] += ar;
        im[i + j] += ai;
        const t = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = t;
      }
    }
  }
}

/**
 * Average power per band (dB) of mono PCM, Welch method (4096-point Hann frames, 50% overlap).
 * Silent frames are skipped so pauses do not dilute the voice's spectrum.
 */
export function bandProfileDb(pcm: Float32Array, sampleRate: number, edges: number[] = EQ_BAND_EDGES): number[] | null {
  const size = 4096;
  if (pcm.length < size) return null;
  const win = new Float64Array(size);
  for (let i = 0; i < size; i++) win[i] = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / size);
  const bands = new Float64Array(edges.length - 1);
  let frames = 0;
  const re = new Float64Array(size);
  const im = new Float64Array(size);
  for (let start = 0; start + size <= pcm.length; start += size / 2) {
    let energy = 0;
    for (let i = 0; i < size; i++) energy += pcm[start + i] * pcm[start + i];
    if (10 * Math.log10(energy / size + 1e-12) < -50) continue;
    for (let i = 0; i < size; i++) {
      re[i] = pcm[start + i] * win[i];
      im[i] = 0;
    }
    fft(re, im);
    for (let k = 1; k < size / 2; k++) {
      const f = (k * sampleRate) / size;
      for (let b = 0; b < bands.length; b++) {
        if (f >= edges[b] && f < edges[b + 1]) {
          bands[b] += re[k] * re[k] + im[k] * im[k];
          break;
        }
      }
    }
    frames++;
  }
  if (frames === 0) return null;
  return Array.from(bands, (v) => 10 * Math.log10(v / frames + 1e-20));
}

/**
 * Per-band EQ gains (dB) that move `dub` toward `reference`, clamped to ±maxDb and centred on the
 * median (the level is matched separately). Bands the reference does not reach (e.g. above the
 * Nyquist of a low-rate original) are left flat.
 */
export function eqCorrectionDb(reference: number[] | null, dub: number[] | null, maxDb: number = MAX_EQ_DB): number[] | null {
  if (!reference || !dub || reference.length !== dub.length) return null;
  const raw = reference.map((r, i) => (Number.isFinite(r) && Number.isFinite(dub[i]) && r > -150 && dub[i] > -150 ? r - dub[i] : NaN));
  const valid = raw.filter((v) => Number.isFinite(v)).sort((a, b) => a - b);
  if (valid.length < 3) return null;
  const median = valid[Math.floor(valid.length / 2)];
  return raw.map((v) => (Number.isFinite(v) ? Number(Math.max(-maxDb, Math.min(maxDb, v - median)).toFixed(1)) : 0));
}

/** Delay of the tone-match FIR filter (s). It is trimmed off again right after the filter. */
export const EQ_FILTER_DELAY_SEC = 0.01;

/**
 * FFmpeg filter chain for per-band gains (band centres, log-spaced), or null when flat. firequalizer
 * delays its output by EQ_FILTER_DELAY_SEC; the following atrim removes exactly that many samples
 * so the voice stays on its original timing (zero_phase only shifts timestamps, which amix ignores).
 */
export function eqFilterFor(gainsDb: number[] | null, edges: number[] = EQ_BAND_EDGES, sampleRate = 44100): string | null {
  if (!gainsDb || gainsDb.every((g) => Math.abs(g) < 0.5)) return null;
  const entries = gainsDb.map((g, i) => `entry(${Math.round(Math.sqrt(edges[i] * edges[i + 1]))},${g})`);
  const delaySamples = Math.round(EQ_FILTER_DELAY_SEC * sampleRate);
  return `firequalizer=gain_entry='${entries.join(";")}':delay=${EQ_FILTER_DELAY_SEC},atrim=start_sample=${delaySamples},asetpts=N/SR/TB`;
}

/**
 * Mean level (dB) of mono PCM over the given spans, like FFmpeg volumedetect's mean_volume.
 * null when the spans hold no samples or only silence.
 */
export function rmsDbOver(pcm: Float32Array, sampleRate: number, spans: TimeSpanMs[]): number | null {
  let sum = 0;
  let count = 0;
  for (const s of spans) {
    const a = Math.max(0, Math.floor((s.startMs * sampleRate) / 1000));
    const b = Math.min(pcm.length, Math.ceil((s.endMs * sampleRate) / 1000));
    for (let i = a; i < b; i++) sum += pcm[i] * pcm[i];
    count += Math.max(0, b - a);
  }
  if (count === 0 || sum <= 0) return null;
  const db = 10 * Math.log10(sum / count);
  return db <= -120 ? null : db;
}

/** Spans from the start, in time order, until `capMs` of material — FFmpeg can stop reading early. */
export function firstSpans<T extends TimeSpanMs>(spans: T[], capMs: number): T[] {
  const out: T[] = [];
  let total = 0;
  for (const s of [...spans].sort((a, b) => a.startMs - b.startMs)) {
    if (total >= capMs) break;
    out.push(s);
    total += s.endMs - s.startMs;
  }
  return out;
}

/** Media longer than this is "long": lower analysis and gain-curve rates keep memory bounded. */
export const LONG_MEDIA_MS = 20 * 60 * 1000;

/** Analysis rate (Hz) for levels and dub activity: speech energy sits well below 1 kHz. */
export function analysisRateFor(totalMs: number): number {
  return totalMs > LONG_MEDIA_MS ? 2000 : 8000;
}

/** Gain-curve rate (Hz): 1 ms steps for clips, 4 ms for long media (fades are 80 ms, ramps 20 ms). */
export function envelopeRateFor(totalMs: number): number {
  return totalMs > LONG_MEDIA_MS ? 250 : ENVELOPE_RATE;
}

/** The `max` longest spans, back in time order — bounds FFmpeg select expressions on long media. */
export function limitSpans<T extends TimeSpanMs>(spans: T[], max: number): T[] {
  if (spans.length <= max) return spans;
  return [...spans].sort((a, b) => b.endMs - b.startMs - (a.endMs - a.startMs)).slice(0, max).sort((a, b) => a.startMs - b.startMs);
}

/** ffmpeg aselect expression (t in seconds) true inside any of the spans. */
export function spansSelectExpr(spans: TimeSpanMs[]): string {
  if (spans.length === 0) return "0";
  return spans.map((s) => `between(t,${sec(s.startMs)},${sec(s.endMs)})`).join("+");
}

export interface FaithfulnessCheck {
  ok: boolean;
  outsideDiffDb: number | null;
  reason?: string;
}

/** Outside the dialogue regions the mix must match the original within maxOutsideDiffDb. */
export function checkFaithfulness(originalOutsideDb: number | null, mixOutsideDb: number | null, maxDiffDb: number = FAITHFUL_MIX.maxOutsideDiffDb): FaithfulnessCheck {
  if (originalOutsideDb === null || mixOutsideDb === null) {
    // Nothing outside the dialogue (or silence): nothing to compare.
    return { ok: true, outsideDiffDb: null };
  }
  const diff = Number((mixOutsideDb - originalOutsideDb).toFixed(2));
  return Math.abs(diff) <= maxDiffDb
    ? { ok: true, outsideDiffDb: diff }
    : { ok: false, outsideDiffDb: diff, reason: `outside-dialogue level differs from the original by ${diff} dB` };
}

// ─── Room estimation & matched reverb (DUBBING_ROOM_MATCH) ───────────────────────────────────

export interface BiquadCoeffs {
  b0: number;
  b1: number;
  b2: number;
  a1: number;
  a2: number;
}

export interface BandRt60Ms {
  lowRt60Ms: number;
  midRt60Ms: number;
  highRt60Ms: number;
}

export interface RegionRoomEstimate {
  regionIndex: number;
  region: TimeSpanMs;
  rt60Ms: number;
  bandRt60Ms: BandRt60Ms;
  drrDb: number;
  cleanOffsetsCount: number;
  tailMs: number;
}

export interface SceneRoomEstimate {
  sceneId: number;
  regionIndices: number[];
  rt60Ms: number | null;
  bandRt60Ms: BandRt60Ms | null;
  drrDb: number | null;
}

export interface SyntheticIrParams {
  rt60Ms: number;
  drrDb: number;
  bandRt60Ms?: BandRt60Ms;
  sampleRate?: number;
}

/** Direct Form I biquad filter. */
export function biquadFilter(samples: Float32Array, coeffs: BiquadCoeffs): Float32Array {
  const { b0, b1, b2, a1, a2 } = coeffs;
  const out = new Float32Array(samples.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < samples.length; i++) {
    const x = samples[i];
    const y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x;
    y2 = y1; y1 = y;
    out[i] = y;
  }
  return out;
}

/** 2nd-order Butterworth lowpass filter coefficients. */
export function biquadLowpass(sampleRate: number, cutoffHz: number): BiquadCoeffs {
  const w0 = (2 * Math.PI * cutoffHz) / sampleRate;
  const alpha = Math.sin(w0) / (2 * Math.SQRT1_2);
  const cosw0 = Math.cos(w0);
  const a0 = 1 + alpha;
  return {
    b0: (1 - cosw0) / (2 * a0),
    b1: (1 - cosw0) / a0,
    b2: (1 - cosw0) / (2 * a0),
    a1: (-2 * cosw0) / a0,
    a2: (1 - alpha) / a0,
  };
}

/** 2nd-order Butterworth highpass filter coefficients. */
export function biquadHighpass(sampleRate: number, cutoffHz: number): BiquadCoeffs {
  const w0 = (2 * Math.PI * cutoffHz) / sampleRate;
  const alpha = Math.sin(w0) / (2 * Math.SQRT1_2);
  const cosw0 = Math.cos(w0);
  const a0 = 1 + alpha;
  return {
    b0: (1 + cosw0) / (2 * a0),
    b1: (-(1 + cosw0)) / a0,
    b2: (1 + cosw0) / (2 * a0),
    a1: (-2 * cosw0) / a0,
    a2: (1 - alpha) / a0,
  };
}

/** Schroeder backward integration to measure RT60 (ms) on an energy decay tail. */
export function schroederRt60(tailPcm: Float32Array, sampleRate: number): number | null {
  if (tailPcm.length < Math.round(sampleRate * 0.20)) return null;
  const N = tailPcm.length;
  const energy = new Float64Array(N);
  let acc = 0;
  for (let i = N - 1; i >= 0; i--) {
    acc += tailPcm[i] * tailPcm[i];
    energy[i] = acc;
  }
  if (energy[0] < 1e-12) return null;
  const e0 = energy[0];

  let idx5 = -1;
  let idx25 = -1;
  const target5 = e0 * Math.pow(10, -5 / 10);
  const target25 = e0 * Math.pow(10, -25 / 10);

  for (let i = 0; i < N; i++) {
    if (idx5 === -1 && energy[i] <= target5) idx5 = i;
    if (idx25 === -1 && energy[i] <= target25) {
      idx25 = i;
      break;
    }
  }

  if (idx5 === -1) return null;
  if (idx25 === -1) {
    const target15 = e0 * Math.pow(10, -15 / 10);
    let idx15 = -1;
    for (let i = idx5; i < N; i++) {
      if (energy[i] <= target15) {
        idx15 = i;
        break;
      }
    }
    if (idx15 === -1 || idx15 <= idx5) return null;
    const dt = (idx15 - idx5) / sampleRate;
    const slope = -10 / dt;
    const rt60 = -60 / slope;
    return rt60 >= 0.05 && rt60 <= 3.0 ? Math.round(rt60 * 1000) : null;
  }

  const dt = (idx25 - idx5) / sampleRate;
  if (dt <= 0) return null;
  const slope = -20 / dt;
  const rt60 = -60 / slope;
  return rt60 >= 0.05 && rt60 <= 3.0 ? Math.round(rt60 * 1000) : null;
}

/**
 * Estimates reverb decay time (RT60 in ms) and direct-to-reverb ratio (DRR in dB)
 * from the clean speech offsets of the vocals stem within a dialogue region.
 * Returns null when there are < 2 clean offsets or < 300 ms total tail. Never guess.
 */
export function estimateRegionRoom(
  vocalsPcm: Float32Array,
  sampleRate: number,
  region: TimeSpanMs,
  activeSpans: TimeSpanMs[],
  regionIndex: number
): RegionRoomEstimate | null {
  const rStart = region.startMs;
  const rEnd = region.endMs;
  const spansInRegion = activeSpans
    .filter((s) => s.endMs > rStart && s.startMs < rEnd)
    .map((s) => ({
      startMs: Math.max(rStart, s.startMs),
      endMs: Math.min(rEnd, s.endMs),
    }))
    .sort((a, b) => a.startMs - b.startMs);

  if (spansInRegion.length === 0) return null;

  const cleanOffsets: { speechStartMs: number; offsetMs: number; gapMs: number }[] = [];
  let totalTailMs = 0;

  for (let i = 0; i < spansInRegion.length; i++) {
    const s = spansInRegion[i];
    const nextStart = i + 1 < spansInRegion.length ? spansInRegion[i + 1].startMs : rEnd;
    const gapMs = nextStart - s.endMs;
    // At least 250 ms clean silence after speech offset
    if (gapMs >= 250) {
      cleanOffsets.push({
        speechStartMs: s.startMs,
        offsetMs: s.endMs,
        gapMs: Math.min(gapMs, 600),
      });
      totalTailMs += gapMs;
    }
  }

  // Minimum 2 clean offsets and 300 ms total tail required
  if (cleanOffsets.length < 2 || totalTailMs < 300) {
    return null;
  }

  const offsetRt60s: number[] = [];
  const offsetDrrs: number[] = [];
  const offsetLowRt60s: number[] = [];
  const offsetMidRt60s: number[] = [];
  const offsetHighRt60s: number[] = [];

  const lpCoeffs = biquadLowpass(sampleRate, 600);
  const hpCoeffs = biquadHighpass(sampleRate, 2500);

  for (const off of cleanOffsets) {
    const offsetSample = Math.round((off.offsetMs * sampleRate) / 1000);
    const speechStartSample = Math.max(0, Math.round((Math.max(off.speechStartMs, off.offsetMs - 200) * sampleRate) / 1000));

    let directSum = 0;
    const speechCount = offsetSample - speechStartSample;
    if (speechCount <= 0) continue;
    for (let k = speechStartSample; k < offsetSample; k++) {
      directSum += vocalsPcm[k] * vocalsPcm[k];
    }
    const directPower = directSum / speechCount;
    if (directPower < 1e-8) continue;

    // Skip initial 15 ms direct speech transient
    const tailStart = offsetSample + Math.round(0.015 * sampleRate);
    const tailEnd = Math.min(vocalsPcm.length, offsetSample + Math.round((off.gapMs * sampleRate) / 1000));
    const tailLen = tailEnd - tailStart;
    if (tailLen < Math.round(0.20 * sampleRate)) continue;

    const tail = vocalsPcm.subarray(tailStart, tailEnd);
    const rt60 = schroederRt60(tail, sampleRate);
    if (!rt60) continue;

    // 3 bands: < 600 Hz, 600-2500 Hz, > 2500 Hz
    const tailLow = biquadFilter(tail, lpCoeffs);
    const tailHigh = biquadFilter(tail, hpCoeffs);
    const tailMid = new Float32Array(tailLen);
    for (let k = 0; k < tailLen; k++) {
      tailMid[k] = tail[k] - tailLow[k] - tailHigh[k];
    }

    const lowRt60 = schroederRt60(tailLow, sampleRate) ?? rt60;
    const midRt60 = schroederRt60(tailMid, sampleRate) ?? rt60;
    const highRt60 = schroederRt60(tailHigh, sampleRate) ?? rt60;

    let tailEnergy = 0;
    for (let k = 0; k < tailLen; k++) tailEnergy += tail[k] * tail[k];
    const tailEnergySec = tailEnergy / sampleRate;
    const tauSec = (rt60 / 1000) / 13.8155;
    const p0 = tailEnergySec / Math.max(1e-6, tauSec);
    const drrDb = 10 * Math.log10(directPower / Math.max(1e-12, p0));

    // Dry studio acoustic: DRR > 25 dB or RT60 < 70 ms
    if (drrDb > 25 || rt60 < 70) continue;

    offsetRt60s.push(rt60);
    offsetDrrs.push(drrDb);
    offsetLowRt60s.push(lowRt60);
    offsetMidRt60s.push(midRt60);
    offsetHighRt60s.push(highRt60);
  }

  if (offsetRt60s.length < 2) return null;

  const median = (arr: number[]) => {
    const s = [...arr].sort((a, b) => a - b);
    return s[Math.floor(s.length / 2)];
  };

  return {
    regionIndex,
    region,
    rt60Ms: median(offsetRt60s),
    bandRt60Ms: {
      lowRt60Ms: median(offsetLowRt60s),
      midRt60Ms: median(offsetMidRt60s),
      highRt60Ms: median(offsetHighRt60s),
    },
    drrDb: Number(median(offsetDrrs).toFixed(1)),
    cleanOffsetsCount: offsetRt60s.length,
    tailMs: totalTailMs,
  };
}

/** Groups consecutive regions with similar room characteristics into scenes. */
export function groupRegionsIntoScenes(
  regions: TimeSpanMs[],
  estimates: (RegionRoomEstimate | null)[]
): SceneRoomEstimate[] {
  interface WorkingScene {
    sceneId: number;
    regionIndices: number[];
    estimates: RegionRoomEstimate[];
  }
  const scenes: WorkingScene[] = [];
  let currentScene: WorkingScene | null = null;

  for (let i = 0; i < regions.length; i++) {
    const est = estimates[i] || null;

    if (!currentScene) {
      currentScene = {
        sceneId: 0,
        regionIndices: [i],
        estimates: est ? [est] : [],
      };
      scenes.push(currentScene);
      continue;
    }

    const prevEst = currentScene.estimates[currentScene.estimates.length - 1] || null;
    let isSameScene = false;

    if (est === null && prevEst === null) {
      isSameScene = true;
    } else if (est !== null && prevEst !== null) {
      const rtDiff = Math.abs(est.rt60Ms - prevEst.rt60Ms);
      const drrDiff = Math.abs(est.drrDb - prevEst.drrDb);
      if (rtDiff <= 150 && drrDiff <= 4.0) {
        isSameScene = true;
      }
    }

    if (isSameScene) {
      currentScene.regionIndices.push(i);
      if (est) currentScene.estimates.push(est);
    } else {
      currentScene = {
        sceneId: scenes.length,
        regionIndices: [i],
        estimates: est ? [est] : [],
      };
      scenes.push(currentScene);
    }
  }

  const median = (arr: number[]) => {
    const sorted = [...arr].sort((a, b) => a - b);
    return sorted[Math.floor(sorted.length / 2)];
  };

  return scenes.map((s) => {
    if (s.estimates.length === 0) {
      return {
        sceneId: s.sceneId,
        regionIndices: s.regionIndices,
        rt60Ms: null,
        bandRt60Ms: null,
        drrDb: null,
      };
    }
    return {
      sceneId: s.sceneId,
      regionIndices: s.regionIndices,
      rt60Ms: median(s.estimates.map((e) => e.rt60Ms)),
      bandRt60Ms: {
        lowRt60Ms: median(s.estimates.map((e) => e.bandRt60Ms.lowRt60Ms)),
        midRt60Ms: median(s.estimates.map((e) => e.bandRt60Ms.midRt60Ms)),
        highRt60Ms: median(s.estimates.map((e) => e.bandRt60Ms.highRt60Ms)),
      },
      drrDb: Number(median(s.estimates.map((e) => e.drrDb)).toFixed(1)),
    };
  });
}

/**
 * Builds a synthetic room impulse response (direct impulse at h[0] = 1.0, decaying noise tail
 * shaped by 3 band decay times and wet gain from DRR).
 * Zero latency: h[0] = 1.0 directly passes dry audio with zero delay through afir=gtype=none.
 */
export function buildSyntheticRoomIr(params: SyntheticIrParams): Float32Array {
  const sr = params.sampleRate ?? 44100;
  const rt60 = params.rt60Ms;
  const bands = params.bandRt60Ms ?? { lowRt60Ms: rt60, midRt60Ms: rt60, highRt60Ms: rt60 };
  const maxRt60 = Math.max(rt60, bands.lowRt60Ms, bands.midRt60Ms, bands.highRt60Ms);
  const durSec = Math.min(1.5, Math.max(0.3, (maxRt60 / 1000) * 1.2));
  const len = Math.round(durSec * sr);
  const ir = new Float32Array(len);
  ir[0] = 1.0; // direct impulse at t=0 guarantees zero latency

  const tauLow = (bands.lowRt60Ms / 1000) / 6.907755;
  const tauMid = (bands.midRt60Ms / 1000) / 6.907755;
  const tauHigh = (bands.highRt60Ms / 1000) / 6.907755;

  const nLow = new Float32Array(len);
  const nMid = new Float32Array(len);
  const nHigh = new Float32Array(len);

  // Seeded reproducible pseudo-random noise generator
  let seed = 12345;
  const rand = () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  };

  for (let i = 1; i < len; i++) {
    const u1 = rand();
    const u2 = rand();
    const z = Math.sqrt(-2 * Math.log(u1 + 1e-12)) * Math.cos(2 * Math.PI * u2);
    nLow[i] = z;
    nMid[i] = z;
    nHigh[i] = z;
  }

  const lpCoeffs = biquadLowpass(sr, 600);
  const hpCoeffs = biquadHighpass(sr, 2500);
  const fLow = biquadFilter(nLow, lpCoeffs);
  const fHigh = biquadFilter(nHigh, hpCoeffs);
  const fMid = new Float32Array(len);
  for (let i = 1; i < len; i++) {
    fMid[i] = nMid[i] - fLow[i] - fHigh[i];
  }

  let tailSumSq = 0;
  for (let i = 1; i < len; i++) {
    const t = i / sr;
    const vLow = fLow[i] * Math.exp(-t / tauLow);
    const vMid = fMid[i] * Math.exp(-t / tauMid);
    const vHigh = fHigh[i] * Math.exp(-t / tauHigh);
    const val = (vLow + vMid + vHigh) / 3;
    ir[i] = val;
    tailSumSq += val * val;
  }

  const wetGain = Math.pow(10, -params.drrDb / 20);
  const norm = Math.sqrt(tailSumSq / Math.max(1, len - 1) + 1e-12);

  const fadeLen = Math.min(len - 1, Math.round(0.03 * sr));
  for (let i = 1; i < len; i++) {
    let fade = 1.0;
    if (i >= len - fadeLen) {
      fade = 0.5 * (1 + Math.cos((Math.PI * (i - (len - fadeLen))) / fadeLen));
    }
    ir[i] = (ir[i] / norm) * wetGain * fade;
  }

  return ir;
}

// ─── Tight stem (DUBBING_TIGHT_STEM) ──────────────────────────────────────────────────────────

export const TIGHT_STEM_FADE_MS = 25;

/**
 * Builds tight stem spans: background stem is active ONLY where original voice is active
 * (padded by padMs, clamped inside the dialogue regions). When `words` are supplied, only
 * vocal activity overlapping a transcribed word (plus wordGuardMs) triggers the stem, so
 * pauses and non-verbal sounds inside a region stay on the original audio.
 */
export function buildTightStemSpans(
  regions: TimeSpanMs[],
  originalVoiceSpans: TimeSpanMs[],
  padMs = 100,
  options?: { words?: TimeSpanMs[]; mergeGapMs?: number; wordGuardMs?: number }
): TimeSpanMs[] {
  const words = options?.words && options.words.length > 0 ? options.words : null;
  const wordGuardMs = options?.wordGuardMs ?? 50;
  const mergeGapMs = options?.mergeGapMs ?? 150;

  let activeVoice = originalVoiceSpans;
  if (words) {
    // Keep vocal activity spans that overlap at least one transcribed word; if vocal stem
    // activity missed a word, include the word span itself so no source word leaks through.
    const matched: TimeSpanMs[] = [];
    for (const v of originalVoiceSpans) {
      if (words.some((w) => w.endMs + wordGuardMs > v.startMs && w.startMs - wordGuardMs < v.endMs)) {
        matched.push(v);
      }
    }
    for (const w of words) {
      const covered = matched.some((m) => m.endMs >= w.startMs && m.startMs <= w.endMs);
      if (!covered && w.endMs > w.startMs) {
        matched.push({ startMs: w.startMs, endMs: w.endMs });
      }
    }
    activeVoice = matched;
  }

  const spans: TimeSpanMs[] = [];
  for (const reg of regions) {
    const overlapping = activeVoice.filter((s) => s.endMs > reg.startMs && s.startMs < reg.endMs);
    if (overlapping.length === 0) continue;
    for (const ov of overlapping) {
      const startMs = Math.max(reg.startMs, ov.startMs - padMs);
      const endMs = Math.min(reg.endMs, ov.endMs + padMs);
      if (endMs > startMs) {
        spans.push({ startMs, endMs });
      }
    }
  }
  spans.sort((a, b) => a.startMs - b.startMs);
  const merged: TimeSpanMs[] = [];
  for (const s of spans) {
    const last = merged[merged.length - 1];
    if (last && s.startMs - last.endMs < mergeGapMs) {
      last.endMs = Math.max(last.endMs, s.endMs);
    } else {
      merged.push({ ...s });
    }
  }
  return merged;
}

/** Adaptive crossfade length (ms): 80 ms when background bed is quiet, up to 250 ms when loud. */
export function adaptiveFadeMs(
  bedPcm: Float32Array,
  sampleRate: number,
  edgeMs: number,
  defaultFadeMs = 80,
  maxFadeMs = 250
): number {
  const windowMs = 100;
  const startSample = Math.max(0, Math.floor(((edgeMs - windowMs / 2) * sampleRate) / 1000));
  const endSample = Math.min(bedPcm.length, Math.ceil(((edgeMs + windowMs / 2) * sampleRate) / 1000));
  let sumSq = 0;
  const n = endSample - startSample;
  if (n <= 0) return defaultFadeMs;
  for (let i = startSample; i < endSample; i++) sumSq += bedPcm[i] * bedPcm[i];
  const rms = Math.sqrt(sumSq / n);
  const rmsDb = 20 * Math.log10(rms + 1e-12);

  if (rmsDb <= -35) return defaultFadeMs;
  if (rmsDb >= -15) return maxFadeMs;
  const ratio = (rmsDb - -35) / 20;
  return Math.round(defaultFadeMs + (maxFadeMs - defaultFadeMs) * ratio);
}

// ─── Voice ride (DUBBING_VOICE_RIDE) ──────────────────────────────────────────────────────────

/**
 * Computes a voice gain ride envelope (Float32Array at envRate) that follows background music swells,
 * smoothed with attack/release >= 300 ms, bounded strictly to ±3 dB around baseGain.
 */
export function computeVoiceRideEnvelope(
  bedPcm: Float32Array,
  sampleRate: number,
  line: TimeSpanMs,
  baseGain: number,
  envRate = 1000
): Float32Array {
  const lineStartSample = Math.max(0, Math.floor((line.startMs * sampleRate) / 1000));
  const lineEndSample = Math.min(bedPcm.length, Math.ceil((line.endMs * sampleRate) / 1000));
  const lineSamples = lineEndSample - lineStartSample;
  const durMs = line.endMs - line.startMs;
  const envLen = Math.max(1, Math.ceil((durMs * envRate) / 1000));
  const env = new Float32Array(envLen);

  if (lineSamples <= 0) {
    env.fill(baseGain);
    return env;
  }

  const frameMs = 50;
  const frameSamples = Math.round((frameMs * sampleRate) / 1000);
  const frameCount = Math.max(1, Math.floor(lineSamples / frameSamples));
  const frameDbs = new Float32Array(frameCount);
  let totalEnergy = 0;

  for (let f = 0; f < frameCount; f++) {
    let sumSq = 0;
    const a = lineStartSample + f * frameSamples;
    const b = Math.min(lineEndSample, a + frameSamples);
    const count = b - a;
    for (let i = a; i < b; i++) sumSq += bedPcm[i] * bedPcm[i];
    const rms = Math.sqrt(sumSq / Math.max(1, count));
    frameDbs[f] = 20 * Math.log10(rms + 1e-12);
    totalEnergy += sumSq;
  }

  const meanRms = Math.sqrt(totalEnergy / Math.max(1, lineSamples));
  const meanDb = 20 * Math.log10(meanRms + 1e-12);

  const dtSec = frameMs / 1000;
  const alpha = 1 - Math.exp(-dtSec / 0.300);
  const smoothedDeltaDb = new Float32Array(frameCount);
  let currDelta = 0;
  for (let f = 0; f < frameCount; f++) {
    const rawDelta = Math.max(-3.0, Math.min(3.0, frameDbs[f] - meanDb));
    currDelta = currDelta + alpha * (rawDelta - currDelta);
    smoothedDeltaDb[f] = Math.max(-3.0, Math.min(3.0, currDelta));
  }

  const baseDb = 20 * Math.log10(Math.max(1e-12, baseGain));
  for (let k = 0; k < envLen; k++) {
    const frac = k / envLen;
    const fIdx = Math.min(frameCount - 1, frac * frameCount);
    const i0 = Math.floor(fIdx);
    const i1 = Math.min(frameCount - 1, i0 + 1);
    const t = fIdx - i0;
    const deltaDb = smoothedDeltaDb[i0] * (1 - t) + smoothedDeltaDb[i1] * t;
    const boundedDb = Math.max(baseDb - 3.0, Math.min(baseDb + 3.0, baseDb + deltaDb));
    env[k] = Math.pow(10, boundedDb / 20);
  }

  return env;
}

// ─── Non-verbal vocal sounds (gasps, grunts, laughs, breaths) ────────────────────────────────

export interface NonVerbalSpan extends TimeSpanMs {
  reason: string;
}

/** Subtracts `cuts` from `spans`, returning remaining fragments >= minDurationMs. */
export function subtractSpans(spans: TimeSpanMs[], cuts: TimeSpanMs[], minDurationMs = 1): TimeSpanMs[] {
  let current = spans.filter((s) => s.endMs > s.startMs).map((s) => ({ ...s }));
  for (const cut of cuts) {
    if (cut.endMs <= cut.startMs) continue;
    const next: TimeSpanMs[] = [];
    for (const s of current) {
      if (cut.endMs <= s.startMs || cut.startMs >= s.endMs) {
        next.push(s);
      } else {
        if (cut.startMs > s.startMs) next.push({ startMs: s.startMs, endMs: cut.startMs });
        if (cut.endMs < s.endMs) next.push({ startMs: cut.endMs, endMs: s.endMs });
      }
    }
    current = next;
  }
  return current.filter((s) => s.endMs - s.startMs >= minDurationMs);
}

/**
 * Finds vocal-stem energy spans that have NO transcribed word and lie OUTSIDE any dubbed line's
 * active window, so language-neutral performances (gasps, grunts, laughs, sighs, breaths) can be
 * kept from the original audio without ever letting a source-language word through.
 */
export function detectNonVerbalSpans(params: {
  vocPcm: Float32Array;
  sampleRate: number;
  words: TimeSpanMs[];
  dubActive: TimeSpanMs[];
  totalMs: number;
  minDurationMs?: number;
  wordGuardMs?: number;
  dubGuardMs?: number;
}): NonVerbalSpan[] {
  const { vocPcm, sampleRate, words, dubActive, totalMs } = params;
  if (!vocPcm || vocPcm.length === 0 || totalMs <= 0) return [];
  const minDur = params.minDurationMs ?? 60;
  const wordGuard = params.wordGuardMs ?? 60;
  const dubGuard = params.dubGuardMs ?? 40;

  const vocalActive = detectActiveSpans(vocPcm, sampleRate, {
    frameMs: FAITHFUL_MIX.activityFrameMs,
    minGapMs: 60,
    thresholdDb: -42,
    relativeDb: 28,
  });
  if (vocalActive.length === 0) return [];

  const guardedCuts: TimeSpanMs[] = [
    ...words.filter((w) => w.endMs > w.startMs).map((w) => ({
      startMs: Math.max(0, w.startMs - wordGuard),
      endMs: Math.min(totalMs, w.endMs + wordGuard),
    })),
    ...dubActive.filter((d) => d.endMs > d.startMs).map((d) => ({
      startMs: Math.max(0, d.startMs - dubGuard),
      endMs: Math.min(totalMs, d.endMs + dubGuard),
    })),
  ];

  const kept = subtractSpans(vocalActive, guardedCuts, minDur);
  return kept.map((s) => ({
    startMs: Math.round(s.startMs),
    endMs: Math.round(s.endMs),
    reason: "vocal_energy_no_word_outside_dub",
  }));
}

// ─── Gap fidelity & edge step measurements ───────────────────────────────────────────────────

/** Standard 1/3-octave center frequencies (Hz) up to 10 kHz. */
export const THIRD_OCTAVE_CENTERS = [
  100, 125, 160, 200, 250, 315, 400, 500, 630, 800,
  1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000,
];

export interface GapFidelityReport {
  loudnessDeltaDb: number | null;
  meanAbsBandDeltaDb: number | null;
  maxBandDeltaDb: number | null;
  bandDeltaDb: Record<string, number>;
  transientLossDb: number | null;
  gapSeconds: number;
}

function concatSpansPcm(pcm: Float32Array, sampleRate: number, spans: TimeSpanMs[]): Float32Array {
  const slices: Float32Array[] = [];
  let total = 0;
  for (const s of spans) {
    const a = Math.max(0, Math.floor((s.startMs * sampleRate) / 1000));
    const b = Math.min(pcm.length, Math.ceil((s.endMs * sampleRate) / 1000));
    if (b > a) {
      const sub = pcm.subarray(a, b);
      slices.push(sub);
      total += sub.length;
    }
  }
  const out = new Float32Array(total);
  let off = 0;
  for (const sl of slices) {
    out.set(sl, off);
    off += sl.length;
  }
  return out;
}

function crestFactorDb(pcm: Float32Array, sampleRate: number): number | null {
  const frame = Math.max(1, Math.round(0.01 * sampleRate)); // 10 ms frames
  if (pcm.length < frame * 2) return null;
  const frameRms: number[] = [];
  for (let i = 0; i + frame <= pcm.length; i += frame) {
    let s = 0;
    for (let j = i; j < i + frame; j++) s += pcm[j] * pcm[j];
    frameRms.push(Math.sqrt(s / frame));
  }
  const sorted = [...frameRms].sort((a, b) => a - b);
  const p95 = sorted[Math.floor((sorted.length - 1) * 0.95)];
  const med = sorted[Math.floor(sorted.length / 2)];
  if (med <= 1e-7 || p95 <= 1e-7) return null;
  return 20 * Math.log10(p95 / med);
}

/**
 * Compares stem vs original in non-speech gaps: loudness delta, 1/3-octave band deltas,
 * and transient crest-factor loss (positive = stem softened transients).
 */
export function measureGapFidelity(
  origPcm: Float32Array,
  stemPcm: Float32Array,
  sampleRate: number,
  gapSpans: TimeSpanMs[]
): GapFidelityReport {
  const gapMs = gapSpans.reduce((sum, s) => sum + Math.max(0, s.endMs - s.startMs), 0);
  const gapSeconds = Number((gapMs / 1000).toFixed(3));
  if (gapSpans.length === 0 || gapMs < 100) {
    return {
      loudnessDeltaDb: null,
      meanAbsBandDeltaDb: null,
      maxBandDeltaDb: null,
      bandDeltaDb: {},
      transientLossDb: null,
      gapSeconds,
    };
  }

  const origDb = rmsDbOver(origPcm, sampleRate, gapSpans);
  const stemDb = rmsDbOver(stemPcm, sampleRate, gapSpans);
  const loudnessDeltaDb =
    origDb !== null && stemDb !== null ? Number((stemDb - origDb).toFixed(2)) : null;

  const nyquist = sampleRate * 0.45;
  const centers = THIRD_OCTAVE_CENTERS.filter((c) => c < nyquist);
  const edges = centers.map((c) => c / Math.pow(2, 1 / 6));
  if (centers.length > 0) edges.push(Math.min(nyquist, centers[centers.length - 1] * Math.pow(2, 1 / 6)));

  const origGapPcm = concatSpansPcm(origPcm, sampleRate, gapSpans);
  const stemGapPcm = concatSpansPcm(stemPcm, sampleRate, gapSpans);

  const bandDeltaDb: Record<string, number> = {};
  let meanAbsBandDeltaDb: number | null = null;
  let maxBandDeltaDb: number | null = null;

  if (centers.length >= 2 && origGapPcm.length >= 4096 && stemGapPcm.length >= 4096) {
    const origProf = bandProfileDb(origGapPcm, sampleRate, edges);
    const stemProf = bandProfileDb(stemGapPcm, sampleRate, edges);
    if (origProf && stemProf) {
      const absDeltas: number[] = [];
      for (let i = 0; i < centers.length; i++) {
        if (Number.isFinite(origProf[i]) && Number.isFinite(stemProf[i]) && origProf[i] > -150 && stemProf[i] > -150) {
          const d = Number((stemProf[i] - origProf[i]).toFixed(2));
          bandDeltaDb[`${centers[i]}Hz`] = d;
          absDeltas.push(Math.abs(d));
        }
      }
      if (absDeltas.length > 0) {
        meanAbsBandDeltaDb = Number((absDeltas.reduce((a, b) => a + b, 0) / absDeltas.length).toFixed(2));
        maxBandDeltaDb = Number(Math.max(...absDeltas).toFixed(2));
      }
    }
  }

  const origCrest = crestFactorDb(origGapPcm, sampleRate);
  const stemCrest = crestFactorDb(stemGapPcm, sampleRate);
  const transientLossDb =
    origCrest !== null && stemCrest !== null ? Number((origCrest - stemCrest).toFixed(2)) : null;

  return {
    loudnessDeltaDb,
    meanAbsBandDeltaDb,
    maxBandDeltaDb,
    bandDeltaDb,
    transientLossDb,
    gapSeconds,
  };
}

/**
 * Maximum level step (dB) across region/stem boundaries in `outPcm` relative to `srcPcm`.
 * Compares 60 ms RMS just before the boundary fade ([tMs - 85, tMs - 25]) vs just after
 * ([tMs + 25, tMs + 85]), ignoring edges where dub or original speech is active.
 */
export function measureEdgeStepsDb(
  srcPcm: Float32Array,
  outPcm: Float32Array,
  sampleRate: number,
  boundaryMsList: number[],
  speechActive: TimeSpanMs[] = [],
  totalMs = Infinity
): number | null {
  const offsetMs = 25;
  const winMs = 60;
  const guardMs = offsetMs + winMs;
  let maxStep: number | null = null;
  for (const tMs of boundaryMsList) {
    if (tMs <= guardMs || tMs >= totalMs - guardMs) continue;
    const speechNear = speechActive.some((d) => d.endMs > tMs - guardMs && d.startMs < tMs + guardMs);
    if (speechNear) continue;
    const before = [{ startMs: tMs - guardMs, endMs: tMs - offsetMs }];
    const after = [{ startMs: tMs + offsetMs, endMs: tMs + guardMs }];
    const sBefore = rmsDbOver(srcPcm, sampleRate, before);
    const sAfter = rmsDbOver(srcPcm, sampleRate, after);
    const oBefore = rmsDbOver(outPcm, sampleRate, before);
    const oAfter = rmsDbOver(outPcm, sampleRate, after);
    if (sBefore === null || sAfter === null || oBefore === null || oAfter === null) continue;
    const srcStep = sAfter - sBefore;
    const outStep = oAfter - oBefore;
    const err = Math.abs(outStep - srcStep);
    if (maxStep === null || err > maxStep) maxStep = Number(err.toFixed(2));
  }
  return maxStep;
}

export interface BgmReport {
  outsideDiffDb: number | null;
  stemSeconds: number;
  totalSeconds: number;
  stemShare: number;
  edgeStepsDb: number | null;
  gapFidelity: GapFidelityReport | null;
  nonVerbalKept: {
    count: number;
    seconds: number;
    spans: NonVerbalSpan[];
  };
  bleed: {
    passed: boolean;
    worstR?: number | null;
    vocalSuppressionDb?: number | null;
    bleedMethod?: string | null;
  } | null;
  backgroundLevelDeltaDb: number | null;
  /** DUBBING_BED_MATCH: the correction applied to the bed (null when the flag is off). */
  bedMatch?: BedMatchPlan | null;
  flags: {
    bedMatch?: boolean;
    tightStem: boolean;
    keepNonVerbal: boolean;
    fidelityStemSelect: boolean;
    roomMatch: boolean;
    sceneTone: boolean;
    voiceRide: boolean;
  };
}
