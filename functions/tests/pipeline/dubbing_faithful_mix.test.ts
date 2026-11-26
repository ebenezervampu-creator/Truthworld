/**
 * Faithful dub mix (services/faithful-mix.ts, MediaService.mixDubFaithful).
 *
 * Goal: a dubbed video sounds like the original apart from the language. Outside the spoken
 * lines the dub IS the original audio; inside them the clean background stem plus the dubbed
 * voice at the original speaker's level; loudness stays the original's.
 *
 * Background (2026-11-21): a 30.8 s English → Telugu dub shipped with the background 9–15 dB
 * below the original and the 300 Hz–8 kHz band cut a further 8–12 dB (crossover fallback,
 * fixed −18 LUFS bed, +3 dB cap, hard mute under speech, −14 LUFS re-target).
 *
 * The integration tests run real FFmpeg (ffmpeg-static, or FFMPEG_BIN) on synthetic audio and are
 * skipped where no FFmpeg binary is available.
 */

import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { execFileSync } from "child_process";

// In-memory GCS: gs://test-bucket/<path> ↔ files under a temp folder.
const BUCKET = "test-bucket";
const gcsRoot = fs.mkdtempSync(path.join(os.tmpdir(), "faithful-gcs-"));
jest.mock("firebase-admin", () => {
  const nodeFs = jest.requireActual("fs");
  const nodePath = jest.requireActual("path");
  const bucket = {
    name: BUCKET,
    file: (p: string) => ({
      download: async (opts?: { destination?: string }) => {
        const src = nodePath.join(gcsRoot, p);
        if (opts?.destination) {
          nodeFs.copyFileSync(src, opts.destination);
          return [];
        }
        return [nodeFs.readFileSync(src)];
      },
      exists: async () => [nodeFs.existsSync(nodePath.join(gcsRoot, p))],
    }),
    upload: async (src: string, opts: { destination: string }) => {
      const dest = nodePath.join(gcsRoot, opts.destination);
      nodeFs.mkdirSync(nodePath.dirname(dest), { recursive: true });
      nodeFs.copyFileSync(src, dest);
      return [];
    },
  };
  return {
    storage: () => ({ bucket: () => bucket }),
    apps: [{}],
    initializeApp: jest.fn(),
    firestore: Object.assign(() => ({}), { FieldValue: {} }),
  };
});

import {
  ENVELOPE_RATE,
  FAITHFUL_MIX,
  bandProfileDb,
  buildEnvelopes,
  buildFaithfulMixGraph,
  buildGainSpans,
  canUseBedUnderDialogue,
  checkFaithfulness,
  detectActiveSpans,
  dubCoverage,
  dubSpansNearLines,
  estimateOriginalVoiceDb,
  eqCorrectionDb,
  envelopeRateFor,
  analysisRateFor,
  eqFilterFor,
  faithfulMixEnabled,
  firstSpans,
  limitSpans,
  rmsDbOver,
  outsideRegions,
  planDialogueRegions,
  roomMatchEnabled,
  sceneToneEnabled,
  tightStemEnabled,
  voiceRideEnabled,
  keepNonVerbalEnabled,
  fidelityStemSelectEnabled,
  schroederRt60,
  estimateRegionRoom,
  groupRegionsIntoScenes,
  buildSyntheticRoomIr,
  buildTightStemSpans,
  adaptiveFadeMs,
  computeVoiceRideEnvelope,
  detectNonVerbalSpans,
  measureGapFidelity,
  measureEdgeStepsDb,
  TIGHT_STEM_FADE_MS,
  type DubBranch,
} from "../../src/pipeline/services/faithful-mix";
import { dubVoiceLiftDb } from "../../src/pipeline/services/faithful-mix";
import { getFfmpegPath, mediaService } from "../../src/pipeline/services/media";

// The sample's three lines (ms), as diarized by AssemblyAI.
const SAMPLE_LINES = [
  { speaker: "A", startMs: 2820, endMs: 6670 },
  { speaker: "A", startMs: 6980, endMs: 9950 },
  { speaker: "B", startMs: 10180, endMs: 13870 },
];

