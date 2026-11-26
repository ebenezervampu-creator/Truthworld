import {
  countSourceSyllables,
  estimateSpeechDurationMs,
  syllableBudgetForDuration,
  permissibleWindowMs,
  syllablesPerSecond,
  TEMPO_HEADROOM,
} from "../../src/pipeline/services/speech-rate";

describe("Phase 3: unified speech-rate model & window function (Fix 3.1, 3.2, 3.6)", () => {
  test("Fix 3.1: pre-TTS estimator and editor budget agree across te, hi, ta, en, es, zh", () => {
    const sampleSyllablesByLang: Record<string, (n: number) => string> = {
      te: (n) => Array.from({ length: n }, () => "క").join(" "),
      hi: (n) => Array.from({ length: n }, () => "क").join(" "),
      ta: (n) => Array.from({ length: n }, () => "க").join(" "),
      en: (n) => Array.from({ length: n }, () => "ba").join(" "),
      es: (n) => Array.from({ length: n }, () => "ba").join(" "),
      zh: (n) => Array.from({ length: n }, () => "好").join(""),
    };

    const windowMs = 4000;
    for (const lang of ["te", "hi", "ta", "en", "es", "zh"]) {
      const budget = syllableBudgetForDuration(windowMs, lang);
      const text = sampleSyllablesByLang[lang](budget);
      expect(countSourceSyllables(text, lang)).toBe(budget);

      const estMs = estimateSpeechDurationMs(text, lang);
      // Budget = floor(seconds * rate * TEMPO_HEADROOM), so estMs ~ windowMs * TEMPO_HEADROOM
      const expectedMs = windowMs * TEMPO_HEADROOM;
      expect(estMs).toBeGreaterThanOrEqual(expectedMs * 0.90);
      expect(estMs).toBeLessThanOrEqual(expectedMs * 1.05);
    }
  });

  test("Fix 3.1: countSourceSyllables snapshot on 10 real lines is unchanged", () => {
    const cases: Array<[string, string, number]> = [
      ["The Lord delivered them in 40 days.", "en", 8],
      ["Why does it feel so wrong to lie to him?", "en", 10],
      ["Pharaoh heard the news.", "en", 5],
      ["ప్రభువు వారిని 40 రోజుల్లో విడిపించాడు.", "te", 14],
      ["వాడికి అబద్ధం చెప్పడం ఎందుకంత తప్పనిపిస్తోంది?", "te", 19],
      ["2024లో ధరలు 12% పెరిగాయి.", "te", 8],
      ["प्रभु ने उन्हें दासत्व से छुड़ाया।", "hi", 12],
      ["यहाँ कुछ नहीं बदला।", "hi", 9],
      ["ஆண்டவர் அவர்களை விடுவித்தார்.", "ta", 11],
      ["[whispers] Hello world.", "en", 3],
    ];
    for (const [text, lang, expected] of cases) {
      expect(countSourceSyllables(text, lang)).toBe(expected);
    }
  });

  test("Fix 3.2: permissibleWindowMs matches the legacy inline calculation on 50 consecutive segments", () => {
    const segs = Array.from({ length: 50 }, (_, i) => ({
      start: i * 3200,
      end: i * 3200 + 2100 + (i % 5) * 200,
    }));
    const totalVideoDurationMs = 165000;

    for (let i = 0; i < segs.length; i++) {
      const seg = segs[i];
      const segWindowMs = seg.end - seg.start;
      const isFinalSeg = i === segs.length - 1;
      const nextSeg = segs[i + 1];
      const nextStartMs = nextSeg ? nextSeg.start : null;

      const hardCeilingMs = isFinalSeg
        ? Math.max(seg.start + 200, totalVideoDurationMs - 150)
        : (nextStartMs !== null ? Math.max(seg.start + 200, nextStartMs - 120) : seg.start + segWindowMs + 1000);
      const rawGapMs = nextStartMs !== null ? nextStartMs - seg.end : 1000;
      const clampedTrailingGapMs = Math.max(0, rawGapMs);
      const permissibleBufferMs = Math.max(0, Math.min(clampedTrailingGapMs - 250, 1500));
      const maxPermissibleEndMs = Math.max(
        seg.start + segWindowMs,
        Math.min(seg.start + segWindowMs + permissibleBufferMs, hardCeilingMs)
      );
      const inlineResult = Math.max(200, Math.min(hardCeilingMs - seg.start, maxPermissibleEndMs - seg.start));

      const unifiedResult = permissibleWindowMs(seg.start, seg.end, nextStartMs, totalVideoDurationMs);
      expect(unifiedResult).toBe(inlineResult);
    }
  });

  test("Fix 3.6: shot change caps only the trailing buffer, never the line's own window", () => {
    // Line 0..2000, next line at 4000 -> without cuts, window = 3500
    expect(permissibleWindowMs(0, 2000, 4000, 10000)).toBe(3500);
    // Cut at 2500 (inside trailing buffer) -> maxEnd = 2500 - 80 = 2420
    expect(permissibleWindowMs(0, 2000, 4000, 10000, [2500])).toBe(2420);
    // Cut at 1200 (inside line's own 0..2000 window) -> does NOT shorten 2000ms line
    expect(permissibleWindowMs(0, 2000, 4000, 10000, [1200])).toBe(3500);
    // Empty cuts -> same as no cuts
    expect(permissibleWindowMs(0, 2000, 4000, 10000, [])).toBe(3500);
    // Measured rate overrides table rate
    expect(syllablesPerSecond("te", 3.8)).toBe(3.8);
  });
});
