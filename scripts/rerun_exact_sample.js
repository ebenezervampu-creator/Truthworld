const fs = require("fs");
const path = require("path");

const WORKER_URL = "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run";

async function main() {
  console.log("================================================================================");
  console.log("🎬 RE-RENDERING EXACT 5-SECOND PRESENTER CLIP WITH UPDATED GPU WORKER");
  console.log("================================================================================");

  // 1. Health check
  console.log("📡 Checking GPU Worker health status...");
  const healthRes = await fetch(`${WORKER_URL}/health`);
  const healthData = await healthRes.json();
  console.log("✅ Worker Health Check:", healthData);

  // 2. Prepare Video & Audio
  const videoPath = path.resolve("tmp/exact_presenter_video_5s.mp4");
  const audioPath = path.resolve("tmp/extracted_sample_audio.wav");

  const videoBase64 = fs.readFileSync(videoPath).toString("base64");
  const videoDataUri = `data:video/mp4;base64,${videoBase64}`;

  const audioBase64 = fs.readFileSync(audioPath).toString("base64");
  const audioDataUri = `data:audio/wav;base64,${audioBase64}`;

  console.log(`✅ Loaded exact video: ${(videoBase64.length / 1024).toFixed(1)} KB`);
  console.log(`✅ Loaded exact audio: ${(audioBase64.length / 1024).toFixed(1)} KB`);

  const jobId = `rerender_exact_5s_${Date.now()}`;
  const payload = {
    jobId,
    videoUrl: videoDataUri,
    audioUrl: audioDataUri,
    language: "te",
    mode: "latentsync",
    faceRestoration: true,
    tier: "video_ultra",
    cinemaGrade: true,
    qualityMode: "ultra",
  };

  const t0 = Date.now();
  console.log(`\n📡 Dispatching payload to Modal GPU worker (/sync)...`);
  const response = await fetch(`${WORKER_URL}/sync`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  const elapsedSec = ((Date.now() - t0) / 1000).toFixed(1);
  const data = await response.json();
  console.log(`\n✅ Render complete in ${elapsedSec}s (HTTP ${response.status})`);
  console.log(" • Response:", data);

  if (data.videoUrl) {
    const localDest = path.resolve("tmp/new_render_ultra.mp4");
    console.log(`📥 Downloading new render to ${localDest}...`);
    try {
      const vidRes = await fetch(data.videoUrl);
      if (vidRes.ok) {
        const buffer = await vidRes.arrayBuffer();
        fs.writeFileSync(localDest, Buffer.from(buffer));
        console.log(`💾 Saved ${localDest} (${(buffer.byteLength / 1024).toFixed(1)} KB)`);
      } else {
        const urlParts = data.videoUrl.split("/");
        const filename = urlParts[urlParts.length - 1];
        const { execSync } = require("child_process");
        execSync(`modal volume get latentsync-checkpoints outputs/${filename} ${localDest}`, { stdio: "inherit" });
        console.log(`💾 Saved ${localDest} from Modal Volume!`);
      }
    } catch (err) {
      console.warn("Direct fetch warning, trying volume get:", err.message);
      const urlParts = data.videoUrl.split("/");
      const filename = urlParts[urlParts.length - 1];
      const { execSync } = require("child_process");
      execSync(`modal volume get latentsync-checkpoints outputs/${filename} ${localDest}`, { stdio: "inherit" });
      console.log(`💾 Saved ${localDest} from Modal Volume!`);
    }
  }
}

main().catch(console.error);
