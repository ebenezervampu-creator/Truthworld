/**
 * 🎬 Generate Video Ultra (Cinema Grade) Dub from Web Sample Video
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const WORKER_URL = "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run";
const videoSourcePath = path.resolve('tmp/web_sample_10s.mp4');
const audioUltraPath = path.resolve('tmp/web_dubbing_10s/audio_ultra_10s.mp3');

async function main() {
  const jobId = `web10s_ultra_${Date.now()}`;
  console.log("================================================================================");
  console.log("🎬 INITIATING [VIDEO ULTRA - CINEMA GRADE] 10S VIDEO DUBBING RUN");
  console.log("================================================================================");
  console.log(` • Job ID:       ${jobId}`);
  console.log(` • Source Video: ${videoSourcePath} (${(fs.statSync(videoSourcePath).size / (1024*1024)).toFixed(2)} MB)`);
  console.log(` • Dubbed Audio: ${audioUltraPath} (${(fs.statSync(audioUltraPath).size / 1024).toFixed(1)} KB)`);
  console.log(` • Tier:         video_ultra (CinemaGrade: true)`);

  const videoBase64 = "data:video/mp4;base64," + fs.readFileSync(videoSourcePath).toString("base64");
  const audioBase64 = "data:audio/mp3;base64," + fs.readFileSync(audioUltraPath).toString("base64");

  const payload = {
    jobId,
    videoUrl: videoBase64,
    audioUrl: audioBase64,
    language: "es",
    mode: "latentsync",
    faceRestoration: true,
    tier: "video_ultra",
    cinemaGrade: true,
    qualityMode: "ultra",
  };

  const t0 = Date.now();
  console.log(`📡 Dispatching inference payload to GPU worker (/sync)...`);

  // Send request in background or with fetch
  fetch(`${WORKER_URL}/sync`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  }).then(async r => {
    const text = await r.text();
    console.log("Worker HTTP response received:", text.slice(0, 200));
  }).catch(err => {
    console.log("Worker dispatch notice (running async on GPU):", err.message);
  });

  console.log("⏳ Inference is running on NVIDIA A10G GPU. Polling volume for output file...");
  const localDest = path.resolve("tmp/web_dubbing_10s/video_ultra_10s.mp4");

  // Poll for the output file
  let foundFilename = null;
  for (let attempt = 1; attempt <= 45; attempt++) {
    await new Promise(r => setTimeout(r, 10000)); // wait 10s between checks
    process.stdout.write(` [Attempt ${attempt}/45 - ${((Date.now() - t0)/1000).toFixed(0)}s elapsed] Checking volume...\r`);

    try {
      const lsOut = execSync('modal volume ls latentsync-checkpoints outputs', {
        encoding: 'utf8',
        env: { ...process.env, PYTHONIOENCODING: 'utf-8' }
      });
      const lines = lsOut.split('\n');
      const match = lines.find(l => l.includes(jobId));
      if (match) {
        foundFilename = match.trim().replace(/^outputs\//, '');
        console.log(`\n🎉 Found output file in volume: ${foundFilename}!`);
        break;
      }
    } catch (e) {
      // ignore transient exec errors
    }
  }

  if (!foundFilename) {
    throw new Error("Timed out waiting for Video Ultra output file in volume.");
  }

  // Fetch the file directly via the worker's HTTP endpoint
  console.log(`📥 Downloading ${foundFilename} from worker endpoint...`);
  const fileUrl = `${WORKER_URL}/outputs/${foundFilename}`;
  const getRes = await fetch(fileUrl);
  if (!getRes.ok) throw new Error(`HTTP error downloading file: ${getRes.status}`);
  const buf = await getRes.arrayBuffer();
  fs.writeFileSync(localDest, Buffer.from(buf));
  console.log(`✅ Saved ${localDest} (${(buf.byteLength / (1024*1024)).toFixed(2)} MB) in ${((Date.now() - t0)/1000).toFixed(1)}s!`);
}

main().catch(err => {
  console.error("FATAL ERROR:", err);
  process.exit(1);
});
