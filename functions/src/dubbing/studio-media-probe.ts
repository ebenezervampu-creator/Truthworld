import * as admin from "firebase-admin";
import * as fs from "fs";
import * as http from "http";
import * as os from "os";
import * as path from "path";
import { Readable } from "stream";
import axios from "axios";
import { logger } from "firebase-functions/v2";
import { isSafePublicUrl, mediaService, parseAnyStorageUrl } from "../pipeline/services/media";

/** Max size eligible for bounded /tmp fallback when range-based probing fails (fits within 512MiB RAM). */
const MAX_TMP_FALLBACK_BYTES = 150 * 1024 * 1024;
const MAX_ISOBMFF_BOXES = 512;

export interface ParsedByteRange {
  start: number;
  end: number;
}

export interface RangeStreamSource {
  size: number;
  contentType: string;
  createReadStream: (start?: number, endInclusive?: number) => Readable | Promise<Readable>;
}

/**
 * Parses an HTTP `Range: bytes=...` header against a known total byte length.
 * Returns `null` when the header is missing or malformed, or `"unsatisfiable"` for out-of-bounds ranges.
 */
export function parseRangeHeader(
  rangeHeader: string | undefined,
  totalSize: number
): ParsedByteRange | "unsatisfiable" | null {
  if (!rangeHeader || !Number.isFinite(totalSize) || totalSize <= 0) return null;
  const match = rangeHeader.trim().match(/^bytes=(\d*)-(\d*)$/i);
  if (!match) return null;

  const [, startStr, endStr] = match;
  if (!startStr && !endStr) return null;

  if (!startStr && endStr) {
    const suffix = parseInt(endStr, 10);
    if (!Number.isFinite(suffix) || suffix <= 0) return "unsatisfiable";
    const start = Math.max(0, totalSize - suffix);
    return { start, end: totalSize - 1 };
  }

  const start = parseInt(startStr, 10);
  if (!Number.isFinite(start) || start < 0 || start >= totalSize) {
    return "unsatisfiable";
  }

  if (!endStr) {
    return { start, end: totalSize - 1 };
  }

  const requestedEnd = parseInt(endStr, 10);
  if (!Number.isFinite(requestedEnd) || requestedEnd < start) {
    return "unsatisfiable";
  }

  return { start, end: Math.min(requestedEnd, totalSize - 1) };
}

/**
 * Serves a `RangeStreamSource` over an ephemeral `http://127.0.0.1:<port>/media` server.
 * This keeps FFprobe/FFmpeg off external DNS and TLS (preventing static-glibc NSS/TLS crashes in
 * Cloud Run gVisor) and avoids `getSignedUrl` `signBlob` IAM dependencies.
 */
export async function withLoopbackRangeProxy<T>(
  source: RangeStreamSource,
  fn: (localUrl: string) => Promise<T>
): Promise<T> {
  const server = http.createServer((req, res) => {
    void (async () => {
      try {
        if (req.method !== "GET" && req.method !== "HEAD") {
          res.writeHead(405);
          res.end();
          return;
        }

        const totalSize = source.size;
        const rangeHeader = typeof req.headers.range === "string" ? req.headers.range : undefined;
        const parsedRange = parseRangeHeader(rangeHeader, totalSize);

        if (parsedRange === "unsatisfiable") {
          res.writeHead(416, { "Content-Range": `bytes */${totalSize}` });
          res.end();
          return;
        }

        const isPartial = parsedRange !== null;
        const start = isPartial ? parsedRange.start : 0;
        const end = isPartial ? parsedRange.end : Math.max(0, totalSize - 1);
        const contentLength = totalSize > 0 ? end - start + 1 : 0;

        const headers: Record<string, string | number> = {
          "Accept-Ranges": "bytes",
          "Content-Type": source.contentType || "application/octet-stream",
          "Content-Length": contentLength,
        };
        if (isPartial) {
          headers["Content-Range"] = `bytes ${start}-${end}/${totalSize}`;
        }

        res.writeHead(isPartial ? 206 : 200, headers);
        if (req.method === "HEAD" || contentLength <= 0) {
          res.end();
          return;
        }

        const stream = await source.createReadStream(start, end);
        let clientClosed = false;
        const cleanup = () => {
          clientClosed = true;
          if (!stream.destroyed) {
            stream.destroy();
          }
        };
        req.on("close", cleanup);
        res.on("close", cleanup);
        stream.on("error", (err) => {
          if (!clientClosed) {
            logger.warn("[DubbingStudio:Duration] Range proxy stream error", { error: String(err) });
          }
          if (!res.headersSent) {
            res.writeHead(502);
          }
          res.end();
        });
        stream.pipe(res);
      } catch (err) {
        logger.warn("[DubbingStudio:Duration] Range proxy request error", { error: String(err) });
        if (!res.headersSent) {
          res.writeHead(500);
        }
        res.end();
      }
    })();
  });

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => resolve());
  });

  const addr = server.address();
  const port = typeof addr === "object" && addr ? addr.port : 0;
  try {
    return await fn(`http://127.0.0.1:${port}/media`);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
}

