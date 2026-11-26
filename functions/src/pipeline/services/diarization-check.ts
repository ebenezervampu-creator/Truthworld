/**
 * Diarization check: Gemini watches the video and says which character speaks each turn, then
 * diarization-reconcile.ts decides (in code, conservatively) whether to correct AssemblyAI's labels.
 *
 * Runs once per dubbing job, before speaker profiling and voice assignment. On any failure it
 * returns the original labels: it can only correct diarization, never block a dub.
 *
 * Keeping characters consistent on long videos:
 *  - An optional creator cast list (cast-list.ts) seeds the roster with stable ids C1..Cn.
 *  - Long videos are checked in windows. Each character gets an anchor: a short clip where they
 *    speak (the cast list's timestamp, or their first confidently identified turn). Later windows
 *    are shown those clips first, so Gemini recognises people by face and voice, not only by a
 *    text description. At most MAX_REFERENCE_CLIPS clips of ANCHOR_MAX_MS each per window.
 */

import { PIPELINE_CONFIG } from "../config";
import { logger } from "../utils/logger";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText, normalizeToGcsUri } from "../utils/ai-utils";
import { reconcileDiarization, type ReconcileResult, type TurnVerdict } from "./diarization-reconcile";
import { castRoster, type CastMember } from "./cast-list";

export interface CheckTurn {
  /** Index into the dubbing segments. */
  index: number;
  start: number;
  end: number;
  speaker: string;
  text: string;
}

export type DiarizationGenerateFn = (args: {
  model: string;
  videoUri: string;
  mimeType: string;
  prompt: string;
  /** Part of the video to watch, in seconds (windowed checks on long videos). */
  startOffsetSec?: number;
  endOffsetSec?: number;
  /** Short clips of characters identified earlier, shown before the main video, in prompt order. */
  references?: ReferenceClip[];
}) => Promise<string>;

export interface ReferenceClip {
  id: string;
  label: string;
  startOffsetSec: number;
  endOffsetSec: number;
}

export interface DiarizationCheckOptions {
  /** Creator cast list (speaking characters), seeds the roster. */
  cast?: CastMember[];
  /** Most turns to check; defaults to MAX_TURNS, capped at MAX_TURNS_CEILING. */
  maxTurns?: number;
}

/** Turns per Gemini call. Long or crowded videos are checked window by window. */
export const WINDOW_TURNS = 80;
/** Most turns checked per job by default (cost bound); later turns keep AssemblyAI's label. */
export const MAX_TURNS = 1000;
/** Upper bound for long-form and cinema jobs (a feature film has roughly 1,500–2,500 turns). */
export const MAX_TURNS_CEILING = 6000;
/** Videos this long (or cinema/reel jobs) check every turn up to MAX_TURNS_CEILING. */
export const LONG_FORM_SEC = 30 * 60;
/** Reference clips per window, and the longest clip, bound the extra video Gemini watches. */
export const MAX_REFERENCE_CLIPS = 8;
export const ANCHOR_MAX_MS = 4000;
const ANCHOR_MIN_MS = 800;
const ANCHOR_MIN_CONFIDENCE = 0.85;

/**
 * Turn limit for a job. Checking costs about one pass over the video's length, so long-form and
 * cinema jobs check every turn; short videos rarely reach the default limit anyway.
 */
export function maxTurnsForJob(job: { durationSec?: number; cinemaGrade?: boolean; isReelJob?: boolean }): number {
  const long = (job.durationSec ?? 0) >= LONG_FORM_SEC;
  return job.cinemaGrade || job.isReelJob || long ? MAX_TURNS_CEILING : MAX_TURNS;
}

export interface RosterEntry {
  id: string;
  description: string;
}

