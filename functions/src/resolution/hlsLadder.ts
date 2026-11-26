/**
 * HLS (RFC 8216) helpers for the resolution service — pure functions, no Firebase calls.
 *
 * Every video now gets one adaptive HLS stream:
 *  - FFmpeg path: each finished quality is remuxed (no re-encode) into a single
 *    fragmented-MP4 file with a byte-range media playlist, then a master playlist
 *    lists every finished quality.
 *  - Transcoder path: the Transcoder's own playlists are rewritten so every URI is
 *    an absolute, playable Firebase Storage URL.
 *
 * Why absolute URLs: Firebase download URLs put the whole object path in one
 * encoded segment (`/o/resolutions%2F<id>%2Fhls%2Fmaster.m3u8`), so relative URIs
 * inside a playlist resolve to the wrong place. Every URI is therefore written as
 * `https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded path>?alt=media&token=<token>`.
 */

import * as path from "path";

/** Qualities above this shorter side need premium playback (mirrors the app's 1040p cap). */
export const FREE_MAX_SHORT_SIDE = 1080;

/** Start quality listed first in the master playlist (AVPlayer starts on the first entry). */
export const START_SHORT_SIDE = 480;

export interface HlsRendition {
  label: string;
  width: number;
  height: number;
  fps: number;
  /** Peak segment bitrate in bits/s (RFC 8216 BANDWIDTH). */
  bandwidth: number;
  /** Average bitrate in bits/s (AVERAGE-BANDWIDTH). */
  averageBandwidth: number;
  /** RFC 6381 codecs string, e.g. "avc1.640028,mp4a.40.2". */
  codecs: string;
  /** Absolute URL of this quality's media playlist. */
  playlistUrl: string;
}

/**
 * FFmpeg output options that remux one finished MP4 quality into a single
 * fragmented-MP4 file + byte-range VOD playlist (stream copy, no re-encode).
 * Only the first video and audio stream are kept (phones add data/timecode tracks).
 */
export function hlsRemuxOutputOptions(localMediaPath: string): string[] {
  return [
    "-map", "0:v:0",
    "-map", "0:a:0?",
    "-c", "copy",
    "-f", "hls",
    "-hls_time", "4",
    "-hls_playlist_type", "vod",
    "-hls_segment_type", "fmp4",
    "-hls_flags", "single_file+independent_segments",
    "-hls_segment_filename", localMediaPath,
  ];
}

/** Firebase Storage download URL for an object, using a download token. */
export function firebaseDownloadUrl(bucket: string, objectPath: string, token: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
}

/** Shorter side of a rendition (its quality class for portrait and landscape). */
export function shortSideOf(r: { width: number; height: number }): number {
  return r.width > 0 && r.height > 0 ? Math.min(r.width, r.height) : r.height;
}

/**
 * RFC 6381 codec string for H.264 from ffprobe's profile name and level number.
 * Unknown profiles fall back to High (the encoder default), which players accept.
 */
export function avcCodecString(profile: string | undefined, level: number | undefined): string {
  const p = (profile || "").toLowerCase();
  let prefix = "6400"; // High
  if (p.includes("constrained baseline") || p === "baseline") prefix = "42E0";
  else if (p.includes("main")) prefix = "4D40";
  else if (p.includes("high 10")) prefix = "6E00";
  const lvl = Number.isFinite(level) && (level as number) > 0 ? (level as number) : 40;
  return `avc1.${prefix}${lvl.toString(16).toUpperCase().padStart(2, "0")}`;
}

/** Codecs attribute for a muxed H.264 (+ optional AAC-LC) rendition. */
export function codecsFor(input: { videoProfile?: string; videoLevel?: number; hasAudio: boolean }): string {
  const video = avcCodecString(input.videoProfile, input.videoLevel);
  return input.hasAudio ? `${video},mp4a.40.2` : video;
}

/**
 * Measures peak and average bitrate from a byte-range media playlist
 * (EXTINF durations + EXT-X-BYTERANGE lengths). This is exact for the file
 * actually served, unlike the encoder's target bitrate.
 */
