import {
  estimateOrderRequirements,
  evaluateOrderCapacity,
  orderCapacityUnavailableMessage,
  readPlanLimitOverrides,
} from "../../src/pipeline/services/voice-capacity";
import { checkOrderCapacityAndAlert } from "../../src/pipeline/services/elevenlabs-capacity-guard";

describe("ElevenLabs capacity guard (pre-order)", () => {
  const savedEnv = { ...process.env };
  afterEach(() => {
    process.env = { ...savedEnv };
  });

  test("plan limits are configurable by env without hard-coded plan names", () => {
    process.env.ELEVENLABS_PLAN_CHAR_LIMIT = "200000";
    process.env.ELEVENLABS_PLAN_VOICE_SLOTS = "50";
    process.env.ELEVENLABS_PLAN_VOICE_OPS = "120";
    process.env.ELEVENLABS_CAPACITY_CHAR_BUFFER = "1000";

    const overrides = readPlanLimitOverrides();
    expect(overrides).toEqual({
      charLimit: 200000,
      voiceSlots: 50,
      voiceOps: 120,
      charBuffer: 1000,
    });

    const res = evaluateOrderCapacity(
      { character_count: 190000, character_limit: 30000, voice_slots_used: 10, voice_limit: 10, voice_add_edit_counter: 10, max_voice_add_edits: 10 },
      { chars: 9500, clones: 2 },
      overrides
    );
    expect(res.ok).toBe(false);
    expect(res.reason).toBe("insufficient_chars");
    expect(res.remainingChars).toBe(9000);
    expect(res.slotsFree).toBe(40);
    expect(res.opsLeft).toBe(110);
  });

  test("estimateOrderRequirements uses dubbing-pricing char length factors", () => {
    const req = estimateOrderRequirements({
      durationSec: 120,
      sourceChars: 1000,
      sourceLang: "en",
      targetLanguages: ["en", "te", "hi"],
      clonesNeeded: 1,
    });
    // te=1.25 (1250) + hi=1.1 (1100), source 'en' skipped
    expect(req.chars).toBe(2350);
    expect(req.clones).toBe(1);
  });

  test("refuses order when voice slots or monthly ops are short", () => {
    const sub = {
      character_count: 0,
      character_limit: 100000,
      voice_slots_used: 10,
      voice_limit: 10,
      voice_add_edit_counter: 5,
      max_voice_add_edits: 65,
      can_use_instant_voice_cloning: true,
    };
    const slotsShort = evaluateOrderCapacity(sub, { chars: 500, clones: 1 });
    expect(slotsShort.ok).toBe(false);
    expect(slotsShort.reason).toBe("slots_full");

    const opsShort = evaluateOrderCapacity(
      { ...sub, voice_slots_used: 2, voice_add_edit_counter: 65 },
      { chars: 500, clones: 1 }
    );
    expect(opsShort.ok).toBe(false);
    expect(opsShort.reason).toBe("monthly_voice_edits_used");
  });

  test("friendly message has no raw error or technical tokens", () => {
    const msg = orderCapacityUnavailableMessage();
    expect(msg).toMatch(/wallet has not been charged/i);
    expect(msg).not.toMatch(/elevenlabs|401|429|quota|api|error/i);
  });

  test("checkOrderCapacityAndAlert refuses and alerts admins when short", async () => {
    const alerts: Array<{ docId: string; payload: Record<string, unknown>; throttleMs: number }> = [];
    const outcome = await checkOrderCapacityAndAlert(
      {
        videoId: "vid_1",
        userId: "user_1",
        durationSec: 60,
        sourceChars: 1000,
        sourceLang: "en",
        targetLanguages: ["te"],
        clonesNeeded: 1,
      },
      {
        getSubscription: async () => ({
          character_count: 29500,
          character_limit: 30000,
          voice_slots_used: 2,
          voice_limit: 10,
          voice_add_edit_counter: 2,
          max_voice_add_edits: 65,
          can_use_instant_voice_cloning: true,
        }),
        alertFn: async (docId, payload, throttleMs) => {
          alerts.push({ docId, payload, throttleMs });
        },
      }
    );

    expect(outcome.allowed).toBe(false);
    expect(outcome.message).toBe(orderCapacityUnavailableMessage());
    expect(alerts.length).toBe(1);
    expect(alerts[0].payload.type).toBe("elevenlabs_capacity_short");
  });

  test("checkOrderCapacityAndAlert alerts admins (1h throttle) and proceeds when subscription fails", async () => {
    const alerts: Array<{ docId: string; payload: Record<string, unknown>; throttleMs: number }> = [];
    const outcome = await checkOrderCapacityAndAlert(
      {
        videoId: "vid_2",
        userId: "user_2",
        durationSec: 60,
        sourceChars: 500,
        sourceLang: "en",
        targetLanguages: ["hi"],
        clonesNeeded: 0,
      },
      {
        getSubscription: async () => {
          const err: any = new Error("Request failed with status code 401");
          err.response = { status: 401 };
          throw err;
        },
        alertFn: async (docId, payload, throttleMs) => {
          alerts.push({ docId, payload, throttleMs });
        },
      }
    );

    expect(outcome.allowed).toBe(true);
    expect(outcome.subscriptionFailed).toBe(true);
    expect(alerts.length).toBe(1);
    expect(alerts[0].docId).toBe("elevenlabs_subscription_error");
    expect(alerts[0].throttleMs).toBe(60 * 60 * 1000);
    expect(String(alerts[0].payload.orderAction)).toMatch(/proceeded/i);
  });
});
