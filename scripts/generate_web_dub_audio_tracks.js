/**
 * 🎙️ Generate Real Dubbed Audio Tracks (Starter, Pro, Ultra) for 10s Web Sample
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { spawnSync } = require('child_process');

const envContent = fs.readFileSync('functions/.env.local', 'utf8');
const elMatch = envContent.match(/ELEVENLABS_API_KEY=(.+)/);
if (!elMatch) throw new Error("Missing ELEVENLABS_API_KEY");
const ELEVENLABS_API_KEY = elMatch[1].trim();

const ffmpegPath = path.resolve('functions/node_modules/ffmpeg-static/ffmpeg.exe');
const ffprobePath = path.resolve('functions/node_modules/@ffprobe-installer/win32-x64/ffprobe.exe');

const outDir = path.resolve('tmp/web_dubbing_10s');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

function runCmd(bin, args) {
  const res = spawnSync(bin, args, { encoding: 'utf8' });
  if (res.status !== 0) {
    throw new Error(`Command failed: ${bin} ${args.join(' ')}\n${res.stderr}`);
  }
  return res.stdout || res.stderr;
}

function synthesizeElevenLabs(text, voiceId, voiceSettings, rawOutputPath) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      text,
      model_id: "eleven_multilingual_v2",
      voice_settings: voiceSettings,
    });

    const req = https.request({
      hostname: "api.elevenlabs.io",
      path: `/v1/text-to-speech/${voiceId}`,
      method: "POST",
      headers: {
        "xi-api-key": ELEVENLABS_API_KEY,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
    }, (res) => {
      if (res.statusCode !== 200) {
        let errBody = "";
        res.on("data", c => errBody += c);
        res.on("end", () => reject(new Error(`ElevenLabs error (${res.statusCode}): ${errBody}`)));
        return;
      }
      const chunks = [];
      res.on("data", chunk => chunks.push(chunk));
      res.on("end", () => {
        fs.writeFileSync(rawOutputPath, Buffer.concat(chunks));
        resolve(rawOutputPath);
      });
    });

    req.on("error", reject);
    req.write(postData);
    req.end();
  });
}

async function main() {
  console.log("================================================================================");
  console.log("🎙️ GENERATING THREE DUBBED AUDIO TRACKS (STARTER, PRO, ULTRA) FOR 10S WEB CLIP");
  console.log("================================================================================\n");

  const spanishText = "Bienvenidos al estudio de doblaje de TruthWorld. Esta es una demostración de traducción y sincronización de alta fidelidad.";
  console.log(`Speech text: "${spanishText}"\n`);

  // 1. Audio Starter
  console.log("▶ [1/3] Synthesizing Audio Starter (River - Neutral Studio Narration)...");
  const rawStarterMp3 = path.join(outDir, "raw_starter.mp3");
  await synthesizeElevenLabs(
    spanishText,
    "SAz9YHcvj6GT2YYXdXww", // River
    { stability: 0.75, similarity_boost: 0.75 },
    rawStarterMp3
  );

  // Master Starter: Pad to 10.0s with silence at start (0.5s pre-roll) and EBU R128 loudness normalization
  const masterStarterMp3 = path.join(outDir, "audio_starter_10s.mp3");
  runCmd(ffmpegPath, [
    "-y",
    "-i", rawStarterMp3,
    "-af", "adelay=500|500,apad=whole_dur=10,loudnorm=I=-16:TP=-1.5:LRA=11",
    "-t", "10.000",
    "-c:a", "libmp3lame",
    "-b:a", "192k",
    "-ar", "44100",
    masterStarterMp3
  ]);
  console.log("  ✅ Audio Starter mastered:", masterStarterMp3);

  // 2. Audio Pro
  console.log("\n▶ [2/3] Synthesizing Audio Pro (Sarah - Natural Tone & Expressive Cadence)...");
  const rawProMp3 = path.join(outDir, "raw_pro.mp3");
  await synthesizeElevenLabs(
    spanishText,
    "EXAVITQu4vr4xnSDxMaL", // Sarah
    { stability: 0.50, similarity_boost: 0.85, style: 0.35 },
    rawProMp3
  );

  // Master Pro: Dynamic presence EQ, warm saturation, broadcast loudness
  const masterProMp3 = path.join(outDir, "audio_pro_10s.mp3");
  runCmd(ffmpegPath, [
    "-y",
    "-i", rawProMp3,
    "-af", "adelay=500|500,highpass=f=80,equalizer=f=3000:t=q:w=1:g=2,apad=whole_dur=10,loudnorm=I=-14:TP=-1:LRA=9",
    "-t", "10.000",
    "-c:a", "libmp3lame",
    "-b:a", "256k",
    "-ar", "44100",
    masterProMp3
  ]);
  console.log("  ✅ Audio Pro mastered:", masterProMp3);

  // 3. Audio Ultra
  console.log("\n▶ [3/3] Synthesizing Audio Ultra (Laura - Voice Cloned Emotion & Spatial Depth)...");
  const rawUltraMp3 = path.join(outDir, "raw_ultra.mp3");
  await synthesizeElevenLabs(
    spanishText,
    "FGY2WhTYpPnrIDTdsKH5", // Laura
    { stability: 0.40, similarity_boost: 0.95, style: 0.65, use_speaker_boost: true },
    rawUltraMp3
  );

  // Master Ultra: Crystalizer stereo clarity, Hollywood M&E dynamics, cinema loudness
  const masterUltraMp3 = path.join(outDir, "audio_ultra_10s.mp3");
  runCmd(ffmpegPath, [
    "-y",
    "-i", rawUltraMp3,
    "-af", "adelay=500|500,aresample=48000,crystalizer=i=1.5,apad=whole_dur=10,loudnorm=I=-14:TP=-0.5:LRA=7",
    "-t", "10.000",
    "-c:a", "libmp3lame",
    "-b:a", "320k",
    "-ar", "48000",
    masterUltraMp3
  ]);
  console.log("  ✅ Audio Ultra mastered:", masterUltraMp3);

  console.log("\n✨ ALL THREE AUDIO TRACKS SUCCESSFULLY SYNTHESIZED AND MASTERED!");
}

main().catch(err => {
  console.error("FATAL ERROR:", err);
  process.exit(1);
});
