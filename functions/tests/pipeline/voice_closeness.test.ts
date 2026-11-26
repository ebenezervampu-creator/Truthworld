import { execFileSync } from "child_process";
import * as os from "os";
import * as path from "path";
import * as fs from "fs";
import { estimatePitch, pitchDistanceSemitones } from "../../src/pipeline/services/pitch-estimation";

jest.mock("firebase-admin", () => ({ storage: () => ({}) }), { virtual: true });
jest.mock("../../src/pipeline/config", () => ({ PIPELINE_CONFIG: {} }), { virtual: true });
jest.mock("axios", () => ({ __esModule: true, default: {} }), { virtual: true });

const hasFfmpeg = (() => {
  try {
    execFileSync("ffmpeg", ["-version"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
})();

const SR = 16000;
/** Voice-like test signal: 8 harmonics, 5 Hz vibrato, pauses every third of a second, noise. */
function voice(f0: number, secs: number, noise = 0.05, missingFundamental = false): Float32Array {
  const n = Math.round(SR * secs);
  const x = new Float32Array(n);
  let phase = 0;
  let seed = 12345;
  const rand = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff) - 0.5;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    phase += (2 * Math.PI * f0 * (1 + 0.03 * Math.sin(2 * Math.PI * 5 * t))) / SR;
    let s = 0;
    for (let h = missingFundamental ? 2 : 1; h <= 8; h++) s += Math.sin(h * phase) / h;
    const speaking = Math.floor(t * 3) % 3 !== 2;
    x[i] = (speaking ? s * 0.3 : 0) + rand() * noise;
  }
  return x;
}

describe("pitch estimation (real F0, not a 3-level guess)", () => {
  it.each([85, 110, 140, 190, 220, 260, 310])("measures %i Hz within 3%%", (f0) => {
    const e = estimatePitch(voice(f0, 3), SR)!;
    expect(e).not.toBeNull();
    expect(Math.abs(e.medianHz - f0) / f0).toBeLessThan(0.03);
  });

  it("finds the fundamental even when it is missing from the signal (phone / thin audio)", () => {
    const e = estimatePitch(voice(120, 3, 0.1, true), SR)!;
    expect(Math.abs(e.medianHz - 120) / 120).toBeLessThan(0.03);
  });

  it("tells apart voices the old heuristic put in the same bucket", () => {
    const a = estimatePitch(voice(140, 2), SR)!.medianHz;
    const b = estimatePitch(voice(165, 2), SR)!.medianHz;
    expect(b - a).toBeGreaterThan(18);
  });

  it("returns null for silence and for pure noise", () => {
    expect(estimatePitch(new Float32Array(SR * 2), SR)).toBeNull();
    let seed = 7;
    const noise = new Float32Array(SR * 2).map(() => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff) - 0.5);
    expect(estimatePitch(noise, SR)).toBeNull();
  });

  it("compares pitch on a semitone scale", () => {
    expect(pitchDistanceSemitones(100, 200)).toBeCloseTo(1);
    // 20 Hz matters more for a deep voice than for a high one.
    expect(pitchDistanceSemitones(90, 110)).toBeGreaterThan(pitchDistanceSemitones(220, 240));
    expect(pitchDistanceSemitones(0, 120)).toBe(0.5);
  });
});

(hasFfmpeg ? describe : describe.skip)("MediaService.extractPitch on an encoded audio file", () => {
  it.each([[105], [130], [210]])("measures a %i Hz voice-like MP3", async (f0) => {
    const { mediaService } = await import("../../src/pipeline/services/media");
    const file = path.join(os.tmpdir(), `tw_pitch_${f0}_${process.pid}.mp3`);
    const expr = [1, 2, 3, 4, 5, 6].map((h) => `sin(${h}*2*PI*${f0}*t)/${h}`).join("+");
    execFileSync("ffmpeg", ["-y", "-v", "error", "-f", "lavfi", "-i", `aevalsrc=0.2*(${expr}):s=44100:d=3`, "-b:a", "64k", file]);
    try {
      const e = await mediaService.extractPitch(file);
      expect(e).not.toBeNull();
      expect(Math.abs(e!.medianHz - f0) / f0).toBeLessThan(0.03);
      expect(await mediaService.extractMedianPitchHz(file)).toBeCloseTo(e!.medianHz);
    } finally {
      fs.rmSync(file, { force: true });
    }
  });

  it("returns null (not a made-up number) for a silent file", async () => {
    const { mediaService } = await import("../../src/pipeline/services/media");
    const file = path.join(os.tmpdir(), `tw_pitch_silence_${process.pid}.mp3`);
    execFileSync("ffmpeg", ["-y", "-v", "error", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "2", file]);
    try {
      expect(await mediaService.extractPitch(file)).toBeNull();
    } finally {
      fs.rmSync(file, { force: true });
    }
  });
});
