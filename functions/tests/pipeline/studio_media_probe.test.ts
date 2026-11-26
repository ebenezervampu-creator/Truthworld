import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { Readable } from "stream";
import {
  parseRangeHeader,
  probeIsobmffDurationMs,
  withLoopbackRangeProxy,
} from "../../src/dubbing/studio-media-probe";
import { execFileAsync, getFfmpegPath, mediaService } from "../../src/pipeline/services/media";

function makeAtom(type: string, payload: Buffer): Buffer {
  const header = Buffer.alloc(8);
  header.writeUInt32BE(8 + payload.length, 0);
  header.write(type, 4, 4, "ascii");
  return Buffer.concat([header, payload]);
}

function makeLargeAtom(type: string, payload: Buffer): Buffer {
  const header = Buffer.alloc(16);
  header.writeUInt32BE(1, 0);
  header.write(type, 4, 4, "ascii");
  const totalSize = 16 + payload.length;
  header.writeUInt32BE(Math.floor(totalSize / 0x100000000), 8);
  header.writeUInt32BE(totalSize >>> 0, 12);
  return Buffer.concat([header, payload]);
}

function makeMvhdV0(timescale: number, duration: number): Buffer {
  const payload = Buffer.alloc(100);
  payload.writeUInt8(0, 0); // version 0
  payload.writeUInt32BE(timescale, 12);
  payload.writeUInt32BE(duration, 16);
  return makeAtom("mvhd", payload);
}

function makeMvhdV1(timescale: number, duration: number): Buffer {
  const payload = Buffer.alloc(112);
  payload.writeUInt8(1, 0); // version 1
  payload.writeUInt32BE(timescale, 20);
  payload.writeUInt32BE(Math.floor(duration / 0x100000000), 24);
  payload.writeUInt32BE(duration >>> 0, 28);
  return makeAtom("mvhd", payload);
}

describe("studio-media-probe", () => {
  describe("parseRangeHeader", () => {
    it("parses open-ended, bounded, and suffix ranges", () => {
      expect(parseRangeHeader("bytes=0-", 1000)).toEqual({ start: 0, end: 999 });
      expect(parseRangeHeader("bytes=100-199", 1000)).toEqual({ start: 100, end: 199 });
      expect(parseRangeHeader("bytes=900-5000", 1000)).toEqual({ start: 900, end: 999 });
      expect(parseRangeHeader("bytes=-64", 1000)).toEqual({ start: 936, end: 999 });
    });

    it("rejects out-of-bounds or invalid ranges cleanly", () => {
      expect(parseRangeHeader(undefined, 1000)).toBeNull();
      expect(parseRangeHeader("items=0-10", 1000)).toBeNull();
      expect(parseRangeHeader("bytes=1000-1010", 1000)).toBe("unsatisfiable");
      expect(parseRangeHeader("bytes=500-400", 1000)).toBe("unsatisfiable");
      expect(parseRangeHeader("bytes=-0", 1000)).toBe("unsatisfiable");
    });
  });

  describe("probeIsobmffDurationMs", () => {
    it("reads v0 mvhd duration even when moov is after a large mdat", async () => {
      const ftyp = makeAtom("ftyp", Buffer.from("isom\x00\x00\x02\x00isommp41", "binary"));
      const mdat = makeAtom("mdat", Buffer.alloc(4096));
      const mvhd = makeMvhdV0(1000, 32450); // 32.45s
      const tkhd = makeAtom("tkhd", Buffer.alloc(84));
      const moov = makeAtom("moov", Buffer.concat([tkhd, mvhd]));
      const mp4 = Buffer.concat([ftyp, mdat, moov]);

      let rangeReads = 0;
      const ms = await probeIsobmffDurationMs(async (start, end) => {
        rangeReads++;
        return mp4.subarray(start, end + 1);
      }, mp4.length);

      expect(ms).toBe(32450);
      expect(rangeReads).toBeLessThanOrEqual(8);
    });

    it("reads v1 64-bit mvhd inside a 64-bit extended-size moov box", async () => {
      const ftyp = makeAtom("ftyp", Buffer.from("qt  \x00\x00\x00\x00qt  ", "binary"));
      const mvhd = makeMvhdV1(600, 3600 * 600); // 1 hour
      const moov = makeLargeAtom("moov", mvhd);
      const mov = Buffer.concat([ftyp, moov]);

      const ms = await probeIsobmffDurationMs(
        async (start, end) => mov.subarray(start, end + 1),
        mov.length
      );
      expect(ms).toBe(3600000);
    });

    it("returns 0 safely for non-ISOBMFF data", async () => {
      const garbage = Buffer.from("not an mp4 file at all");
      const ms = await probeIsobmffDurationMs(
        async (start, end) => garbage.subarray(start, end + 1),
        garbage.length
      );
      expect(ms).toBe(0);
    });
  });

  describe("withLoopbackRangeProxy + mediaService.probeMediaDurationMs", () => {
    it("probes a real MP4 with moov at the end over 127.0.0.1 range requests", async () => {
      const ffmpegPath = getFfmpegPath();
      if (!ffmpegPath) return;

      const tmpMp4 = path.join(os.tmpdir(), `studio_probe_test_${Date.now()}.mp4`);
      try {
        // Generate a real 3-second silent MP4 (without faststart, so moov is at the end)
        await execFileAsync(ffmpegPath, [
          "-y",
          "-f", "lavfi",
          "-i", "anullsrc=r=44100:cl=mono",
          "-t", "3",
          "-c:a", "aac",
          tmpMp4,
        ]);
        const bytes = await fs.promises.readFile(tmpMp4);

        const probedMs = await withLoopbackRangeProxy(
          {
            size: bytes.length,
            contentType: "video/mp4",
            createReadStream: (start, end) =>
              Readable.from(
                start !== undefined && end !== undefined ? bytes.subarray(start, end + 1) : bytes
              ),
          },
          (localUrl) => mediaService.probeMediaDurationMs(localUrl)
        );

        expect(probedMs).toBeGreaterThanOrEqual(2800);
        expect(probedMs).toBeLessThanOrEqual(3300);
      } finally {
        await fs.promises.unlink(tmpMp4).catch(() => {});
      }
    });
  });
});