describe("faithful mix — planning (pure)", () => {
  it("is on by default and off with DUBBING_FAITHFUL_MIX=false", () => {
    expect(faithfulMixEnabled({})).toBe(true);
    expect(faithfulMixEnabled({ DUBBING_FAITHFUL_MIX: "true" })).toBe(true);
    expect(faithfulMixEnabled({ DUBBING_FAITHFUL_MIX: "false" })).toBe(false);
    expect(faithfulMixEnabled({ DUBBING_FAITHFUL_MIX: "FALSE" })).toBe(false);
  });

  it("pads and merges close lines into one region, and leaves the rest of the video untouched", () => {
    const regions = planDialogueRegions(SAMPLE_LINES, 30800);
    // Gaps of 310 ms and 230 ms are below the 400 ms merge gap.
    expect(regions).toEqual([{ startMs: 2670, endMs: 14020 }]);
    expect(outsideRegions(regions, 30800)).toEqual([
      { startMs: 0, endMs: 2670 },
      { startMs: 14020, endMs: 30800 },
    ]);
  });

  it("keeps separate regions apart, clamps to the media length and ignores empty spans", () => {
    const regions = planDialogueRegions(
      [{ startMs: 100, endMs: 1000 }, { startMs: 5000, endMs: 5000 }, { startMs: 9000, endMs: 9990 }, { startMs: 3000, endMs: 4000 }],
      10000
    );
    expect(regions).toEqual([
      { startMs: 0, endMs: 1150 },
      { startMs: 2850, endMs: 4150 },
      { startMs: 8850, endMs: 10000 },
    ]);
    // Region separation always leaves room for both fades.
    expect(FAITHFUL_MIX.mergeGapMs).toBeGreaterThanOrEqual(2 * FAITHFUL_MIX.fadeMs);
  });

  it("uses the background under dialogue only for a clean neural stem with the isolated voice available", () => {
    expect(canUseBedUnderDialogue({ bedUrl: "gs://b/m.mp3", isolatedVocalUrl: "gs://b/v.mp3" })).toBe(true); // Demucs stems
    expect(canUseBedUnderDialogue({ bedUrl: "gs://b/m.mp3", isolatedVocalUrl: "gs://b/v.mp3", validationStatus: "passed", source: "neural_demixing" })).toBe(true);
    expect(canUseBedUnderDialogue({ bedUrl: "gs://b/m.mp3", isolatedVocalUrl: "gs://b/v.mp3", source: "fallback_crossover" })).toBe(false);
    expect(canUseBedUnderDialogue({ bedUrl: "gs://b/m.mp3", isolatedVocalUrl: "gs://b/v.mp3", source: "dsp_fallback" })).toBe(false);
    expect(canUseBedUnderDialogue({ bedUrl: "gs://b/m.mp3", isolatedVocalUrl: "gs://b/v.mp3", validationStatus: "degraded" })).toBe(false);
    expect(canUseBedUnderDialogue({ bedUrl: "gs://b/m.mp3", isolatedVocalUrl: "gs://b/v.mp3", validationStatus: "failed" })).toBe(false);
    expect(canUseBedUnderDialogue({ bedUrl: "gs://b/m.mp3", isolatedVocalUrl: null })).toBe(false);
    expect(canUseBedUnderDialogue({ bedUrl: null, isolatedVocalUrl: "gs://b/v.mp3" })).toBe(false);
  });

  it("estimates the original voice level from the isolated voice, else the mix minus the background", () => {
    expect(estimateOriginalVoiceDb({ isolatedVoiceDb: -23, sourceDb: -18, bedDb: -25 })).toBe(-23);
    // -18 dB mix with a -25 dB bed: voice power = 10^-1.8 − 10^-2.5 → ≈ -19.0 dB.
    expect(estimateOriginalVoiceDb({ sourceDb: -18, bedDb: -25 })).toBeCloseTo(-18.97, 1);
    // Background as loud as the mix: fall back to the mix level rather than invent a voice level.
    expect(estimateOriginalVoiceDb({ sourceDb: -20, bedDb: -20 })).toBe(-20);
    expect(estimateOriginalVoiceDb({ sourceDb: null })).toBeNull();
  });

  it("builds per-line gain spans that follow each speaker until the next line", () => {
    const spans = buildGainSpans(SAMPLE_LINES, { A: -5.7, B: -8.8 }, 30800);
    expect(spans.map((s) => [s.startMs, s.endMs, s.speaker])).toEqual([
      [2770, 6980, "A"],
      [6930, 10180, "A"],
      [10130, 15370, "B"],
    ]);
    expect(spans[0].gain).toBeCloseTo(10 ** (-5.7 / 20), 5);
    expect(spans[2].gain).toBeCloseTo(10 ** (-8.8 / 20), 5);
  });

  it("gain curves: original outside, background and dub inside, linear fades, per-speaker gains", () => {
    const env = buildEnvelopes({
      regions: [{ startMs: 2000, endMs: 4000 }],
      gainSpans: [
        { startMs: 1950, endMs: 3000, gain: 0.5, speaker: "A" },
        { startMs: 3000, endMs: 4000, gain: 2, speaker: "B" },
      ],
      totalMs: 6000,
      branches: [{ speakers: ["A"], eqFilter: "firequalizer" }, { speakers: ["B"], eqFilter: null }],
    });
    const at = (ms: number) => Math.round((ms * ENVELOPE_RATE) / 1000);
    expect(env.orig[at(1000)]).toBe(1);
    expect(env.bed[at(1000)]).toBe(0);
    expect(env.orig[at(1960)]).toBeCloseTo(0.5, 2); // 80 ms fade centred on the region edge
    expect(env.orig[at(2500)]).toBe(0);
    expect(env.bed[at(2500)]).toBe(1);
    expect(env.orig[at(5000)]).toBe(1);
    // Speaker A on branch 0 at gain 0.5, speaker B on branch 1 at gain 2, nothing outside.
    expect(env.dub[0][at(2500)]).toBeCloseTo(0.5, 5);
    expect(env.dub[1][at(2500)]).toBe(0);
    expect(env.dub[1][at(3500)]).toBeCloseTo(2, 5);
    expect(env.dub[0][at(1000)]).toBe(0);
    expect(env.dub[1][at(5000)]).toBe(0);
    // Gain changes are ramped, never stepped.
    expect(env.dub[1][at(3000)]).toBeGreaterThan(0.5);
    expect(env.dub[1][at(3000)]).toBeLessThan(1.5);
    // Curves outlast the media.
    expect(env.orig.length).toBeGreaterThan(at(6000));
    // orig + bed is always exactly 1 (no level change at the crossfades).
    for (let k = 0; k < env.orig.length; k += 7) expect(env.orig[k] + env.bed[k]).toBeCloseTo(1, 6);
  });

  it("stays bounded on a long film with thousands of lines", () => {
    // ~0.3 s for two hours in plain Node; Jest's sandbox makes typed-array loops ~30x slower.
    const lines = Array.from({ length: 1500 }, (_, i) => ({ speaker: `S${i % 7}`, startMs: i * 2400, endMs: i * 2400 + 1800 }));
    const totalMs = 3600 * 1000;
    const t0 = Date.now();
    const regions = planDialogueRegions(lines, totalMs);
    const env = buildEnvelopes({
      regions,
      gainSpans: buildGainSpans(lines, {}, totalMs),
      totalMs,
      branches: [{ speakers: [], eqFilter: null }],
    });
    expect(Date.now() - t0).toBeLessThan(30000);
    expect(env.orig.length).toBeLessThan(4_000_000); // ~14 MB per curve per hour at 1 kHz
    expect(limitSpans(regions, 80).length).toBeLessThanOrEqual(80);
  }, 60000);

  it("filter graph multiplies gain curves in, never ducks, normalises or re-targets loudness", () => {
    const graph = buildFaithfulMixGraph({
      hasBed: true,
      branches: [{ speakers: ["A"], eqFilter: "firequalizer=gain_entry='entry(1000,3)'" }, { speakers: [], eqFilter: null }],
    });
    expect(graph).toContain("[3:a]"); // original curve
    expect(graph).toContain("[4:a]"); // background curve
    expect(graph).toContain("[5:a]"); // dub branch 0 curve
    expect(graph).toContain("[6:a]"); // dub branch 1 curve
    expect(graph).toContain("asplit=2");
    expect(graph).toContain("firequalizer");
    expect(graph).toContain("amix=inputs=4:normalize=0:duration=first[out]");
    expect(graph).not.toMatch(/sidechaincompress|loudnorm|highpass|lowpass|stereotools/);
    const noBed = buildFaithfulMixGraph({ hasBed: false, branches: [{ speakers: [], eqFilter: null }] });
    expect(noBed).toContain("amix=inputs=2:normalize=0:duration=first[out]");
    expect(noBed).not.toContain("[2:a]aresample=44100,aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[s_bed]");
    expect(noBed).not.toContain("asplit");
  });

  it("tone match moves the dub's spectrum toward the original voice, within ±6 dB, level-neutral", () => {
    const sr = 44100;
    // Reference: energy falls 6 dB per band. Dub: flat. Correction should tilt the dub down.
    const ref = [0, -6, -12, -18, -24, -30, -36, -42, -48];
    const dub = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    const eq = eqCorrectionDb(ref, dub)!;
    expect(eq[0]).toBe(6); // clamped
    expect(eq[4]).toBe(0); // median band unchanged: level is matched separately
    expect(eq[8]).toBe(-6); // clamped
    expect(eqFilterFor(eq)).toMatch(/^firequalizer=gain_entry='entry\(113,6\);.*':delay=0\.01,atrim=start_sample=441,asetpts=N\/SR\/TB$/);
    expect(eqFilterFor([0, 0.2, -0.3, 0, 0, 0, 0, 0, 0])).toBeNull(); // flat enough: no filter
    expect(eqCorrectionDb(null, dub)).toBeNull();
    // Band profile of a 1 kHz tone puts the energy in the 630–1250 Hz band.
    const pcm = new Float32Array(sr * 2);
    for (let i = 0; i < pcm.length; i++) pcm[i] = 0.3 * Math.sin((2 * Math.PI * 1000 * i) / sr);
    const prof = bandProfileDb(pcm, sr)!;
    expect(prof.indexOf(Math.max(...prof))).toBe(3); // bands: 80–160, 160–315, 315–630, 630–1250 …
  });

  it("measures levels over spans in memory, and picks rates that keep long media small", () => {
    const sr = 1000;
    const pcm = new Float32Array(5000);
    for (let i = 1000; i < 2000; i++) pcm[i] = 0.5; // -6 dB for 1 s
    expect(rmsDbOver(pcm, sr, [{ startMs: 1000, endMs: 2000 }])).toBeCloseTo(-6.02, 1);
    expect(rmsDbOver(pcm, sr, [{ startMs: 1000, endMs: 3000 }])).toBeCloseTo(-9.03, 1);
    expect(rmsDbOver(pcm, sr, [{ startMs: 3000, endMs: 4000 }])).toBeNull();
    expect(rmsDbOver(pcm, sr, [])).toBeNull();
    expect(firstSpans([{ startMs: 5000, endMs: 9000 }, { startMs: 0, endMs: 4000 }, { startMs: 10000, endMs: 14000 }], 6000))
      .toEqual([{ startMs: 0, endMs: 4000 }, { startMs: 5000, endMs: 9000 }]);
    expect(analysisRateFor(60_000)).toBe(8000);
    expect(analysisRateFor(2 * 3600_000)).toBe(2000);
    expect(envelopeRateFor(60_000)).toBe(1000);
    expect(envelopeRateFor(2 * 3600_000)).toBe(250);
  });

  it("finds where the dubbed track is audible", () => {
    const sr = 8000;
    const pcm = new Float32Array(sr * 6);
    const burst = (a: number, b: number) => {
      for (let i = Math.round(a * sr); i < Math.round(b * sr); i++) pcm[i] = 0.3 * Math.sin((2 * Math.PI * 220 * i) / sr);
    };
    burst(1, 2);
    burst(2.1, 2.5); // 100 ms pause: same span
    burst(4, 4.6);
    const spans = detectActiveSpans(pcm, sr);
    expect(spans).toHaveLength(2);
    expect(spans[0].startMs).toBeCloseTo(1000, -2);
    expect(spans[0].endMs).toBeCloseTo(2500, -2);
    expect(spans[1].startMs).toBeCloseTo(4000, -2);
    expect(spans[1].endMs).toBeCloseTo(4600, -2);
  });

  it("ignores faint residue far below the dubbed speech", () => {
    const sr = 8000;
    const pcm = new Float32Array(sr * 10);
    for (let i = 1 * sr; i < 3 * sr; i++) pcm[i] = 0.3 * Math.sin((2 * Math.PI * 220 * i) / sr); // speech, ≈ -13 dBFS
    for (let i = 5 * sr; i < 9 * sr; i++) pcm[i] = 0.008 * Math.sin((2 * Math.PI * 440 * i) / sr); // residue, ≈ -45 dBFS... -44
    const spans = detectActiveSpans(pcm, sr);
    expect(spans).toHaveLength(1);
    expect(spans[0].startMs).toBeCloseTo(1000, -2);
  });

  it("keeps only dub activity that belongs to a spoken line, clipped to its overrun window", () => {
    const lines = [{ startMs: 2820, endMs: 6670 }, { startMs: 10180, endMs: 13870 }];
    const active = [
      { startMs: 2830, endMs: 6900 }, // line 1 running 230 ms over: kept
      { startMs: 15000, endMs: 30000 }, // residue under the song: clipped to 15000–15870
      { startMs: 20000, endMs: 21000 }, // far from any line: dropped
    ];
    expect(dubSpansNearLines(active, lines)).toEqual([
      { startMs: 2830, endMs: 6900 },
      { startMs: 15000, endMs: 15870 },
    ]);
  });

  it("measures how much of the dubbed speech the regions hold", () => {
    const regions = [{ startMs: 2670, endMs: 14020 }];
    expect(dubCoverage([{ startMs: 2830, endMs: 6900 }, { startMs: 6980, endMs: 10300 }], regions)).toBe(1);
    // Line timings given in seconds instead of ms: regions sit in the first 15 ms.
    expect(dubCoverage([{ startMs: 2830, endMs: 6900 }], [{ startMs: 0, endMs: 14 }])).toBe(0);
    expect(dubCoverage([], regions)).toBe(1);
  });

  it("faithfulness check passes within 0.5 dB outside the dialogue", () => {
    expect(checkFaithfulness(-16.0, -16.2)).toEqual({ ok: true, outsideDiffDb: -0.2 });
    expect(checkFaithfulness(-16.0, -25.8).ok).toBe(false); // the old mix: ~10 dB down
    expect(checkFaithfulness(null, null).ok).toBe(true);
  });
});

