import {
  CLONE_ALL,
  cloneAllSpeakersEnabled,
  cloneStrict,
  selectStrictCloneSample,
  unclonedSpeakers,
  cloneMaxSpeakers,
  cloneMinSeconds,
  planSpeakerClones,
  remainingCloneCapacity,
  selectCloneTurns,
} from "../../src/pipeline/services/speaker-clone-plan";

/** n lines of `len` seconds for one speaker, spaced so they never overlap. */
function lines(speaker: string, n: number, len: number, offset: number): Array<{ speaker: string; startSec: number; endSec: number }> {
  return Array.from({ length: n }, (_, i) => ({ speaker, startSec: offset + i * 1000, endSec: offset + i * 1000 + len }));
}

describe("speaker-clone-plan", () => {
  it("is off unless DUBBING_CLONE_ALL_SPEAKERS is true", () => {
    expect(cloneAllSpeakersEnabled({})).toBe(false);
    expect(cloneAllSpeakersEnabled({ DUBBING_CLONE_ALL_SPEAKERS: "false" })).toBe(false);
    expect(cloneAllSpeakersEnabled({ DUBBING_CLONE_ALL_SPEAKERS: "TRUE" })).toBe(true);
  });

  it("clamps the speaker limit to 1–10 and the minimum speech to at least 10 s", () => {
    expect(cloneMaxSpeakers({})).toBe(10);
    expect(cloneMaxSpeakers({ DUBBING_CLONE_MAX_SPEAKERS: "4" })).toBe(4);
    expect(cloneMaxSpeakers({ DUBBING_CLONE_MAX_SPEAKERS: "25" })).toBe(10);
    expect(cloneMaxSpeakers({ DUBBING_CLONE_MAX_SPEAKERS: "0" })).toBe(10);
    expect(cloneMinSeconds({})).toBe(10);
    expect(cloneMinSeconds({ DUBBING_CLONE_MIN_SECONDS: "3" })).toBe(10);
    expect(cloneMinSeconds({ DUBBING_CLONE_MIN_SECONDS: "30" })).toBe(30);
  });

  it("uses only the speaker's own lines that overlap nobody else", () => {
    const all = [
      { speaker: "A", startSec: 0, endSec: 6 },
      { speaker: "B", startSec: 5, endSec: 9 }, // overlaps A's first line
      { speaker: "A", startSec: 10, endSec: 14 },
      { speaker: "A", startSec: 20, endSec: 20.5 }, // shorter than 1 s
    ];
    const a = selectCloneTurns(all, "A");
    expect(a.turns).toEqual([{ startSec: 10, durationSec: 4 }]);
    expect(a.seconds).toBe(4);
  });

  it("caps the sample at the maximum, longest lines first, returned in time order", () => {
    const all = [
      { speaker: "A", startSec: 0, endSec: 50 },
      { speaker: "A", startSec: 100, endSec: 190 },
      { speaker: "A", startSec: 200, endSec: 210 },
    ];
    const a = selectCloneTurns(all, "A", 120);
    expect(a.seconds).toBe(120);
    expect(a.turns).toEqual([
      { startSec: 0, durationSec: 30 },
      { startSec: 100, durationSec: 90 },
    ]);
  });

  it("clones up to 10 speakers with enough speech, most speech first", () => {
    const all = Array.from({ length: 12 }, (_, i) => lines(`S${i}`, 3, 5 + i, i * 10_000)).flat();
    const ids = all.map((t) => t.speaker);
    const plan = planSpeakerClones(ids, all);
    expect(plan.clone).toHaveLength(CLONE_ALL.maxSpeakers);
    expect(plan.clone[0].speakerId).toBe("S11");
    expect(plan.skipped).toEqual([
      { speakerId: "S1", reason: "over_speaker_limit", seconds: 18 },
      { speakerId: "S0", reason: "over_speaker_limit", seconds: 15 },
    ]);
  });

  it("leaves speakers with too little clean speech on a matched voice", () => {
    const all = [...lines("A", 3, 5, 0), ...lines("B", 2, 4, 50_000)];
    const plan = planSpeakerClones(["A", "B"], all);
    expect(plan.clone.map((c) => c.speakerId)).toEqual(["A"]);
    expect(plan.skipped).toEqual([{ speakerId: "B", reason: "too_little_clean_speech", seconds: 8 }]);
  });

  it("stops at the plan's free capacity", () => {
    const all = [...lines("A", 3, 9, 0), ...lines("B", 3, 8, 50_000), ...lines("C", 3, 7, 90_000)];
    const plan = planSpeakerClones(["A", "B", "C"], all, { capacityLeft: 2 });
    expect(plan.clone.map((c) => c.speakerId)).toEqual(["A", "B"]);
    expect(plan.skipped).toEqual([{ speakerId: "C", reason: "plan_capacity", seconds: 21 }]);
  });

  it("reads free capacity as the smaller of free slots and monthly operations left", () => {
    expect(remainingCloneCapacity(null)).toBeNull();
    expect(remainingCloneCapacity({ canClone: false, reason: "slots_full" })).toBe(0);
    expect(remainingCloneCapacity({ canClone: true, slotsUsed: 3, slotLimit: 10, editsUsed: 60, editLimit: 65 })).toBe(5);
    expect(remainingCloneCapacity({ canClone: true, slotsUsed: 8, slotLimit: 10, editLimit: null })).toBe(2);
    expect(remainingCloneCapacity({ canClone: true })).toBeNull();
  });

  describe("strict mode (every speaker cloned)", () => {
    it("is off unless DUBBING_CLONE_STRICT is true", () => {
      expect(cloneStrict({})).toBe(false);
      expect(cloneStrict({ DUBBING_CLONE_STRICT: "true" })).toBe(true);
    });

    it("uses clean lines when they reach 10 s", () => {
      const got = selectStrictCloneSample(lines("A", 3, 5, 0), "A");
      expect(got?.sample).toBe("clean");
      expect(got?.seconds).toBe(15);
    });

    it("adds short clean lines, then overlapping lines, before looping", () => {
      const short = [...lines("A", 2, 4, 0), ...Array.from({ length: 6 }, (_, i) => ({ speaker: "A", startSec: 5000 + i * 10, endSec: 5000 + i * 10 + 0.5 }))];
      expect(selectStrictCloneSample(short, "A")?.sample).toBe("short_lines");

      const overlapped = [
        ...lines("A", 2, 4, 0),
        { speaker: "A", startSec: 9000, endSec: 9004 },
        { speaker: "B", startSec: 9003, endSec: 9010 },
      ];
      const got = selectStrictCloneSample(overlapped, "A");
      expect(got?.sample).toBe("with_overlap");
      expect(got?.seconds).toBe(12);
    });

    it("loops a short speaker's speech up to 10 s, and gives up under 1 s", () => {
      const got = selectStrictCloneSample([{ speaker: "R", startSec: 44, endSec: 47 }], "R");
      expect(got?.sample).toBe("looped");
      expect(got?.turns).toHaveLength(4);
      expect(got?.seconds).toBe(12);
      expect(selectStrictCloneSample([{ speaker: "R", startSec: 44, endSec: 44.6 }], "R")).toBeNull();
    });

    it("plans every speaker, including one with a single 3 s line", () => {
      const all = [...lines("A", 3, 6, 0), ...lines("B", 3, 5, 50_000), { speaker: "R", startSec: 90_000, endSec: 90_003 }];
      const plan = planSpeakerClones(["A", "B", "R"], all, { strict: true });
      expect(plan.skipped).toEqual([]);
      expect(plan.clone.find((c) => c.speakerId === "R")?.sample).toBe("looped");
    });

    it("reports a speaker with no usable speech", () => {
      const all = [...lines("A", 3, 6, 0), { speaker: "X", startSec: 90_000, endSec: 90_000.5 }];
      const plan = planSpeakerClones(["A", "X"], all, { strict: true });
      expect(plan.skipped).toEqual([{ speakerId: "X", reason: "no_usable_speech", seconds: 0.5 }]);
    });

    it("finds speakers whose voice is not one of the job's clones", () => {
      expect(unclonedSpeakers(["A", "B", "C"], { A: "c1", B: "lib9", C: "c2" }, ["c1", "c2"])).toEqual(["B"]);
      expect(unclonedSpeakers(["A"], {}, ["c1"])).toEqual(["A"]);
    });
  });
});

describe("describeElevenLabsError", () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { describeElevenLabsError } = require("../../src/pipeline/services/tts");
  it("keeps ElevenLabs' status and message from a JSON, text or binary body", () => {
    expect(describeElevenLabsError({ response: { status: 403, data: { detail: { status: "voice_not_allowed", message: "This voice cannot be cloned." } } } }))
      .toBe("HTTP 403 voice_not_allowed: This voice cannot be cloned.");
    expect(describeElevenLabsError({ response: { status: 401, data: Buffer.from(JSON.stringify({ detail: { status: "missing_permissions", message: "needs user_read" } })) } }))
      .toBe("HTTP 401 missing_permissions: needs user_read");
    expect(describeElevenLabsError({ response: { status: 500, data: "oops" } })).toBe("HTTP 500: oops");
    expect(describeElevenLabsError({ message: "timeout of 60000ms exceeded" })).toBe("no response: timeout of 60000ms exceeded");
  });
});
