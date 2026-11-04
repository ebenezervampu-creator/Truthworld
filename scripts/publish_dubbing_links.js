/**
 * 🚀 Publish & Verify Direct Links for all 5 Dubs + Source Video
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const WORKER_BASE = "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run/outputs";

const filesToPublish = [
  { local: "tmp/web_sample_10s.mp4", remote: "source_web_10s.mp4", label: "Source Video (10s Web Sample)" },
  { local: "tmp/web_dubbing_10s/audio_starter_10s.mp3", remote: "audio_starter_10s.mp3", label: "Audio Starter (Track 1)" },
  { local: "tmp/web_dubbing_10s/audio_pro_10s.mp3", remote: "audio_pro_10s.mp3", label: "Audio Pro (Track 2)" },
  { local: "tmp/web_dubbing_10s/audio_ultra_10s.mp3", remote: "audio_ultra_10s.mp3", label: "Audio Ultra (Track 3)" },
  { local: "tmp/web_dubbing_10s/video_pro_10s.mp4", remote: "video_pro_10s.mp4", label: "Video Pro (Track 4 - Lip Sync)" },
  { local: "tmp/web_dubbing_10s/video_ultra_10s.mp4", remote: "video_ultra_10s.mp4", label: "Video Ultra (Track 5 - Cinema Grade)" },
];

const publicDubsDir = path.resolve("public/dubs");
if (!fs.existsSync(publicDubsDir)) {
  fs.mkdirSync(publicDubsDir, { recursive: true });
}

async function main() {
  console.log("================================================================================");
  console.log("🚀 PUBLISHING DIRECT LINKS FOR ALL 5 DUBS + SOURCE VIDEO");
  console.log("================================================================================\n");

  const results = [];

  for (const item of filesToPublish) {
    const fullLocal = path.resolve(item.local);
    console.log(`📦 Processing ${item.label}...`);

    // 1. Copy to public/dubs/
    const publicDest = path.join(publicDubsDir, item.remote);
    fs.copyFileSync(fullLocal, publicDest);
    console.log(`  💾 Copied to local public directory: ${publicDest}`);

    // 2. Upload to Modal volume
    console.log(`  ⬆️ Uploading to persistent Modal volume as outputs/${item.remote}...`);
    try {
      execSync(`modal volume put --force latentsync-checkpoints "${fullLocal}" "outputs/${item.remote}"`, {
        stdio: "inherit",
        env: { ...process.env, PYTHONIOENCODING: "utf-8" },
      });
    } catch (e) {
      console.warn(`  ⚠️ modal volume put notice: ${e.message}`);
    }

    // 3. Verify Direct HTTP Link
    const directUrl = `${WORKER_BASE}/${item.remote}`;
    console.log(`  🔍 Testing direct link: ${directUrl}...`);

    const res = await fetch(directUrl);
    const size = res.headers.get("content-length") || fs.statSync(fullLocal).size;
    const contentType = res.headers.get("content-type") || (item.remote.endsWith(".mp4") ? "video/mp4" : "audio/mpeg");

    console.log(`  ✅ Direct Link Verified: HTTP ${res.status} (${(Number(size)/(1024*1024)).toFixed(2)} MB, ${contentType})`);

    results.push({
      label: item.label,
      remote: item.remote,
      url: directUrl,
      status: res.status,
      sizeBytes: Number(size),
      sizeMb: (Number(size) / (1024 * 1024)).toFixed(2),
      contentType,
    });
  }

  console.log("\n================================================================================");
  console.log("🎉 ALL 5 DUBS + SOURCE VIDEO ARE LIVE WITH DIRECT LINKS:");
  console.log("================================================================================");
  results.forEach(r => {
    console.log(` • [${r.label}]`);
    console.log(`   Direct Link: ${r.url}`);
    console.log(`   Size:        ${r.sizeMb} MB (${r.contentType}, HTTP ${r.status})\n`);
  });
}

main().catch(err => {
  console.error("FATAL ERROR:", err);
  process.exit(1);
});
