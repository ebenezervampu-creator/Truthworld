/**
 * 🎙️ TruthWorld: Zero-Credit ElevenLabs API Key Production Verification
 *
 * Verifies your ElevenLabs API key against live ElevenLabs infrastructure
 * strictly using the metadata endpoint (GET /v1/user/subscription).
 *
 * 💰 Character Cost: 0 characters ($0.00)
 * 🛡️ No audio is synthesized, no credits are deducted.
 *
 * Usage:
 *   node scripts/verify_elevenlabs_production.js
 *   node scripts/verify_elevenlabs_production.js [OPTIONAL_API_KEY]
 */

const https = require("https");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function getApiKey() {
  // 1. Argument passed directly
  if (process.argv[2] && process.argv[2].trim()) {
    return { key: process.argv[2].trim(), source: "CLI argument" };
  }

  // 2. Environment variable
  if (process.env.ELEVENLABS_API_KEY && process.env.ELEVENLABS_API_KEY.trim()) {
    return { key: process.env.ELEVENLABS_API_KEY.trim(), source: "process.env.ELEVENLABS_API_KEY" };
  }

  // 3. Local functions/.env.local
  const envLocalPath = path.resolve(__dirname, "../functions/.env.local");
  if (fs.existsSync(envLocalPath)) {
    const content = fs.readFileSync(envLocalPath, "utf8");
    const match = content.match(/^ELEVENLABS_API_KEY=(.+)$/m);
    if (match && match[1].trim() && !match[1].includes("YOUR_")) {
      return { key: match[1].trim(), source: "functions/.env.local" };
    }
  }

  // 4. GCP Secret Manager
  try {
    const gcpKey = execSync(
      "gcloud secrets versions access latest --secret=ELEVENLABS_API_KEY --project=truthworld-1",
      { stdio: ["pipe", "pipe", "ignore"], encoding: "utf8" }
    ).trim();
    if (gcpKey) {
      return { key: gcpKey, source: "Google Cloud Secret Manager (truthworld-1)" };
    }
  } catch (_) {
    // Ignore if gcloud not available/logged in
  }

  return { key: null, source: null };
}

async function verifyElevenLabs() {
  console.log("\n================================================================================");
  console.log("🎙️  TRUTHWORLD: ZERO-CREDIT ELEVENLABS PRODUCTION VERIFICATION");
  console.log("================================================================================\n");

  const { key, source } = getApiKey();

  if (!key) {
    console.error("❌ No ElevenLabs API key found!");
    console.error("   Please provide it via one of:");
    console.error("     1. node scripts/verify_elevenlabs_production.js <YOUR_KEY>");
    console.error("     2. Setting ELEVENLABS_API_KEY in functions/.env.local");
    console.error("     3. Storing it in GCP Secret Manager (ELEVENLABS_API_KEY)");
    process.exit(1);
  }

  const maskedKey = key.length > 8 ? `${key.substring(0, 4)}...${key.substring(key.length - 4)}` : "****";
  console.log(`[1/2] Loaded Key: ${maskedKey} (Source: ${source})`);
  console.log("[2/2] Connecting to ElevenLabs Subscription Metadata API (GET /v1/user/subscription)...");
  console.log("      💰 Verified Cost: 0 characters ($0.00 credits consumed)\n");

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: "api.elevenlabs.io",
        path: "/v1/user/subscription",
        method: "GET",
        headers: {
          "xi-api-key": key,
          "User-Agent": "TruthWorld-Production-HealthCheck/1.0",
        },
        timeout: 10000,
      },
      (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          if (res.statusCode === 200) {
            try {
              const data = JSON.parse(body);
              console.log("================================================================================");
              console.log("✅ ELEVENLABS PRODUCTION API KEY IS VALID AND ACTIVE!");
              console.log("================================================================================");
              console.log(`  • Plan Tier:                  ${data.tier}`);
              console.log(`  • Status:                     ${data.status}`);
              console.log(`  • Character Usage:            ${data.character_count.toLocaleString()} / ${data.character_limit.toLocaleString()}`);
              console.log(`  • Remaining Characters:       ${(data.character_limit - data.character_count).toLocaleString()}`);
              console.log(`  • Instant Voice Cloning:      ${data.can_use_instant_voice_cloning ? "Enabled" : "Disabled"}`);
              console.log(`  • Professional Voice Cloning: ${data.can_use_professional_voice_cloning ? "Enabled" : "Disabled"}`);
              console.log("--------------------------------------------------------------------------------");
              console.log("🛡️  Zero credits consumed: Verified via read-only subscription metadata endpoint.");
              console.log("================================================================================\n");
              resolve(data);
            } catch (parseErr) {
              console.error("❌ Failed to parse response JSON:", body);
              reject(parseErr);
            }
          } else {
            console.error("================================================================================");
            console.error(`❌ ELEVENLABS AUTHENTICATION FAILED (HTTP Status: ${res.statusCode})`);
            console.error("================================================================================");
            try {
              const errJson = JSON.parse(body);
              console.error(`  Error Code:    ${errJson.detail?.status || errJson.detail?.code || "auth_error"}`);
              console.error(`  Error Message: ${errJson.detail?.message || JSON.stringify(errJson.detail)}`);
            } catch (_) {
              console.error(`  Raw Response:  ${body}`);
            }
            console.error("--------------------------------------------------------------------------------");
            console.error("👉 Please verify the API key and ensure it has not been revoked or expired.");
            console.error("================================================================================\n");
            reject(new Error(`ElevenLabs error status: ${res.statusCode}`));
          }
        });
      }
    );

    req.on("error", (err) => {
      console.error("❌ Network error connecting to ElevenLabs API:", err.message);
      reject(err);
    });

    req.on("timeout", () => {
      req.destroy();
      console.error("❌ Request timed out after 10 seconds.");
      reject(new Error("Timeout"));
    });

    req.end();
  });
}

verifyElevenLabs().catch(() => process.exit(1));
