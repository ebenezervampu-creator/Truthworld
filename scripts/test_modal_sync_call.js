const fs = require("fs");
const path = require("path");

async function testModalSync() {
  const url = "https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run/sync";
  
  // Real audio synthesized earlier with ElevenLabs (Tier 2 / Tier 3)
  const audioPath = path.resolve("tmp/dubbing_5s_real/tier2_audio_pro_real.mp3");
  const audioBase64 = fs.readFileSync(audioPath).toString("base64");
  const audioDataUri = `data:audio/mp3;base64,${audioBase64}`;

  // Public talking head video benchmark from LatentSync
  const videoUrl = "https://github.com/bytedance/LatentSync/raw/main/assets/demo1_video.mp4";

  console.log("🚀 Sending real Lip-Sync inference request to deployed Modal worker...");
  console.log("Endpoint:", url);
  console.log("Audio Size (bytes):", fs.statSync(audioPath).size);
  console.log("Video URL:", videoUrl);

  const payload = {
    jobId: "real_test_job_101",
    videoUrl: videoUrl,
    audioUrl: audioDataUri,
    language: "es",
    mode: "latentsync",
    faceRestoration: true
  };

  try {
    const t0 = Date.now();
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    const elapsed = (Date.now() - t0) / 1000;
    console.log(`\n✅ Modal /sync status ${res.status} in ${elapsed.toFixed(1)}s!`);
    console.log("Response data:", JSON.stringify(data, null, 2));
  } catch (err) {
    console.error("❌ Request error:", err.message);
  }
}

testModalSync();
