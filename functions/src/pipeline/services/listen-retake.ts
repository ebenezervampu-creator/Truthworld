/**
 * Listen-and-retake (2026-11-24, flag DUBBING_LISTEN_RETAKE, off by default).
 *
 * After every line is voiced, Gemini listens to the original line and the dubbed line together and
 * reports concrete faults in the dubbed PERFORMANCE (not the wording). Lines with a fault a second
 * take can fix are re-voiced with adjusted settings; the new take is listened to again and kept only
 * when it is judged better. Spend is bounded by the language's RetryBudget (dubbing-economics.ts)
 * and by LISTEN.maxRetakeShare / maxRetakeLines.
 *
 * Why: rules catch only what they anticipate. In the te test the reviewer flagged breathy onsets,
 * a synthetic whisper on a teasing line and a flat narrator against a loud score (00:06, 00:20,
 * 00:54) — each is audible on a listen, none is visible in the text or the tags.
 *
 * Pure parts (parse, select, settings, compare) are exported for tests; Gemini is injected.
 */

export const LISTEN = {
  /** At most this share of a language's lines is re-voiced. */
  maxRetakeShare: 0.25,
  /** …and never more than this many lines. */
  maxRetakeLines: 20,
  /** A line scored at or below this (1–5) is a retake candidate even without a named fault. */
  retakeScoreAtOrBelow: 2,
  /** Lines listened to in parallel. */
  concurrency: 4,
  /** Longest clip sent per side (s); longer lines are cut to their first part. */
  maxClipSec: 15,
} as const;

export function listenRetakeEnabled(env: Record<string, string | undefined> = process.env): boolean {
  return String(env.DUBBING_LISTEN_RETAKE ?? "").toLowerCase() === "true";
}

export type ListenFaultType =
  | "unwanted_whisper"
  | "breathy_onset"
  | "wrong_emotion"
  | "flat_delivery"
  | "overacted"
  | "mispronunciation"
  | "garbled"
  | "clipped_ending";

/** Faults a second take with adjusted settings can fix. Clipped endings are timing (stitcher), not takes. */
export const RETAKE_FAULTS = new Set<ListenFaultType>([
  "unwanted_whisper",
  "breathy_onset",
  "wrong_emotion",
  "flat_delivery",
  "overacted",
  "mispronunciation",
  "garbled",
]);

const KNOWN_FAULTS = new Set<string>([...RETAKE_FAULTS, "clipped_ending"]);

export interface ListenFault {
  type: ListenFaultType;
  detail?: string;
}

export interface ListenVerdict {
  index: number;
  /** 1 (unusable) … 5 (as good as the original's performance). */
  score: number;
  faults: ListenFault[];
  /** The original's delivery in Gemini's words (e.g. "teasing", "grieving"). */
  sourceDelivery?: string;
}

function parseJson(raw: string): any {
  const text = String(raw || "").trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const body = fenced ? fenced[1] : text;
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(body.slice(start, end + 1));
  } catch {
    return null;
  }
}

/** Gemini's reply → verdict. Unreadable replies give null (the line keeps its take). */
export function parseListenVerdict(raw: string, index: number): ListenVerdict | null {
  const parsed = parseJson(raw);
  if (!parsed || typeof parsed !== "object") return null;
  const score = Number(parsed.score);
  if (!Number.isFinite(score)) return null;
  const faults: ListenFault[] = Array.isArray(parsed.faults)
    ? parsed.faults
        .map((f: any) => (typeof f === "string" ? { type: f } : f))
        .filter((f: any) => f && typeof f.type === "string" && KNOWN_FAULTS.has(f.type.trim()))
        .map((f: any) => ({ type: f.type.trim() as ListenFaultType, ...(typeof f.detail === "string" ? { detail: f.detail.slice(0, 200) } : {}) }))
    : [];
  return {
    index,
    score: Math.max(1, Math.min(5, Math.round(score))),
    faults,
    ...(typeof parsed.source_delivery === "string" ? { sourceDelivery: parsed.source_delivery.slice(0, 60) } : {}),
  };
}

export function retakeableFaults(v: ListenVerdict): ListenFault[] {
  return v.faults.filter((f) => RETAKE_FAULTS.has(f.type));
}

/** Lines to re-voice: a fixable fault (or a very low score), worst first, within the caps. */
export function selectRetakes(verdicts: ListenVerdict[], totalLines: number): number[] {
  const cap = Math.min(LISTEN.maxRetakeLines, Math.max(1, Math.floor(totalLines * LISTEN.maxRetakeShare)));
  return verdicts
    .filter((v) => retakeableFaults(v).length > 0 || v.score <= LISTEN.retakeScoreAtOrBelow)
    .sort((a, b) => a.score - b.score || retakeableFaults(b).length - retakeableFaults(a).length)
    .slice(0, cap)
    .map((v) => v.index);
}

export interface TakeSettings {
  stability: number;
  style: number;
  emotionTag?: string;
}

