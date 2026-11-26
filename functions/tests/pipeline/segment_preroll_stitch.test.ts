/**
 * Early start instead of trim, through the real stitcher (MediaService.mergeAudioChunks + FFmpeg).
 * Line 1 (3.0 s of tone for a 2.0 s turn) still overflows after the 1.15x tempo cap. With
 * DUBBING_PREROLL=true it starts up to 300 ms earlier (into the silence after line 0); without the
 * flag it starts on time and is trimmed at the next turn, as before.
 */
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { execFileSync } from "child_process";
import * as admin from "firebase-admin";
import { MediaService, getFfmpegPath } from "../../src/pipeline/services/media";

const ffmpeg = getFfmpegPath();
const itFfmpeg = ffmpeg ? it : it.skip;

describe("stitcher with DUBBING_PREROLL", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "preroll-"));
  const files: Record<string, string> = {};
  let saved: Buffer | null = null;
  const prevFlag = process.env.DUBBING_PREROLL;

  beforeAll(() => {
    if (!ffmpeg) return;
    const tone = (name: string, sec: number, hz: number) => {
      const p = path.join(dir, name);
      execFileSync(ffmpeg, ["-y", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", `sine=f=${hz}:d=${sec}`, "-c:a", "libmp3lame", "-b:a", "128k", p]);
      files[`chunks/${name}`] = p;
    };
    tone("l0.mp3", 1.0, 300);
    tone("l1.mp3", 3.0, 500);
    tone("l2.mp3", 0.5, 700);
    jest.spyOn(admin, "storage").mockImplementation((() => ({
      bucket: () => ({
        name: "test-bucket",
        file: (p: string) => ({
          exists: async () => [true],
          download: async (opts?: { destination?: string }) => {
            const data = fs.readFileSync(files[p]);
            if (opts?.destination) {
              fs.writeFileSync(opts.destination, data);
              return [];
            }
            return [data];
          },
          save: async (buf: Buffer) => {
            saved = buf;
          },
        }),
      }),
    })) as any);
  });

  afterAll(() => {
    jest.restoreAllMocks();
    fs.rmSync(dir, { recursive: true, force: true });
    if (prevFlag === undefined) delete process.env.DUBBING_PREROLL;
    else process.env.DUBBING_PREROLL = prevFlag;
  });

  /** RMS (dBFS) of the stitched track between two times. */
  const rmsDb = (mp3: Buffer, fromMs: number, toMs: number): number => {
    const p = path.join(dir, `out_${Date.now()}.mp3`);
    fs.writeFileSync(p, mp3);
    const pcm = execFileSync(ffmpeg!, ["-v", "error", "-i", p, "-ac", "1", "-ar", "8000", "-f", "f32le", "pipe:1"], { maxBuffer: 64 * 1024 * 1024 });
    const s = new Float32Array(pcm.buffer, pcm.byteOffset, Math.floor(pcm.length / 4));
    let sum = 0;
    let n = 0;
    for (let i = Math.floor((fromMs / 1000) * 8000); i < Math.floor((toMs / 1000) * 8000) && i < s.length; i++) {
      sum += s[i] * s[i];
      n++;
    }
    return 10 * Math.log10(sum / Math.max(1, n) + 1e-12);
  };

  const stitch = async (flag: boolean): Promise<Buffer> => {
    if (flag) process.env.DUBBING_PREROLL = "true";
    else delete process.env.DUBBING_PREROLL;
    saved = null;
    await new MediaService().mergeAudioChunks(
      "job_preroll",
      ["gs://test-bucket/chunks/l0.mp3", "gs://test-bucket/chunks/l1.mp3", "gs://test-bucket/chunks/l2.mp3"],
      "te",
      {
        segments: [
          { start: 0, end: 1500 },
          { start: 2000, end: 4000 },
          { start: 4200, end: 5000 },
        ],
        totalDurationMs: 6000,
      }
    );
    expect(saved).not.toBeNull();
    return saved as unknown as Buffer;
  };

  itFfmpeg("flag on: the long line starts ~300 ms early; flag off: silence there as before", async () => {
    const on = await stitch(true);
    const off = await stitch(false);
    // 1750–1950 ms lies inside the 300 ms early start (1700–2000) and after line 0 ends (1000).
    expect(rmsDb(on, 1750, 1950)).toBeGreaterThan(-30);
    expect(rmsDb(off, 1750, 1950)).toBeLessThan(-50);
    // Neither version runs into line 2's turn (4080–4200 ms is kept clear by the 120 ms separation).
    expect(rmsDb(on, 4100, 4180)).toBeLessThan(-40);
    expect(rmsDb(off, 4100, 4180)).toBeLessThan(-40);
  }, 60000);
});
