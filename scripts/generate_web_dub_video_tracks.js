/**
 * 🎬 Generate Video Pro and Video Ultra Dubs from Web Sample Video
 * Dispatches to LatentSync GPU Worker on Modal (NVIDIA A10G)
 */

const fs = require('fs');
const path = require('path');

const WORKER_URL = "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run";
const videoSourcePath = path.resolve('tmp/web_sample_10s.mp4');
const audioProPath = path.resolve('tmp/web_dubbing_10s/audio_pro_10s.mp3');
const audioUltraPath = path.resolve('tmp/web_dubbing_10s/audio_ultra_10s.mp3');

async function runVideoTier(tierName, isUltra, audioPath) {
  const jobId = `web10s_${tierName}_${Date.now()}`;
  console.log(`\n================================================================================`);
  console.log(`🎬 INITIATING [${tierName.toUpperCase()}] 10S VIDEO DUBBING RUN`);
  console.log(`================================================================================`);
  console.log(` • Job ID:       ${jobId}`);
  console.log(` • Source Video: ${videoSourcePath} (${(fs.statSync(videoSourcePath).size / (1024*1024)).toFixed(2)} MB)`);
  console.log(` • Dubbed Audio: ${audioPath} (${(fs.statSync(audioPath).size / 1024).toFixed(1)} KB)`);
  console.log(` • Tier:         ${tierName} (CinemaGrade: ${isUltra})`);

  const videoBase64 = "data:video/mp4;base64," + fs.readFileSync(videoSourcePath).toString("base64");
  const audioBase64 = "data:audio/mp3;base64," + fs.readFileSync(audioPath).toString("base64");

  const payload = {
    jobId,
    videoUrl: videoBase64,
    audioUrl: audioBase64,
    language: "es",
    mode: "latentsync",
    faceRestoration: true,
    tier: isUltra ? "video_ultra" : "video_pro",
    cinemaGrade: isUltra,
    qualityMode: isUltra ? "ultra" : "pro",
  };

  const t0 = Date.now();
  console.log(`📡 Sending payload to GPU Worker (${WORKER_URL}/sync)...`);
  const response = await fetch(`${WORKER_URL}/sync`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  const durationSec = ((Date.now() - t0) / 1000).toFixed(1);
  const data = await response.json();

  console.log(`\n✅ [${tierName.toUpperCase()}] COMPLETE IN ${durationSec}s (HTTP ${response.status})`);
  console.log(` • Status:        ${data.status}`);
  console.log(` • Engine:        ${data.engine}`);
  console.log(` • Face Detected: ${data.faceDetected}`);
  console.log(` • Video URL:     ${data.videoUrl}`);
  console.log(` • Message:       ${data.message}`);

  const localDest = path.resolve(`tmp/web_dubbing_10s/video_${tierName}_10s.mp4`);

  if (data.videoUrl) {
    console.log(`📥 Downloading output video to ${localDest}...`);
    try {
      const vidRes = await fetch(data.videoUrl);
      if (vidRes.ok) {
        const buffer = await vidRes.arrayBuffer();
        fs.writeFileSync(localDest, Buffer.from(buffer));
        console.log(`💾 Saved ${localDest} (${(buffer.byteLength / (1024*1024)).toFixed(2)} MB)`);
      } else {
        throw new Error(`Fetch returned HTTP ${vidRes.status}`);
      }
    } catch (e) {
      console.warn(`Direct fetch failed (${e.message}). Downloading from Modal volume...`);
      const urlParts = data.videoUrl.split("/");
      const filename = urlParts[urlParts.length - 1];
      const { execSync } = require("child_process");
      execSync(`modal volume get latentsync-checkpoints outputs/${filename} ${localDest}`, { stdio: "inherit" });
      console.log(`💾 Saved from Modal Volume: ${localDest}`);
    }
  }

  return { tier: tierName, elapsedSec: durationSec, data, localDest };
}

async function main() {
  console.log("Checking GPU Worker health...");
  const healthRes = await fetch(`${WORKER_URL}/health`);
  const health = await healthRes.json();
  console.log("Health:", health);

  // 1. Run Video Pro
  await runVideoTier("pro", false, audioProPath);

  // 2. Run Video Ultra
  await runVideoTier("ultra", true, audioUltraPath);

  console.log("\n🎉 BOTH VIDEO DUBBING TRACKS COMPLETED SUCCESSFULLY!");
}

main().catch(err => {
  console.error("FATAL ERROR:", err);
  process.exit(1);
});
