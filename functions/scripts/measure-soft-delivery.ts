import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import axios from "axios";
import * as dotenv from "dotenv";
import { execFile } from "child_process";
import { promisify } from "util";
import { estimatePitch, f32leToSamples } from "../src/pipeline/services/pitch-estimation";
import { getFfmpegPath } from "../src/pipeline/services/media";

const execFileAsync = promisify(execFile);

dotenv.config({ path: path.resolve(__dirname, "../.env") });
const envLocal = path.resolve(__dirname, "../.env.local");
if (fs.existsSync(envLocal)) {
  dotenv.config({ path: envLocal, override: true });
}

const apiKey = process.env.ELEVENLABS_API_KEY;
if (!apiKey || apiKey === "mock_key") {
  console.error("ELEVENLABS_API_KEY is missing or mock_key");
  process.exit(1);
}

const FFMPEG = getFfmpegPath() || "ffmpeg";

interface TestItem {
  id: string;
  lang: string;
  voiceId: string;
  voiceName: string;
  text: string;
  stability: number;
  similarity: number;
}

const TEST_ITEMS: TestItem[] = [
  {
    id: "TE-1",
    lang: "te",
    voiceId: "RoLT1qx7XJRXxWSIG5hS",
    voiceName: "Bharadwaj",
    text: "సరైనదని మనకు తెలిసిన నిర్ణయాన్నే మనం తీసుకున్నాం.",
    stability: 0.57,
    similarity: 0.85,
  },
  {
    id: "TE-2",
    lang: "te",
    voiceId: "RoLT1qx7XJRXxWSIG5hS",
    voiceName: "Bharadwaj",
    text: "చెబితే తప్ప మనం ఎవరో తనకెలా తెలుస్తుంది?",
    stability: 0.57,
    similarity: 0.85,
  },
  {
    id: "TE-3",
    lang: "te",
    voiceId: "mvTVhSTUXcuGkC3ojN1I",
    voiceName: "Netri",
    text: "స్టీఫెన్ గ్రాంట్ రోజర్స్?",
    stability: 0.55,
    similarity: 0.85,
  },
  {
    id: "HI-1",
    lang: "hi",
    voiceId: "RoLT1qx7XJRXxWSIG5hS",
    voiceName: "Bharadwaj",
    text: "हमने वही फैसला किया जो हमें सही लगा।",
    stability: 0.57,
    similarity: 0.85,
  },
  {
    id: "HI-2",
    lang: "hi",
    voiceId: "mvTVhSTUXcuGkC3ojN1I",
    voiceName: "Netri",
    text: "जब तक हम बताएंगे नहीं, उसे कैसे पता चलेगा?",
    stability: 0.55,
    similarity: 0.85,
  },
  {
    id: "HI-3",
    lang: "hi",
    voiceId: "mvTVhSTUXcuGkC3ojN1I",
    voiceName: "Netri",
    text: "क्या आप स्टीव रोजर्स हैं?",
    stability: 0.55,
    similarity: 0.85,
  },
];

async function synthesize(text: string, voiceId: string, stability: number, similarity: number, lang: string): Promise<Buffer> {
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;
  const resp = await axios.post(
    url,
    {
      text,
      model_id: "eleven_v4",
      language_code: lang,
      voice_settings: {
        stability,
        similarity_boost: similarity,
        use_speaker_boost: true,
      },
    },
    {
      headers: {
        "xi-api-key": apiKey,
        "Content-Type": "application/json",
      },
      responseType: "arraybuffer",
      timeout: 30000,
    }
  );
  return Buffer.from(resp.data);
}