/** Tags that make ElevenLabs v4 breathe or whisper; removed for breath faults. */
const BREATHY_TAGS = new Set(["whispers", "whisper", "soft", "softly", "sighs"]);
const STRONG_TAGS = new Set(["crying", "shouting", "screaming", "distressed", "menacing", "laughs", "angry", "excited", "sorrowful", "sad"]);

/**
 * Settings for the second take. Bounded so a retake cannot slur or drift the voice: stability stays
 * within [0.3, 0.75] (dubbing-guards.ts: near 0.2 slurred Telugu), style within [0, 0.6].
 */
export function retakeSettings(faults: ListenFault[], base: TakeSettings, sourceDelivery?: string): TakeSettings {
  let { stability, style, emotionTag } = base;
  const types = new Set(faults.map((f) => f.type));
  if (types.has("unwanted_whisper") || types.has("breathy_onset")) {
    if (emotionTag && BREATHY_TAGS.has(emotionTag)) emotionTag = undefined;
    stability = Math.max(stability, 0.55);
  }
  if (types.has("wrong_emotion")) {
    const wanted = (sourceDelivery || "").toLowerCase().trim();
    emotionTag = STRONG_TAGS.has(wanted) ? wanted : undefined;
    style = style + 0.15;
  }
  if (types.has("flat_delivery")) {
    style = style + 0.2;
    stability = stability - 0.08;
  }
  if (types.has("overacted")) {
    style = style - 0.2;
    stability = stability + 0.1;
    if (emotionTag && STRONG_TAGS.has(emotionTag)) emotionTag = undefined;
  }
  // mispronunciation / garbled: same settings; a fresh take is the fix.
  return {
    stability: Number(Math.max(0.3, Math.min(0.75, stability)).toFixed(2)),
    style: Number(Math.max(0, Math.min(0.6, style)).toFixed(2)),
    ...(emotionTag ? { emotionTag } : {}),
  };
}

/** Keep the new take only when it is judged better: higher score, or same score with fewer fixable faults. */
export function newTakeIsBetter(oldV: ListenVerdict, newV: ListenVerdict | null): boolean {
  if (!newV) return false;
  if (newV.score > oldV.score) return true;
  return newV.score === oldV.score && retakeableFaults(newV).length < retakeableFaults(oldV).length;
}

export function buildListenPrompt(params: { sourceText: string; dubText: string; targetLanguage: string; durationSec?: number }): string {
  return `You are a dubbing director. Audio 1 is a line from the original video. Audio 2 is the same line dubbed into ${params.targetLanguage} by a synthetic voice.
Original words: ${JSON.stringify(params.sourceText.slice(0, 300))}
Dubbed words: ${JSON.stringify(params.dubText.replace(/\[[^\]]+\]\s*/g, "").slice(0, 300))}

Judge ONLY the dubbed performance against the original's: voice texture, emotion, energy and clarity. Do not judge the translation's wording or the language.
Report a fault only when you clearly hear it:
- unwanted_whisper: dubbed line is whispered or airy where the original is spoken with voice
- breathy_onset: dubbed line starts breathy/whispery, then becomes a full voice
- wrong_emotion: clearly different emotion from the original (e.g. sad vs teasing)
- flat_delivery: original is emotional or energetic, dub is flat
- overacted: dub is much more intense than the original
- mispronunciation: a name or word is clearly mispronounced
- garbled: words are slurred, skipped or unintelligible
- clipped_ending: the last word is cut off
Score 1-5: 5 = performance as convincing as the original, 3 = acceptable, 1 = unusable.

Return ONLY JSON:
{"score": 4, "faults": [{"type": "breathy_onset", "detail": "first word whispered"}], "source_delivery": "one word for the original's emotion"}`;
}

export type ListenGenerateFn = (args: { prompt: string; sourceWavBase64: string; dubWavBase64: string }) => Promise<string>;

/** One listen: returns a verdict, or null when Gemini fails or answers unreadably (the line keeps its take). */
export async function listenToLine(
  generate: ListenGenerateFn,
  params: { index: number; sourceWav: Buffer; dubWav: Buffer; sourceText: string; dubText: string; targetLanguage: string }
): Promise<ListenVerdict | null> {
  try {
    const raw = await generate({
      prompt: buildListenPrompt(params),
      sourceWavBase64: params.sourceWav.toString("base64"),
      dubWavBase64: params.dubWav.toString("base64"),
    });
    return parseListenVerdict(raw, params.index);
  } catch {
    return null;
  }
}

// ─── Orchestration (I/O injected) ──────────────────────────────────────────────────────────────

export interface ListenLine {
  /** Index into the language's line list (normalised / ttsUrls). */
  index: number;
  sourceText: string;
  /** Text that was voiced, tags included. */
  dubText: string;
  dubUrl: string;
  startMs: number;
  endMs: number;
  /** Measured length of the current take (ms). */
  durationMs?: number;
  /** Settings the current take was voiced with. */
  base: TakeSettings;
}