const defaultGenerate: DiarizationGenerateFn = async ({ model, videoUri, mimeType, prompt, startOffsetSec, endOffsetSec, references }) => {
  const m = getVertexAI().getGenerativeModel({
    model,
    generationConfig: { responseMimeType: "application/json", temperature: 0 },
  });
  const clip = (startSec?: number, endSec?: number): any => {
    const part: any = { fileData: { mimeType, fileUri: videoUri } };
    if (typeof startSec === "number" && typeof endSec === "number") {
      part.videoMetadata = { startOffset: `${Math.max(0, startSec).toFixed(1)}s`, endOffset: `${endSec.toFixed(1)}s` };
    }
    return part;
  };
  const parts: any[] = [];
  for (const ref of references ?? []) {
    parts.push({ text: `Reference clip for ${ref.id} (${ref.label}):` });
    parts.push(clip(ref.startOffsetSec, ref.endOffsetSec));
  }
  if (parts.length > 0) parts.push({ text: "Main video:" });
  parts.push(clip(startOffsetSec, endOffsetSec), { text: prompt });
  const result: any = await m.generateContent({
    contents: [{ role: "user", parts }],
  });
  return extractCandidateText(result.response?.candidates?.[0]) || result.response?.candidates?.[0]?.content?.parts?.[0]?.text || "";
};

function clock(ms: number): string {
  const sec = Math.max(0, ms) / 1000;
  const m = Math.floor(sec / 60);
  const s = sec - m * 60;
  return `${String(m).padStart(2, "0")}:${s.toFixed(1).padStart(4, "0")}`;
}

export function buildDiarizationPrompt(
  turns: CheckTurn[],
  roster: RosterEntry[] = [],
  extras: { fromCast?: number; references?: ReferenceClip[] } = {}
): string {
  const nextId = roster.length + 1;
  const fromCast = Math.min(Math.max(0, extras.fromCast ?? 0), roster.length);
  const cast = roster.slice(0, fromCast);
  const found = roster.slice(fromCast);
  const castText = cast.length
    ? `
Cast list from the creator — the speaking characters in this video. Use these ids for them:
${cast.map((r) => `${r.id}: ${r.description}`).join("\n")}
`
    : "";
  const foundText = found.length
    ? `
Characters already identified earlier in this video (reuse these ids when the same person speaks again):
${found.map((r) => `${r.id}: ${r.description}`).join("\n")}
`
    : "";
  const newIdText = roster.length
    ? `Anyone not listed above gets the next unused id, starting at C${nextId}.\n`
    : "";
  const refs = extras.references ?? [];
  const refText = refs.length
    ? `
Before the main video you were shown reference clips, in this order: ${refs
        .map((r) => `${r.id} (${r.label}) at ${clock(r.startOffsetSec * 1000)}`)
        .join("; ")}.
Use them to recognise the same people by face and voice. Turn times below refer to the main video.
`
    : "";
  const rosterText = castText + foundText + newIdText + refText;
  const table = turns
    .map((t) => `T${t.index} | ${clock(t.start)}–${clock(t.end)} | label ${t.speaker} | "${t.text.replace(/"/g, "'").slice(0, 160)}"`)
    .join("\n");
  return `You are checking speaker diarization for a dubbing pipeline.
A speech-recognition system split this video's dialogue into turns and labelled each with a speaker label.
Labels come from voice clustering alone and can be wrong: two people with similar voices may share a label,
and one person may be split across labels.

For EVERY turn below, decide which on-screen character is speaking, using both:
- the voice (timbre, pitch, accent) compared with the other turns, and
- who is visibly speaking at that time (mouth movement, who is addressed, reaction shots).
Give characters stable ids C1, C2, C3... — the same person must get the same id in every turn.
Do not trust the existing labels; judge each turn yourself.
${rosterText}Confidence is 0 to 1. Use below 0.5 when you cannot tell (speaker off screen and voice ambiguous).${isTranscriptPlausibilityRecheckEnabled() ? "\nAlso inspect each turn's text for acoustic speech-recognition errors that clash with neighbouring dialogue. If any turn appears implausible, list its id in 'flagged_turns': [{\"id\":\"T0\",\"reason\":\"...\"}]." : ""}

Turns (id | time mm:ss | current label | text):
${table}

Return ONLY JSON:
{"characters":[{"id":"C1","description":"short visual + voice description"}],
 "turns":[{"id":"T0","character":"C1","confidence":0.9}]${isTranscriptPlausibilityRecheckEnabled() ? ',\n "flagged_turns":[{"id":"T0","reason":"..."}]' : ""}}`;
}