/**
 * Pure-TypeScript ISOBMFF (`mp4`, `mov`, `m4a`, `m4v`, `3gp`) duration reader using byte-range reads.
 * Walks top-level atoms to locate `moov -> mvhd` without downloading `mdat` or invoking native binaries.
 */
export async function probeIsobmffDurationMs(
  readRange: (start: number, endInclusive: number) => Promise<Buffer>,
  totalSize: number
): Promise<number> {
  if (!Number.isFinite(totalSize) || totalSize < 16) return 0;

  async function readBoxHeader(offset: number, containerEnd: number): Promise<{
    type: string;
    headerSize: number;
    boxSize: number;
  } | null> {
    if (offset + 8 > containerEnd) return null;
    const probeLen = Math.min(16, containerEnd - offset);
    const buf = await readRange(offset, offset + probeLen - 1);
    if (buf.length < 8) return null;

    const size32 = buf.readUInt32BE(0);
    const type = buf.subarray(4, 8).toString("ascii");
    if (size32 === 1) {
      if (buf.length < 16) return null;
      const hi = buf.readUInt32BE(8);
      const lo = buf.readUInt32BE(12);
      const boxSize = hi * 0x100000000 + lo;
      return boxSize >= 16 ? { type, headerSize: 16, boxSize } : null;
    }
    if (size32 === 0) {
      return { type, headerSize: 8, boxSize: containerEnd - offset };
    }
    return size32 >= 8 ? { type, headerSize: 8, boxSize: size32 } : null;
  }

  let offset = 0;
  let moovStart = -1;
  let moovEnd = -1;
  for (let i = 0; i < MAX_ISOBMFF_BOXES && offset + 8 <= totalSize; i++) {
    const hdr = await readBoxHeader(offset, totalSize);
    if (!hdr) break;
    const boxEnd = Math.min(totalSize, offset + hdr.boxSize);
    if (hdr.type === "moov") {
      moovStart = offset + hdr.headerSize;
      moovEnd = boxEnd;
      break;
    }
    if (boxEnd <= offset) break;
    offset = boxEnd;
  }

  if (moovStart < 0 || moovEnd <= moovStart) return 0;

  let childOffset = moovStart;
  for (let i = 0; i < MAX_ISOBMFF_BOXES && childOffset + 8 <= moovEnd; i++) {
    const hdr = await readBoxHeader(childOffset, moovEnd);
    if (!hdr) break;
    const childEnd = Math.min(moovEnd, childOffset + hdr.boxSize);
    if (hdr.type === "mvhd") {
      const payloadStart = childOffset + hdr.headerSize;
      const payloadLen = childEnd - payloadStart;
      if (payloadLen < 20) return 0;
      const mvhd = await readRange(payloadStart, payloadStart + Math.min(32, payloadLen) - 1);
      if (mvhd.length < 20) return 0;
      const version = mvhd.readUInt8(0);
      if (version === 0 && mvhd.length >= 20) {
        const timescale = mvhd.readUInt32BE(12);
        const duration = mvhd.readUInt32BE(16);
        if (timescale > 0 && duration > 0) {
          return Math.round((duration / timescale) * 1000);
        }
      } else if (version === 1 && mvhd.length >= 32) {
        const timescale = mvhd.readUInt32BE(20);
        const hi = mvhd.readUInt32BE(24);
        const lo = mvhd.readUInt32BE(28);
        const duration = hi * 0x100000000 + lo;
        if (timescale > 0 && duration > 0) {
          return Math.round((duration / timescale) * 1000);
        }
      }
      return 0;
    }
    if (childEnd <= childOffset) break;
    childOffset = childEnd;
  }

  return 0;
}

async function readStreamToBuffer(stream: Readable): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of stream) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
}

async function probeHlsDurationMs(playlistUrl: string): Promise<number> {
  if (!isSafePublicUrl(playlistUrl)) return 0;
  const resp = await axios.get<string>(playlistUrl, { responseType: "text", timeout: 15000 });
  const text = String(resp.data || "");

  let totalSec = 0;
  const extInfRegex = /^#EXTINF:([0-9]+(?:\.[0-9]+)?)/gm;
  let match: RegExpExecArray | null;
  while ((match = extInfRegex.exec(text)) !== null) {
    const sec = parseFloat(match[1]);
    if (Number.isFinite(sec) && sec > 0) totalSec += sec;
  }
  if (totalSec > 0) return Math.round(totalSec * 1000);

  // Master playlist: follow first variant playlist URI
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  for (let i = 0; i < lines.length - 1; i++) {
    if (lines[i].startsWith("#EXT-X-STREAM-INF") && !lines[i + 1].startsWith("#")) {
      const variantUrl = new URL(lines[i + 1], playlistUrl).toString();
      if (variantUrl !== playlistUrl) {
        return probeHlsDurationMs(variantUrl);
      }
    }
  }
  return 0;
}

