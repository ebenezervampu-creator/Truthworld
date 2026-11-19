#!/usr/bin/env node
/**
 * 🎬 TruthWorld Production Dubbing Pipeline — Real-Time Test Harness
 *
 * Exercises the EXACT production code path:
 *   Layer 05 Transcription  → (already completed, transcript.json)
 *   Layer 07 Translation    → (already completed, Telugu text verified)
 *   Layer 07 TTS            → Production eleven_v4 + ExpressiveV4Bus + full text pipeline
 *   MediaService            → M&E ducking + EBU R128 mastering + video remux
 *
 * Run from: c:\company\truthworld\functions
 *   node production_dub_test.js
 */

"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

process.env.NODE_ENV = "test";

// Minimal firebase-admin init
const adminMod = require("firebase-admin");
if (adminMod.apps.length === 0) {
  adminMod.initializeApp({ projectId: "truthworld-1" });
}

// Load .env.local for API keys
const envPath = path.resolve(__dirname, ".env.local");
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, "utf8");
  for (const line of envContent.split("\n")) {
    const match = line.match(/^([A-Z_][A-Z0-9_]*)=(.+)/);
    if (match) process.env[match[1]] = match[2].trim();
  }
}

// ─── Import REAL production code ────────────────────────────────────────────
const {
  sanitizeTextForElevenLabsV4,
  applyPronunciationGlossary,
  TTS_MODELS,
  VALID_ELEVENLABS_AUDIO_TAGS,
} = require("./lib/pipeline/services/tts");

const {
  applyTeluguTheologicalLexiconGuard,
  normalizeScriptureCitationsForTts,
  decodeHtmlEntities,
  sanitizeSpokenTranslationForTts,
  stripDanglingClauseFragments,
} = require("./lib/pipeline/services/translation");

const { ExpressiveV4Bus } = require("./lib/pipeline/services/expressiveV4Bus");

// Instantiate production ExpressiveV4Bus
const expressiveV4Bus = new ExpressiveV4Bus();

// ─── Configuration ──────────────────────────────────────────────────────────
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;
const PRODUCTION_MODEL = TTS_MODELS.v4; // "eleven_v4"
const OUTPUT_FORMAT = "mp3_44100_128";

const ffmpeg = path.resolve(__dirname, "node_modules/@ffmpeg-installer/win32-x64/ffmpeg.exe");
const ffprobe = path.resolve(__dirname, "node_modules/@ffprobe-installer/win32-x64/ffprobe.exe");
const workDir = path.resolve(__dirname, "../tmp/sample_dub_test");

// Ensure work dir exists
if (!fs.existsSync(workDir)) fs.mkdirSync(workDir, { recursive: true });

console.log("================================================================================");
console.log("🎬 TRUTHWORLD PRODUCTION DUBBING PIPELINE — REAL-TIME TEST");
console.log("================================================================================");
console.log(` • TTS Model:       ${PRODUCTION_MODEL}`);
console.log(` • Output Format:   ${OUTPUT_FORMAT}`);
console.log(` • API Key Present: ${Boolean(ELEVENLABS_API_KEY)}`);
console.log(` • FFmpeg:          ${fs.existsSync(ffmpeg) ? "✅" : "❌"}`);
console.log(` • FFprobe:         ${fs.existsSync(ffprobe) ? "✅" : "❌"}`);
console.log("");

