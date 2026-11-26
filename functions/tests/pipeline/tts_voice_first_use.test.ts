/**
 * First use of an ElevenLabs Voice Library voice (2026-11-24): parallel lines of a new voice failed with
 * 409 "already_running" while ElevenLabs added the voice to the account, failing a whole Hindi dub.
 */
import * as fs from "fs";
import * as path from "path";
import {
  acquireVoiceFirstUse,
  isVoiceAddConflict,
  resetVoiceFirstUseForTests,
  VOICE_ADD_CONFLICT_RETRIES,
} from "../../src/pipeline/services/tts";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Simulates synthesize(): wait for the gate, "call ElevenLabs", report the outcome. */
async function fakeCall(voiceId: string, log: string[], inFlight: { now: number; max: number }, ok = true) {
  const done = await acquireVoiceFirstUse(voiceId);
  inFlight.now++;
  inFlight.max = Math.max(inFlight.max, inFlight.now);
  log.push(`start ${voiceId}`);
  await sleep(20);
  inFlight.now--;
  log.push(`end ${voiceId}`);
  done(ok);
}

describe("first use of a voice runs alone", () => {
  beforeEach(() => resetVoiceFirstUseForTests());

  it("runs the first call alone, then the rest in parallel", async () => {
    const log: string[] = [];
    const inFlight = { now: 0, max: 0 };
    await Promise.all([1, 2, 3, 4].map(() => fakeCall("niraj", log, inFlight)));
    // The first call finished before any other started.
    expect(log.slice(0, 2)).toEqual(["start niraj", "end niraj"]);
    // After that, the remaining three overlapped.
    expect(inFlight.max).toBeGreaterThanOrEqual(2);
  });

  it("does not hold back a voice that is already in use", async () => {
    await fakeCall("maddy", [], { now: 0, max: 0 });
    const inFlight = { now: 0, max: 0 };
    await Promise.all([1, 2, 3].map(() => fakeCall("maddy", [], inFlight)));
    expect(inFlight.max).toBe(3);
  });

  it("lets the next line try alone if the first call failed", async () => {
    const log: string[] = [];
    const inFlight = { now: 0, max: 0 };
    await Promise.all([
      fakeCall("new_voice", log, inFlight, false),
      fakeCall("new_voice", log, inFlight, true),
      fakeCall("new_voice", log, inFlight, true),
    ]);
    expect(log.slice(0, 4)).toEqual(["start new_voice", "end new_voice", "start new_voice", "end new_voice"]);
  });

  it("does not make different voices wait for each other", async () => {
    const inFlight = { now: 0, max: 0 };
    await Promise.all(["v1", "v2", "v3"].map((v) => fakeCall(v, [], inFlight)));
    expect(inFlight.max).toBe(3);
  });
});

describe("409 already_running is retried", () => {
  it("recognises the voice-add conflict only", () => {
    const body = '{"detail":{"type":"conflict","code":"already_running","message":"Multiple voice additions/deletions for the same voice were called at the same time. Please retry shortly."}}';
    expect(isVoiceAddConflict(409, body)).toBe(true);
    expect(isVoiceAddConflict(409, '{"detail":{"code":"other"}}')).toBe(false);
    expect(isVoiceAddConflict(429, body)).toBe(false);
    expect(VOICE_ADD_CONFLICT_RETRIES).toBeGreaterThanOrEqual(3);
  });

  it("is wired into synthesize: gate before the slot, retry without using up attempts, gate released", () => {
    const src = fs.readFileSync(path.resolve(__dirname, "../../src/pipeline/services/tts.ts"), "utf8");
    const body = src.slice(src.indexOf("async synthesize("));
    expect(body.indexOf("acquireVoiceFirstUse(voiceId)")).toBeLessThan(body.indexOf("GlobalTTSConcurrencyManager.acquireSlot()"));
    expect(body).toMatch(/isVoiceAddConflict\(statusCode, errorBody\) && voiceAddConflictWaits < VOICE_ADD_CONFLICT_RETRIES/);
    expect(body).toMatch(/attempt--;\s*continue;/);
    expect(body).toMatch(/finishFirstUse\(synthesized\)/);
    expect(body).toMatch(/synthesized = true;\s*return \{/);
  });
});
