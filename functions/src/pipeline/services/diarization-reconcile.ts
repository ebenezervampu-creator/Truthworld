/**
 * Decides corrected speaker labels from a per-turn "who is speaking" verdict
 * (dependency-free, unit-tested; the Gemini call lives in diarization-check.ts).
 *
 * Why: AssemblyAI clusters by voice alone. In Clip 2 it put Joseph's 0:13 line under the guard's
 * label and the prisoner's 0:29 line under the guard's label too, so Joseph spoke in two voices and
 * the prisoner in the guard's. Voice locking downstream can only be as right as these labels.
 *
 * Rules (conservative: when unsure, keep AssemblyAI's label):
 *  - Only verdicts at or above minConfidence are used; below minCoverage of turns, nothing changes.
 *  - Each character keeps the AssemblyAI label most of its speech already had (by duration), so
 *    labels stay stable and voice-cache keys keep working. Characters are served longest-first.
 *  - A character whose best label is already taken gets a new label "<label>_<n>" (a split).
 *  - Two labels whose confident turns are all one character collapse into that character's label (a merge).
 *  - If the result would put every turn on one label while AssemblyAI had several, nothing changes.
 */

export interface DiarizationTurn {
  id: string;
  label: string;
  durationMs: number;
}

export interface TurnVerdict {
  id: string;
  character: string;
  confidence: number;
}

export interface LabelChange {
  id: string;
  from: string;
  to: string;
  character: string;
}

export interface ReconcileResult {
  applied: boolean;
  reason: string;
  /** Turn id → label to use (every input turn is present). */
  labels: Map<string, string>;
  changes: LabelChange[];
  /** Character id → label assigned to it. */
  characterLabels: Map<string, string>;
  /** Optional turn id → corrected transcript text from plausibility recheck. */
  textCorrections?: Map<string, string>;
}

export const DEFAULT_MIN_CONFIDENCE = 0.8;
export const DEFAULT_MIN_COVERAGE = 0.6;

export function reconcileDiarization(
  turns: DiarizationTurn[],
  verdicts: TurnVerdict[],
  opts: { minConfidence?: number; minCoverage?: number } = {}
): ReconcileResult {
  const minConfidence = opts.minConfidence ?? DEFAULT_MIN_CONFIDENCE;
  const minCoverage = opts.minCoverage ?? DEFAULT_MIN_COVERAGE;
  const unchanged = (reason: string): ReconcileResult => ({
    applied: false,
    reason,
    labels: new Map(turns.map((t) => [t.id, t.label])),
    changes: [],
    characterLabels: new Map(),
    textCorrections: new Map(),
  });

  if (turns.length === 0) return unchanged("no turns");

  const turnById = new Map(turns.map((t) => [t.id, t]));
  const confident = new Map<string, string>(); // turn id → character
  for (const v of verdicts) {
    const character = typeof v.character === "string" ? v.character.trim() : "";
    if (!turnById.has(v.id) || !character) continue;
    if (!(typeof v.confidence === "number" && v.confidence >= minConfidence)) continue;
    confident.set(v.id, character);
  }
  if (confident.size / turns.length < minCoverage) {
    return unchanged(`only ${confident.size}/${turns.length} turns identified with confidence >= ${minConfidence}`);
  }

  // Duration each character spends under each original label.
  const byCharacter = new Map<string, { total: number; perLabel: Map<string, number> }>();
  for (const [turnId, character] of confident) {
    const t = turnById.get(turnId)!;
    if (!byCharacter.has(character)) byCharacter.set(character, { total: 0, perLabel: new Map() });
    const c = byCharacter.get(character)!;
    const d = Math.max(1, t.durationMs);
    c.total += d;
    c.perLabel.set(t.label, (c.perLabel.get(t.label) || 0) + d);
  }

  const allLabels = new Set(turns.map((t) => t.label));
  const used = new Set<string>();
  const characterLabels = new Map<string, string>();
  const characters = [...byCharacter.entries()].sort((a, b) => b[1].total - a[1].total || a[0].localeCompare(b[0]));
  for (const [character, { perLabel }] of characters) {
    const ranked = [...perLabel.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
    const free = ranked.find(([label]) => !used.has(label));
    let label: string;
    if (free) {
      label = free[0];
    } else {
      const base = ranked[0][0];
      let n = 2;
      while (used.has(`${base}_${n}`) || allLabels.has(`${base}_${n}`)) n++;
      label = `${base}_${n}`;
    }
    used.add(label);
    characterLabels.set(character, label);
  }

  const labels = new Map<string, string>();
  const changes: LabelChange[] = [];
  for (const t of turns) {
    const character = confident.get(t.id);
    const to = character ? characterLabels.get(character)! : t.label;
    labels.set(t.id, to);
    if (to !== t.label) changes.push({ id: t.id, from: t.label, to, character: character! });
  }

  const before = new Set(turns.map((t) => t.label)).size;
  const after = new Set(labels.values()).size;
  if (before >= 2 && after === 1) {
    return unchanged(`refused to collapse ${before} AssemblyAI speakers into one voice`);
  }
  if (changes.length === 0) {
    return { applied: false, reason: "AssemblyAI labels already match the characters", labels, changes, characterLabels };
  }
  return { applied: true, reason: `${changes.length} turn(s) relabelled`, labels, changes, characterLabels };
}

/**
 * Carries corrected labels from the dubbing segments over to transcript utterances (which speaker
 * profiling reads), by greatest time overlap, so every corrected label gets its own profile and voice.
 * Utterances that overlap no segment keep their label.
 */
export function relabelByOverlap<U extends { start: number; end: number; speaker?: string }>(
  utterances: U[],
  segments: Array<{ start: number; end: number; speaker?: string }>
): U[] {
  return utterances.map((u) => {
    let best: string | undefined;
    let bestOverlap = 0;
    for (const s of segments) {
      const overlap = Math.min(u.end, s.end) - Math.max(u.start, s.start);
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        best = s.speaker;
      }
    }
    return best && best !== u.speaker ? { ...u, speaker: best } : u;
  });
}

