/**
 * Offline BGM & SFX fidelity measurement on existing local-dub-output clips.
 * Runs MediaService.mixDubFaithful with real FFmpeg on the saved stems/audio
 * (before = flags OFF, after = DUBBING_TIGHT_STEM=true + DUBBING_KEEP_NONVERBAL=true)
 * and writes bgm_report_before.json + bgm_report.json in each folder.
 */
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { execFileSync } from "child_process";

const gcsRoot = fs.mkdtempSync(path.join(os.tmpdir(), "measure-bgm-gcs-"));
const BUCKET = "local-bgm-test";

// Shim firebase-admin storage before loading MediaService
// eslint-disable-next-line @typescript-eslint/no-var-requires
const admin = require("firebase-admin");
Object.defineProperty(admin, "storage", {
  value: () => ({
    bucket: () => ({
      name: BUCKET,
      file: (p: string) => ({
        download: async (opts?: { destination?: string }) => {
          const src = path.join(gcsRoot, p);
          if (opts?.destination) {
            fs.copyFileSync(src, opts.destination);
            return [];
          }
          return [fs.readFileSync(src)];
        },
        exists: async () => [fs.existsSync(path.join(gcsRoot, p))],
      }),
      upload: async (src: string, opts: { destination: string }) => {
        const dest = path.join(gcsRoot, opts.destination);
        fs.mkdirSync(path.dirname(dest), { recursive: true });
        fs.copyFileSync(src, dest);
        return [];
      },
    }),
  }),
  configurable: true,
});

import { getFfmpegPath, mediaService } from "../../src/pipeline/services/media";

interface ClipSpec {
  folder: string;
  label: string;
  vocalsFile?: string;
}

const CLIPS: ClipSpec[] = [
  { folder: "dub-test-te-1795544954895", label: "baseline_25s_animated" },
  { folder: "dub-test-te-1795531020819", label: "clip2_60s_video" },
  {
    folder: "dub-test-te-1795460745628",
    label: "clip3_30s_benchmark",
    vocalsFile: path.resolve(__dirname, "../../local-dub-output/demucs-check/warmup_check_1795454131605_vocals.mp3"),
  },
];

function stage(localPath: string, relDest: string): string {
  const dest = path.join(gcsRoot, relDest);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(localPath, dest);
  return `gs://${BUCKET}/${relDest}`;
}

async function measureClip(clip: ClipSpec): Promise<void> {
  const dir = path.resolve(__dirname, "../../local-dub-output", clip.folder);
  const reportJsonPath = path.join(dir, "report.json");
  const transPath = path.join(dir, "translation_te.json");
  const bedPath = path.join(dir, "background_stem.mp3");
  const dialPath = path.join(dir, "dialogue_te.mp3");
  const srcVideo = path.join(dir, "source_clip.mp4");
  const srcMp3 = path.join(dir, "source_clip.mp3");

  const ffmpeg = getFfmpegPath();
  if (!ffmpeg) throw new Error("FFmpeg not found");

  const reportData = JSON.parse(fs.readFileSync(reportJsonPath, "utf8"));
  let srcAudioLocal = srcMp3;
  if (!fs.existsSync(srcAudioLocal)) {
    const videoInput = fs.existsSync(srcVideo) ? srcVideo : reportData.source;
    srcAudioLocal = path.join(gcsRoot, `${clip.folder}_src.mp3`);
    execFileSync(ffmpeg, ["-y", "-i", videoInput, "-vn", "-c:a", "libmp3lame", "-b:a", "256k", "-ar", "44100", "-ac", "2", srcAudioLocal], {
      stdio: "pipe",
    });
  }
  const trans = JSON.parse(fs.readFileSync(transPath, "utf8")) as Array<{ start: number; end: number; speaker?: string }>;
  const lines = trans.map((t, i) => ({
    speaker: t.speaker || `S${i % 2}`,
    startMs: t.start,
    endMs: t.end,
  }));
  const totalDurationMs = Math.round((reportData.seconds || 30) * 1000);

  const srcUrl = stage(srcAudioLocal, `${clip.folder}/source.mp3`);
  const dubUrl = stage(dialPath, `${clip.folder}/dialogue.mp3`);
  const bedUrl = stage(bedPath, `${clip.folder}/bed.mp3`);

  let vocalsUrl: string | null = null;
  const localVoc = clip.vocalsFile && fs.existsSync(clip.vocalsFile) ? clip.vocalsFile : path.join(dir, "vocals_stem.mp3");
  if (fs.existsSync(localVoc)) {
    // Trim vocals to clip duration if longer (e.g. 3m15s benchmark vocals for 30s clip)
    const trimmedVoc = path.join(gcsRoot, `${clip.folder}_voc_trim.mp3`);
    execFileSync(
      ffmpeg,
      ["-y", "-i", localVoc, "-t", String((totalDurationMs / 1000).toFixed(3)), "-c:a", "libmp3lame", "-b:a", "256k", trimmedVoc],
      { stdio: "pipe" }
    );
    vocalsUrl = stage(trimmedVoc, `${clip.folder}/vocals.mp3`);
  }

  // 1. Before (flags OFF)
  process.env.DUBBING_TIGHT_STEM = "false";
  process.env.DUBBING_KEEP_NONVERBAL = "false";
  const before = await mediaService.mixDubFaithful(`${clip.folder}_before`, "te", {
    sourceAudioUrl: srcUrl,
    dubbedAudioUrl: dubUrl,
    bedUrl,
    isolatedVocalUrl: vocalsUrl,
    lines,
    totalDurationMs,
  });

  // 2. After (DUBBING_TIGHT_STEM=true + DUBBING_KEEP_NONVERBAL=true)
  process.env.DUBBING_TIGHT_STEM = "true";
  process.env.DUBBING_KEEP_NONVERBAL = "true";
  const after = await mediaService.mixDubFaithful(`${clip.folder}_after`, "te", {
    sourceAudioUrl: srcUrl,
    dubbedAudioUrl: dubUrl,
    bedUrl,
    isolatedVocalUrl: vocalsUrl,
    lines,
    totalDurationMs,
  });

  if (before.bgmReport) {
    fs.writeFileSync(path.join(dir, "bgm_report_before.json"), JSON.stringify(before.bgmReport, null, 2), "utf8");
  }
  if (after.bgmReport) {
    fs.writeFileSync(path.join(dir, "bgm_report.json"), JSON.stringify(after.bgmReport, null, 2), "utf8");
  }

  console.log(`\n=== ${clip.label} (${clip.folder}, vocals=${vocalsUrl ? "yes" : "no"}) ===`);
  console.log("BEFORE:", JSON.stringify({ ok: before.ok, regionMs: before.regionMs, ...before.bgmReport }));
  console.log("AFTER: ", JSON.stringify({ ok: after.ok, regionMs: after.regionMs, ...after.bgmReport }));
}

async function main() {
  for (const c of CLIPS) {
    await measureClip(c);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
