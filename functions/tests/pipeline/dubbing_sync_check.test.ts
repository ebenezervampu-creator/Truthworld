import {
  checkDubSpeech,
  dialogueExtents,
  findMissingDubSpeech,
  MIN_SUBTITLE_LINE_COVERAGE,
  subtitleLineCoverage,
  syncViolations,
  voiceGenderMismatch,
} from "../../src/pipeline/services/dub-sync-check";
import { DubbingQualityGate, isBlockingViolation } from "../../src/pipeline/layers/quality-gate";

const s = (a: number, b: number) => ({ startMs: Math.round(a * 1000), endMs: Math.round(b * 1000) });

// Measured on 24 Nov from the 60 s English → Telugu test: English voice activity (Demucs vocals)…
const englishSpeech = [
  s(6.48, 7.28), s(10.26, 11.28), s(13.04, 14.42), s(16.64, 18.9), s(21.4, 26.0), s(28.36, 30.16),
  s(32.82, 34.12), s(35.22, 37.16), s(44.42, 45.54), s(53.98, 54.62), s(56.3, 57.48), s(59.92, 60.86),
];
// …the transcript's lines (6.26–57.13 s; nothing after 57.4 s was transcribed)…
const lines = [s(6.26, 19.28), s(19.47, 24.14), s(24.19, 37.34), s(37.61, 45.15), s(45.2, 57.13)];
// …and the Telugu dialogue activity of three dubs.
const teMorning = [s(6.62, 9.32), s(10.14, 13.38), s(14.0, 18.04), s(19.76, 21.32), s(23.48, 27.9), s(28.5, 30.74), s(31.4, 36.58), s(37.8, 39.32), s(45.38, 46.14), s(46.78, 48.54)];
const teMissingLine = [s(6.46, 9.32), s(12.88, 17.34), s(17.7, 19.32), s(19.68, 21.44), s(23.54, 27.26), s(28.26, 30.92), s(32.78, 34.64), s(35.06, 38.22), s(44.26, 45.86), s(53.96, 55.12), s(56.2, 57.98)];
const teGood = [s(6.46, 9.32), s(10.2, 12.6), s(12.9, 18.9), s(19.68, 21.44), s(21.5, 27.26), s(28.26, 30.92), s(32.78, 34.64), s(35.06, 38.22), s(44.26, 45.86), s(53.96, 55.12), s(56.2, 57.98)];

const extents = dialogueExtents(lines);
const missingAt = (dub: typeof teGood) => findMissingDubSpeech({ sourceSpeech: englishSpeech, dubSpeech: dub, extents }).map((m) => m.startMs / 1000);

describe("dub measured against the original", () => {
  it("catches the morning dub that drifted 7–9 s early (lines at 54 s and 56 s had no Telugu)", () => {
    expect(missingAt(teMorning)).toEqual([53.98, 56.3]);
  });
  it("catches the 11:05 dub that dropped the line at 10.3 s", () => {
    expect(missingAt(teMissingLine)).toEqual([10.26]);
  });
  it("passes a dub that speaks every line", () => {
    expect(missingAt(teGood)).toEqual([]);
  });
  it("ignores speech outside the transcribed dialogue (59.9 s, after the transcript ends)", () => {
    expect(missingAt(teGood)).not.toContain(59.92);
  });
  it("turns findings into blocking gate violations", () => {
    const v = syncViolations({ checked: true, missing: [s(10.26, 11.28)], genderMismatches: [{ speaker: "B", originalHz: 139, dubHz: 215 }] });
    expect(v).toHaveLength(2);
    expect(v.every(isBlockingViolation)).toBe(true);
    expect(syncViolations({ checked: false, missing: [s(1, 2)], genderMismatches: [] })).toEqual([]);
    expect(syncViolations(undefined)).toEqual([]);
  });
  it("the quality gate fails a track with a sync finding", () => {
    const gate = DubbingQualityGate.evaluate({
      jobId: "j", targetLang: "te", totalSegments: 12, successfulSegments: 12, failedSegments: [],
      actualDurationSeconds: 60, expectedDurationSeconds: 60, isVoiceCloningRequested: false, isVoiceCloned: false,
      stemIsolationRequested: false, isStemPreserved: false, outputAudioSize: 500000, tier: "audio_track",
      syncViolations: ["Dubbed speech missing: 1 original line(s) have no dubbed speech near them (at 10.3s)"],
    });
    expect(gate.passed).toBe(false);
    expect(gate.violations.some(isBlockingViolation)).toBe(true);
  });
});