export function measurePlaylistBandwidth(playlist: string): { bandwidth: number; averageBandwidth: number } {
  const lines = playlist.split(/\r?\n/);
  let pendingDuration = 0;
  let peak = 0;
  let totalBits = 0;
  let totalSeconds = 0;
  for (const raw of lines) {
    const line = raw.trim();
    if (line.startsWith("#EXTINF:")) {
      pendingDuration = parseFloat(line.slice("#EXTINF:".length)) || 0;
    } else if (line.startsWith("#EXT-X-BYTERANGE:")) {
      const length = parseInt(line.slice("#EXT-X-BYTERANGE:".length).split("@")[0], 10) || 0;
      if (pendingDuration > 0 && length > 0) {
        const bits = length * 8;
        peak = Math.max(peak, bits / pendingDuration);
        totalBits += bits;
        totalSeconds += pendingDuration;
      }
      pendingDuration = 0;
    }
  }
  const average = totalSeconds > 0 ? totalBits / totalSeconds : 0;
  return { bandwidth: Math.ceil(peak), averageBandwidth: Math.ceil(average) };
}

/** Rewrites every URI in a playlist (bare URI lines and URI="..." attributes) with `resolve`. */
export function rewritePlaylistUris(playlist: string, resolve: (uri: string) => string): string {
  return playlist
    .split(/\r?\n/)
    .map((line) => {
      const trimmed = line.trim();
      if (trimmed.length === 0) return line;
      if (trimmed.startsWith("#")) {
        return line.replace(/URI="([^"]+)"/g, (_m, uri: string) => `URI="${resolve(uri)}"`);
      }
      return resolve(trimmed);
    })
    .join("\n");
}

/**
 * Resolves a playlist URI against the playlist's own storage path.
 * Returns null for absolute http(s) URIs (kept as they are) and for any path that
 * would leave `confineTo` (the video's own HLS folder), so a crafted playlist can't
 * point a tokenized URL at another object.
 */
export function resolveRelativeObjectPath(playlistObjectPath: string, uri: string, confineTo: string): string | null {
  if (/^[a-z][a-z0-9+.-]*:/i.test(uri)) return null;
  const clean = uri.split("?")[0].split("#")[0];
  if (clean.length === 0 || clean.startsWith("/")) return null;
  const joined = path.posix.normalize(path.posix.join(path.posix.dirname(playlistObjectPath), clean));
  const root = confineTo.endsWith("/") ? confineTo : `${confineTo}/`;
  return joined.startsWith(root) ? joined : null;
}

/**
 * Builds a master playlist. The quality closest to 480p (at or below) is listed
 * first so AVPlayer starts quickly on mobile networks; the rest follow in
 * ascending bandwidth. `maxShortSide` drops premium qualities for the free master.
 */
export function buildMasterPlaylist(renditions: HlsRendition[], options: { maxShortSide?: number } = {}): string {
  const usable = renditions
    .filter((r) => r.playlistUrl && r.bandwidth > 0)
    .filter((r) => options.maxShortSide === undefined || shortSideOf(r) <= options.maxShortSide)
    .sort((a, b) => a.bandwidth - b.bandwidth);
  if (usable.length === 0) return "";

  const start =
    [...usable].reverse().find((r) => shortSideOf(r) <= START_SHORT_SIDE) ?? usable[0];
  const ordered = [start, ...usable.filter((r) => r !== start)];

  const lines = ["#EXTM3U", "#EXT-X-VERSION:7", "#EXT-X-INDEPENDENT-SEGMENTS"];
  for (const r of ordered) {
    const attrs = [
      `BANDWIDTH=${r.bandwidth}`,
      `AVERAGE-BANDWIDTH=${Math.min(r.averageBandwidth || r.bandwidth, r.bandwidth)}`,
      `RESOLUTION=${r.width}x${r.height}`,
      `CODECS="${r.codecs}"`,
    ];
    if (r.fps > 0) attrs.push(`FRAME-RATE=${r.fps.toFixed(3)}`);
    lines.push(`#EXT-X-STREAM-INF:${attrs.join(",")}`);
    lines.push(r.playlistUrl);
  }
  return lines.join("\n") + "\n";
}

/**
 * Keeps only the variant streams of an existing master playlist whose shorter
 * side is at most `maxShortSide` (used to make the free master from the
 * Transcoder's master). Other tags (EXT-X-MEDIA etc.) are kept.
 */
export function filterMasterByShortSide(master: string, maxShortSide: number): string {
  const lines = master.split(/\r?\n/);
  const out: string[] = [];
  let kept = 0;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("#EXT-X-STREAM-INF:")) {
      const match = /RESOLUTION=(\d+)x(\d+)/.exec(line);
      const width = match ? parseInt(match[1], 10) : 0;
      const height = match ? parseInt(match[2], 10) : 0;
      const keep = !match || shortSideOf({ width, height }) <= maxShortSide;
      const uri = lines[i + 1];
      i++;
      if (keep) {
        out.push(line, uri);
        kept++;
      }
      continue;
    }
    out.push(line);
  }
  return kept > 0 ? out.join("\n") : "";
}