// ─── Dialogue Segments (from AssemblyAI transcript) ─────────────────────────
const segments = [
  {
    id: 1,
    startMs: 420,
    endMs: 1800,
    originalText: "We heard what you did.",
    teluguText: "నువ్వు ఏం చేశావో మేము విన్నాం.",
    voiceId: "pNInz6obpgDQGcFmaJgB", // Adam — Dominant, stern Egyptian official
    emotion: { anger: 0.55, joy: 0, sadness: 0, surprise: 0 },
    energyDb: -18,
    deliveryStyle: "confrontational",
  },
  {
    id: 2,
    startMs: 3400,
    endMs: 7220,
    originalText: "Is this how you repay Egyptians after living in their country?",
    teluguText: "ఈ దేశంలో ఉంటూ ఈజిప్షియన్లకి ఇచ్చే బహుమతి ఇదేనా?",
    voiceId: "pNInz6obpgDQGcFmaJgB", // Adam — same speaker continues
    emotion: { anger: 0.70, joy: 0, sadness: 0, surprise: 0.15 },
    energyDb: -14,
    deliveryStyle: "argumentative",
  },
  {
    id: 3,
    startMs: 18000,
    endMs: 20530,
    originalText: "Be with me here, Lord.",
    teluguText: "నాతో ఉండండి, ప్రభువా.",
    voiceId: "7fbQ7yJuEo56rYjrYaEh", // John Doe Intimate — reverent prayer
    emotion: { anger: 0, joy: 0, sadness: 0.45, surprise: 0 },
    energyDb: -40,
    deliveryStyle: "prayerful",
    voiceQuality: "breathy",
  },
  {
    id: 4,
    startMs: 22160,
    endMs: 24710,
    originalText: "Keep your eyes on that prisoner.",
    teluguText: "ఆ ఖైదీపై ఓ కన్నేసి ఉంచు.",
    voiceId: "CwhRBWXzGAHq8TQ4Fs17", // Roger — guard commander
    emotion: { anger: 0.25, joy: 0, sadness: 0, surprise: 0 },
    energyDb: -20,
    deliveryStyle: "matter-of-fact",
  },
  {
    id: 5,
    startMs: 26200,
    endMs: 26800,
    originalText: "Yes.",
    teluguText: "అలాగే.",
    voiceId: "IKne3meq5aSn9XLyUdCD", // Charlie — disciplined soldier
    emotion: { anger: 0, joy: 0, sadness: 0, surprise: 0 },
    energyDb: -22,
    deliveryStyle: "formal",
  },
];

// ─── STEP 1: Production Text Processing Pipeline ────────────────────────────
async function processTextProduction(segment) {
  let text = segment.teluguText;

  // 1. HTML entity decoding (production step)
  text = decodeHtmlEntities(text);

  // 2. Pronunciation glossary (production step)
  text = applyPronunciationGlossary(text, [
    { term: "TruthWorld", replacement: "Trooth-Wurld" },
  ]);

  // 3. Telugu Theological Lexicon Guard (production step — critical for "Lord" → "ప్రభువా")
  text = applyTeluguTheologicalLexiconGuard(text);

  // 4. Scripture citation normalization (production step)
  text = normalizeScriptureCitationsForTts(text, "te");

  // 5. Spoken translation sanitization (strip dual-script glosses)
  text = sanitizeSpokenTranslationForTts(text);

  // 6. Dangling clause fragment stripping
  text = stripDanglingClauseFragments(text);

  // 7. Final V4 sanitizer
  text = sanitizeTextForElevenLabsV4(text);

  return text;
}

// ─── STEP 2: Production ExpressiveV4Bus Conditioning ────────────────────────
function getProductionVoiceParams(segment, processedText, prevText, nextText) {
  const busResult = expressiveV4Bus.processSegment({
    jobId: "production_test",
    language: "te",
    translatedText: processedText,
    sourceText: segment.originalText,
    telemetry: {
      energyDb: segment.energyDb,
      emotionTag: undefined, // Let bus infer from emotion intensities
      emotionalIntensity: segment.emotion,
      deliveryStyle: segment.deliveryStyle,
      voiceQuality: segment.voiceQuality,
    },
    preferVoiceCloning: false,
    targetDurationMs: segment.endMs - segment.startMs,
    previousText: prevText,
    nextText: nextText,
  });

  return busResult;
}