function parseJson(raw: string): any {
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    return JSON.parse(match[0]);
  } catch {
    return null;
  }
}

export function parseDiarizationCharacters(raw: string): RosterEntry[] {
  const parsed = parseJson(raw);
  if (!Array.isArray(parsed?.characters)) return [];
  return parsed.characters
    .filter((c: any) => c && typeof c.id === "string" && c.id.trim())
    .map((c: any) => ({ id: c.id.trim(), description: typeof c.description === "string" ? c.description.slice(0, 200) : "" }));
}

export function parseDiarizationVerdicts(raw: string): TurnVerdict[] {
  const parsed = parseJson(raw);
  if (!Array.isArray(parsed?.turns)) return [];
  return parsed.turns
    .filter((t: any) => t && typeof t.id === "string")
    .map((t: any) => ({
      id: String(t.id).replace(/^T/i, ""),
      character: typeof t.character === "string" ? t.character : "",
      confidence: Number(t.confidence),
    }));
}

export function isTranscriptPlausibilityRecheckEnabled(): boolean {
  return (
    process.env.ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK === "true" ||
    (PIPELINE_CONFIG as any).ENABLE_TRANSCRIPT_PLAUSIBILITY_RECHECK === true
  );
}

export function parseDiarizationFlaggedTurns(raw: string): string[] {
  const parsed = parseJson(raw);
  const list = parsed?.flagged_turns || parsed?.flaggedTurns;
  if (!Array.isArray(list)) return [];
  return list
    .map((item: any) => (typeof item === "string" ? item : item?.id))
    .filter((id: any): id is string => typeof id === "string" && Boolean(id.trim()))
    .map((id) => id.replace(/^T/i, "").trim());
}

/**
 * Dedicated transcript-plausibility pass (2026-11-24). The diarization prompt only asks for
 * implausible turns as a side task, and in the te test (dub-test-te-1795522961000) it flagged none:
 * "Every time you walk into school" between "lie to him" and "kiss him goodnight" went through, and
 * the translation editor had to guess the meaning. This prompt does only this one job, per window,
 * and only proposes turns to re-listen to; recheckTranscriptTurn decides on the audio.
 */
export function buildPlausibilityPrompt(turns: CheckTurn[]): string {
  const table = turns
    .map((t) => `T${t.index} | ${clock(t.start)}–${clock(t.end)} | "${t.text.replace(/"/g, "'").slice(0, 200)}"`)
    .join("\n");
  return `You are proofreading a speech-recognition transcript of this video's dialogue, turn by turn.
Flag a turn ONLY when its words are probably misheard: a word, pronoun or object that does not fit the
surrounding dialogue or what is happening on screen, where a similar-sounding phrase would fit
(e.g. "walk into school" in a conversation about taking a child to school, where "walk him to school" fits).
Do not flag a turn for style, grammar, slang, names or claims you merely doubt. Most transcripts have no
such errors: an empty list is the normal answer.

Turns (id | time mm:ss | text):
${table}

Return ONLY JSON:
{"flagged_turns":[{"id":"T0","reason":"short reason naming the misheard words"}]}`;
}

export interface RecheckOutcome {
  index: number;
  accepted: boolean;
  confidence: number;
  reason?: string;
}

export function hasNumberMismatch(before: string, after: string): boolean {
  const numRegex = /\b\d+(?:\.\d+)?\b/g;
  const beforeNums = (before || "").match(numRegex) || [];
  const afterNums = (after || "").match(numRegex) || [];
  return beforeNums.join(",") !== afterNums.join(",");
}

export const HIGH_RECHECK_CONFIDENCE = 0.85;

export interface RecheckTranscriptOptions {
  model?: string;
  generateFn?: DiarizationGenerateFn;
}

