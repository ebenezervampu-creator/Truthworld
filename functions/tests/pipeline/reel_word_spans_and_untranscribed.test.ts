import { encodeWordSpans, decodeWordSpans, MAX_META_WORDS } from "../../src/pipeline/services/reel-word-spans";
import { checkDubSpeech, dialogueExtents } from "../../src/pipeline/services/dub-sync-check";

describe("reel word spans (reel_orchestration/meta.wordSpans)", () => {
  it("encodes words as flat integer pairs and decodes them back", () => {
    const enc = encodeWordSpans([{ start: 22980.4, end: 23400 }, { start: 24024, end: 24500 }]);
    expect(enc).toEqual([22980, 23400, 24024, 24500]);
    expect(decodeWordSpans({ wordSpans: enc })).toEqual([{ start: 22980, end: 23400 }, { start: 24024, end: 24500 }]);
  });
  it("skips broken words, handles absence, caps the count", () => {
    expect(encodeWordSpans([{ start: 5, end: 5 }, { start: NaN, end: 9 }, {}])).toEqual([]);
    expect(encodeWordSpans(undefined)).toEqual([]);
    const many = Array.from({ length: MAX_META_WORDS + 10 }, (_, i) => ({ start: i * 10, end: i * 10 + 5 }));
    expect(encodeWordSpans(many).length).toBe(MAX_META_WORDS * 2);
  });
  it("falls back to an older words list, else nothing", () => {
    expect(decodeWordSpans({ words: [{ start: 1, end: 2 }] })).toEqual([{ start: 1, end: 2 }]);
    expect(decodeWordSpans({})).toEqual([]);
    expect(decodeWordSpans(null)).toEqual([]);
  });
});

// 25 Nov film run …2722813: AssemblyAI line 10.11–27.07 s whose first word is at 22.98 s; the voice
// track had 0.76 s of sound at 10.64–11.40 s with no word → it blocked the whole 12-minute film.
describe("dub speech check with word timings", () => {
  // Line 1 is long with little dubbed speech (as in the film run, so the early-finish rule does not
  // apply); line 2 is a separate transcribed line.
  const lines = [{ startMs: 10110, endMs: 27070 }, { startMs: 30000, endMs: 32000 }];
  const extents = dialogueExtents(lines);
  const words = [{ startMs: 22980, endMs: 23500 }, { startMs: 24024, endMs: 26500 }, { startMs: 30100, endMs: 31900 }];
  const source = [{ startMs: 10640, endMs: 11400 }, { startMs: 22980, endMs: 26500 }, { startMs: 30100, endMs: 31900 }];

  it("voice with no transcribed word is a warning (untranscribed), not missing", () => {
    const r = checkDubSpeech({
      sourceSpeech: source,
      dubSpeech: [{ startMs: 23000, endMs: 23400 }, { startMs: 30100, endMs: 32200 }],
      extents,
      lines,
      words,
    });
    expect(r.missing).toEqual([]);
    expect(r.untranscribed).toEqual([{ startMs: 10640, endMs: 11400 }]);
  });

  it("a transcribed line with no dub is still missing (a dropped line keeps blocking)", () => {
    const r = checkDubSpeech({
      sourceSpeech: source,
      dubSpeech: [{ startMs: 23000, endMs: 23400 }], // line 2 never dubbed
      extents,
      lines,
      words,
    });
    expect(r.missing).toEqual([{ startMs: 30100, endMs: 31900 }]);
    expect(r.untranscribed).toEqual([{ startMs: 10640, endMs: 11400 }]);
  });

  it("without word timings the film-run case blocks as before", () => {
    const r = checkDubSpeech({
      sourceSpeech: source,
      dubSpeech: [{ startMs: 23000, endMs: 23400 }, { startMs: 30100, endMs: 32200 }],
      extents,
      lines,
    });
    expect(r.missing).toEqual([{ startMs: 10640, endMs: 11400 }]);
    expect(r.untranscribed).toEqual([]);
  });
});
