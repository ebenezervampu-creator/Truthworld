/**
 * Emotion transfer: how strongly each source line is performed, measured from the audio itself.
 *
 * Why (2026-11-20, Joseph clip): Pharaoh roars at 216 Hz, the cupbearer cries at 320 Hz and the
 * demon growls at 78 Hz, but all three Telugu lines came out as calm speech at 101–158 Hz. The
 * pipeline had no measure of "louder / higher than this character normally speaks", Gemini's tag
 * list could not say "crying" or "shouting", and a 0.5 stability floor on every non-English line
 * held the voice to a steady read.
 *
 * Here: per line, F0 and voiced loudness are compared with the character's normal voice, and with
 * Gemini's emotion hints decide a delivery tag and intensity. An intense tag (shouting, crying, …)
 * lowers stability for that line only; every other line keeps the stability floor.
 *
 * Pure functions; decoding happens in AudioIdentityService.
 */
import { analyseVoicing, estimatePitch, MIN_VOICED_FRAMES } from "./pitch-estimation";

/** v4 audio tags this module can emit. All are plain-English performance cues v4 accepts. */
export const INTENSE_DELIVERY_TAGS = new Set<string>(["shouting", "screaming", "crying", "distressed", "menacing", "intense"]);

/**
 * Lowest stability an intense line may use (all other non-English lines keep the 0.5 floor).
 * Not lower: on 2026-11-19 stability near 0.2 slurred Telugu phonemes and drifted the voice
 * (see dubbing-guards.ts). The audio tag carries most of the emotion; stability only frees the voice.
 */
export const MIN_INTENSE_STABILITY = 0.3;

/** Typical speaking F0 and the most a "normal" speaking voice is taken to be. */
const NORMAL_F0: Record<"male" | "female", number> = { male: 120, female: 210 };
const NORMAL_F0_CEILING: Record<"male" | "female", number> = { male: 150, female: 255 };
const UNKNOWN_F0_CEILING = 255;

export interface LineAcoustics {
  index: number;
  startMs?: number;
  endMs?: number;
  speaker?: string;
  gender?: "male" | "female";
  /** Median F0 of voiced frames (Hz), null when the line has too little voiced speech. */
  f0Hz?: number | null;
  /** Loudness of the line's voiced part (dBFS). */
  voicedRmsDb?: number | null;
}

export interface LineEmotionHints {
  anger?: number;
  sadness?: number;
  fear?: number;
  /** Tag suggested by Gemini or the lexical hint (e.g. "shouts", "sorrowful", "crying"). */
  tag?: string;
  voiceQuality?: "breathy" | "modal" | "creaky" | "pressed";
}

export interface DeliveryDecision {
  tag?: string;
  /** 0 … 1 */
  intensity: number;
  /** F0 relative to the character's normal voice (semitones). */
  pitchRiseSemitones: number | null;
  /** F0 relative to a typical voice of that gender (semitones) — catches a character who growls throughout. */
  pitchVsNormSemitones: number | null;
  /** Voiced loudness relative to the video's typical line (dB). */
  loudRiseDb: number | null;
  reason: string;
}

