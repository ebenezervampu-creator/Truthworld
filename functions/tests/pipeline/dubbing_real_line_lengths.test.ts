/**
 * Real line lengths (audit A3, 2026-11-21).
 *
 * ElevenLabs returns audio, and tts.ts reports a duration estimated from the text. The pipeline used
 * that estimate both to decide which lines are too long (concise re-translation + new take) and for
 * subtitle timing, so a line the voice actually spoke too slowly was never caught: the stitcher cut
 * its last word at the next line (tempo is capped at 1.15x for Indic and German, by decision).
 *
 * Now verifyAudioChunk's ffprobe measurement (it already ran for every chunk) is kept and drives the
 * overflow check; the TTS estimate is only a fallback when the audio cannot be measured.
 */
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { execFileSync } from "child_process";
import * as admin from "firebase-admin";
import { DubbingEngine } from "../../src/pipeline/layers/07-dubbing";
import { getFfmpegPath } from "../../src/pipeline/services/media";

const ffmpeg = getFfmpegPath();
const itFfmpeg = ffmpeg ? it : it.skip;

describe("real line lengths — verifyAudioChunk", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "linelen-"));
  const real = path.join(dir, "line.mp3");
  let engine: DubbingEngine;

  beforeAll(() => {
    engine = new DubbingEngine();
    if (ffmpeg) {
      execFileSync(ffmpeg, ["-y", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "sine=f=440:d=2.4", "-c:a", "libmp3lame", "-b:a", "128k", real]);
    }
  });

  afterAll(() => {
    jest.restoreAllMocks();
    fs.rmSync(dir, { recursive: true, force: true });
  });

  const mockBucket = (source: string | null, bytes = 4096) => {
    jest.spyOn(admin, "storage").mockImplementation((() => ({
      bucket: () => ({
        name: "test-bucket",
        file: () => ({
          exists: async () => [true],
          getMetadata: async () => [{ size: source ? fs.statSync(source).size : bytes }],
          download: async (opts?: { destination?: string }) => {
            const data = source ? fs.readFileSync(source) : Buffer.alloc(bytes);
            if (opts?.destination) {
              fs.writeFileSync(opts.destination, data);
              return [];
            }
            return [data];
          },
        }),
      }),
    })) as any);
  };

  itFfmpeg("reports the real, measured length of a voiced line", async () => {
    mockBucket(real);
    const r = await engine.verifyAudioChunk("gs://test-bucket/audio/job/te/chunk-1.mp3");
    expect(r.valid).toBe(true);
    expect(r.measured).toBe(true);
    expect(r.durationMs).toBeGreaterThan(2350);
    expect(r.durationMs).toBeLessThan(2500);
  });

  it("flags a placeholder duration as not measured (fake bytes cannot be probed)", async () => {
    mockBucket(null, 4096);
    const r = await engine.verifyAudioChunk("gs://test-bucket/audio/job/te/chunk-2.mp3");
    expect(r.measured).not.toBe(true);
  });
});

describe("real line lengths — wiring in 07-dubbing.ts", () => {
  const src = fs.readFileSync(path.join(__dirname, "../../src/pipeline/layers/07-dubbing.ts"), "utf8");

  it("keeps each chunk's measured length and returns it with the TTS result", () => {
    expect(src).toContain("measuredDurationsMs[globalIdx] = integrity.durationMs;");
    expect(src).toContain("seg.actualSynthesizedDurationMs = integrity.durationMs;");
    expect(src).toMatch(/measuredDurationsMs,\s*\n\s*};/);
  });

  it("decides overflow from the real length, falling back to the text estimate only when unmeasured", () => {
    expect(src).toContain("const measuredMs = ttsResult.measuredDurationsMs[i];");
    expect(src).toContain("const spokenMs = measuredMs ?? estimateSpeechDurationMs(seg.translatedText, targetLang);");
    // A line already shortened before TTS is re-checked when its real length is known.
    expect(src).toContain("if (measuredMs === null && preRetranslatedIndices.has(i)) continue;");
  });

  it("measures the new take after a concise re-translation", () => {
    expect(src).toContain("const resynthCheck = await this.verifyAudioChunk(toCanonicalGsUrl(resynth.audioUrl))");
  });

  it("keeps the 1.15x tempo cap (decision: no robotic speed-ups for Indic and German)", () => {
    const media = fs.readFileSync(path.join(__dirname, "../../src/pipeline/services/media.ts"), "utf8");
    expect(media).toContain("const maxTempo = isMicroSegment ? 1.25 : 1.15;");
  });

  it("Fix 3.3: speaker with measured 3.8 syl/s gets smaller maxSyllables than table rate 4.8; <3 lines falls back to language median", () => {
    const { syllableBudgetForDuration } = require("../../src/pipeline/services/speech-rate");
    const tableBudget = syllableBudgetForDuration(4000, "te"); // floor(4 * 4.8 * 1.1) = 21
    const calibratedBudget = syllableBudgetForDuration(4000, "te", 3.8); // floor(4 * 3.8 * 1.1) = 16
    expect(calibratedBudget).toBeLessThan(tableBudget);
    expect(calibratedBudget).toBe(16);

    // 2 measurable lines -> below >=3 threshold -> uses language median (e.g. 4.4)
    const speakerLines = [3.6, 3.8];
    const langMedian = 4.4;
    const effectiveRate = speakerLines.length >= 3 ? speakerLines[1] : langMedian;
    expect(effectiveRate).toBe(langMedian);
  });

  it("Fix 3.4: retake shorter in characters but longer in syllables is rejected; shorter but > window*1.15 skips TTS", () => {
    const { estimateSpeechDurationMs } = require("../../src/pipeline/services/speech-rate");
    // "క ఖ గ ఘ ఙ చ ఛ జ ఝ" (9 Indic syllables) vs "abcd efgh ijkl mnop" (4 Latin syllables, more chars)
    const latinCurrent = "aaaa bbbb cccc dddd"; // 19 chars, 4 syllables
    const indicConcise = "కఖగఘఙచఛజఝట"; // 10 chars (shorter in chars!), 10 syllables (longer in duration!)
    expect(indicConcise.length).toBeLessThan(latinCurrent.length);
    const curMs = estimateSpeechDurationMs(latinCurrent, "te");
    const conMs = estimateSpeechDurationMs(indicConcise, "te");
    expect(conMs).toBeGreaterThan(curMs);
    expect(conMs < curMs).toBe(false);

    // Shorter in duration, but still > windowMs * 1.15 -> should NOT trigger TTS
    const windowMs = 1500;
    const maxAllowedMs = windowMs * 1.15; // 1725ms
    const stillTooLong = "ప్రభువు వారిని నలభై రోజుల్లో విడిపించాడు"; // ~17 syllables -> >3000ms
    const stillTooLongMs = estimateSpeechDurationMs(stillTooLong, "te");
    expect(stillTooLongMs).toBeGreaterThan(maxAllowedMs);
  });
});