export async function recheckTranscriptTurn(
  videoUri: string,
  mimeType: string,
  turn: CheckTurn,
  contextBefore?: CheckTurn,
  contextAfter?: CheckTurn,
  options: RecheckTranscriptOptions = {}
): Promise<{ accepted: boolean; correctedText?: string; confidence: number; reason?: string }> {
  const model = options.model || diarizationModel();
  const generate = options.generateFn || defaultGenerate;
  const startSec = Math.max(0, turn.start / 1000 - 1.0);
  const endSec = turn.end / 1000 + 1.0;

  const prompt = `You are verifying the speech-recognition transcript of a short audio window from the video.
Current transcript under review:
"${turn.text}"

Surrounding context:
Before: "${contextBefore?.text || '(scene begins)'}"
After: "${contextAfter?.text || '(scene ends)'}"

Listen carefully to the audio in this window. If the transcript contains an acoustic speech-recognition error that clashes with the dialogue (e.g. misheard word, pronoun or object clash), propose the corrected line.
CRITICAL RULES:
1. Return confidence >= 0.85 ONLY if you clearly and distinctly hear the corrected words in the audio.
2. NEVER change numbers, digits, amounts, units, proper names, or factual claims.
3. If the original text is plausible or you are unsure, return confidence < 0.85 and keep the original text.

Return ONLY JSON:
{"correctedText": "exact words spoken in audio", "confidence": 0.9, "reason": "short explanation"}`;

  try {
    const raw = await generate({
      model,
      videoUri,
      mimeType,
      prompt,
      startOffsetSec: startSec,
      endOffsetSec: endSec,
    });
    const parsed = parseJson(raw);
    const confidence = Number(parsed?.confidence) || 0;
    const correctedText = typeof parsed?.correctedText === "string" ? parsed.correctedText.trim() : "";

    if (!correctedText || correctedText === turn.text) {
      return { accepted: false, confidence, reason: "unchanged" };
    }
    if (confidence < HIGH_RECHECK_CONFIDENCE) {
      return { accepted: false, confidence, reason: "confidence below threshold" };
    }
    if (hasNumberMismatch(turn.text, correctedText)) {
      return { accepted: false, confidence, reason: "numbers changed" };
    }

    logger.info("[Transcription:Recheck]", { index: turn.index, before: turn.text, after: correctedText });
    return { accepted: true, correctedText, confidence, reason: parsed?.reason };
  } catch (err) {
    logger.warn("[Transcription:Recheck] Recheck failed, keeping original", { index: turn.index, error: String(err) });
    return { accepted: false, confidence: 0, reason: "error" };
  }
}

/**
 * After a window: each character's first confidently identified turn (at least ANCHOR_MIN_MS long)
 * becomes their anchor, unless they already have one (e.g. from the cast list). Also adds up
 * confident speaking time, which decides who gets a reference clip when there are too many.
 */
export function recordAnchors(
  verdicts: TurnVerdict[],
  turnByIndex: Map<string, { start: number; end: number }>,
  anchors: Map<string, { startMs: number; endMs: number }>,
  talkMs: Map<string, number>
): void {
  for (const v of verdicts) {
    const character = typeof v.character === "string" ? v.character.trim() : "";
    const turn = turnByIndex.get(v.id);
    if (!character || !turn || !(v.confidence >= ANCHOR_MIN_CONFIDENCE)) continue;
    const duration = Math.max(0, turn.end - turn.start);
    talkMs.set(character, (talkMs.get(character) || 0) + duration);
    if (!anchors.has(character) && duration >= ANCHOR_MIN_MS) {
      anchors.set(character, { startMs: turn.start, endMs: turn.start + Math.min(duration, ANCHOR_MAX_MS) });
    }
  }
}

/**
 * Reference clips for one window: characters with an anchor outside this window (inside it, Gemini
 * already sees them), most speaking time first, cast members before unseen extras, at most
 * MAX_REFERENCE_CLIPS. Returned in the order the clips are shown.
 */