describe("a dubbed line that finishes early is a warning, not missing speech (24 Nov, 14:04 and 14:13 runs)", () => {
  // The dubbed line windows of those runs (translation_te.json, first five lines).
  const dubLines = [s(6.36, 11.71), s(12.82, 15.15), s(16.42, 19.42), s(19.47, 23.348), s(23.398, 24.143)];
  // Telugu says the whole first sentence by ~9.4 s; the English pauses and says "that we knew was right" at 10.26–11.28 s.
  const teEarly = [s(6.46, 9.36), s(12.88, 15.1), s(16.5, 19.3), s(19.68, 21.44), s(23.54, 24.1)];
  const speech = englishSpeech.filter((x) => x.startMs < 25000);
  const ext = dialogueExtents(dubLines);

  it("without line windows, the check is unchanged (still reported missing)", () => {
    expect(findMissingDubSpeech({ sourceSpeech: speech, dubSpeech: teEarly, extents: ext }).map((m) => m.startMs / 1000)).toEqual([10.26]);
  });
  it("with line windows, 10.3 s is an early finish inside a dubbed line, and nothing is missing", () => {
    const r = checkDubSpeech({ sourceSpeech: speech, dubSpeech: teEarly, extents: ext, lines: dubLines });
    expect(r.missing).toEqual([]);
    expect(r.earlyFinish.map((m) => m.startMs / 1000)).toEqual([10.26]);
    expect(syncViolations({ checked: true, missing: r.missing, earlyFinish: r.earlyFinish, genderMismatches: [] })).toEqual([]);
  });
  it("a line whose dub is absent is still missing (its own window has no dubbed speech)", () => {
    const dropped = teEarly.filter((x) => x.startMs !== 12880); // no Telugu for 12.82–15.15 s
    const r = checkDubSpeech({ sourceSpeech: speech, dubSpeech: dropped, extents: ext, lines: dubLines });
    expect(r.missing.map((m) => m.startMs / 1000)).toEqual([13.04]);
  });
  it("a long stretch with no dub is still missing, even inside a dubbed line", () => {
    const longSource = [s(6.48, 7.28), s(10.26, 13.4)]; // 3.1 s of English after the dub ends
    const line = [s(6.36, 13.6)];
    const r = checkDubSpeech({ sourceSpeech: longSource, dubSpeech: [s(6.46, 9.36)], extents: dialogueExtents(line), lines: line });
    expect(r.missing.map((m) => m.startMs / 1000)).toEqual([10.26]);
  });
  it("a line whose dub is much shorter than its original speech is still missing", () => {
    const source = [s(6.0, 8.4), s(9.0, 11.0)]; // 4.4 s of English
    const line = [s(6.0, 11.2)];
    const r = checkDubSpeech({ sourceSpeech: source, dubSpeech: [s(6.0, 7.2)], extents: dialogueExtents(line), lines: line }); // 1.2 s of dub < 40%
    expect(r.missing.map((m) => m.startMs / 1000)).toEqual([9]);
  });
});

describe("voice gender check", () => {
  const steady = (medianHz: number) => ({ medianHz, voicedFrames: 300, spreadSemitones: 2 });
  it("flags a reliably male original voiced by a clearly female dub, and the reverse", () => {
    expect(voiceGenderMismatch(steady(121), 215)).toBe(true);
    expect(voiceGenderMismatch(steady(220), 120)).toBe(true);
  });
  it("never flags a soft-spoken woman whose reading is unreliable (Peggy: 139 Hz, spread 5 st)", () => {
    expect(voiceGenderMismatch({ medianHz: 138.9, voicedFrames: 371, spreadSemitones: 4.98 }, 210)).toBe(false);
  });
  it("does not flag same-gender voices, the overlap band, or unmeasured voices", () => {
    expect(voiceGenderMismatch(steady(121), 118)).toBe(false);
    expect(voiceGenderMismatch(steady(150), 175)).toBe(false);
    expect(voiceGenderMismatch(null, 215)).toBe(false);
    expect(voiceGenderMismatch(steady(121), null)).toBe(false);
  });
});

describe("subtitle coverage", () => {
  const dubLines = Array.from({ length: 11 }, (_, i) => ({ startMs: 6000 + i * 4500, endMs: 9000 + i * 4500, text: "x" }));
  it("rejects the 24 Nov track: 2 cues for 11 lines", () => {
    const cues = [s(19.5, 24.1), s(56.0, 57.0)];
    expect(subtitleLineCoverage(cues, dubLines)).toBeLessThan(MIN_SUBTITLE_LINE_COVERAGE);
  });
  it("accepts a track that covers the lines", () => {
    expect(subtitleLineCoverage(dubLines.map((l) => ({ startMs: l.startMs, endMs: l.endMs })), dubLines)).toBe(1);
  });
});