async function analyzeAudio(mp3Buffer: Buffer): Promise<{
  durationSec: number;
  f0Hz: number | null;
  voicedFrames: number;
  voicedRatio: number;
  meanVolumeDb: number | null;
  spreadSemitones: number;
}> {
  const tmpDir = os.tmpdir();
  const inPath = path.join(tmpDir, `test_in_${Date.now()}_${Math.random().toString(36).slice(2)}.mp3`);
  fs.writeFileSync(inPath, mp3Buffer);

  try {
    // 1. RMS Mean volume
    let meanVolumeDb: number | null = null;
    try {
      const { stderr } = await execFileAsync(
        FFMPEG,
        ["-i", inPath, "-af", "volumedetect", "-f", "null", process.platform === "win32" ? "NUL" : "/dev/null"],
        { timeout: 10000 }
      );
      const m = stderr.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
      if (m) meanVolumeDb = parseFloat(m[1]);
    } catch {}

    // 2. Decode to PCM 16kHz f32le mono
    const { stdout } = await execFileAsync(
      FFMPEG,
      ["-v", "error", "-i", inPath, "-ac", "1", "-ar", "16000", "-f", "f32le", "pipe:1"],
      { encoding: "buffer", maxBuffer: 50 * 1024 * 1024, timeout: 10000 } as any
    );
    const buf = Buffer.from(stdout as unknown as Buffer);
    const samples = f32leToSamples(buf);
    const durationSec = Number((samples.length / 16000).toFixed(2));

    const pitch = estimatePitch(samples, 16000, {
      minHz: 60,
      maxHz: 700,
      hopMs: 10,
      threshold: 0.3,
      relativeSilence: 0.2,
    });

    return {
      durationSec,
      f0Hz: pitch ? pitch.medianHz : null,
      voicedFrames: pitch ? pitch.voicedFrames : 0,
      voicedRatio: pitch ? pitch.voicedRatio : 0,
      meanVolumeDb,
      spreadSemitones: pitch ? pitch.spreadSemitones : 0,
    };
  } finally {
    try {
      fs.unlinkSync(inPath);
    } catch {}
  }
}

async function main() {
  console.log("=== ElevenLabs Soft Delivery Measurement Test ===");
  console.log(`Testing ${TEST_ITEMS.length} lines both ways: Take A ([softly]) vs Take B (no tag)`);

  let totalChars = 0;
  const results: any[] = [];

  for (const item of TEST_ITEMS) {
    const textSoftly = `[softly] ${item.text}`;
    const textUntagged = item.text;

    totalChars += textSoftly.length + textUntagged.length;

    console.log(`\nSynthesizing ${item.id} (${item.lang}, ${item.voiceName})...`);

    // Take A: [softly]
    const mp3A = await synthesize(textSoftly, item.voiceId, item.stability, item.similarity, item.lang);
    const metricsA = await analyzeAudio(mp3A);

    // Short delay to avoid rate limit
    await new Promise((r) => setTimeout(r, 600));

    // Take B: untagged
    const mp3B = await synthesize(textUntagged, item.voiceId, item.stability, item.similarity, item.lang);
    const metricsB = await analyzeAudio(mp3B);

    await new Promise((r) => setTimeout(r, 600));

    results.push({
      item,
      takeA: { text: textSoftly, ...metricsA },
      takeB: { text: textUntagged, ...metricsB },
    });

    console.log(`  Take A [softly]: dur=${metricsA.durationSec}s, F0=${metricsA.f0Hz ?? "none"} Hz, voicedRatio=${(metricsA.voicedRatio * 100).toFixed(0)}%, RMS=${metricsA.meanVolumeDb ?? "none"} dB`);
    console.log(`  Take B [none]  : dur=${metricsB.durationSec}s, F0=${metricsB.f0Hz ?? "none"} Hz, voicedRatio=${(metricsB.voicedRatio * 100).toFixed(0)}%, RMS=${metricsB.meanVolumeDb ?? "none"} dB`);
  }

  // Cost calculation: ElevenLabs v4 Turbo standard tier is $0.08 / 1000 characters
  const costUsd = Number(((totalChars / 1000) * 0.08).toFixed(4));
  console.log(`\n=== Summary ===`);
  console.log(`Total characters: ${totalChars}, Estimated cost: $${costUsd}`);

  const reportPath = path.resolve(__dirname, "../../local-dub-output/soft-delivery-measurements.json");
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, JSON.stringify({ totalChars, costUsd, results }, null, 2));
  console.log(`Measurements saved to ${reportPath}`);
}

main().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