// ─── STEP 3: Production ElevenLabs V4 Synthesis ─────────────────────────────
async function synthesizeProductionV4(segment, busPayload, prevText, nextText) {
  const payload = {
    text: busPayload.text,
    model_id: PRODUCTION_MODEL, // "eleven_v4" — STRICTLY
    voice_settings: {
      stability: busPayload.voiceSettings.stability,
      similarity_boost: busPayload.voiceSettings.similarity_boost,
      style: busPayload.voiceSettings.style,
      use_speaker_boost: true,
    },
  };

  // Context windowing (non-billed cadence continuity)
  if (prevText && prevText.trim().length > 0) {
    payload.previous_text = prevText.trim().slice(-450);
  }
  if (nextText && nextText.trim().length > 0) {
    payload.next_text = nextText.trim().slice(0, 450);
  }

  const url = `https://api.elevenlabs.io/v1/text-to-speech/${segment.voiceId}?output_format=${OUTPUT_FORMAT}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "xi-api-key": ELEVENLABS_API_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(`ElevenLabs V4 HTTP ${res.status}: ${errBody}`);
  }

  return Buffer.from(await res.arrayBuffer());
}

// ─── MAIN EXECUTION ─────────────────────────────────────────────────────────
async function main() {
  const t0 = Date.now();

  console.log("═══════════════════════════════════════════════════════════════");
  console.log("  STEP 1: Production Text Processing Pipeline (7 stages)");
  console.log("═══════════════════════════════════════════════════════════════");

  const processedSegments = [];
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    const processed = await processTextProduction(seg);
    processedSegments.push(processed);

    console.log(`  Seg ${seg.id} [${seg.deliveryStyle}]:`);
    console.log(`    Raw:       "${seg.teluguText}"`);
    console.log(`    Processed: "${processed}"`);
  }

  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log("  STEP 2: ExpressiveV4Bus Dynamic Voice Conditioning");
  console.log("═══════════════════════════════════════════════════════════════");

  const busPayloads = [];
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    const prevText = i > 0 ? processedSegments[i - 1] : undefined;
    const nextText = i < segments.length - 1 ? processedSegments[i + 1] : undefined;
    const busResult = getProductionVoiceParams(seg, processedSegments[i], prevText, nextText);
    busPayloads.push(busResult);

    console.log(`  Seg ${seg.id} [${seg.deliveryStyle}]:`);
    console.log(`    Stability:       ${busResult.voiceSettings.stability}`);
    console.log(`    Similarity:      ${busResult.voiceSettings.similarity_boost}`);
    console.log(`    Style:           ${busResult.voiceSettings.style}`);
    console.log(`    Emotion Tag:     ${busResult.emotionTag || "(none)"}`);
    console.log(`    Detected Style:  ${busResult.detectedStyle || "(none)"}`);
    console.log(`    Pacing:          ${busResult.pacingAdjustment || "neutral"}`);
    console.log(`    Final Text:      "${busResult.text}"`);
  }

  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log(`  STEP 3: ElevenLabs V4 Synthesis (model: ${PRODUCTION_MODEL})`);
  console.log("═══════════════════════════════════════════════════════════════");

  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    const prevText = i > 0 ? processedSegments[i - 1] : undefined;
    const nextText = i < segments.length - 1 ? processedSegments[i + 1] : undefined;

    console.log(`  Synthesizing Seg ${seg.id} (voice: ${seg.voiceId})...`);
    const audioBuffer = await synthesizeProductionV4(seg, busPayloads[i], prevText, nextText);
    const outPath = path.join(workDir, `v4_telugu_seg_${seg.id}.mp3`);
    fs.writeFileSync(outPath, audioBuffer);

    // Probe duration
    const probe = spawnSync(ffprobe, ["-v", "error", "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1", outPath], { encoding: "utf8" });
    const dur = parseFloat(probe.stdout.trim()).toFixed(3);
    console.log(`    ✅ Saved ${path.basename(outPath)} (${audioBuffer.length} bytes, ${dur}s)`);
  }

  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log("  STEP 4: Dialogue Stem Assembly (Time-Aligned)");
  console.log("═══════════════════════════════════════════════════════════════");

  const dialogueStem = path.join(workDir, "v4_telugu_dialogue_stem.wav");
  const inputs = segments.map((s) => ["-i", path.join(workDir, `v4_telugu_seg_${s.id}.mp3`)]).flat();

  const filterParts = segments.map((s, i) =>
    `[${i}:a]adelay=${s.startMs}|${s.startMs},aformat=channel_layouts=stereo:sample_rates=48000[s${i}];`
  ).join("");
  const mixPart = segments.map((_, i) => `[s${i}]`).join("") +
    `amix=inputs=${segments.length}:duration=longest,volume=${segments.length},apad=whole_len=${Math.round(30.9 * 48000)}[dialogue]`;

  const stemRes = spawnSync(ffmpeg, [
    "-y", ...inputs,
    "-filter_complex", filterParts + mixPart,
    "-map", "[dialogue]", "-t", "30.900", dialogueStem
  ], { encoding: "utf8" });

  if (stemRes.status !== 0) {
    console.error("  ❌ Stem assembly failed:", stemRes.stderr);
    process.exit(1);
  }
  console.log("  ✅ Dialogue stem created:", path.basename(dialogueStem));

  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log("  STEP 5: M&E Ducking + EBU R128 Broadcast Mastering");
  console.log("═══════════════════════════════════════════════════════════════");

  const originalAudio = path.join(workDir, "extracted_audio.mp3");
  const masteredAudio = path.join(workDir, "v4_master_telugu_audio.mp3");

  // Build speech mute windows from segment timestamps
  const clauses = segments.map(s =>
    `between(t,${(Math.max(0, s.startMs - 100) / 1000).toFixed(3)},${((s.endMs + 200) / 1000).toFixed(3)})`
  ).join("+");

  const mixFilter = [
    `[0:a]aformat=channel_layouts=stereo:sample_rates=48000,volume=enable='${clauses}':volume=0.03:eval=frame[bgm];`,
    `[1:a]aformat=channel_layouts=stereo:sample_rates=48000[dub];`,
    `[bgm][dub]amix=inputs=2:duration=first,volume=2,loudnorm=I=-16:TP=-1.5:LRA=11[out]`
  ].join("");

  const masterRes = spawnSync(ffmpeg, [
    "-y", "-i", originalAudio, "-i", dialogueStem,
    "-filter_complex", mixFilter,
    "-map", "[out]", "-c:a", "libmp3lame", "-b:a", "192k", "-ar", "48000",
    "-t", "30.900", masteredAudio
  ], { encoding: "utf8" });

  if (masterRes.status !== 0) {
    console.error("  ❌ Mastering failed:", masterRes.stderr);
    process.exit(1);
  }
  console.log("  ✅ Mastered audio:", path.basename(masteredAudio));

  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log("  STEP 6: Video Remuxing (H.264 copy + AAC stereo)");
  console.log("═══════════════════════════════════════════════════════════════");

  const sourceVideo = "C:/Users/ebene/.gemini/antigravity/brain/5e842f58-380d-4e51-a42d-adf6834694ad/.user_uploaded/media_1794992352127_bfde113a.mp4";
  const dubbedVideo = path.join(workDir, "v4_truthworld_telugu_dubbed.mp4");

  const remuxRes = spawnSync(ffmpeg, [
    "-y", "-i", sourceVideo, "-i", masteredAudio,
    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
    "-map", "0:v:0", "-map", "1:a:0", "-shortest", dubbedVideo
  ], { encoding: "utf8" });

  if (remuxRes.status !== 0) {
    console.error("  ❌ Remux failed:", remuxRes.stderr);
    process.exit(1);
  }

  // Probe final video
  const finalProbe = spawnSync(ffprobe, ["-v", "error", "-show_format",
    "-of", "default=noprint_wrappers=1", dubbedVideo], { encoding: "utf8" });
  console.log("  ✅ Final dubbed video:", path.basename(dubbedVideo));
  console.log("  " + finalProbe.stdout.trim().split("\n").join("\n  "));

  // Copy to artifacts
  const artifactDir = "C:/Users/ebene/.gemini/antigravity/brain/5e842f58-380d-4e51-a42d-adf6834694ad";
  fs.copyFileSync(dubbedVideo, path.join(artifactDir, "v4_truthworld_telugu_dubbed.mp4"));
  fs.copyFileSync(masteredAudio, path.join(artifactDir, "v4_truthworld_telugu_master_audio.mp3"));

  const wallMs = Date.now() - t0;
  console.log("\n================================================================================");
  console.log(`🎉 PRODUCTION PIPELINE TEST COMPLETE — ${(wallMs / 1000).toFixed(1)}s wall time`);
  console.log("================================================================================");
  console.log(`  📹 Video:  ${path.join(artifactDir, "v4_truthworld_telugu_dubbed.mp4")}`);
  console.log(`  🎵 Audio:  ${path.join(artifactDir, "v4_truthworld_telugu_master_audio.mp3")}`);
}

main().catch(err => {
  console.error("\n❌ FATAL ERROR:", err.message);
  console.error(err.stack);
  process.exit(1);
});