describe("faithful mix — wiring in 07-dubbing.ts", () => {
  const src = fs.readFileSync(path.join(__dirname, "../../src/pipeline/layers/07-dubbing.ts"), "utf8");

  it("tries the faithful mix before the sidechain mix, and falls back to it", () => {
    const faithful = src.indexOf("mediaService.mixDubFaithful(");
    const legacy = src.indexOf("mediaService.mixDubWithMne(");
    expect(faithful).toBeGreaterThan(0);
    expect(legacy).toBeGreaterThan(faithful);
    expect(src).toContain("if (!faithfulMixed && mneStemUrl && mneValidation?.validationStatus !== \"failed\")");
  });

  it("keeps the original's loudness in the delivery check", () => {
    expect(src).toMatch(/targetLufs: deliveryTargetLufs/);
    expect(src).toMatch(/deliveryTargetLufs = typeof faithful\.sourceLufs === "number"/);
  });

  it("never puts a degraded stem under the dub", () => {
    expect(src).toMatch(/bedUrl: useBed \? mneStemUrl : null/);
  });
});

// ─── Integration: real FFmpeg on synthetic audio ──────────────────────────────────────────────

const ffmpeg = getFfmpegPath();
const itFfmpeg = ffmpeg ? it : it.skip;

function run(args: string[]): void {
  execFileSync(ffmpeg!, ["-y", "-hide_banner", "-loglevel", "error", ...args]);
}

function decodeStereo(file: string, sr = 44100, startSec?: number, durSec?: number): Float32Array[] {
  const range = startSec !== undefined ? ["-ss", String(startSec), "-t", String(durSec ?? 5)] : [];
  const buf = execFileSync(ffmpeg!, ["-v", "error", ...range, "-i", file, "-ac", "2", "-ar", String(sr), "-f", "f32le", "pipe:1"], { maxBuffer: 256 * 1024 * 1024 });
  const all = new Float32Array(buf.buffer, buf.byteOffset, Math.floor(buf.length / 4));
  const l = new Float32Array(all.length / 2);
  const r = new Float32Array(all.length / 2);
  for (let i = 0; i < l.length; i++) {
    l[i] = all[2 * i];
    r[i] = all[2 * i + 1];
  }
  return [l, r];
}

const rmsDb = (x: Float32Array, a: number, b: number, sr = 44100): number => {
  let s = 0;
  const i0 = Math.round(a * sr);
  const i1 = Math.min(x.length, Math.round(b * sr));
  for (let i = i0; i < i1; i++) s += x[i] * x[i];
  return 10 * Math.log10(s / Math.max(1, i1 - i0) + 1e-12);
};

/** Level (dB) of one sine frequency in a stretch, by correlation with sin/cos at that frequency. */
const toneDb = (x: Float32Array, hz: number, a: number, b: number, sr = 44100): number => {
  let c = 0;
  let s = 0;
  const i0 = Math.round(a * sr);
  const i1 = Math.min(x.length, Math.round(b * sr));
  for (let i = i0; i < i1; i++) {
    c += x[i] * Math.cos((2 * Math.PI * hz * i) / sr);
    s += x[i] * Math.sin((2 * Math.PI * hz * i) / sr);
  }
  const amp = (2 * Math.sqrt(c * c + s * s)) / Math.max(1, i1 - i0);
  return 20 * Math.log10(amp + 1e-12);
};

const corr = (x: Float32Array, y: Float32Array, a: number, b: number, sr = 44100): number => {
  const i0 = Math.round(a * sr);
  const i1 = Math.min(x.length, y.length, Math.round(b * sr));
  let sxy = 0;
  let sxx = 0;
  let syy = 0;
  for (let i = i0; i < i1; i++) {
    sxy += x[i] * y[i];
    sxx += x[i] * x[i];
    syy += y[i] * y[i];
  }
  return sxy / Math.sqrt(sxx * syy + 1e-20);
};

