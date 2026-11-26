/**
 * Early start instead of trim (segment-preroll.ts, DUBBING_PREROLL).
 * Case from the te test (dub-test-te-1795516992008): segment 7 overflowed its turn by 640 ms and was
 * trimmed by 510 ms at 00:37, clipping the last word.
 */
import { planPreroll, prerollEnabled, PREROLL } from "../../src/pipeline/services/segment-preroll";

describe("planPreroll", () => {
  test("a line that fits is untouched", () => {
    expect(planPreroll({ startMs: 10000, durationMs: 2000, ceilingMs: 12500, prevEndMs: 9000 })).toEqual({
      startMs: 10000,
      shiftMs: 0,
      trimToMs: null,
    });
  });

  test("overflow smaller than the silence before it: starts earlier, nothing trimmed", () => {
    // 200 ms too long, previous line ended 1 s before → start 200 ms early.
    const p = planPreroll({ startMs: 32660, durationMs: 2000, ceilingMs: 34460, prevEndMs: 31000 });
    expect(p.shiftMs).toBe(200);
    expect(p.startMs).toBe(32460);
    expect(p.trimToMs).toBeNull();
  });

  test("shift is capped at maxPrerollMs; the rest is trimmed", () => {
    // 640 ms too long with plenty of silence: 300 ms early start, 340 ms still trimmed.
    const p = planPreroll({ startMs: 32660, durationMs: 2420, ceilingMs: 34440, prevEndMs: 30000 });
    expect(p.shiftMs).toBe(PREROLL.maxPrerollMs);
    expect(p.startMs).toBe(32360);
    expect(p.trimToMs).toBe(34440 - 32360);
  });

  test("never starts before the previous dubbed line ends + separation", () => {
    // Previous line ends 200 ms before this start → only 80 ms of room (200 − 120 separation).
    const p = planPreroll({ startMs: 20000, durationMs: 1500, ceilingMs: 21000, prevEndMs: 19800 });
    expect(p.shiftMs).toBe(80);
    expect(p.startMs).toBe(19920);
    expect(p.startMs).toBeGreaterThanOrEqual(19800 + PREROLL.separationMs);
    expect(p.trimToMs).toBe(21000 - 19920);
  });

  test("no room before the line: behaves like the old trim", () => {
    const p = planPreroll({ startMs: 20000, durationMs: 1500, ceilingMs: 21000, prevEndMs: 19950 });
    expect(p.shiftMs).toBe(0);
    expect(p.trimToMs).toBe(1000);
  });

  test("first line can use the silence from the start of the clip", () => {
    const p = planPreroll({ startMs: 150, durationMs: 1200, ceilingMs: 1200, prevEndMs: null });
    expect(p.shiftMs).toBe(150);
    expect(p.startMs).toBe(0);
  });

  test("overflow within 20 ms tolerance is left alone", () => {
    expect(planPreroll({ startMs: 0, durationMs: 1015, ceilingMs: 1000, prevEndMs: null }).shiftMs).toBe(0);
  });

  test("flag is off unless DUBBING_PREROLL=true", () => {
    expect(prerollEnabled({})).toBe(false);
    expect(prerollEnabled({ DUBBING_PREROLL: "true" })).toBe(true);
    expect(prerollEnabled({ DUBBING_PREROLL: "1" })).toBe(false);
  });
});
