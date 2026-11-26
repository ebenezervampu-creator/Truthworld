import { decideSpeakerGender, isReliablePitch } from "../../src/pipeline/services/voice-matcher";
import { selectPitchTurns, PITCH_MAX_TOTAL_SECONDS, selectProfilingTurns } from "../../src/pipeline/services/speaker-turn-sampler";
import {
  activeRmsDb,
  buildGainSpans,
  dubVoiceLiftDb,
  LINE_LEVEL,
  planLineGainsDb,
  sortedLines,
} from "../../src/pipeline/services/faithful-mix";

describe("speaker gender decision", () => {
  // Measured in the 24 Nov 11:05 Telugu run (all turns, up to 30 s).
  const steve = { medianPitchHz: 120.8, voicedFrames: 201, spreadSemitones: 2.43 };
  const peggy = { medianPitchHz: 138.9, voicedFrames: 371, spreadSemitones: 4.98 };
  it("a reliable male reading overrides Gemini saying female (run 1: Steve cast as a woman)", () => {
    expect(decideSpeakerGender({ ...steve, geminiGender: "female", geminiAge: 38 })).toEqual({ gender: "male", basis: "pitch" });
  });
  it("an unreliable reading does not override Gemini (run 2: Peggy cast as a man)", () => {
    expect(decideSpeakerGender({ ...peggy, geminiGender: "female", geminiAge: 42 })).toEqual({ gender: "female", basis: "gemini" });
    expect(isReliablePitch(peggy.voicedFrames, peggy.spreadSemitones)).toBe(false);
    expect(isReliablePitch(steve.voicedFrames, steve.spreadSemitones)).toBe(true);
  });
  it("too few voiced frames is unreliable", () => {
    expect(decideSpeakerGender({ medianPitchHz: 118, voicedFrames: 40, spreadSemitones: 1.5, geminiGender: "female" }).basis).toBe("gemini");
  });
  it("a reliable female reading overrides Gemini saying male", () => {
    expect(decideSpeakerGender({ medianPitchHz: 215, voicedFrames: 300, spreadSemitones: 2.5, geminiGender: "male", geminiAge: 30 })).toEqual({ gender: "female", basis: "pitch" });
  });
  it("Gemini decides in the overlap band even when the reading is reliable", () => {
    expect(decideSpeakerGender({ medianPitchHz: 160, voicedFrames: 300, spreadSemitones: 2, geminiGender: "female" })).toEqual({ gender: "female", basis: "gemini" });
    expect(decideSpeakerGender({ medianPitchHz: 160, voicedFrames: 300, spreadSemitones: 2, geminiGender: "male" })).toEqual({ gender: "male", basis: "gemini" });
  });
  it("Gemini decides when pitch is unknown", () => {
    expect(decideSpeakerGender({ medianPitchHz: 0, geminiGender: "female" })).toEqual({ gender: "female", basis: "gemini" });
  });
  it("a child's high voice is not forced to female", () => {
    expect(decideSpeakerGender({ medianPitchHz: 260, voicedFrames: 300, spreadSemitones: 2, geminiGender: "male", geminiAge: 9 })).toEqual({ gender: "male", basis: "gemini" });
  });
  it("without Gemini, any reading is split at splitHz; nothing at all → male", () => {
    expect(decideSpeakerGender({ medianPitchHz: 170 })).toEqual({ gender: "female", basis: "pitch_split" });
    expect(decideSpeakerGender({ medianPitchHz: 150 })).toEqual({ gender: "male", basis: "pitch_split" });
    expect(decideSpeakerGender({ medianPitchHz: 0 })).toEqual({ gender: "male", basis: "default_male" });
  });
  it("a requested gender always wins", () => {
    expect(decideSpeakerGender({ preferredGender: "female", ...steve, geminiGender: "male" })).toEqual({ gender: "female", basis: "requested" });
    expect(decideSpeakerGender({ preferredGender: "auto", ...steve, geminiGender: "female" }).gender).toBe("male");
  });
});

describe("pitch clip covers all of a speaker's turns", () => {
  const turns = [
    // A's longest turns are breathy; the shorter ones carry the pitch.
    { speaker: "A", startSec: 6.26, endSec: 10.07 },
    { speaker: "A", startSec: 10.12, endSec: 13.92 },
    { speaker: "A", startSec: 19.47, endSec: 21.0 },
    { speaker: "A", startSec: 23.4, endSec: 24.14 },
    { speaker: "B", startSec: 14.0, endSec: 19.3 },
  ];
  it("takes every turn, not just the 3 longest", () => {
    const pitch = selectPitchTurns(turns, "A");
    expect(pitch.map((t) => t.startSec)).toEqual([6.26, 10.12, 19.47, 23.4]);
    expect(selectProfilingTurns(turns, "A").length).toBeLessThanOrEqual(3);
  });
  it("caps the total at 30 s and prefers clean turns", () => {
    const many = Array.from({ length: 20 }, (_, i) => ({ speaker: "A", startSec: i * 10, endSec: i * 10 + 6 }));
    many.push({ speaker: "B", startSec: 2, endSec: 3 });
    const pitch = selectPitchTurns(many, "A");
    const total = pitch.reduce((s, t) => s + t.durationSec, 0);
    expect(total).toBeLessThanOrEqual(PITCH_MAX_TOTAL_SECONDS + 1e-9);
    expect(pitch.some((t) => t.startSec === 0)).toBe(false); // overlaps B
  });
  it("no turns → nothing", () => {
    expect(selectPitchTurns(turns, "C")).toEqual([]);
  });
});

