/**
 * Launch fixes (2026-11-24): A8 line merging, A15 friendly status messages, A16 no American fallback voice.
 */
import * as fs from "fs";
import * as path from "path";
import { endsOnConnector, shouldStitch, MAX_STITCH_GAP_MS } from "../../src/pipeline/services/segment-stitching";
import { friendlyDubbingError, friendlyDubbingJobError, dubbingLanguageName } from "../../src/pipeline/services/dubbing-user-messages";

const PIPELINE = fs.readFileSync(path.resolve(__dirname, "../../src/pipeline/layers/07-dubbing.ts"), "utf8");

describe("A8: joining transcript lines", () => {
  const line = (text: string, start: number, end: number, speaker = "A") => ({ text, start, end, speaker });

  it("matches connecting words as whole words only", () => {
    expect(endsOnConnector("we went there and")).toBe(true);
    expect(endsOnConnector("give it to")).toBe(true);
    expect(endsOnConnector("I want to as well, also")).toBe(false);
    expect(endsOnConnector("they walked into")).toBe(false);
    expect(endsOnConnector("just breathe")).toBe(false);
    expect(endsOnConnector("the actor")).toBe(false);
    expect(endsOnConnector("we said so,")).toBe(true);
  });

  it("matches Hindi connectors only as separate words", () => {
    expect(endsOnConnector("मैं वहाँ गया और")).toBe(true);
    expect(endsOnConnector("यह सही है")).toBe(true);
    expect(endsOnConnector("उसने कहा कि")).toBe(true);
    expect(endsOnConnector("वह आदमी")).toBe(false);
  });

  it("joins a connector line with the next line of the same speaker across a short pause", () => {
    expect(shouldStitch(line("we went there and", 0, 1000), line("came back", 1200, 2000))).toBe(true);
  });

  it("never joins across a long pause", () => {
    expect(shouldStitch(line("Yes.", 0, 500), line("Let's go now, please.", 500 + MAX_STITCH_GAP_MS + 1, 4000))).toBe(false);
    expect(shouldStitch(line("we went there and", 0, 1000), line("came back", 3000, 4000))).toBe(false);
  });

  it("never joins different speakers", () => {
    expect(shouldStitch(line("Yes.", 0, 500, "A"), line("Good.", 600, 900, "B"))).toBe(false);
  });

  it("does not join a full line that merely ends in 'also'", () => {
    expect(shouldStitch(line("I would like that one also", 0, 2000), line("Sure.", 2100, 2500))).toBe(false);
  });

  it("is what stitchSegments uses", () => {
    expect(PIPELINE).toMatch(/while \(i \+ 1 < segments\.length && shouldStitch\(current, segments\[i \+ 1\]\)\)/);
    expect(PIPELINE).not.toMatch(/\(\?:and\|the\|so\|but\|or\|to\|for\|with\|तो\|और\|कि\|है\)\$\/i/);
  });
});

describe("A15: friendly status messages", () => {
  const technical = /Error:|\[Dubbing|stack|TypeError|ECONN|at \w+ \(|undefined|null/;

  it("names the language and mentions the refund", () => {
    const m = friendlyDubbingError("te", "Error: [Dubbing Quality Gate] Track rejected: missing_segments at foo (bar.ts:1)");
    expect(m).toMatch(/Telugu/);
    expect(m).toMatch(/refunded/);
    expect(m).not.toMatch(technical);
  });

  it("explains a missing native voice and a busy voice service", () => {
    expect(friendlyDubbingError("ta", "no_native_voice: no female native ta voice for speaker B")).toMatch(/Tamil voice/);
    expect(friendlyDubbingError("ml", "ElevenLabs quota_exceeded: 0 credits remaining")).toMatch(/busy/);
    expect(friendlyDubbingError("mr", "Function timed out")).toMatch(/too long/);
  });

  it("handles unknown languages and empty errors", () => {
    expect(dubbingLanguageName("hi-IN")).toBe("Hindi");
    expect(dubbingLanguageName("xx")).toBe("XX");
    expect(friendlyDubbingError(undefined, undefined)).not.toMatch(technical);
    expect(friendlyDubbingJobError()).not.toMatch(technical);
  });

  it("is used for every user-visible error field in the pipeline", () => {
    expect(PIPELINE).toMatch(/payload\.error = status === "failed" \? friendlyDubbingError\(targetLang, error\) : error;/);
    expect((PIPELINE.match(/friendlyDubbingError\(targetLang, error\)/g) || []).length).toBe(2);
    expect(PIPELINE).not.toMatch(/\{ status: "failed", error: errMsg \}/);
    expect(PIPELINE).not.toMatch(/upsertDubbingJob\(jobId, \{\s*status: "failed",\s*error: errMsg/);
    expect(PIPELINE).not.toMatch(/error: ttsResult\.failedSegments\[0\]\?\.error \|\|/);
  });
});

describe("A16: no American fallback voice under the native-voice policy", () => {
  const ttsBlock = PIPELINE.slice(PIPELINE.indexOf("// A16: with the native-voice policy on"), PIPELINE.indexOf("// Derive pitch and speakingRate"));

  it("uses a native voice of the same gender, or fails the line", () => {
    expect(ttsBlock).toMatch(/voiceMapping\[speakerId\] \|\| \(nativeOnly \? nativeVoiceOfGender\(isFemaleSpeaker\) \|\| "" : defaultVoiceId\)/);
    expect(ttsBlock).toMatch(/throw new Error\(`no_native_voice:/);
  });

  it("only uses the Sarah/Antoni presets when the native-voice policy is off", () => {
    const firewall = ttsBlock.slice(ttsBlock.indexOf("const clash ="));
    const nativeBranch = firewall.slice(firewall.indexOf("if (nativeOnly) {"), firewall.indexOf("} else {"));
    expect(nativeBranch).not.toMatch(/EXAVITQu4vr4xnSDxMaL|ErXwobaYiN019PkySvjV/);
    expect(nativeBranch).toMatch(/nativeVoiceOfGender\(gender === "FEMALE"\)/);
  });
});
