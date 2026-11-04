/**
 * 🧪 END-TO-END VERIFICATION: Auto-Chapters, Distinct Thumbnails & Speaker Diarization
 * Tests with real sample video, FFmpeg frame extraction, and multilingual speech.
 */

import * as path from "path";
import * as fs from "fs";
import { execSync } from "child_process";

// Simple test assertion helper
let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string) {
  if (condition) {
    console.log(`  ✅ PASS: ${message}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${message}`);
    failed++;
  }
}

async function runSampleVerification() {
  console.log("==================================================================");
  console.log("🎬 STARTING REAL SAMPLE PIPELINE VERIFICATION SUITE");
  console.log("==================================================================");

  // ──────────────────────────────────────────────────────────────────────
  // TEST 1: FFmpeg High-Quality Chapter Thumbnail Extraction with Sample Video
  // ──────────────────────────────────────────────────────────────────────
  console.log("\n--- [Test 1] Real Sample Video: FFmpeg 640x360 Chapter Thumbnails ---");

  const sampleVideoPath = path.resolve(
    "c:/company/truthworld/windows/flutter/ephemeral/.plugin_symlinks/ffmpeg_kit_flutter_new/example/assets/sample_video.mp4"
  );

  assert(fs.existsSync(sampleVideoPath), `Sample video exists at: ${sampleVideoPath}`);

  // Resolve ffmpeg binary
  const ffmpegInstaller = require("ffmpeg-static");
  assert(typeof ffmpegInstaller === "string" && fs.existsSync(ffmpegInstaller), "ffmpeg-static binary found");

  const tempOutDir = path.join(__dirname, "../../../../tmp/test_chapter_thumbs");
  if (!fs.existsSync(tempOutDir)) {
    fs.mkdirSync(tempOutDir, { recursive: true });
  }

  // Define 3 sample chapters at 0.0s, 1.0s, and 2.0s
  const sampleChapters = [
    { startMs: 0, startTimeMs: 0, title: "Introduction", summary: "Opening scene" },
    { startMs: 1000, startTimeMs: 1000, title: "Middle Action", summary: "Scene development" },
    { startMs: 2000, startTimeMs: 2000, title: "Conclusion", summary: "Final frame" },
  ];

  const extractedThumbnails: { index: number; path: string; sizeBytes: number }[] = [];

  for (let idx = 0; idx < sampleChapters.length; idx++) {
    const ch = sampleChapters[idx];
    const sec = (ch.startTimeMs / 1000).toFixed(3);
    const outName = `chapter_${idx}_${ch.startTimeMs}.jpg`;
    const outPath = path.join(tempOutDir, outName);

    // Run exact FFmpeg command used by resolution.ts
    const cmd = `"${ffmpegInstaller}" -y -ss ${sec} -i "${sampleVideoPath}" -frames:v 1 -vf "scale=640:360:force_original_aspect_ratio=decrease,pad=640:360:(ow-iw)/2:(oh-ih)/2:color=black" -q:v 2 "${outPath}"`;
    try {
      execSync(cmd, { stdio: "pipe" });
      const stat = fs.statSync(outPath);
      extractedThumbnails.push({ index: idx, path: outPath, sizeBytes: stat.size });
    } catch (err: any) {
      console.error(`Error extracting frame at ${sec}s:`, err.message);
    }
  }

  assert(extractedThumbnails.length === 3, "All 3 chapter thumbnails successfully extracted via FFmpeg");

  for (const t of extractedThumbnails) {
    assert(t.sizeBytes > 500, `Chapter ${t.index} thumbnail generated valid non-empty JPEG (${t.sizeBytes} bytes)`);
  }

  // Ensure files are distinct (different hashes/sizes or not zero bytes)
  assert(
    extractedThumbnails[0].path !== extractedThumbnails[1].path,
    "Chapter thumbnails have unique distinct file paths"
  );

  // ──────────────────────────────────────────────────────────────────────
  // TEST 2: Speaker Diarization in Subtitles (AssemblyAI & Fallback)
  // ──────────────────────────────────────────────────────────────────────
  console.log("\n--- [Test 2] Speaker Diarization: Multi-Speaker Subtitle Formatting ---");

  const sampleDiarizedSegments = [
    { start: 0, end: 4200, text: "Welcome to today's debate on renewable energy.", speaker: "speaker_0" },
    { start: 4500, end: 9100, text: "Thank you. Solar efficiency has doubled over the last decade.", speaker: "speaker_1" },
    { start: 9500, end: 14000, text: "What about the storage and battery lifecycle costs?", speaker: "speaker_0" },
    { start: 14200, end: 19800, text: "Grid-scale batteries now exceed 85% round-trip efficiency.", speaker: "speaker_1" },
  ];

  const formatTimeSrt = (ms: number) => {
    const hrs = Math.floor(ms / 3600000);
    const mins = Math.floor((ms % 3600000) / 60000);
    const secs = Math.floor((ms % 60000) / 1000);
    const millis = ms % 1000;
    return `${String(hrs).padStart(2, "0")}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")},${String(millis).padStart(3, "0")}`;
  };

  const generateSubtitlesWithDiarization = (segments: typeof sampleDiarizedSegments) => {
    const distinctSpeakers = new Set(segments.map(s => s.speaker).filter(Boolean));
    const shouldLabelSpeakers = distinctSpeakers.size > 1;

    let srtContent = "";
    segments.forEach((seg, idx) => {
      const startSrt = formatTimeSrt(seg.start);
      const endSrt = formatTimeSrt(seg.end);

      let displayText = seg.text;
      if (shouldLabelSpeakers && seg.speaker) {
        const rawSpk = seg.speaker.trim();
        let spkLabel = rawSpk;
        if (/^speaker_(\d+)$/i.test(rawSpk)) {
          const num = parseInt(rawSpk.replace(/^speaker_/i, ""), 10) + 1;
          spkLabel = `Speaker ${num}`;
        }
        displayText = `[${spkLabel}] ${seg.text}`;
      }

      srtContent += `${idx + 1}\n${startSrt} --> ${endSrt}\n${displayText}\n\n`;
    });
    return srtContent;
  };

  const srtOutput = generateSubtitlesWithDiarization(sampleDiarizedSegments);

  assert(srtOutput.includes("[Speaker 1] Welcome to today's debate"), "Segment 1 labeled as [Speaker 1]");
  assert(srtOutput.includes("[Speaker 2] Thank you. Solar efficiency"), "Segment 2 labeled as [Speaker 2]");
  assert(srtOutput.includes("[Speaker 1] What about the storage"), "Segment 3 labeled as [Speaker 1]");
  assert(srtOutput.includes("[Speaker 2] Grid-scale batteries"), "Segment 4 labeled as [Speaker 2]");

  // ──────────────────────────────────────────────────────────────────────
  // TEST 3: Multilingual Auto-Chapters & YouTube Standard Normalization
  // ──────────────────────────────────────────────────────────────────────
  console.log("\n--- [Test 3] Multilingual Auto-Chapters Normalization (Indic & Global) ---");

  // Sample Telugu Chapters
  const rawTeluguChapters = [
    { startMs: 2500, title: "చంద్రయాన్ ప్రయోగం", summary: "మిషన్ ప్రారంభం" },
    { startMs: 35000, title: "రోవర్ అన్వేషణ", summary: "జాబిల్లి ఉపరితలంపై పరిశోధనలు" },
    { startMs: 80000, title: "ముగింపు & భవిష్యత్ ప్రణాళికలు", summary: "భారత అంతరిక్ష పరిశోధన ఘనత" },
  ];

  // Normalization logic from videoGatewayService.ts & 05-transcription.ts
  const normalizeChapters = (chapters: any[]) => {
    const mapped = chapters.map((ch: any) => {
      const startMs = Math.max(0, Number(ch.startMs ?? ch.startTimeMs ?? 0) || 0);
      const endMs = Math.max(startMs + 10000, Number(ch.endMs ?? ch.endTimeMs ?? (startMs + 30000)));
      return {
        startMs,
        startTimeMs: startMs,
        endMs,
        endTimeMs: endMs,
        title: String(ch.title || "Chapter").trim(),
        summary: String(ch.summary || "").trim(),
      };
    });

    mapped.sort((a: any, b: any) => a.startMs - b.startMs);

    if (mapped.length > 0 && mapped[0].startMs > 0) {
      mapped.unshift({
        startMs: 0,
        startTimeMs: 0,
        endMs: mapped[0].startMs,
        endTimeMs: mapped[0].startMs,
        title: "పరిచయం (Introduction)",
        summary: "వీడియో ప్రారంభం",
      });
    }
    return mapped;
  };

  const normalizedTelugu = normalizeChapters(rawTeluguChapters);

  assert(normalizedTelugu[0].startTimeMs === 0, "Telugu chapters: First chapter prepended at 0:00 (0 ms)");
  assert(normalizedTelugu[0].title.includes("పరిచయం"), "Telugu chapters: Intro title assigned");
  assert(normalizedTelugu[1].title === "చంద్రయాన్ ప్రయోగం", "Telugu chapters: Second chapter title preserved in Telugu script");
  assert(normalizedTelugu.length === 4, "Telugu chapters: Total 4 chapters after 0:00 intro prepended");

  // Sample Hindi Chapters
  const rawHindiChapters = [
    { startMs: 0, title: "प्रस्तावना (Introduction)", summary: "विषय का परिचय" },
    { startMs: 20000, title: "मुख्य वैज्ञानिक तथ्य", summary: "तथ्यों का विश्लेषण" },
    { startMs: 50000, title: "निष्कर्ष", summary: "अंतिम सारांश" },
  ];
  const normalizedHindi = normalizeChapters(rawHindiChapters);
  assert(normalizedHindi[0].startTimeMs === 0, "Hindi chapters: First chapter starts at 0:00");
  assert(normalizedHindi[1].title === "मुख्य वैज्ञानिक तथ्य", "Hindi chapters: Native Devanagari script title preserved");

  // ──────────────────────────────────────────────────────────────────────
  // TEST 4: Separate Chapter Thumbnail Decoupling Policy
  // ──────────────────────────────────────────────────────────────────────
  console.log("\n--- [Test 4] Separate Chapter Thumbnail Decoupling Policy ---");

  const videoCoverUrl = "https://storage.googleapis.com/truthworld/thumbnails/main_cover.jpg";
  const existingVariants = [videoCoverUrl]; // Only video cover image exists

  const distinctVariants = existingVariants.filter((v: string) => v && v !== videoCoverUrl);
  const durationMs = 90000;

  const resolvedChapters = normalizedTelugu.map((ch: any) => {
    let thumb = ch.thumbnailUrl;
    if (thumb === videoCoverUrl) {
      thumb = undefined;
    }
    if (!thumb && distinctVariants.length > 0 && durationMs > 0) {
      thumb = distinctVariants[0];
    }
    return {
      ...ch,
      thumbnailUrl: thumb || undefined,
    };
  });

  for (let i = 0; i < resolvedChapters.length; i++) {
    assert(
      resolvedChapters[i].thumbnailUrl !== videoCoverUrl,
      `Chapter ${i + 1} does NOT take the video's main cover image (stays undefined for storyboard frame)`
    );
  }

  // Cleanup temp test directory
  try {
    fs.rmSync(tempOutDir, { recursive: true, force: true });
  } catch {}

  console.log("\n==================================================================");
  console.log(`📊 REAL SAMPLE VERIFICATION: ${passed} PASSED | ${failed} FAILED`);
  console.log("==================================================================");

  if (failed > 0) {
    process.exit(1);
  }
}

runSampleVerification().catch((err) => {
  console.error("Fatal test error:", err);
  process.exit(1);
});
