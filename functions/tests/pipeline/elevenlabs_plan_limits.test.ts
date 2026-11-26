/**
 * ElevenLabs Starter plan safety: concurrency default and voice-clone capacity check.
 */
import { DEFAULT_MAX_ELEVENLABS_CONCURRENCY, readMaxElevenLabsConcurrency } from "../../src/pipeline/services/elevenlabs-plan";
import { cloneUnavailableMessage, evaluateCloneCapacity } from "../../src/pipeline/services/voice-capacity";

describe("ElevenLabs concurrency default", () => {
  const original = process.env.ELEVENLABS_MAX_CONCURRENCY;
  afterEach(() => {
    if (original === undefined) delete process.env.ELEVENLABS_MAX_CONCURRENCY;
    else process.env.ELEVENLABS_MAX_CONCURRENCY = original;
  });

  test("defaults to the Starter plan limit (3)", () => {
    delete process.env.ELEVENLABS_MAX_CONCURRENCY;
    expect(DEFAULT_MAX_ELEVENLABS_CONCURRENCY).toBe(3);
    expect(readMaxElevenLabsConcurrency()).toBe(3);
  });

  test("the env var raises it after an upgrade, without a code change", () => {
    process.env.ELEVENLABS_MAX_CONCURRENCY = "5";
    expect(readMaxElevenLabsConcurrency()).toBe(5);
  });

  test("garbage or zero falls back to the default instead of NaN / unlimited", () => {
    for (const bad of ["", "abc", "0", "-2"]) {
      process.env.ELEVENLABS_MAX_CONCURRENCY = bad;
      expect(readMaxElevenLabsConcurrency()).toBe(3);
    }
  });
});

describe("voice clone capacity", () => {
  const starter = { voice_limit: 10, max_voice_add_edits: 65, can_use_instant_voice_cloning: true };

  test("room left → can clone", () => {
    expect(evaluateCloneCapacity({ ...starter, voice_slots_used: 4, voice_add_edit_counter: 12 })).toMatchObject({ canClone: true });
  });

  test("all 10 Starter slots used → blocked with slots_full", () => {
    expect(evaluateCloneCapacity({ ...starter, voice_slots_used: 10, voice_add_edit_counter: 12 })).toMatchObject({ canClone: false, reason: "slots_full" });
  });

  test("65 monthly operations used → blocked until reset", () => {
    expect(evaluateCloneCapacity({ ...starter, voice_slots_used: 3, voice_add_edit_counter: 65 })).toMatchObject({
      canClone: false,
      reason: "monthly_voice_edits_used",
    });
  });

  test("unlimited operations (null) are not treated as a limit", () => {
    expect(evaluateCloneCapacity({ ...starter, max_voice_add_edits: null, voice_slots_used: 1, voice_add_edit_counter: 9999 }).canClone).toBe(true);
  });

  test("plan without instant cloning → blocked", () => {
    expect(evaluateCloneCapacity({ can_use_instant_voice_cloning: false }).reason).toBe("cloning_not_on_plan");
  });

  test("missing fields never block (the clone attempt decides)", () => {
    expect(evaluateCloneCapacity({}).canClone).toBe(true);
    expect(evaluateCloneCapacity(null).canClone).toBe(true);
  });

  test("creator messages are friendly and contain no technical detail", () => {
    for (const r of ["slots_full", "monthly_voice_edits_used", "cloning_not_on_plan", "clone_failed"] as const) {
      const m = cloneUnavailableMessage(r);
      expect(m).toMatch(/studio voice/);
      expect(m).not.toMatch(/error|elevenlabs|slot|api|429|quota/i);
    }
  });
});