/**
 * Measures a Studio media file's duration in milliseconds on the server.
 *
 * Uses a local `127.0.0.1` HTTP Range proxy backed by the GCS Admin SDK (avoiding `getSignedUrl`
 * IAM dependencies and static-binary DNS/TLS segfaults in Cloud Run gVisor), with a bounded
 * `/tmp` fallback for small non-seekable files and a pure-TypeScript MP4/MOV `mvhd` reader.
 */
export async function probeStudioMediaDurationMs(mediaUrl: string): Promise<number> {
  if (!mediaUrl || typeof mediaUrl !== "string") return 0;
  const trimmed = mediaUrl.trim();
  if (!trimmed) return 0;

  try {
    const info = parseAnyStorageUrl(trimmed);
    if (info) {
      const file = admin.storage().bucket(info.bucketName || undefined).file(info.filePath);
      const [metadata] = await file.getMetadata();
      const totalSize = parseInt(String(metadata.size ?? "0"), 10);
      const contentType = String(metadata.contentType || "application/octet-stream");

      if (!(totalSize > 0)) {
        logger.warn("[DubbingStudio:Duration] Storage object has zero size", { filePath: info.filePath });
        return 0;
      }

      // 1. Loopback Range proxy -> FFprobe / FFmpeg (works for 4GB+ files without downloading)
      const proxiedMs = await withLoopbackRangeProxy(
        {
          size: totalSize,
          contentType,
          createReadStream: (start, end) =>
            file.createReadStream(start !== undefined && end !== undefined ? { start, end } : {}),
        },
        (localUrl) => mediaService.probeMediaDurationMs(localUrl)
      );
      if (proxiedMs > 0) return proxiedMs;

      // 2. Bounded /tmp fallback for small files whose container isn't HTTP-seekable
      if (totalSize <= MAX_TMP_FALLBACK_BYTES) {
        const ext = path.extname(info.filePath) || ".mp4";
        const tmpPath = path.join(os.tmpdir(), `studio_probe_${Date.now()}_${Math.random().toString(36).slice(2)}${ext}`);
        try {
          await file.download({ destination: tmpPath });
          const localMs = await mediaService.probeMediaDurationMs(tmpPath);
          if (localMs > 0) return localMs;
        } finally {
          await fs.promises.unlink(tmpPath).catch(() => {});
        }
      }

      // 3. Pure-TypeScript ISOBMFF (mp4/mov/m4a/3gp) mvhd reader (zero native binary dependency)
      const isobmffMs = await probeIsobmffDurationMs(
        (start, end) => readStreamToBuffer(file.createReadStream({ start, end })),
        totalSize
      );
      if (isobmffMs > 0) return isobmffMs;

      logger.warn("[DubbingStudio:Duration] All duration probes returned 0 for storage file", {
        filePath: info.filePath,
        totalSize,
        contentType,
      });
      return 0;
    }

    if (trimmed.toLowerCase().includes(".m3u8")) {
      const hlsMs = await probeHlsDurationMs(trimmed);
      if (hlsMs > 0) return hlsMs;
    }

    if (!isSafePublicUrl(trimmed)) {
      logger.warn("[DubbingStudio:Duration] Blocked unsafe media URL for duration probe");
      return 0;
    }

    // Non-GCS public HTTP(S) media: probe via loopback Range proxy backed by Node axios
    const headResp = await axios.head(trimmed, { timeout: 10000 }).catch(() => null);
    const totalSize = parseInt(String(headResp?.headers?.["content-length"] ?? "0"), 10);
    const contentType = String(headResp?.headers?.["content-type"] || "application/octet-stream");

    if (totalSize > 0) {
      const proxiedMs = await withLoopbackRangeProxy(
        {
          size: totalSize,
          contentType,
          createReadStream: async (start, end) => {
            const resp = await axios.get<Readable>(trimmed, {
              responseType: "stream",
              timeout: 20000,
              headers: start !== undefined && end !== undefined ? { Range: `bytes=${start}-${end}` } : undefined,
            });
            return resp.data;
          },
        },
        (localUrl) => mediaService.probeMediaDurationMs(localUrl)
      );
      if (proxiedMs > 0) return proxiedMs;

      const isobmffMs = await probeIsobmffDurationMs(async (start, end) => {
        const resp = await axios.get<ArrayBuffer>(trimmed, {
          responseType: "arraybuffer",
          timeout: 15000,
          headers: { Range: `bytes=${start}-${end}` },
        });
        return Buffer.from(resp.data);
      }, totalSize);
      if (isobmffMs > 0) return isobmffMs;
    }

    return 0;
  } catch (err) {
    logger.warn("[DubbingStudio:Duration] Could not measure media length", { error: String(err) });
    return 0;
  }
}