const clamp01 = (v: number) => Math.max(0, Math.min(1, v));
const r1 = (v: number) => Math.round(v * 10) / 10;
const median = (xs: number[]) => {
  if (!xs.length) return NaN;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
const st = (a: number, b: number) => 12 * Math.log2(a / b);

/** Stability for an intense line: 0.40 at low intensity, down to 0.30 at full intensity. */
export function intenseStability(intensity: number): number {
  return Number(Math.max(MIN_INTENSE_STABILITY, 0.4 - 0.1 * clamp01(intensity)).toFixed(2));
}

export function isIntenseDeliveryTag(tag?: string | null): boolean {
  return Boolean(tag && INTENSE_DELIVERY_TAGS.has(tag.toLowerCase().trim()));
}

/** F0 and voiced loudness of one line from mono PCM. */
export function measureLineAcoustics(
  samples: Float32Array,
  sampleRate: number,
  startMs: number,
  endMs: number
): { f0Hz: number | null; voicedRmsDb: number | null; voicedShare?: number | null } {
  const s = Math.max(0, Math.floor((startMs / 1000) * sampleRate));
  const e = Math.min(samples.length, Math.ceil((endMs / 1000) * sampleRate));
  if (e - s < sampleRate * 0.25) return { f0Hz: null, voicedRmsDb: null, voicedShare: null };
  const slice = samples.subarray(s, e);
  // Screams and cries reach well above normal speech: search up to 700 Hz. The looser periodicity
  // threshold and silence gate were tuned on a film mix (music under dialogue), where the default
  // voice-matching settings found a pitch on only 1 of 9 lines; these find it on 6 of 9.
  const pitchOpts = { minHz: 60, maxHz: 700, hopMs: 10, threshold: 0.3, relativeSilence: 0.2 };
  const pitch = estimatePitch(slice, sampleRate, pitchOpts);

  // Voiced loudness: mean power of the louder half of 20 ms frames (pauses do not dilute it).
  const frame = Math.round(0.02 * sampleRate);
  const powers: number[] = [];
  for (let i = 0; i + frame <= slice.length; i += frame) {
    let p = 0;
    for (let j = i; j < i + frame; j++) p += slice[j] * slice[j];
    powers.push(p / frame);
  }
  powers.sort((a, b) => b - a);
  const top = powers.slice(0, Math.max(1, Math.ceil(powers.length / 2)));
  const meanPower = top.reduce((a, b) => a + b, 0) / top.length;
  const voicedRmsDb = meanPower > 1e-10 ? r1(10 * Math.log10(meanPower)) : null;
  return {
    f0Hz: pitch ? pitch.medianHz : null,
    voicedRmsDb,
    voicedShare: pitch ? pitch.voicedRatio : measuredVoicedShare(slice, sampleRate, pitchOpts),
  };
}

/**
 * Voiced share of a line whose median pitch could not be estimated. Before 2026-11-24 such a line
 * got voicedShare 0, which the whisper guard read as "measured unvoiced" — in the te test it kept
 * [whispers] on a line the original speaks in full voice (line 10, 00:54), and logged 0% voiced on a
 * 5.3 s line Gemini rated "modal". Now: the real share when enough frames had energy to judge,
 * otherwise null ("not measurable"), which never verifies a whisper.
 */
export function measuredVoicedShare(
  slice: Float32Array,
  sampleRate: number,
  options: Parameters<typeof analyseVoicing>[2]
): number | null {
  const voicing = analyseVoicing(slice, sampleRate, options);
  if (!voicing || voicing.energeticFrames < MIN_VOICED_FRAMES) return null;
  return Math.round((voicing.f0s.length / voicing.energeticFrames) * 100) / 100;
}

/** Each character's normal speaking F0 (Hz), never above a normal-voice ceiling. */
export function speakerF0Baselines(lines: LineAcoustics[]): Map<string, number> {
  const bySpeaker = new Map<string, { f0s: number[]; gender?: "male" | "female" }>();
  for (const l of lines) {
    const key = l.speaker || "_";
    const e = bySpeaker.get(key) || { f0s: [], gender: l.gender };
    if (typeof l.f0Hz === "number" && l.f0Hz > 0) e.f0s.push(l.f0Hz);
    e.gender = e.gender || l.gender;
    bySpeaker.set(key, e);
  }
  const allF0 = lines.map((l) => l.f0Hz).filter((v): v is number => typeof v === "number" && v > 0);
  const out = new Map<string, number>();
  for (const [speaker, { f0s, gender }] of bySpeaker) {
    const ceiling = gender ? NORMAL_F0_CEILING[gender] : UNKNOWN_F0_CEILING;
    if (f0s.length >= 3) {
      out.set(speaker, Math.min(median(f0s), ceiling));
    } else if (gender) {
      out.set(speaker, NORMAL_F0[gender]);
    } else if (allF0.length >= 3) {
      out.set(speaker, Math.min(median(allF0), ceiling));
    }
  }
  return out;
}

function normTag(tag?: string): string {
  return (tag || "").toLowerCase().trim();
}

/** Decide delivery for one line. */
export function decideDelivery(
  line: LineAcoustics,
  baselineF0: number | undefined,
  baselineLoudDb: number | undefined,
  hints: LineEmotionHints = {}
): DeliveryDecision {
  const f0 = typeof line.f0Hz === "number" && line.f0Hz > 0 ? line.f0Hz : null;
  const rise = f0 && baselineF0 ? r1(st(f0, baselineF0)) : null;
  const vsNorm = f0 && line.gender ? r1(st(f0, NORMAL_F0[line.gender])) : null;
  const loud = typeof line.voicedRmsDb === "number" && typeof baselineLoudDb === "number" ? r1(line.voicedRmsDb - baselineLoudDb) : null;
  const anger = hints.anger ?? 0;
  const sadness = hints.sadness ?? 0;
  const tag = normTag(hints.tag);
  const p = rise === null ? 0 : clamp01((rise - 3) / 9); // +3 st → 0, +12 st → 1
  const l = loud === null ? 0 : clamp01((loud - 2) / 8); // +2 dB → 0, +10 dB → 1
  const base = { pitchRiseSemitones: rise, pitchVsNormSemitones: vsNorm, loudRiseDb: loud };

  const hintCry = ["crying", "sobbing", "sorrowful", "weeping"].includes(tag);
  const hintShout = ["shouts", "shouting", "yelling", "screaming", "angry", "said angrily", "furious"].includes(tag);

  // 1. Crying: needs a sadness signal from the model (pitch alone cannot tell crying from shouting).
  if (tag === "crying" || tag === "sobbing" || (sadness >= 0.5 && ((rise ?? 0) >= 3 || hintCry || hints.voiceQuality === "breathy" || hints.voiceQuality === "creaky"))) {
    return { ...base, tag: "crying", intensity: r1(Math.max(0.5, sadness, p)), reason: `sadness ${sadness}, pitch ${rise ?? "?"} st` };
  }
  // 2. Screaming: far higher and much louder than normal.
  if (tag === "screaming" || ((rise ?? 0) >= 10 && (loud ?? 0) >= 4)) {
    return { ...base, tag: "screaming", intensity: r1(Math.max(0.8, p, l)), reason: `pitch +${rise} st, loud +${loud} dB` };
  }
  // 3. Shouting: the model hears anger/shouting, or the line is both much higher and louder.
  const acousticShout = (rise ?? 0) >= 5 && (loud ?? 0) >= 2;
  const modelShout = (hintShout || anger >= 0.5) && ((rise ?? 0) >= 3 || (loud ?? 0) >= 2 || rise === null || anger >= 0.7);
  if (acousticShout || modelShout) {
    return { ...base, tag: "shouting", intensity: r1(Math.max(0.5, 0.6 * p + 0.4 * l, anger * 0.8)), reason: `pitch ${rise ?? "?"} st, loud ${loud ?? "?"} dB, anger ${anger}` };
  }
  // 4. Distress: fear or sadness with a raised voice (pleading, panic, holding back tears).
  if (((hints.fear ?? 0) >= 0.5 || sadness >= 0.4) && (rise ?? 0) >= 5) {
    return { ...base, tag: "distressed", intensity: r1(Math.max(0.5, p)), reason: `fear ${hints.fear ?? 0}, sadness ${sadness}, pitch +${rise} st` };
  }
  // 5. Low, loud growl (a character who is low throughout: compare with a typical voice, not their own).
  if ((vsNorm ?? 0) <= -4 && ((loud ?? 0) >= 2 || anger >= 0.5)) {
    return { ...base, tag: "menacing", intensity: r1(Math.max(0.5, l, anger)), reason: `pitch ${vsNorm} st below a typical voice, loud ${loud ?? "?"} dB` };
  }
  // 6. Clearly heightened, emotion unknown (no model hint): a neutral "[intense]" cue; v4 takes the
  //    emotion from the words. Either far above the character's normal pitch, or loud with no
  //    measurable pitch (growls and screams are too rough to have one).
  if ((rise ?? 0) >= 7 || (f0 === null && (loud ?? 0) >= 3)) {
    return { ...base, tag: "intense", intensity: r1(Math.max(0.5, p, l)), reason: rise !== null ? `pitch +${rise} st` : `loud +${loud} dB, no stable pitch` };
  }
  return { ...base, intensity: 0, reason: "normal delivery" };
}

/** Delivery for every line. Loudness is compared with the video's median line. */
export function planDelivery(
  lines: LineAcoustics[],
  hints: Map<number, LineEmotionHints> = new Map()
): Map<number, DeliveryDecision> {
  const f0Base = speakerF0Baselines(lines);
  const louds = lines.map((l) => l.voicedRmsDb).filter((v): v is number => typeof v === "number");
  const loudBase = louds.length >= 3 ? median(louds) : undefined;
  const out = new Map<number, DeliveryDecision>();
  for (const l of lines) {
    out.set(l.index, decideDelivery(l, f0Base.get(l.speaker || "_"), loudBase, hints.get(l.index)));
  }
  smoothTurns(lines, out);
  return out;
}

/** Lines of one speaker with gaps under this are one turn. */
const TURN_GAP_MS = 700;

/**
 * A character does not switch from shouting to calm mid-rant: when at least half the lines of a
 * continuous turn are intense, the turn's most common tag is applied to the calm lines too.
 */
function smoothTurns(lines: LineAcoustics[], plan: Map<number, DeliveryDecision>): void {
  const timed = lines.filter((l) => typeof l.startMs === "number" && typeof l.endMs === "number").sort((a, b) => a.startMs! - b.startMs!);
  let turn: LineAcoustics[] = [];
  const flush = () => {
    if (turn.length >= 2) {
      const tags = turn.map((l) => plan.get(l.index)?.tag).filter((t): t is string => Boolean(t));
      if (tags.length * 2 >= turn.length) {
        const counts = new Map<string, number>();
        for (const t of tags) counts.set(t, (counts.get(t) || 0) + 1);
        const dominant = [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0];
        for (const l of turn) {
          const d = plan.get(l.index)!;
          if (!d.tag) plan.set(l.index, { ...d, tag: dominant, intensity: 0.5, reason: `continues the ${dominant} turn` });
        }
      }
    }
    turn = [];
  };
  for (const l of timed) {
    const prev = turn[turn.length - 1];
    if (prev && (prev.speaker !== l.speaker || l.startMs! - prev.endMs! > TURN_GAP_MS)) flush();
    turn.push(l);
  }
  flush();
}
