/**
 * 🎬 TRUTHWORLD DUBBING & LIP-SYNC VERIFICATION: TELUGU (te)
 *
 * Tests 5-second English video clip dubbed into Telugu:
 *  - Test 1: Video Pro Tier ($3.00) -> 1080p source preservation, Reinhard Lab color calibration, Poisson blending
 *  - Test 2: Video Ultra Cinema Tier ($5.00) -> 4K oral detail, Farneback optical flow temporal coherence, saliva specular sheen, film grain
 */

const fs = require("fs");
const path = require("path");

const WORKER_URL = "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run";

async function runTier(tierName, isUltra, videoDataUri, audioDataUri) {
  const jobId = `telugu_5s_${tierName}_${Date.now()}`;
  console.log(`\n================================================================================`);
  console.log(`🎬 INITIATING [${tierName.toUpperCase()}] TELUGU LIP-SYNC RUN`);
  console.log(`================================================================================`);
  console.log(` • Job ID:        ${jobId}`);
  console.log(` • Target Lang:   te (Telugu)`);
  console.log(` • Quality Tier:  ${tierName} (CinemaGrade: ${isUltra})`);
  console.log(` • Target Engine: LatentSync-1.6 + FaceHarmonizer [${isUltra ? "Ultra Optical Flow Lock" : "Pro 1080p"}]`);

  const payload = {
    jobId,
    videoUrl: videoDataUri,
    audioUrl: audioDataUri,
    language: "te",
    mode: "latentsync",
    faceRestoration: true,
    tier: isUltra ? "video_ultra" : "video_pro",
    cinemaGrade: isUltra,
    qualityMode: isUltra ? "ultra" : "pro",
  };

  const t0 = Date.now();
  console.log(`📡 Dispatching inference payload to GPU worker (/sync)...`);
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

  if (data.videoUrl) {
    const localDest = path.resolve(`tmp/telugu_output_${tierName}.mp4`);
    console.log(`📥 Downloading ${tierName.toUpperCase()} output video to ${localDest}...`);
    try {
      const vidRes = await fetch(data.videoUrl);
      if (vidRes.ok) {
        const buffer = await vidRes.arrayBuffer();
        fs.writeFileSync(localDest, Buffer.from(buffer));
        console.log(`💾 Saved ${localDest} (${(buffer.byteLength / 1024).toFixed(1)} KB)`);
      } else {
        console.warn(`⚠️ Direct fetch returned HTTP ${vidRes.status}. Falling back to Modal Volume retrieval...`);
        const urlParts = data.videoUrl.split("/");
        const filename = urlParts[urlParts.length - 1];
        const { execSync } = require("child_process");
        execSync(`modal volume get latentsync-checkpoints outputs/${filename} ${localDest}`, { stdio: "inherit" });
        console.log(`💾 Saved ${localDest} from Modal Volume!`);
      }
    } catch (fetchErr) {
      console.warn(`⚠️ Download error: ${fetchErr.message}. Attempting Modal Volume fallback...`);
      const urlParts = data.videoUrl.split("/");
      const filename = urlParts[urlParts.length - 1];
      const { execSync } = require("child_process");
      execSync(`modal volume get latentsync-checkpoints outputs/${filename} ${localDest}`, { stdio: "inherit" });
      console.log(`💾 Saved ${localDest} from Modal Volume!`);
    }
  }

  return { tier: tierName, elapsedSec: durationSec, data };
}

async function main() {
  console.log("================================================================================");
  console.log("🚀 STARTING DUAL-TIER TELUGU DUBBING VERIFICATION (PRO & ULTRA)");
  console.log("================================================================================\n");

  // 1. Health check
  console.log("📡 [Step 1] Checking GPU Worker health status...");
  const healthRes = await fetch(`${WORKER_URL}/health`);
  const healthData = await healthRes.json();
  console.log("✅ Worker Health Check:", healthData);

  // 2. Prepare Audio
  console.log("\n🔊 [Step 2] Preparing Telugu reference audio...");
  const audioPath = path.resolve("tmp/telugu_5s_speech.mp3");
  if (!fs.existsSync(audioPath)) {
    console.error(`❌ Telugu audio asset missing: ${audioPath}`);
    process.exit(1);
  }
  const audioBase64 = fs.readFileSync(audioPath).toString("base64");
  const audioDataUri = `data:audio/mp3;base64,${audioBase64}`;
  console.log(`✅ Loaded Telugu audio: ${(audioBase64.length / 1024).toFixed(1)} KB base64`);

  // 3. Prepare Video (Pristine presenter video uploaded by user: check_the_output.mp4)
  console.log("\n👤 [Step 3] Preparing pristine 5-second presenter video (check_the_output.mp4)...");
  const videoPath = path.resolve("C:/Users/ebene/.gemini/antigravity/brain/10727ba2-3129-4bd9-ac74-5afd862811d9/.user_uploaded/media_1793595239366_70e84d05.mp4");
  if (!fs.existsSync(videoPath)) {
    console.error(`❌ Source video asset missing: ${videoPath}`);
    process.exit(1);
  }
  const videoBase64 = fs.readFileSync(videoPath).toString("base64");
  const videoDataUri = `data:video/mp4;base64,${videoBase64}`;
  console.log(`✅ Loaded English presenter video: ${(videoBase64.length / 1024).toFixed(1)} KB base64`);

  // 4. Run Pro Tier
  console.log("\n================================================================================");
  console.log("▶️ STEP 4: PROCESSING PRO TIER ($3.00)");
  console.log("================================================================================");
  const proResult = await runTier("pro", false, videoDataUri, audioDataUri);

  // 5. Run Ultra Tier
  console.log("\n================================================================================");
  console.log("▶️ STEP 5: PROCESSING ULTRA CINEMA TIER ($5.00)");
  console.log("================================================================================");
  const ultraResult = await runTier("ultra", true, videoDataUri, audioDataUri);

  console.log("\n================================================================================");
  console.log("🏁 DUAL-TIER COMPARISON SUMMARY");
  console.log("================================================================================");
  console.log(` • PRO TIER:   Status=${proResult.data.status} | Latency=${proResult.elapsedSec}s | Video=${proResult.data.videoUrl}`);
  console.log(` • ULTRA TIER: Status=${ultraResult.data.status} | Latency=${ultraResult.elapsedSec}s | Video=${ultraResult.data.videoUrl}`);
  console.log("================================================================================\n");
}

main().catch((err) => {
  console.error("❌ Fatal execution error:", err);
  process.exit(1);
});
