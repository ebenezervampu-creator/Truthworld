/**
 * Adaptive HLS for every video (2026-11-21).
 *
 * - FFmpeg path: each finished quality is remuxed (no re-encode) to one fragmented-MP4
 *   file with a byte-range playlist; a master playlist lists every finished quality.
 * - Transcoder path: its relative playlist URIs are rewritten to absolute Firebase URLs.
 * - A free master (up to 1080p) mirrors the app's premium cap.
 *
 * The end-to-end case runs the worker's real FFmpeg options when ffmpeg/ffprobe are on
 * PATH (they are in CI images with ffmpeg; otherwise it is skipped, not faked).
 */

import { execFileSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import {
  HlsRendition,
  avcCodecString,
  buildMasterPlaylist,
  codecsFor,
  filterMasterByShortSide,
  firebaseDownloadUrl,
  hlsRemuxOutputOptions,
  measurePlaylistBandwidth,
  resolveRelativeObjectPath,
  rewritePlaylistUris,
} from "../../src/resolution/hlsLadder";
import { playbackResetFields } from "../../src/resolution/resolutionPlanning";

const rendition = (label: string, width: number, height: number, bandwidth: number): HlsRendition => ({
  label,
  width,
  height,
  fps: 30,
  bandwidth,
  averageBandwidth: Math.round(bandwidth * 0.8),
  codecs: "avc1.640028,mp4a.40.2",
  playlistUrl: `https://example.test/${label}/index.m3u8`,
});

const LADDER = [
  rendition("2160p", 3840, 2160, 16000000),
  rendition("1080p", 1920, 1080, 5000000),
  rendition("720p", 1280, 720, 2800000),
  rendition("480p", 854, 480, 1400000),
  rendition("360p", 640, 360, 900000),
];

const streamOrder = (master: string) =>
  master.split("\n").filter((l) => l.startsWith("http")).map((l) => l.split("/")[3]);

describe("buildMasterPlaylist", () => {
  it("lists 480p first (fast start), then the rest by bandwidth", () => {
    expect(streamOrder(buildMasterPlaylist(LADDER))).toEqual(["480p", "360p", "720p", "1080p", "2160p"]);
  });

  it("the free master stops at 1080p", () => {
    const hd = buildMasterPlaylist(LADDER, { maxShortSide: 1080 });
    expect(streamOrder(hd)).toEqual(["480p", "360p", "720p", "1080p"]);
  });

  it("portrait qualities are classified by the shorter side", () => {
    const portrait = [rendition("2160p", 2160, 3840, 16000000), rendition("1080p", 1080, 1920, 5000000)];
    expect(streamOrder(buildMasterPlaylist(portrait, { maxShortSide: 1080 }))).toEqual(["1080p"]);
  });

  it("writes RFC 8216 attributes", () => {
    const text = buildMasterPlaylist([LADDER[2]]);
    expect(text.startsWith("#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-INDEPENDENT-SEGMENTS\n")).toBe(true);
    expect(text).toContain(
      '#EXT-X-STREAM-INF:BANDWIDTH=2800000,AVERAGE-BANDWIDTH=2240000,RESOLUTION=1280x720,CODECS="avc1.640028,mp4a.40.2",FRAME-RATE=30.000'
    );
  });

  it("returns nothing when no quality is ready", () => {
    expect(buildMasterPlaylist([])).toBe("");
  });
});

describe("codec strings", () => {
  it("maps ffprobe profile + level to RFC 6381", () => {
    expect(avcCodecString("High", 40)).toBe("avc1.640028");
    expect(avcCodecString("Main", 31)).toBe("avc1.4D401F");
    expect(avcCodecString("Constrained Baseline", 30)).toBe("avc1.42E01E");
    expect(codecsFor({ videoProfile: "High", videoLevel: 42, hasAudio: false })).toBe("avc1.64002A");
  });
});

describe("byte-range playlists", () => {
  const playlist = [
    "#EXTM3U",
    '#EXT-X-MAP:URI="stream.mp4",BYTERANGE="1373@0"',
    "#EXTINF:4.000000,",
    "#EXT-X-BYTERANGE:1000000@1373",
    "stream.mp4",
    "#EXTINF:2.000000,",
    "#EXT-X-BYTERANGE:750000@1001373",
    "stream.mp4",
    "#EXT-X-ENDLIST",
  ].join("\n");

  it("measures peak and average bitrate from what is actually served", () => {
    expect(measurePlaylistBandwidth(playlist)).toEqual({ bandwidth: 3000000, averageBandwidth: 2333334 });
  });

  it("rewrites the media file and the init-segment URI", () => {
    const out = rewritePlaylistUris(playlist, (u) => (u === "stream.mp4" ? "https://cdn.test/a.mp4" : u));
    expect(out).toContain('#EXT-X-MAP:URI="https://cdn.test/a.mp4",BYTERANGE="1373@0"');
    expect(out.split("\n").filter((l) => l === "https://cdn.test/a.mp4")).toHaveLength(2);
  });
});

describe("Transcoder playlists become playable from Firebase Storage", () => {
  const master = [
    "#EXTM3U",
    '#EXT-X-STREAM-INF:BANDWIDTH=18192000,RESOLUTION=3840x2160,CODECS="avc1.640033,mp4a.40.2"',
    "hls-2160p.m3u8",
    '#EXT-X-STREAM-INF:BANDWIDTH=4692000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"',
    "hls-1080p.m3u8",
  ].join("\n");
  const masterObject = "resolutions/vid/hls/master.m3u8";

  it("resolves relative URIs against the playlist's folder", () => {
    const root = "resolutions/vid/hls/";
    expect(resolveRelativeObjectPath(masterObject, "hls-1080p.m3u8", root)).toBe("resolutions/vid/hls/hls-1080p.m3u8");
    expect(resolveRelativeObjectPath("resolutions/vid/hls/hls-1080p.m3u8", "hls-1080p/segment-0.ts", root))
      .toBe("resolutions/vid/hls/hls-1080p/segment-0.ts");
    expect(resolveRelativeObjectPath("resolutions/vid/hls/hls-1080p/index.m3u8", "../hls-720p/seg.ts", root))
      .toBe("resolutions/vid/hls/hls-720p/seg.ts");
    // Never outside the video's own HLS folder
    expect(resolveRelativeObjectPath(masterObject, "../../other/x.ts", root)).toBeNull();
    expect(resolveRelativeObjectPath(masterObject, "/abs/x.ts", root)).toBeNull();
    expect(resolveRelativeObjectPath(masterObject, "https://already/absolute.m3u8", root)).toBeNull();
    expect(resolveRelativeObjectPath(masterObject, "data:text/plain,x", root)).toBeNull();
  });

  it("rewrites to absolute tokenized URLs, and running twice changes nothing", () => {
    const toAbs = (uri: string) => {
      const p = resolveRelativeObjectPath(masterObject, uri, "resolutions/vid/hls/");
      return p ? firebaseDownloadUrl("bucket", p, "tok") : uri;
    };
    const once = rewritePlaylistUris(master, toAbs);
    expect(once).toContain(
      "https://firebasestorage.googleapis.com/v0/b/bucket/o/resolutions%2Fvid%2Fhls%2Fhls-1080p.m3u8?alt=media&token=tok"
    );
    expect(rewritePlaylistUris(once, toAbs)).toBe(once);
  });

  it("free master keeps only qualities up to 1080p", () => {
    const hd = filterMasterByShortSide(master, 1080);
    expect(hd).toContain("hls-1080p.m3u8");
    expect(hd).not.toContain("hls-2160p.m3u8");
    expect(filterMasterByShortSide(master, 480)).toBe("");
  });
});

describe("re-upload reset includes the HLS fields", () => {
  it("clears media.abrHlsUrl and media.abrHlsHdUrl", () => {
    const del = { d: true };
    const fields = playbackResetFields("vid", {}, del);
    expect(fields["media.abrHlsUrl"]).toBe(del);
    expect(fields["media.abrHlsHdUrl"]).toBe(del);
  });
});

const hasFfmpeg = (() => {
  try {
    execFileSync("ffmpeg", ["-version"], { stdio: "ignore" });
    execFileSync("ffprobe", ["-version"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
})();

(hasFfmpeg ? describe : describe.skip)("end to end with the worker's FFmpeg options", () => {
  let dir: string;
  beforeAll(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), "hls-ladder-"));
  });
  afterAll(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  const encode = (name: string, size: string) => {
    const out = path.join(dir, `${name}.mp4`);
    execFileSync("ffmpeg", [
      "-loglevel", "error", "-y",
      "-f", "lavfi", "-i", `testsrc=size=${size}:rate=30`,
      "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
      "-t", "9",
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "30", "-keyint_min", "30", "-sc_threshold", "0",
      "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", out,
    ]);
    return out;
  };

  const remux = (label: string, input: string) => {
    const work = path.join(dir, label);
    fs.mkdirSync(work);
    const media = path.join(work, "stream.mp4");
    execFileSync("ffmpeg", ["-loglevel", "error", "-i", input, ...hlsRemuxOutputOptions(media), path.join(work, "index.m3u8")]);
    return { work, playlist: fs.readFileSync(path.join(work, "index.m3u8"), "utf8") };
  };

  it("produces aligned 4-second byte-range segments and a master that ffprobe can open", () => {
    const qualities = [
      { label: "360p", w: 640, h: 360 },
      { label: "720p", w: 1280, h: 720 },
    ].map((q) => {
      const { work, playlist } = remux(q.label, encode(q.label, `${q.w}x${q.h}`));
      expect(playlist).toContain("#EXT-X-PLAYLIST-TYPE:VOD");
      expect(playlist).toContain("#EXT-X-MAP:URI=\"stream.mp4\"");
      const durations = [...playlist.matchAll(/#EXTINF:([\d.]+)/g)].map((m) => Number(m[1]));
      expect(durations.slice(0, -1).every((d) => d === 4)).toBe(true);
      const { bandwidth, averageBandwidth } = measurePlaylistBandwidth(playlist);
      expect(bandwidth).toBeGreaterThan(0);
      expect(averageBandwidth).toBeLessThanOrEqual(bandwidth);
      return { ...q, work, bandwidth, averageBandwidth };
    });

    const master = buildMasterPlaylist(qualities.map((q) => ({
      label: q.label,
      width: q.w,
      height: q.h,
      fps: 30,
      bandwidth: q.bandwidth,
      averageBandwidth: q.averageBandwidth,
      codecs: "avc1.640028,mp4a.40.2",
      playlistUrl: path.join(q.work, "index.m3u8"),
    })));
    const masterPath = path.join(dir, "master.m3u8");
    fs.writeFileSync(masterPath, master);

    const probe = execFileSync("ffprobe", [
      "-v", "error", "-show_entries", "stream=codec_type,width,height", "-of", "json", masterPath,
    ]).toString();
    const streams = JSON.parse(probe).streams as Array<{ codec_type: string; height?: number }>;
    const heights = streams.filter((s) => s.codec_type === "video").map((s) => s.height).sort();
    expect(heights).toEqual([360, 720]);
  });
});