export interface NewTake {
  url: string;
  durationMs: number;
}

export interface ListenDeps {
  generate: ListenGenerateFn;
  /** Original line audio (16 kHz mono WAV), or null when unavailable. */
  sourceWav(line: ListenLine): Promise<Buffer | null>;
  /** Dubbed take audio (16 kHz mono WAV), or null. */
  dubWav(url: string): Promise<Buffer | null>;
  resynthesize(line: ListenLine, settings: TakeSettings): Promise<NewTake | null>;
  /** Reserves retake characters from the language's retry budget. */
  tryConsumeBudget(chars: number): boolean;
  /** Commit a kept take (replace the line's audio, checkpoint). */
  keep(line: ListenLine, take: NewTake): Promise<void>;
  log(message: string, data: Record<string, unknown>): void;
}

export interface ListenSummary {
  listened: number;
  unreadable: number;
  scores: Record<string, number>;
  faults: Record<string, number>;
  retakesTried: number;
  retakesKept: number;
  refusedForBudget: number;
  rejectedTooLong: number;
}

/** A new take may not be much longer than the old one or the line's window (timing would get worse). */
export function takeFitsTiming(line: ListenLine, take: NewTake): boolean {
  const windowMs = Math.max(0, line.endMs - line.startMs);
  const limit = Math.max(line.durationMs ?? 0, windowMs) * 1.1;
  return limit <= 0 || take.durationMs <= limit;
}

async function mapLimit<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i]);
    }
  });
  await Promise.all(workers);
  return out;
}

const stripTags = (t: string) => t.replace(/\[[^\]]+\]\s*/g, "").trim();

export async function runListenAndRetake(lines: ListenLine[], targetLanguage: string, deps: ListenDeps): Promise<ListenSummary> {
  const summary: ListenSummary = {
    listened: 0,
    unreadable: 0,
    scores: {},
    faults: {},
    retakesTried: 0,
    retakesKept: 0,
    refusedForBudget: 0,
    rejectedTooLong: 0,
  };
  const byIndex = new Map(lines.map((l) => [l.index, l]));
  const sources = new Map<number, Buffer>();

  const verdicts = (
    await mapLimit(lines, LISTEN.concurrency, async (line) => {
      const [src, dub] = await Promise.all([deps.sourceWav(line).catch(() => null), deps.dubWav(line.dubUrl).catch(() => null)]);
      if (!src || !dub) return null;
      sources.set(line.index, src);
      const v = await listenToLine(deps.generate, {
        index: line.index,
        sourceWav: src,
        dubWav: dub,
        sourceText: line.sourceText,
        dubText: line.dubText,
        targetLanguage,
      });
      summary.listened++;
      if (!v) summary.unreadable++;
      else {
        summary.scores[String(v.score)] = (summary.scores[String(v.score)] || 0) + 1;
        for (const f of v.faults) summary.faults[f.type] = (summary.faults[f.type] || 0) + 1;
        deps.log("[Dubbing:Listen] Line", { index: v.index, score: v.score, faults: v.faults, sourceDelivery: v.sourceDelivery });
      }
      return v;
    })
  ).filter((v): v is ListenVerdict => Boolean(v));

  const verdictByIndex = new Map(verdicts.map((v) => [v.index, v]));
  for (const index of selectRetakes(verdicts, lines.length)) {
    const line = byIndex.get(index);
    const oldV = verdictByIndex.get(index);
    const src = sources.get(index);
    if (!line || !oldV || !src) continue;
    if (!deps.tryConsumeBudget(stripTags(line.dubText).length)) {
      summary.refusedForBudget++;
      continue;
    }
    const settings = retakeSettings(retakeableFaults(oldV), line.base, oldV.sourceDelivery);
    summary.retakesTried++;
    const take = await deps.resynthesize(line, settings).catch(() => null);
    if (!take) continue;
    if (!takeFitsTiming(line, take)) {
      summary.rejectedTooLong++;
      deps.log("[Dubbing:Listen] Retake rejected (too long)", { index, newMs: take.durationMs, oldMs: line.durationMs ?? null });
      continue;
    }
    const newDub = await deps.dubWav(take.url).catch(() => null);
    const newV = newDub
      ? await listenToLine(deps.generate, { index, sourceWav: src, dubWav: newDub, sourceText: line.sourceText, dubText: line.dubText, targetLanguage })
      : null;
    const better = newTakeIsBetter(oldV, newV);
    deps.log("[Dubbing:Listen] Retake", {
      index,
      settings,
      oldScore: oldV.score,
      newScore: newV?.score ?? null,
      oldFaults: oldV.faults.map((f) => f.type),
      newFaults: newV ? newV.faults.map((f) => f.type) : null,
      kept: better,
    });
    if (better) {
      await deps.keep(line, take);
      summary.retakesKept++;
    }
  }
  return summary;
}