interface TimedWord {
  start: number;
  end: number;
  text?: string;
  speaker?: string;
}

/**
 * Like relabelByOverlap, but an utterance that spans segments with different corrected labels is
 * split into one utterance per label run, so every corrected label reaches speaker profiling.
 *
 * Why: AssemblyAI can return several characters as ONE long utterance (Joseph clip, 2026-11-20:
 * Pharaoh, Cupbearer and Guard in a single 4.8–25.4 s "B" utterance). relabelByOverlap gives that
 * utterance one label, so the split labels (B_2, B_3) got no profile and no matched voice.
 *
 *  - Overlapping segments are grouped into runs of consecutive segments sharing a label.
 *  - With word timings, each word goes to the run containing its midpoint (else the nearest run);
 *    a part's times and text come from its words, and runs that received no words are dropped.
 *  - Without word timings, a part takes its run's times (clipped to the utterance) and segment text.
 *  - Utterances overlapping a single label (or none) are handled exactly like relabelByOverlap.
 * Other utterance fields are kept on every part. Output is in time order.
 */
export function splitUtterancesBySegments<
  U extends { start: number; end: number; speaker?: string; text?: string; words?: TimedWord[] }
>(utterances: U[], segments: Array<{ start: number; end: number; speaker?: string; text?: string }>): U[] {
  const ordered = [...segments].sort((a, b) => a.start - b.start || a.end - b.end);
  const out: U[] = [];

  for (const u of utterances) {
    const overlapping = ordered.filter((s) => s.speaker && Math.min(u.end, s.end) - Math.max(u.start, s.start) > 0);
    if (new Set(overlapping.map((s) => s.speaker)).size <= 1) {
      out.push(...relabelByOverlap([u], segments));
      continue;
    }

    const runs: Array<{ speaker: string; start: number; end: number; texts: string[]; words: TimedWord[] }> = [];
    for (const s of overlapping) {
      const last = runs[runs.length - 1];
      if (last && last.speaker === s.speaker) {
        last.end = Math.max(last.end, s.end);
        if (s.text) last.texts.push(s.text);
      } else {
        runs.push({ speaker: s.speaker!, start: s.start, end: s.end, texts: s.text ? [s.text] : [], words: [] });
      }
    }

    const words = Array.isArray(u.words) ? u.words : [];
    if (words.length > 0) {
      for (const word of words) {
        const mid = (word.start + word.end) / 2;
        let target = runs.find((r) => mid >= r.start && mid <= r.end);
        if (!target) {
          const gap = (r: { start: number; end: number }) => (mid < r.start ? r.start - mid : mid - r.end);
          target = runs.reduce((best, r) => (gap(r) < gap(best) ? r : best));
        }
        target.words.push(word);
      }
      for (const r of runs) {
        if (r.words.length === 0) continue;
        out.push({
          ...u,
          speaker: r.speaker,
          start: r.words[0].start,
          end: r.words[r.words.length - 1].end,
          text: r.words.map((x) => x.text ?? "").join(" ").trim(),
          words: r.words.map((x) => ({ ...x, speaker: r.speaker })),
        });
      }
    } else {
      for (const r of runs) {
        out.push({
          ...u,
          speaker: r.speaker,
          start: Math.max(u.start, r.start),
          end: Math.min(u.end, r.end),
          text: r.texts.join(" ").trim() || u.text,
        });
      }
    }
  }

  return out
    .map((u, i) => ({ u, i }))
    .sort((a, b) => a.u.start - b.u.start || a.i - b.i)
    .map((x) => x.u);
}

/** What the diarization check did, in a form that can be stored on the job and in test reports. */
export interface DiarizationSummary {
  /** Distinct speaker labels AssemblyAI gave the checked turns. */
  speakersBefore: number;
  /** Distinct speaker labels after the check (equal to speakersBefore when nothing was applied). */
  speakersAfter: number;
  applied: boolean;
  reason: string;
  /** Turns whose label the check changed. */
  changedTurns: number;
  textCorrections?: Record<string, string>;
}

/**
 * Summarises a check result against the labels AssemblyAI gave. Accepts `labels` as a Map or as a
 * plain object, because a cached result comes back from JSON.
 */
export function summarizeDiarization(
  originalLabels: string[],
  result: {
    applied?: boolean;
    reason?: string;
    labels?: Map<string, string> | Record<string, string>;
    changes?: unknown[];
    textCorrections?: Map<string, string> | Record<string, string>;
  }
): DiarizationSummary {
  const speakersBefore = new Set(originalLabels).size;
  const applied = result.applied === true;
  let speakersAfter = speakersBefore;
  if (applied && result.labels) {
    const values = result.labels instanceof Map ? [...result.labels.values()] : Object.values(result.labels);
    if (values.length > 0) speakersAfter = new Set(values).size;
  }
  const textCorrections = result.textCorrections
    ? result.textCorrections instanceof Map
      ? Object.fromEntries(result.textCorrections.entries())
      : (result.textCorrections as Record<string, string>)
    : undefined;
  return {
    speakersBefore,
    speakersAfter,
    applied,
    reason: String(result.reason ?? ""),
    changedTurns: applied && Array.isArray(result.changes) ? result.changes.length : 0,
    ...(textCorrections && Object.keys(textCorrections).length > 0 ? { textCorrections } : {}),
  };
}