export function pickReferences(
  anchors: Map<string, { startMs: number; endMs: number }>,
  talkMs: Map<string, number>,
  labels: Map<string, string>,
  roster: RosterEntry[],
  winStartSec: number,
  winEndSec: number
): ReferenceClip[] {
  const rosterOrder = new Map(roster.map((r, i) => [r.id, i]));
  return [...anchors.entries()]
    .filter(([, a]) => a.endMs / 1000 <= winStartSec || a.startMs / 1000 >= winEndSec)
    .sort(
      ([a], [b]) =>
        (talkMs.get(b) || 0) - (talkMs.get(a) || 0) ||
        (rosterOrder.get(a) ?? Number.MAX_SAFE_INTEGER) - (rosterOrder.get(b) ?? Number.MAX_SAFE_INTEGER) ||
        a.localeCompare(b)
    )
    .slice(0, MAX_REFERENCE_CLIPS)
    .map(([id, a]) => {
      const description = roster.find((r) => r.id === id)?.description || "";
      return {
        id,
        label: labels.get(id) || description.slice(0, 40) || id,
        startOffsetSec: Math.round(a.startMs / 100) / 10,
        endOffsetSec: Math.round(a.endMs / 100) / 10,
      };
    });
}

/**
 * Gemini model for the diarization check. GEMINI_MODEL_DIARIZATION overrides it (e.g. to compare a
 * Flash model with the default on clips AssemblyAI merged); the default is unchanged.
 */
export function diarizationModel(): string {
  return (
    process.env.GEMINI_MODEL_DIARIZATION ||
    (PIPELINE_CONFIG as any).GEMINI_MODELS?.diarization ||
    PIPELINE_CONFIG.GEMINI_MODEL ||
    "gemini-3.5-flash-lite"
  );
}

export class DiarizationCheckService {
  constructor(private readonly generate: DiarizationGenerateFn = defaultGenerate) {}