describe("faithful mix — MediaService.mixDubFaithful with real FFmpeg", () => {
  // 12 s clip: "music" = 330 Hz + 495 Hz (L/R different) + pink noise, all the way through.
  // English voice = 1200 Hz tone at 3.0–6.0 s. Dubbed (Telugu) voice = 900 Hz at 3.0–6.4 s, 8 dB too loud.
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "faithful-work-"));
  const put = (name: string) => path.join(gcsRoot, "in", name);
  const MUSIC = "aevalsrc='0.10*sin(2*PI*330*t)+0.02*sin(2*PI*2500*t)|0.10*sin(2*PI*495*t)+0.02*sin(2*PI*2500*t)':s=44100:d=12";
  const ENGLISH = "aevalsrc='0.12*sin(2*PI*1200*t)*between(t,3,6)|0.12*sin(2*PI*1200*t)*between(t,3,6)':s=44100:d=12";
  // Plus a short stray 700 Hz sound at 9.0–9.2 s, far from any line: it must never reach the output.
  // (Kept short: a long one would trip the dub-coverage guard, which refuses the faithful mix.)
  const TELUGU = "aevalsrc='0.30*sin(2*PI*900*t)*between(t,3,6.4)+0.05*sin(2*PI*700*t)*between(t,9,9.2)|0.30*sin(2*PI*900*t)*between(t,3,6.4)+0.05*sin(2*PI*700*t)*between(t,9,9.2)':s=44100:d=12";

  beforeAll(() => {
    if (!ffmpeg) return;
    fs.mkdirSync(path.join(gcsRoot, "in"), { recursive: true });
    const enc = ["-c:a", "libmp3lame", "-b:a", "256k"];
    run(["-f", "lavfi", "-i", MUSIC, ...enc, put("bed.mp3")]);
    run(["-f", "lavfi", "-i", ENGLISH, ...enc, put("vocals.mp3")]);
    run(["-f", "lavfi", "-i", MUSIC, "-f", "lavfi", "-i", ENGLISH, "-filter_complex", "[0][1]amix=inputs=2:normalize=0", ...enc, put("source.mp3")]);
    run(["-f", "lavfi", "-i", TELUGU, ...enc, put("dub.mp3")]);
  });

  afterAll(() => {
    fs.rmSync(work, { recursive: true, force: true });
  });

  const gs = (name: string) => `gs://${BUCKET}/in/${name}`;
  const lines = [{ speaker: "A", startMs: 3000, endMs: 6000 }];

  itFfmpeg("keeps the original outside the dialogue and the clean background under it, voice at the original level", async () => {
    const res = await mediaService.mixDubFaithful("job_faithful", "te", {
      sourceAudioUrl: gs("source.mp3"),
      dubbedAudioUrl: gs("dub.mp3"),
      bedUrl: gs("bed.mp3"),
      isolatedVocalUrl: gs("vocals.mp3"),
      lines,
      totalDurationMs: 12000,
      toneMatch: false, // pure tones as voices: this test checks levels and structure only
    });
    expect(res.ok).toBe(true);
    expect(res.url).toBe(`gs://${BUCKET}/audio/job_faithful/te/master_faithful.mp3`);
    expect(res.usedBed).toBe(true);
    expect(res.regions).toBe(1);
    // Dubbed voice was 0.30 vs 0.12 amplitude (+8 dB): brought down by ~8 dB.
    expect(res.voiceGainDb.A).toBeGreaterThan(-9.5);
    expect(res.voiceGainDb.A).toBeLessThan(-6.5);
    expect(Math.abs(res.outsideDiffDb ?? 99)).toBeLessThan(0.3);
    expect(Math.abs((res.mixLufs ?? 0) - (res.sourceLufs ?? 99))).toBeLessThan(1.5);

    const [ml, mr] = decodeStereo(path.join(gcsRoot, "audio/job_faithful/te/master_faithful.mp3"));
    const [sl, sr] = decodeStereo(path.join(gcsRoot, "in/source.mp3"));
    // Outside the dialogue: the original, sample for sample, in both channels (stereo image kept).
    for (const [a, b] of [[0.2, 2.6], [7.0, 11.8]]) {
      expect(corr(ml, sl, a, b)).toBeGreaterThan(0.99);
      expect(corr(mr, sr, a, b)).toBeGreaterThan(0.99);
      expect(Math.abs(rmsDb(ml, a, b) - rmsDb(sl, a, b))).toBeLessThan(0.3);
    }
    // Stray sound in the dubbed track outside the dialogue is cut.
    // (The stray is ≈ -32 dB; music leakage into this short window reads the same in the original.)
    expect(Math.abs(toneDb(ml, 700, 9.02, 9.18) - toneDb(sl, 700, 9.02, 9.18))).toBeLessThan(3);
    // Under the dialogue: the music at its original level, no English, Telugu at the English level.
    expect(Math.abs(toneDb(ml, 330, 3.5, 5.5) - toneDb(sl, 330, 3.5, 5.5))).toBeLessThan(1);
    expect(Math.abs(toneDb(mr, 495, 3.5, 5.5) - toneDb(sr, 495, 3.5, 5.5))).toBeLessThan(1);
    expect(toneDb(ml, 1200, 3.5, 5.5)).toBeLessThan(toneDb(sl, 1200, 3.5, 5.5) - 30);
    // Dubbed voice at the original voice's level plus the dialogue lift (DUBBING_VOICE_LIFT_DB, 2 dB default).
    expect(Math.abs(toneDb(ml, 900, 3.5, 5.5) - toneDb(sl, 1200, 3.5, 5.5) - dubVoiceLiftDb())).toBeLessThan(1.5);
  }, 120000);

  itFfmpeg("without a clean background stem, the dub plays alone under the dialogue and the rest stays original", async () => {
    const res = await mediaService.mixDubFaithful("job_faithful_nobed", "te", {
      sourceAudioUrl: gs("source.mp3"),
      dubbedAudioUrl: gs("dub.mp3"),
      bedUrl: null,
      isolatedVocalUrl: gs("vocals.mp3"),
      lines,
      totalDurationMs: 12000,
      toneMatch: false,
    });
    expect(res.ok).toBe(true);
    expect(res.usedBed).toBe(false);
    const [ml] = decodeStereo(path.join(gcsRoot, "audio/job_faithful_nobed/te/master_faithful.mp3"));
    const [sl] = decodeStereo(path.join(gcsRoot, "in/source.mp3"));
    expect(corr(ml, sl, 7.0, 11.8)).toBeGreaterThan(0.99);
    // No English and no music under the dub (the music would carry the English in a real degraded stem).
    expect(toneDb(ml, 1200, 3.5, 5.5)).toBeLessThan(toneDb(sl, 1200, 3.5, 5.5) - 30);
    expect(toneDb(ml, 330, 3.5, 5.5)).toBeLessThan(toneDb(sl, 330, 3.5, 5.5) - 30);
    // Dubbed voice at the original voice's level plus the dialogue lift (DUBBING_VOICE_LIFT_DB, 2 dB default).
    expect(Math.abs(toneDb(ml, 900, 3.5, 5.5) - toneDb(sl, 1200, 3.5, 5.5) - dubVoiceLiftDb())).toBeLessThan(1.5);
  }, 120000);

  itFfmpeg("refuses when the line timings do not match the dubbed track, so the original language never ships", async () => {
    const res = await mediaService.mixDubFaithful("job_faithful_units", "te", {
      sourceAudioUrl: gs("source.mp3"),
      dubbedAudioUrl: gs("dub.mp3"),
      bedUrl: gs("bed.mp3"),
      isolatedVocalUrl: gs("vocals.mp3"),
      lines: [{ speaker: "A", startMs: 3, endMs: 6 }], // seconds passed as ms
      totalDurationMs: 12000,
    });
    expect(res.ok).toBe(false);
    expect(res.reason).toMatch(/outside the dialogue timings/);
    expect(fs.existsSync(path.join(gcsRoot, "audio/job_faithful_units/te/master_faithful.mp3"))).toBe(false);
  }, 60000);

  itFfmpeg("speech-only video: keeps the original room sound between lines and tone-matches the dubbed voice", async () => {
    const enc = ["-c:a", "libmp3lame", "-b:a", "256k"];
    // Room sound all the way through (quiet), a dark English voice at 3–6 s; a bright dubbed voice at 3–6.4 s.
    // Voices as speech-shaped noise; the dub differs by a studio-vs-room tilt (−5 dB bass, +5 dB treble).
    run(["-f", "lavfi", "-i", "anoisesrc=d=12:c=pink:a=0.003:seed=1",
      "-f", "lavfi", "-i", "anoisesrc=d=12:c=pink:a=0.25:seed=2,highpass=f=100,lowpass=f=7000,volume='between(t,3,6)':eval=frame",
      "-filter_complex", "[0][1]amix=inputs=2:normalize=0,aformat=channel_layouts=stereo", ...enc, put("speech_source.mp3")]);
    run(["-f", "lavfi", "-i", "anoisesrc=d=12:c=pink:a=0.25:seed=3,highpass=f=100,lowpass=f=7000,bass=g=-5,treble=g=5,volume='between(t,3,6.4)':eval=frame",
      "-ac", "2", ...enc, put("speech_dub.mp3")]);

    const res = await mediaService.mixDubFaithful("job_faithful_speech", "te", {
      sourceAudioUrl: gs("speech_source.mp3"),
      dubbedAudioUrl: gs("speech_dub.mp3"),
      bedUrl: null,
      isolatedVocalUrl: null,
      lines,
      totalDurationMs: 12000,
      sourceIsSpeechOnly: true,
    });
    expect(res.ok).toBe(true);
    expect(res.toneMatchedSpeakers).toEqual(["A"]);

    const [ml] = decodeStereo(path.join(gcsRoot, "audio/job_faithful_speech/te/master_faithful.mp3"));
    const [sl] = decodeStereo(path.join(gcsRoot, "in/speech_source.mp3"));
    const [dl] = decodeStereo(path.join(gcsRoot, "in/speech_dub.mp3"));
    // The original room sound between lines is kept, sample for sample.
    expect(corr(ml, sl, 7.0, 11.8)).toBeGreaterThan(0.98);
    expect(Math.abs(rmsDb(ml, 7.0, 11.8) - rmsDb(sl, 7.0, 11.8))).toBeLessThan(0.5);
    // The dubbed voice's spectrum moved toward the English voice's.
    const slice = (x: Float32Array) => x.slice(Math.round(3.4 * 44100), Math.round(5.8 * 44100));
    const shape = (p: number[]) => {
      const m = [...p].sort((a, b) => a - b)[Math.floor(p.length / 2)];
      return p.map((v) => v - m);
    };
    const distance = (a: number[], b: number[]) => {
      const sa = shape(a);
      const sb = shape(b);
      return sa.reduce((sum, v, i) => sum + Math.abs(v - sb[i]), 0);
    };
    const english = bandProfileDb(slice(sl), 44100)!;
    const before = distance(bandProfileDb(slice(dl), 44100)!, english);
    const after = distance(bandProfileDb(slice(ml), 44100)!, english);
    expect(before).toBeGreaterThan(10); // the test voices really do differ
    expect(after).toBeLessThan(before * 0.5);
    // Tone matching must not move the voice in time (firequalizer delays 10 ms; the chain trims it).
    let best = 0;
    let bestLag = 0;
    const a0 = Math.round(3.6 * 44100);
    for (let lag = -1000; lag <= 1000; lag++) {
      let s = 0;
      for (let i = 0; i < 22050; i++) s += dl[a0 + i] * ml[a0 + i + lag];
      if (Math.abs(s) > Math.abs(best)) {
        best = s;
        bestLag = lag;
      }
    }
    expect(Math.abs(bestLag)).toBeLessThanOrEqual(2);
  }, 120000);

  itFfmpeg("long-form (21 min, reel size): many lines, low analysis rates, still the original outside the dialogue", async () => {
    const enc = ["-c:a", "libmp3lame", "-b:a", "256k"];
    const D = 21 * 60;
    // A line every 10 s (4 s long), alternating two speakers; music throughout.
    const on = "lt(mod(t,10),4)";
    run(["-f", "lavfi", "-i", `aevalsrc='0.10*sin(2*PI*330*t)|0.10*sin(2*PI*495*t)':s=44100:d=${D}`, ...enc, put("long_bed.mp3")]);
    run(["-f", "lavfi", "-i", `aevalsrc='0.12*sin(2*PI*1200*t)*${on}':s=44100:d=${D}`, "-ac", "2", ...enc, put("long_vocals.mp3")]);
    run(["-i", put("long_bed.mp3"), "-i", put("long_vocals.mp3"), "-filter_complex", "[0][1]amix=inputs=2:normalize=0", ...enc, put("long_source.mp3")]);
    run(["-f", "lavfi", "-i", `aevalsrc='0.30*sin(2*PI*900*t)*lt(mod(t,10),4.3)':s=44100:d=${D}`, "-ac", "2", ...enc, put("long_dub.mp3")]);
    const longLines = Array.from({ length: D / 10 }, (_, i) => ({ speaker: i % 2 ? "B" : "A", startMs: i * 10000, endMs: i * 10000 + 4000 }));

    const t0 = Date.now();
    const res = await mediaService.mixDubFaithful("job_faithful_long", "te", {
      sourceAudioUrl: gs("long_source.mp3"),
      dubbedAudioUrl: gs("long_dub.mp3"),
      bedUrl: gs("long_bed.mp3"),
      isolatedVocalUrl: gs("long_vocals.mp3"),
      lines: longLines,
      totalDurationMs: D * 1000,
      toneMatch: false,
    });
    const elapsed = Date.now() - t0;
    expect(res.ok).toBe(true);
    expect(res.regions).toBe(D / 10);
    expect(Math.abs(res.outsideDiffDb ?? 99)).toBeLessThan(0.3);
    expect(res.voiceGainDb.A).toBeLessThan(-6.5);
    expect(res.voiceGainDb.B).toBeLessThan(-6.5);
    // Decode only short windows: the whole film at 44.1 kHz stereo would be ~450 MB.
    const win = (file: string, startSec: number, durSec: number) =>
      decodeStereo(file, 44100, startSec, durSec)[0];
    const mixFile = path.join(gcsRoot, "audio/job_faithful_long/te/master_faithful.mp3");
    const srcFile = path.join(gcsRoot, "in/long_source.mp3");
    // Gaps at the start, middle and end of the film are the original.
    for (const t of [5, 605, D - 5]) {
      expect(corr(win(mixFile, t, 5), win(srcFile, t, 5), 0.2, 4.6)).toBeGreaterThan(0.99);
    }
    // No English under the dub, deep into the film.
    expect(toneDb(win(mixFile, 1000, 4), 1200, 0.5, 3.5)).toBeLessThan(toneDb(win(srcFile, 1000, 4), 1200, 0.5, 3.5) - 30);
    console.log(`[faithful long-form] 21 min mixed in ${Math.round(elapsed / 1000)} s`);
  }, 600000);

  // DUBBING_BED_MATCH (2026-11-25): a separated background that came out 4 dB too quiet with its
  // 495 Hz music cut by 6 dB (like Demucs on run …4954895) is corrected from the speech-free audio.
  itFfmpeg("bed match: a weak, dull separated background is brought back to the original under the dialogue", async () => {
    run(["-i", put("bed.mp3"), "-af", "equalizer=f=495:t=q:w=4:g=-6,volume=-4dB", "-c:a", "libmp3lame", "-b:a", "256k", put("bed_weak.mp3")]);
    const mix = async (id: string, on: boolean) => {
      const prev = process.env.DUBBING_BED_MATCH;
      if (on) process.env.DUBBING_BED_MATCH = "true"; else delete process.env.DUBBING_BED_MATCH;
      try {
        return await mediaService.mixDubFaithful(id, "te", {
          sourceAudioUrl: gs("source.mp3"),
          dubbedAudioUrl: gs("dub.mp3"),
          bedUrl: gs("bed_weak.mp3"),
          isolatedVocalUrl: gs("vocals.mp3"),
          lines,
          totalDurationMs: 12000,
          toneMatch: false,
        });
      } finally {
        if (prev === undefined) delete process.env.DUBBING_BED_MATCH; else process.env.DUBBING_BED_MATCH = prev;
      }
    };
    const off = await mix("job_bed_off", false);
    const on = await mix("job_bed_on", true);
    expect(off.ok).toBe(true);
    expect(on.ok).toBe(true);
    expect(off.bgmReport?.bedMatch ?? null).toBeNull();
    expect(on.bgmReport?.bedMatch?.applied).toBe(true);
    expect(on.bgmReport!.bedMatch!.gainDb).toBeGreaterThan(2.5);

    const [sl, sr] = decodeStereo(path.join(gcsRoot, "in/source.mp3"));
    const [offL, offR] = decodeStereo(path.join(gcsRoot, "audio/job_bed_off/te/master_faithful.mp3"));
    const [onL, onR] = decodeStereo(path.join(gcsRoot, "audio/job_bed_on/te/master_faithful.mp3"));
    // Without the correction the music under the dialogue is ~4 dB low (330 Hz) and ~10 dB low (495 Hz).
    expect(toneDb(offL, 330, 3.5, 5.5)).toBeLessThan(toneDb(sl, 330, 3.5, 5.5) - 3);
    // With it: within 1.5 dB at 330 Hz, and the cut 495 Hz much closer than without.
    expect(Math.abs(toneDb(onL, 330, 3.5, 5.5) - toneDb(sl, 330, 3.5, 5.5))).toBeLessThan(1.5);
    const err495Off = Math.abs(toneDb(offR, 495, 3.5, 5.5) - toneDb(sr, 495, 3.5, 5.5));
    const err495On = Math.abs(toneDb(onR, 495, 3.5, 5.5) - toneDb(sr, 495, 3.5, 5.5));
    expect(err495On).toBeLessThan(err495Off - 3);
    // Outside the dialogue nothing changes: still the original.
    expect(Math.abs(on.outsideDiffDb ?? 99)).toBeLessThan(0.3);
    expect(corr(onL, sl, 7.0, 11.8)).toBeGreaterThan(0.99);
    // Still no English under the dub.
    expect(toneDb(onL, 1200, 3.5, 5.5)).toBeLessThan(toneDb(sl, 1200, 3.5, 5.5) - 30);
  }, 180000);

  itFfmpeg("refuses (ok=false) when the inputs are unusable, so the caller keeps the previous mixer", async () => {
    const res = await mediaService.mixDubFaithful("job_faithful_bad", "te", {
      sourceAudioUrl: gs("source.mp3"),
      dubbedAudioUrl: gs("does-not-exist.mp3"),
      bedUrl: null,
      lines,
      totalDurationMs: 12000,
    });
    expect(res.ok).toBe(false);
    expect(res.url).toBeNull();
    expect(res.reason).toBeTruthy();
  }, 60000);

  describe("Faithful mix extensions (room matching, scene tone, tight stem, voice ride)", () => {
    const origEnv = { ...process.env };
    afterEach(() => {
      process.env = { ...origEnv };
    });

    it("Room estimate: synthetic voice convolved with known RT60 estimated within tolerance, dry/few offsets return null", () => {
      const sr = 8000;
      const totalSamples = sr * 4;
      const pcm = new Float32Array(totalSamples);
      // Two speech bursts: 200..800 ms and 1500..2100 ms
      for (let i = Math.round(0.2 * sr); i < Math.round(0.8 * sr); i++) {
        pcm[i] = 0.5 * Math.sin((2 * Math.PI * 300 * i) / sr);
      }
      for (let i = Math.round(1.5 * sr); i < Math.round(2.1 * sr); i++) {
        pcm[i] = 0.5 * Math.sin((2 * Math.PI * 450 * i) / sr);
      }

      // Add reverb tail with known RT60 = 400 ms, DRR = 10 dB
      const tau = 0.4 / 6.907755;
      const wetAmp = Math.pow(10, -10 / 20) * 0.5;
      for (let i = Math.round(0.8 * sr); i < Math.round(1.4 * sr); i++) {
        const t = (i - Math.round(0.8 * sr)) / sr;
        pcm[i] = wetAmp * (Math.random() * 2 - 1) * Math.exp(-t / tau);
      }
      for (let i = Math.round(2.1 * sr); i < Math.round(2.7 * sr); i++) {
        const t = (i - Math.round(2.1 * sr)) / sr;
        pcm[i] = wetAmp * (Math.random() * 2 - 1) * Math.exp(-t / tau);
      }

      const region = { startMs: 0, endMs: 3000 };
      const spans = [
        { startMs: 200, endMs: 800 },
        { startMs: 1500, endMs: 2100 },
      ];

      // 1. Known RT60 estimation
      const est = estimateRegionRoom(pcm, sr, region, spans, 0);
      expect(est).not.toBeNull();
      expect(Math.abs(est!.rt60Ms - 400)).toBeLessThanOrEqual(50);
      expect(est!.cleanOffsetsCount).toBe(2);

      // 2. Dry input returns null
      const dryPcm = new Float32Array(totalSamples);
      for (let i = Math.round(0.2 * sr); i < Math.round(0.8 * sr); i++) {
        dryPcm[i] = 0.5 * Math.sin((2 * Math.PI * 300 * i) / sr);
      }
      for (let i = Math.round(1.5 * sr); i < Math.round(2.1 * sr); i++) {
        dryPcm[i] = 0.5 * Math.sin((2 * Math.PI * 450 * i) / sr);
      }
      expect(estimateRegionRoom(dryPcm, sr, region, spans, 0)).toBeNull();

      // 3. Too few offsets (< 2) returns null
      const singleSpan = [{ startMs: 200, endMs: 2500 }];
      expect(estimateRegionRoom(pcm, sr, region, singleSpan, 0)).toBeNull();
    });

    it("Scene tone: two synthetic scenes get different EQ corrections, short scene falls back to speaker-wide", () => {
      const dubProfile = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      const scene0Ref = [0, 0, 0, 0, 0, 0, 0, 4, 4, 4];
      const scene1Ref = [5, 5, 5, 0, 0, 0, 0, 0, 0, 0];
      const speakerRef = [2.5, 2.5, 2.5, 0, 0, 0, 0, 2, 2, 2];

      const eqScene0 = eqCorrectionDb(scene0Ref, dubProfile);
      const eqScene1 = eqCorrectionDb(scene1Ref, dubProfile);
      const eqSpeaker = eqCorrectionDb(speakerRef, dubProfile);

      expect(eqScene0).not.toBeNull();
      expect(eqScene1).not.toBeNull();
      expect(eqScene0).not.toEqual(eqScene1);

      const shortSceneSpeechSec = 1.5;
      const chosenEq = shortSceneSpeechSec >= 3.0 ? eqScene0 : eqSpeaker;
      expect(chosenEq).toEqual(eqSpeaker);
    });

    it("Tight stem: stem time drops on fixture where dub and original speech don't fully overlap", () => {
      const regions = [{ startMs: 0, endMs: 5000 }];
      const origVoice = [{ startMs: 1200, endMs: 2200 }];

      const tight = buildTightStemSpans(regions, origVoice, 100);
      expect(tight).toEqual([{ startMs: 1100, endMs: 2300 }]);

      const stemMsBefore = regions.reduce((sum, r) => sum + (r.endMs - r.startMs), 0);
      const stemMsAfter = tight.reduce((sum, s) => sum + (s.endMs - s.startMs), 0);
      expect(stemMsBefore).toBe(5000);
      expect(stemMsAfter).toBe(1200);
      expect(stemMsAfter).toBeLessThan(stemMsBefore);

      const sr = 8000;
      const bed = new Float32Array(sr * 4);
      for (let i = 0; i < sr; i++) bed[i] = 0.005 * (Math.random() * 2 - 1);
      for (let i = sr * 2; i < sr * 3; i++) bed[i] = 0.4 * (Math.random() * 2 - 1);

      expect(adaptiveFadeMs(bed, sr, 500)).toBe(80);
      expect(adaptiveFadeMs(bed, sr, 2500)).toBeGreaterThan(200);
    });

    it("Voice ride: envelope stays within ±3 dB and never lowers the background music", () => {
      const sr = 8000;
      const bed = new Float32Array(sr * 4);
      for (let i = 0; i < sr; i++) bed[i] = 0.05 * Math.sin((2 * Math.PI * 400 * i) / sr);
      for (let i = sr; i < sr * 2; i++) bed[i] = 0.20 * Math.sin((2 * Math.PI * 400 * i) / sr);
      for (let i = sr * 2; i < sr * 3; i++) bed[i] = 0.01 * Math.sin((2 * Math.PI * 400 * i) / sr);

      const line = { startMs: 500, endMs: 3000 };
      const baseGain = 1.0;
      const env = computeVoiceRideEnvelope(bed, sr, line, baseGain, 1000);

      const minGain = Math.min(...env);
      const maxGain = Math.max(...env);
      const minDb = 20 * Math.log10(minGain);
      const maxDb = 20 * Math.log10(maxGain);

      expect(minDb).toBeGreaterThanOrEqual(-3.05);
      expect(maxDb).toBeLessThanOrEqual(3.05);

      const baseEnvelopes = buildEnvelopes({
        regions: [{ startMs: 0, endMs: 4000 }],
        gainSpans: [{ startMs: 500, endMs: 3000, gain: 1.0 }],
        totalMs: 4000,
        branches: [{ speakers: ["A"], eqFilter: null }],
        voiceRideCurves: [{ spanIndex: 0, curve: env }],
      });
      expect(baseEnvelopes.bed[1000]).toBeCloseTo(1.0, 2);
    });

    it("Each flag OFF: output graph and envelopes are identical to baseline", () => {
      const branches: DubBranch[] = [
        { speakers: ["A"], eqFilter: "firequalizer=gain_entry='entry(1000,2)':delay=0.01,atrim=start_sample=441,asetpts=N/SR/TB" },
        { speakers: ["B"], eqFilter: null },
      ];
      const regions = [{ startMs: 1000, endMs: 4000 }];
      const gainSpans = [
        { startMs: 1000, endMs: 2000, gain: 0.8, speaker: "A" },
        { startMs: 2500, endMs: 3800, gain: 1.2, speaker: "B" },
      ];

      const baselineGraph = buildFaithfulMixGraph({ hasBed: true, branches });
      const testGraph = buildFaithfulMixGraph({ hasBed: true, branches, firstEnvIndex: undefined });
      expect(testGraph).toBe(baselineGraph);

      const baselineEnv = buildEnvelopes({ regions, gainSpans, totalMs: 5000, branches });
      const testEnv = buildEnvelopes({
        regions,
        gainSpans,
        totalMs: 5000,
        branches,
        tightStemSpans: undefined,
        voiceRideCurves: undefined,
      });

      expect(Array.from(testEnv.orig)).toEqual(Array.from(baselineEnv.orig));
      expect(Array.from(testEnv.bed)).toEqual(Array.from(baselineEnv.bed));
      expect(testEnv.dub.length).toBe(baselineEnv.dub.length);
      for (let i = 0; i < testEnv.dub.length; i++) {
        expect(Array.from(testEnv.dub[i])).toEqual(Array.from(baselineEnv.dub[i]));
      }
    });

    itFfmpeg("Reverb branch: real FFmpeg run keeps outside matching within 0.5 dB and voice onset timing unchanged", async () => {
      process.env.DUBBING_ROOM_MATCH = "true";
      const enc = ["-c:a", "libmp3lame", "-b:a", "256k"];

      run(["-f", "lavfi", "-i", "aevalsrc='0.15*sin(2*PI*330*t)|0.15*sin(2*PI*495*t)':s=44100:d=12", ...enc, put("rev_bed.mp3")]);
      const on = "between(t,2,3.5)+between(t,6,7.5)";
      run(["-f", "lavfi", "-i", `aevalsrc='0.3*sin(2*PI*800*t)*(${on})':s=44100:d=12`, ...enc, put("rev_clean_voc.mp3")]);
      run(["-i", put("rev_clean_voc.mp3"), "-af", "aecho=0.8:0.7:100:0.3", ...enc, put("rev_vocals.mp3")]);
      run(["-i", put("rev_bed.mp3"), "-i", put("rev_vocals.mp3"), "-filter_complex", "[0][1]amix=inputs=2:normalize=0", ...enc, put("rev_source.mp3")]);
      run(["-f", "lavfi", "-i", `aevalsrc='0.25*sin(2*PI*700*t)*(${on})':s=44100:d=12`, "-ac", "2", ...enc, put("rev_dub.mp3")]);

      const revLines = [
        { speaker: "A", startMs: 2000, endMs: 3500 },
        { speaker: "A", startMs: 6000, endMs: 7500 },
      ];

      const res = await mediaService.mixDubFaithful("job_faithful_reverb", "te", {
        sourceAudioUrl: gs("rev_source.mp3"),
        dubbedAudioUrl: gs("rev_dub.mp3"),
        bedUrl: gs("rev_bed.mp3"),
        isolatedVocalUrl: gs("rev_vocals.mp3"),
        lines: revLines,
        totalDurationMs: 12000,
      });

      expect(res.ok).toBe(true);
      expect(Math.abs(res.outsideDiffDb ?? 99)).toBeLessThanOrEqual(0.5);

      const [ml] = decodeStereo(path.join(gcsRoot, "audio/job_faithful_reverb/te/master_faithful.mp3"));
      const [dl] = decodeStereo(path.join(gcsRoot, "in/rev_dub.mp3"));
      let best = 0;
      let bestLag = 0;
      const a0 = Math.round(2.1 * 44100);
      for (let lag = -20; lag <= 20; lag++) {
        let s = 0;
        for (let i = 0; i < 4410; i++) s += dl[a0 + i] * ml[a0 + i + lag];
        if (Math.abs(s) > Math.abs(best)) {
          best = s;
          bestLag = lag;
        }
      }
      expect(Math.abs(bestLag)).toBeLessThanOrEqual(2);
    }, 120000);

    it("All new BGM preservation flags default to OFF", () => {
      const cleanEnv: Record<string, string | undefined> = {};
      expect(tightStemEnabled(cleanEnv)).toBe(false);
      expect(keepNonVerbalEnabled(cleanEnv)).toBe(false);
      expect(fidelityStemSelectEnabled(cleanEnv)).toBe(false);
      expect(voiceRideEnabled(cleanEnv)).toBe(false);
    });

    it("Tight stem with word timings + equal-power <= 30ms fade: keeps pauses on original and maintains constant power", () => {
      const regions = [{ startMs: 0, endMs: 5000 }];
      const origVoice = [
        { startMs: 500, endMs: 1200 },
        { startMs: 2500, endMs: 2800 }, // non-verbal gasp (no word!)
        { startMs: 3600, endMs: 4400 },
      ];
      const words = [
        { startMs: 520, endMs: 1180 },
        { startMs: 3620, endMs: 4380 },
      ];
      const tight = buildTightStemSpans(regions, origVoice, 100, { words, mergeGapMs: 80 });
      expect(tight).toEqual([
        { startMs: 400, endMs: 1300 },
        { startMs: 3500, endMs: 4500 },
      ]);

      const env = buildEnvelopes({
        regions,
        gainSpans: [{ startMs: 500, endMs: 4400, gain: 1.0, speaker: "A" }],
        totalMs: 5000,
        branches: [{ speakers: ["A"], eqFilter: null }],
        tightStemSpans: tight,
        stemFadesMs: tight.map(() => ({ startFadeMs: TIGHT_STEM_FADE_MS, endFadeMs: TIGHT_STEM_FADE_MS })),
        equalPowerTightFade: true,
      });

      expect(TIGHT_STEM_FADE_MS).toBeLessThanOrEqual(30);
      for (let k = 0; k < 5000; k++) {
        const power = env.orig[k] * env.orig[k] + env.bed[k] * env.bed[k];
        expect(power).toBeCloseTo(1.0, 5);
      }
      // At t = 2650 ms (the non-verbal gasp with no word), original audio is 100% active.
      expect(env.orig[2650]).toBeCloseTo(1.0, 5);
      expect(env.bed[2650]).toBeCloseTo(0.0, 5);
    });

    it("Non-verbal detection: keeps gasps/grunts without words outside dub, never lets transcribed words through", () => {
      const sr = 8000;
      const vocPcm = new Float32Array(sr * 6);
      // Spoken word at 1000..1800 ms
      for (let i = 1.0 * sr; i < 1.8 * sr; i++) vocPcm[i] = 0.4 * Math.sin((2 * Math.PI * 300 * i) / sr);
      // Non-verbal gasp at 2500..2900 ms (no word, no dub)
      for (let i = 2.5 * sr; i < 2.9 * sr; i++) vocPcm[i] = 0.35 * Math.sin((2 * Math.PI * 500 * i) / sr);
      // Non-verbal grunt at 4200..4600 ms overlapping a dub line
      for (let i = 4.2 * sr; i < 4.6 * sr; i++) vocPcm[i] = 0.35 * Math.sin((2 * Math.PI * 250 * i) / sr);

      const kept = detectNonVerbalSpans({
        vocPcm,
        sampleRate: sr,
        words: [{ startMs: 1000, endMs: 1800 }],
        dubActive: [{ startMs: 4000, endMs: 4800 }],
        totalMs: 6000,
      });

      expect(kept.length).toBe(1);
      expect(kept[0].startMs).toBeGreaterThanOrEqual(2450);
      expect(kept[0].endMs).toBeLessThanOrEqual(2950);
      expect(kept[0].reason).toBe("vocal_energy_no_word_outside_dub");
    });

    it("Gap fidelity & edge step measurements: identical stem reads ~0 dB delta; attenuated stem is flagged", () => {
      const sr = 8000;
      const orig = new Float32Array(sr * 4);
      for (let i = 0; i < orig.length; i++) {
        orig[i] = 0.2 * Math.sin((2 * Math.PI * 250 * i) / sr) + 0.1 * Math.sin((2 * Math.PI * 1200 * i) / sr);
      }
      const gaps = [{ startMs: 500, endMs: 2500 }];
      const identical = measureGapFidelity(orig, orig, sr, gaps);
      expect(identical.loudnessDeltaDb).toBeCloseTo(0, 1);
      expect(identical.meanAbsBandDeltaDb).toBeCloseTo(0, 1);

      const quietStem = orig.map((v) => v * 0.5); // -6 dB
      const attenuated = measureGapFidelity(orig, quietStem, sr, gaps);
      expect(attenuated.loudnessDeltaDb).toBeCloseTo(-6.02, 0);

      const edgeErr = measureEdgeStepsDb(orig, orig, sr, [1000, 2000], [], 4000);
      expect(edgeErr).toBe(0);
    });

    it("Voice ride leaves orig and bed envelopes byte-identical to no-ride", () => {
      const regions = [{ startMs: 500, endMs: 3500 }];
      const gainSpans = [{ startMs: 600, endMs: 3400, gain: 1.0, speaker: "A" }];
      const branches: DubBranch[] = [{ speakers: ["A"], eqFilter: null }];
      const rideCurve = new Float32Array(2800).fill(1.2);

      const withoutRide = buildEnvelopes({ regions, gainSpans, totalMs: 4000, branches });
      const withRide = buildEnvelopes({
        regions,
        gainSpans,
        totalMs: 4000,
        branches,
        voiceRideCurves: [{ spanIndex: 0, curve: rideCurve }],
      });

      expect(Array.from(withRide.orig)).toEqual(Array.from(withoutRide.orig));
      expect(Array.from(withRide.bed)).toEqual(Array.from(withoutRide.bed));
    });

    itFfmpeg("Tight stem + keep non-verbal: real FFmpeg run populates bgmReport and passes all gates", async () => {
      process.env.DUBBING_TIGHT_STEM = "true";
      process.env.DUBBING_KEEP_NONVERBAL = "true";
      const enc = ["-c:a", "libmp3lame", "-b:a", "256k"];

      // Continuous music bed (10s)
      run(["-f", "lavfi", "-i", "aevalsrc='0.25*sin(2*PI*220*t)|0.25*sin(2*PI*330*t)':s=44100:d=10", ...enc, put("ts_bed.mp3")]);
      // Vocals: spoken word at 2.0-3.2s and 6.0-7.2s, plus non-verbal gasp at 4.2-4.6s
      const vocExpr = "0.30*sin(2*PI*600*t)*(between(t,2.0,3.2)+between(t,4.2,4.6)+between(t,6.0,7.2))";
      run(["-f", "lavfi", "-i", `aevalsrc='${vocExpr}':s=44100:d=10`, ...enc, put("ts_vocals.mp3")]);
      run(["-i", put("ts_bed.mp3"), "-i", put("ts_vocals.mp3"), "-filter_complex", "[0][1]amix=inputs=2:normalize=0", ...enc, put("ts_source.mp3")]);
      // Dubbed speech only at 2.0-3.1s and 6.0-7.1s (leaves 4.2-4.6s gasp free!)
      const dubExpr = "0.30*sin(2*PI*500*t)*(between(t,2.0,3.1)+between(t,6.0,7.1))";
      run(["-f", "lavfi", "-i", `aevalsrc='${dubExpr}':s=44100:d=10`, "-ac", "2", ...enc, put("ts_dub.mp3")]);

      const res = await mediaService.mixDubFaithful("job_tight_nv", "te", {
        sourceAudioUrl: gs("ts_source.mp3"),
        dubbedAudioUrl: gs("ts_dub.mp3"),
        bedUrl: gs("ts_bed.mp3"),
        isolatedVocalUrl: gs("ts_vocals.mp3"),
        lines: [
          { speaker: "A", startMs: 2000, endMs: 3200 },
          { speaker: "A", startMs: 4100, endMs: 7200 },
        ],
        sourceWords: [
          { startMs: 2000, endMs: 3200 },
          { startMs: 6000, endMs: 7200 },
        ],
        totalDurationMs: 10000,
      });

      expect(res.ok).toBe(true);
      expect(res.bgmReport).toBeDefined();
      expect(Math.abs(res.bgmReport!.outsideDiffDb ?? 99)).toBeLessThanOrEqual(0.5);
      expect(res.bgmReport!.stemSeconds).toBeLessThan(res.regionMs / 1000);
      expect(res.bgmReport!.nonVerbalKept.count).toBeGreaterThanOrEqual(1);
      expect(res.bgmReport!.edgeStepsDb ?? 0).toBeLessThanOrEqual(1.2);
      expect(Math.abs(res.bgmReport!.backgroundLevelDeltaDb ?? 99)).toBeLessThanOrEqual(1.0);
    }, 120000);
  });
});

