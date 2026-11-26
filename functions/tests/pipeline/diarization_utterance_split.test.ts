/**
 * Corrected speaker labels must reach speaker profiling, which reads transcript utterances.
 *
 * Regression case: Joseph dreams clip (2026-11-20), 25.4 s, production payload
 * speaker_options { max_speakers_expected: 12 }. AssemblyAI returned 2 speakers and one
 * 4.78–25.38 s utterance for Pharaoh, the Cupbearer and the Guard. reconcileDiarization split the
 * segments into B_3 / B_2 / B, but relabelByOverlap gave the whole utterance one label ("B"), so
 * B_2 and B_3 got no profile and no matched voice.
 */
import { relabelByOverlap, splitUtterancesBySegments } from "../../src/pipeline/services/diarization-reconcile";

const w = (text: string, start: number, end: number) => ({ text, start, end, speaker: "B" });

const wiseMen = {
  start: 340,
  end: 2510,
  speaker: "A",
  confidence: 0.95,
  text: "but we cannot interpret your dreams.",
  words: [{ text: "but", start: 340, end: 600, speaker: "A" }, { text: "dreams.", start: 2100, end: 2510, speaker: "A" }],
};

const mergedB = {
  start: 4780,
  end: 25379,
  speaker: "B",
  confidence: 0.91,
  text: "Is there no one here who can interpret my dreams? Don't worry, Joseph. I will remember you and speak to Pharaoh. I forgot about Joseph. God didn't protect you. Forsake him for letting you suffer.",
  words: [
    w("Is", 4780, 5000), w("dreams?", 7800, 8140),                 // Pharaoh
    w("Don't", 11620, 11900), w("Joseph.", 12400, 12780),          // Cupbearer
    w("I", 12840, 12950), w("Pharaoh.", 14300, 14800),
    w("I", 14800, 14900), w("Joseph.", 16100, 16560),
    w("God", 18340, 18600), w("you.", 19800, 20100),               // Guard
    w("Forsake", 22000, 22500), w("suffer.", 24900, 25379),
  ],
};

// Dubbing segments after reconcileDiarization (C2 Pharaoh → B_3, C3 Cupbearer → B_2, C4 Guard → B).
const segments = [
  { start: 340, end: 2510, speaker: "A", text: "but we cannot interpret your dreams." },
  { start: 4780, end: 8140, speaker: "B_3", text: "Is there no one here who can interpret my dreams?" },
  { start: 11620, end: 12780, speaker: "B_2", text: "Don't worry, Joseph." },
  { start: 12840, end: 14800, speaker: "B_2", text: "I will remember you and speak to Pharaoh." },
  { start: 14800, end: 16560, speaker: "B_2", text: "I forgot about Joseph." },
  { start: 18340, end: 20100, speaker: "B", text: "God didn't protect you." },
  { start: 22000, end: 25379, speaker: "B", text: "Forsake him for letting you suffer." },
];

describe("splitUtterancesBySegments", () => {
  test("old behaviour (documents the bug): one merged utterance keeps one label", () => {
    const speakers = new Set(relabelByOverlap([wiseMen, mergedB], segments).map((u) => u.speaker));
    expect([...speakers].sort()).toEqual(["A", "B"]);
  });

  test("Joseph clip: a merged utterance is split so every corrected label has its own utterance", () => {
    const out = splitUtterancesBySegments([wiseMen, mergedB], segments);
    expect(out.map((u) => u.speaker)).toEqual(["A", "B_3", "B_2", "B"]);
    expect(new Set(out.map((u) => u.speaker)).size).toBe(4);

    const [, pharaoh, cupbearer, guard] = out;
    expect([pharaoh.start, pharaoh.end]).toEqual([4780, 8140]);
    expect([cupbearer.start, cupbearer.end]).toEqual([11620, 16560]);
    expect([guard.start, guard.end]).toEqual([18340, 25379]);

    // Words go to the part they were spoken in, and text is rebuilt from them.
    expect(pharaoh.words!.map((x) => x.text)).toEqual(["Is", "dreams?"]);
    expect(cupbearer.words!.map((x) => x.text)).toEqual(["Don't", "Joseph.", "I", "Pharaoh.", "I", "Joseph."]);
    expect(guard.text).toBe("God you. Forsake suffer.");
    expect(cupbearer.words!.every((x) => x.speaker === "B_2")).toBe(true);
    // Other utterance fields are kept.
    expect(guard.confidence).toBe(0.91);
  });

  test("an utterance covered by one label behaves exactly like relabelByOverlap", () => {
    const utterances = [
      { start: 2180, end: 8730, speaker: "A", text: "guard" },
      { start: 12980, end: 15150, speaker: "A", text: "joseph" },
      { start: 40000, end: 41000, speaker: "A", text: "no segment" },
    ];
    const segs = [
      { start: 2180, end: 8730, speaker: "A" },
      { start: 12980, end: 15150, speaker: "B" },
    ];
    expect(splitUtterancesBySegments(utterances, segs)).toEqual(relabelByOverlap(utterances, segs));
  });

  test("without word timings, parts use the segments' times and text", () => {
    const { words: _ignored, ...noWords } = mergedB;
    const out = splitUtterancesBySegments([noWords], segments);
    expect(out.map((u) => u.speaker)).toEqual(["B_3", "B_2", "B"]);
    expect(out[1].text).toBe("Don't worry, Joseph. I will remember you and speak to Pharaoh. I forgot about Joseph.");
    expect([out[2].start, out[2].end]).toEqual([18340, 25379]);
  });

  test("words outside every segment join the nearest part; no words are lost", () => {
    const u = { start: 0, end: 10000, speaker: "B", text: "x", words: [w("a", 100, 200), w("b", 4000, 4200), w("c", 9800, 9900)] };
    const segs = [{ start: 3000, end: 5000, speaker: "B" }, { start: 6000, end: 9000, speaker: "B_2" }];
    const out = splitUtterancesBySegments([u], segs);
    expect(out.map((p) => [p.speaker, p.words!.map((x) => x.text).join("")])).toEqual([["B", "ab"], ["B_2", "c"]]);
  });

  test("output stays in time order across utterances", () => {
    const out = splitUtterancesBySegments([mergedB, wiseMen], segments);
    const starts = out.map((u) => u.start);
    expect(starts).toEqual([...starts].sort((a, b) => a - b));
  });
});
