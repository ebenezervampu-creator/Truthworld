/**
 * 🧪 TRUTHWORLD MANUAL LIP-SYNC VERIFICATION CLI
 *
 * Runs direct verification against the production GPU worker:
 *  - Mode 1 (Talking Head): Real face video -> verifies LatentSync neural diffusion (status: "completed")
 *  - Mode 2 (Screen Share / No Face): Code / slides video -> verifies automatic face detection (status: "no_face_detected")
 *
 * Usage:
 *   node scripts/test_lipsync_scenarios.js --mode=face
 *   node scripts/test_lipsync_scenarios.js --mode=noface
 */

const fs = require("fs");
const path = require("path");

const WORKER_URL = "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run";

async function main() {
  const mode = process.argv.find((arg) => arg.startsWith("--mode="))?.split("=")[1] || "face";
  const tier = process.argv.find((arg) => arg.startsWith("--tier="))?.split("=")[1] || "ultra";
  const isCinemaUltra = tier === "ultra" || tier === "video_ultra";

  console.log("================================================================================");
  console.log(`🎬 TRUTHWORLD LIP-SYNC MANUAL TEST RUNNER [Mode: ${mode.toUpperCase()} | Tier: ${tier.toUpperCase()}]`);
  console.log("================================================================================\n");

  // 1. Health check
  console.log("📡 [1/3] Checking GPU Worker health status...");
  try {
    const healthRes = await fetch(`${WORKER_URL}/health`);
    const healthData = await healthRes.json();
    console.log("✅ Worker Health Check:", healthData);
  } catch (err) {
    console.error("❌ Worker Health Check Failed:", err.message);
    process.exit(1);
  }

  // 2. Prepare Audio
  console.log("\n🔊 [2/3] Preparing reference dubbed audio...");
  const sampleAudioPath = path.resolve("tmp/dubbing_5s_real/tier2_audio_pro_real.mp3");
  if (!fs.existsSync(sampleAudioPath)) {
    console.error(`❌ Audio asset not found at: ${sampleAudioPath}`);
    process.exit(1);
  }
  const audioBase64 = fs.readFileSync(sampleAudioPath).toString("base64");
  const audioDataUri = `data:audio/mp3;base64,${audioBase64}`;

  // 3. Configure Video by Mode
  let videoUrl = "";
  if (mode === "noface") {
    console.log("🖥️ Mode: Screen Share / No Face");
    const testVideoPath = path.resolve("tmp/dubbing_5s_test/source_5s.mp4");
    if (fs.existsSync(testVideoPath)) {
      const videoBase64 = fs.readFileSync(testVideoPath).toString("base64");
      videoUrl = `data:video/mp4;base64,${videoBase64}`;
    } else {
      videoUrl = "https://github.com/intel-iot-devkit/sample-videos/raw/master/classroom.mp4";
    }
  } else {
    console.log("👤 Mode: Talking Head Presenter");
    // Standard LatentSync benchmark talking-head video
    videoUrl = "https://github.com/bytedance/LatentSync/raw/main/assets/demo1_video.mp4";
  }

  const payload = {
    jobId: `manual_test_${mode}_${tier}_${Date.now()}`,
    videoUrl: videoUrl,
    audioUrl: audioDataUri,
    language: "es",
    mode: "latentsync",
    faceRestoration: true,
    tier: isCinemaUltra ? "video_ultra" : "video_pro",
    cinemaGrade: isCinemaUltra,
    qualityMode: isCinemaUltra ? "ultra" : "pro",
  };

  console.log("\n🚀 [3/3] Dispatched request to /sync endpoint...");
  const displayVideoUrl = videoUrl.startsWith("data:") 
    ? `[data URI payload: ${(videoUrl.length / 1024).toFixed(1)} KB]` 
    : videoUrl;
  console.log(`   Video URL: ${displayVideoUrl}`);
  console.log(`   Quality Tier: ${tier.toUpperCase()} (${isCinemaUltra ? "Ultra 4K Oral / Optical Flow Lock" : "Pro 1080p Seamless"})`);
  console.log(`   Target Language: es (Spanish)`);

  const t0 = Date.now();
  try {
    const res = await fetch(`${WORKER_URL}/sync`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
    const data = await res.json();

    console.log(`\n================================================================================`);
    console.log(`📊 INFERENCE COMPLETED IN ${elapsed}s (HTTP ${res.status})`);
    console.log(`================================================================================`);
    console.log("Result Details:");
    console.log(` • Status:       ${data.status}`);
    console.log(` • Engine Used:  ${data.engine}`);
    console.log(` • Face Detected:${data.faceDetected}`);
    console.log(` • Message:      ${data.message}`);
    console.log(` • Output Video: ${data.videoUrl || "(none)"}`);
    console.log(`================================================================================\n`);

    if (mode === "face" && data.status === "completed") {
      console.log("🎉 SUCCESS: Talking head detected & LatentSync neural diffusion generated!");
      console.log(`👉 Open this URL in browser to view the video:\n   ${data.videoUrl}`);
    } else if (mode === "noface" && data.status === "no_face_detected") {
      console.log("🎉 SUCCESS: Screen recording correctly flagged as 'no_face_detected'!");
      console.log("👉 Audio was cleanly remuxed via FFmpeg without crashing.");
      console.log("👉 Pipeline will auto-credit $2.50 to creator's channel wallet.");
    }
  } catch (err) {
    console.error("❌ Inference request error:", err.message);
  }
}

main();