describe("bed match planning (pure)", () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const fm = require("../../src/pipeline/services/faithful-mix");
  it("is off unless DUBBING_BED_MATCH=true", () => {
    expect(fm.bedMatchEnabled({})).toBe(false);
    expect(fm.bedMatchEnabled({ DUBBING_BED_MATCH: "true" })).toBe(true);
  });
  it("speech-free spans exclude lines, words and voice activity with a guard, and drop short gaps", () => {
    const free = fm.speechFreeSpans(10000, [{ startMs: 2000, endMs: 4000 }, { startMs: 4300, endMs: 4500 }, { startMs: 7000, endMs: 7100 }]);
    expect(free).toEqual([
      { startMs: 0, endMs: 1850 },
      { startMs: 4650, endMs: 6850 },
      { startMs: 7250, endMs: 10000 },
    ]);
  });
  it("needs 3 s of speech-free audio and a measurable level", () => {
    expect(fm.planBedMatch({ gapSeconds: 2, originalProfile: null, bedProfile: null, originalDb: -20, bedDb: -24 }).applied).toBe(false);
    expect(fm.planBedMatch({ gapSeconds: 5, originalProfile: null, bedProfile: null, originalDb: null, bedDb: -24 }).applied).toBe(false);
  });
  it("corrects each band by original − bed, bounded to ±6 dB, and skips tiny differences", () => {
    const orig = Array(9).fill(-30);
    const big = fm.planBedMatch({ gapSeconds: 5, originalProfile: orig, bedProfile: Array(9).fill(-50), originalDb: -20, bedDb: -40 });
    expect(big.applied).toBe(true);
    expect(big.bandsDb).toEqual(Array(9).fill(6));
    expect(big.gainDb).toBe(6);
    expect(big.filter).toMatch(/^firequalizer=/);
    const tiny = fm.planBedMatch({ gapSeconds: 5, originalProfile: orig, bedProfile: Array(9).fill(-30.2), originalDb: -20, bedDb: -20.2 });
    expect(tiny.applied).toBe(false);
  });
  it("a band the separation dulled is lifted; the others are left alone", () => {
    const orig = [-30, -30, -30, -30, -30, -30, -30, -30, -30];
    const bed = [-30, -30, -30, -30, -42, -30, -30, -30, -30]; // one band 12 dB low
    const plan = fm.planBedMatch({ gapSeconds: 5, originalProfile: orig, bedProfile: bed, originalDb: -20, bedDb: -21 });
    expect(plan.applied).toBe(true);
    expect(plan.bandsDb).toEqual([0, 0, 0, 0, 6, 0, 0, 0, 0]);
  });
  it("near-empty bands (codec noise, > 40 dB under the loudest band) are never corrected", () => {
    const orig = [-30, -30, -95, -30, -30, -30, -30, -30, -30];
    const bed = [-30, -30, -110, -30, -30, -30, -30, -30, -30];
    const plan = fm.planBedMatch({ gapSeconds: 5, originalProfile: orig, bedProfile: bed, originalDb: -20, bedDb: -20 });
    expect(plan.applied).toBe(false);
    expect(plan.bandsDb[2]).toBe(0);
  });
  it("the mix graph applies the correction to the bed input only", () => {
    const g = fm.buildFaithfulMixGraph({ hasBed: true, branches: [{ speakers: ["A"], eqFilter: null }], bedFilter: "volume=3dB" });
    expect(g).toMatch(/\[2:a\][^;]*volume=3dB\[s_bed\]/);
    expect(g).not.toMatch(/\[0:a\][^;]*volume=3dB/);
    const plain = fm.buildFaithfulMixGraph({ hasBed: true, branches: [{ speakers: ["A"], eqFilter: null }] });
    expect(plain).not.toMatch(/volume=/);
  });
  it("non-verbal carve-out uses gains that sum to 1 (linear: original and bed are correlated)", () => {
    const env = fm.buildEnvelopes({
      regions: [{ startMs: 1000, endMs: 4000 }],
      gainSpans: [{ startMs: 1000, endMs: 4000, gain: 1, speaker: "A" }],
      totalMs: 5000,
      branches: [{ speakers: ["A"], eqFilter: null }],
      nonVerbalKeepSpans: [{ startMs: 2000, endMs: 2400 }],
    });
    for (let k = 0; k < env.orig.length; k++) expect(env.orig[k] + env.bed[k]).toBeCloseTo(1, 5);
  });
});