describe("line-by-line dubbed voice level", () => {
  const lines = [
    { speaker: "A", startMs: 1000, endMs: 3000 },
    { speaker: "A", startMs: 4000, endMs: 6000 },
    { speaker: "B", startMs: 7000, endMs: 9000 },
  ];
  it("a soft dubbed line is raised to its English line, beyond the speaker's average", () => {
    // Speaker A gain −8 dB on average, but line 2 came out 5 dB softer than line 1.
    const dubDb = [-20, -25, -20];
    const origDb = [-28, -28, -25];
    const gains = planLineGainsDb({
      lines,
      totalMs: 10000,
      speakerGainDb: { A: -8, B: -5 },
      originalLineDb: (l) => origDb[sortedLines(lines).indexOf(l)],
      dubLineDb: (e) => dubDb[buildGainSpans(lines, {}, 10000).findIndex((x) => x.startMs === e.startMs)],
    });
    expect(gains).toEqual([-8, -3, -5]);
  });
  it("correction stays within ±maxDeviationDb of the speaker's gain, and the lift is added", () => {
    const gains = planLineGainsDb({
      lines,
      totalMs: 10000,
      speakerGainDb: { A: 0, B: 0 },
      liftDb: 2,
      originalLineDb: () => -10,
      dubLineDb: () => -40,
    });
    expect(gains).toEqual([LINE_LEVEL.maxDeviationDb + 2, LINE_LEVEL.maxDeviationDb + 2, LINE_LEVEL.maxDeviationDb + 2]);
  });
  it("an unmeasurable line keeps the speaker's gain (plus lift)", () => {
    const gains = planLineGainsDb({ lines, totalMs: 10000, speakerGainDb: { A: -4 }, liftDb: 2, originalLineDb: () => null, dubLineDb: () => -20 });
    expect(gains).toEqual([-2, -2, 2]);
  });
  it("buildGainSpans uses per-line gains when given", () => {
    const spans = buildGainSpans(lines, { A: 0, B: 0 }, 10000, [6, null, -6]);
    expect(spans.map((s) => Number((20 * Math.log10(s.gain)).toFixed(2)))).toEqual([6, 0, -6]);
  });
  it("activeRmsDb measures only where speech is active", () => {
    const rate = 1000;
    const pcm = new Float32Array(3000);
    for (let i = 1000; i < 1500; i++) pcm[i] = 0.1; // 500 ms of speech, rest silence
    const db = activeRmsDb(pcm, rate, { startMs: 0, endMs: 3000 }, [{ startMs: 1000, endMs: 1500 }]);
    expect(db).toBeCloseTo(-20, 1);
    expect(activeRmsDb(pcm, rate, { startMs: 0, endMs: 3000 }, [{ startMs: 1000, endMs: 1100 }])).toBeNull();
  });
  it("lift defaults to 2 dB and is bounded 0–6", () => {
    expect(dubVoiceLiftDb({})).toBe(2);
    expect(dubVoiceLiftDb({ DUBBING_VOICE_LIFT_DB: "0" })).toBe(0);
    expect(dubVoiceLiftDb({ DUBBING_VOICE_LIFT_DB: "20" })).toBe(6);
    expect(dubVoiceLiftDb({ DUBBING_VOICE_LIFT_DB: "x" })).toBe(2);
  });
});

import { attachWordsToUtterances, chunkTimesFromWords, collectWordTimings, hasUtteranceWordTimings } from "../../src/pipeline/services/segment-timing";