  /**
   * Returns the label to use for every turn (keyed by String(index)) and what changed. Never throws.
   */
  async check(
    jobId: string,
    videoUrl: string | undefined,
    turns: CheckTurn[],
    options: DiarizationCheckOptions = {}
  ): Promise<ReconcileResult> {
    const keep = (reason: string): ReconcileResult => ({
      applied: false,
      reason,
      labels: new Map(turns.map((t) => [String(t.index), t.speaker])),
      changes: [],
      characterLabels: new Map(),
    });

    if (turns.length < 2) return keep("fewer than 2 turns");
    const videoUri = videoUrl ? (normalizeToGcsUri(videoUrl) || (videoUrl.startsWith("gs://") ? videoUrl : null)) : null;
    if (!videoUri) return keep("video is not in Cloud Storage; Gemini cannot read it");

    const turnLimit = Math.min(MAX_TURNS_CEILING, Math.max(1, Math.floor(options.maxTurns ?? MAX_TURNS)));
    const checked = turns.slice(0, turnLimit);
    const model = diarizationModel();
    const mimeType = videoUri.endsWith(".mov") ? "video/quicktime" : "video/mp4";
    const windows: CheckTurn[][] = [];
    for (let i = 0; i < checked.length; i += WINDOW_TURNS) windows.push(checked.slice(i, i + WINDOW_TURNS));
    const windowed = windows.length > 1;

    try {
      // Windows run in order so each one sees the characters found so far and keeps their ids.
      // The cast list (if any) seeds the roster with ids C1..Cn and their anchors.
      const cast = castRoster(options.cast ?? []);
      const roster: RosterEntry[] = cast.map((c) => ({ id: c.id, description: c.description }));
      const labels = new Map<string, string>(cast.map((c) => [c.id, c.member.name]));
      const anchors = new Map<string, { startMs: number; endMs: number }>();
      for (const c of cast) {
        if (typeof c.member.appearsAtSec === "number") {
          const startMs = c.member.appearsAtSec * 1000;
          anchors.set(c.id, { startMs, endMs: startMs + ANCHOR_MAX_MS });
        }
      }
      const talkMs = new Map<string, number>();
      const turnByIndex = new Map(checked.map((t) => [String(t.index), t]));

      const verdicts: TurnVerdict[] = [];
      const flaggedTurns: string[] = [];
      let failedWindows = 0;
      let referenceClips = 0;
      for (const win of windows) {
        const winStart = win[0].start / 1000 - 2;
        const winEnd = win[win.length - 1].end / 1000 + 2;
        const references = windowed ? pickReferences(anchors, talkMs, labels, roster, winStart, winEnd) : [];
        referenceClips += references.length;
        try {
          const raw = await this.generate({
            model,
            videoUri,
            mimeType,
            prompt: buildDiarizationPrompt(win, roster, { fromCast: cast.length, references }),
            ...(windowed ? { startOffsetSec: winStart, endOffsetSec: winEnd } : {}),
            ...(references.length > 0 ? { references } : {}),
          });
          const winVerdicts = parseDiarizationVerdicts(raw);
          verdicts.push(...winVerdicts);
          for (const c of parseDiarizationCharacters(raw)) {
            if (!roster.some((r) => r.id === c.id)) roster.push(c);
          }
          if (isTranscriptPlausibilityRecheckEnabled()) {
            flaggedTurns.push(...parseDiarizationFlaggedTurns(raw));
            try {
              const plausibilityRaw = await this.generate({
                model,
                videoUri,
                mimeType,
                prompt: buildPlausibilityPrompt(win),
                ...(windowed ? { startOffsetSec: winStart, endOffsetSec: winEnd } : {}),
              });
              flaggedTurns.push(...parseDiarizationFlaggedTurns(plausibilityRaw));
            } catch (plausErr) {
              logger.warn("[Transcription:Recheck] Plausibility pass failed for a window", {
                jobId,
                firstTurn: win[0].index,
                error: String(plausErr),
              });
            }
          }
          recordAnchors(winVerdicts, turnByIndex, anchors, talkMs);
        } catch (winErr) {
          failedWindows++;
          logger.warn("[DiarizationCheck] Window failed — its turns keep AssemblyAI labels", {
            jobId,
            firstTurn: win[0].index,
            error: String(winErr),
          });
        }
      }
      if (failedWindows === windows.length) return keep("Gemini call failed");

      const result = reconcileDiarization(
        checked.map((t) => ({ id: String(t.index), label: t.speaker, durationMs: Math.max(0, t.end - t.start) })),
        verdicts
      );
      // Turns beyond the limit keep AssemblyAI's label.
      for (const t of turns.slice(turnLimit)) result.labels.set(String(t.index), t.speaker);

      if (isTranscriptPlausibilityRecheckEnabled()) {
        const textCorrections = new Map<string, string>();
        const outcomes: RecheckOutcome[] = [];
        const uniqueFlagged = Array.from(new Set(flaggedTurns));
        for (const turnId of uniqueFlagged) {
          const t = turnByIndex.get(turnId);
          if (!t) continue;
          const turnIdx = turns.findIndex((x) => String(x.index) === turnId);
          const prevTurn = turnIdx > 0 ? turns[turnIdx - 1] : undefined;
          const nextTurn = turnIdx < turns.length - 1 ? turns[turnIdx + 1] : undefined;
          const recheck = await recheckTranscriptTurn(videoUri, mimeType, t, prevTurn, nextTurn, {
            model,
            generateFn: this.generate,
          });
          outcomes.push({ index: t.index, accepted: recheck.accepted, confidence: recheck.confidence, reason: recheck.reason });
          if (recheck.accepted && recheck.correctedText) {
            t.text = recheck.correctedText;
            textCorrections.set(turnId, recheck.correctedText);
          }
        }
        // Always logged when the recheck is on, so "flagged nothing" and "did not run" look different.
        logger.info("[Transcription:Recheck] Summary", {
          jobId,
          flagged: uniqueFlagged.length,
          accepted: outcomes.filter((o) => o.accepted).length,
          outcomes,
        });
        if (textCorrections.size > 0) result.textCorrections = textCorrections;
      }
      logger.info("[DiarizationCheck] Result", {
        jobId,
        model,
        turns: turns.length,
        checked: checked.length,
        windows: windows.length,
        failedWindows,
        turnLimit,
        castSize: cast.length,
        referenceClips,
        characters: roster.length,
        verdicts: verdicts.length,
        applied: result.applied,
        reason: result.reason,
        changes: result.changes,
        characterLabels: Object.fromEntries(result.characterLabels),
      });
      return result;
    } catch (err) {
      logger.warn("[DiarizationCheck] Check failed — keeping AssemblyAI labels", { jobId, error: String(err) });
      return keep("Gemini call failed");
    }
  }
}

export const diarizationCheckService = new DiarizationCheckService();