describe("dubbed line timing follows the words (24 Nov Telugu drift)", () => {
  // The 60 s test's last utterance: "Are you Steve Rogers?" spoken at ~44.4 s, then a long pause,
  // then "Years ago, we did what was needed." at ~54 s. Character share put both 7–9 s early.
  const w = (text: string, start: number, end: number) => ({ text, start, end, confidence: 0.9 });
  const words = [
    w("Are", 44420, 44600), w("you", 44600, 44750), w("Steve", 44750, 45100), w("Rogers?", 45100, 45520),
    w("Years", 53980, 54300), w("ago,", 54300, 54600), w("we", 56300, 56400), w("did", 56400, 56600),
    w("what", 56600, 56800), w("was", 56800, 57000), w("needed.", 57000, 57420),
  ];
  it("each sentence starts where its first word is spoken", () => {
    const spans = chunkTimesFromWords(["Are you Steve Rogers?", "Years ago,", "we did what was needed."], words);
    expect(spans).toEqual([
      { start: 44420, end: 45520 },
      { start: 53980, end: 54600 },
      { start: 56300, end: 57420 },
    ]);
  });
  it("falls back (null) when words don't match the text", () => {
    expect(chunkTimesFromWords(["Are you Steve Rogers?", "Years ago, we did what was needed."], words.slice(0, 3))).toBeNull();
    expect(chunkTimesFromWords(["a b"], [])).toBeNull();
  });
  it("attaches words to the utterance containing them, keeping existing words", () => {
    const utts = [
      { start: 37610, end: 45520, text: "Are you Steve Rogers?" },
      { start: 53980, end: 57420, text: "Years ago, we did what was needed." },
      { start: 1000, end: 2000, text: "x", words: [w("x", 1000, 2000)] },
    ];
    const out = attachWordsToUtterances(utts, words) as any[];
    expect(out[0].timingWords.map((x: any) => x.text)).toEqual(["Are", "you", "Steve", "Rogers?"]);
    expect(out[1].timingWords.length).toBe(7);
    expect(out[2].words.map((x: any) => x.text)).toEqual(["x"]);
    // `words` stays as it was, so subtitles get the same input as before (24 Nov regression).
    expect(out[0].words).toBeUndefined();
    expect(out[1].words).toBeUndefined();
    expect(hasUtteranceWordTimings(out)).toBe(true);
    expect(hasUtteranceWordTimings(utts)).toBe(true);
    expect(hasUtteranceWordTimings([{ words: [] }])).toBe(false);
  });
  // The opening utterance of the 60 s test: three sentences, the first two partly breathy.
  const opening = [
    w("We", 6480, 6600), w("made", 6600, 6800), w("a", 6800, 6850), w("choice", 6850, 7300), w("that", 7400, 7600),
    w("we", 7600, 7700), w("knew", 7700, 8000), w("was", 8000, 8200), w("right.", 8200, 8900),
    w("Why", 10240, 10400), w("does", 10400, 10550), w("it", 10550, 10600), w("feel", 10600, 10900), w("so", 10900, 11000),
    w("wrong", 11000, 11300), w("to", 11300, 11400), w("lie", 11400, 11800), w("to", 11800, 11900), w("him?", 11900, 12500),
    w("How's", 13040, 13300), w("he", 13300, 13400), w("ever", 13400, 13700), w("gonna", 13700, 14000), w("know", 14000, 14420),
    w("who", 16640, 16800), w("we", 16800, 16900), w("are", 16900, 17100), w("unless", 17100, 17600), w("we", 17600, 17700),
    w("tell", 17700, 18000), w("him?", 18000, 18880),
  ];
  const sentences = ["We made a choice that we knew was right.", "Why does it feel so wrong to lie to him?", "How's he ever gonna know who we are unless we tell him?"];
  it("sentences start on their own first word", () => {
    expect(chunkTimesFromWords(sentences, opening)!.map((x) => x.start)).toEqual([6480, 10240, 13040]);
  });
  it("a word missing from the word list does not shift later sentences", () => {
    const missing = opening.filter((x) => x.text !== "a" && x.text !== "that");
    expect(chunkTimesFromWords(sentences, missing)!.map((x) => x.start)).toEqual([6480, 10240, 13040]);
  });
  it("an extra filler word in the word list does not shift later sentences", () => {
    const extra = [...opening.slice(0, 5), w("uh", 7350, 7400), ...opening.slice(5)];
    expect(chunkTimesFromWords(sentences, extra)!.map((x) => x.start)).toEqual([6480, 10240, 13040]);
  });
  it("first chunk starts at the first word even if a later word matches its opening token", () => {
    const skewed = [
      w("We've", 10640, 11420), w("got", 11420, 11600),
      w("We", 22980, 23200), w("have", 23200, 23400), w("main", 23400, 23600), w("engine", 23600, 23800), w("start.", 23800, 24000),
      w("4,", 24024, 24300), w("3,", 24535, 24700), w("2,", 24816, 25100), w("1.", 25373, 25700),
    ];
    const spans = chunkTimesFromWords(["We have main engine start.", "4,", "3,", "2,", "1."], skewed);
    expect(spans![0].start).toBe(10640);
  });
  it("collects words from top-level words or from segments", () => {
    expect(collectWordTimings({ words }).length).toBe(11);
    expect(collectWordTimings({ segments: [{ words: words.slice(4) }, { words: words.slice(0, 4) }] })[0].text).toBe("Are");
    expect(collectWordTimings({ utterances: [{ text: "x" }] })).toEqual([]);
  });
});
