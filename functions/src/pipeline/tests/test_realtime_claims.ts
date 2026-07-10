import { ClaimVerificationService } from "../services/claimVerification.js";
import { PIPELINE_CONFIG } from "../config.js";
import { ClaimNature, FilteredClaim } from "../types.js";

async function main() {
  console.log("🚀 Initializing Claim Verification Service with Live Grounding...");
  const verificationService = new ClaimVerificationService(PIPELINE_CONFIG.GEMINI_API_KEY, 0.6);

  const claims: FilteredClaim[] = [
    {
      claimId: "claim_1",
      text: "Anthropic launched Claude 3.5 Sonnet in June 2024.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.8,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_2",
      text: "The speed of light in a vacuum is exactly 299,792,458 meters per second.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.5,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_3",
      text: "Keir Starmer is the Prime Minister of the United Kingdom.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.9,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_4",
      text: "The capital of Australia is Sydney.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.7,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_5",
      text: "OpenAI released GPT-5 on January 1, 2025.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.8,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_6",
      text: "Water is composed of two hydrogen atoms and one oxygen atom.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.5,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_7",
      text: "NASA's Artemis program aims to land the first woman and next man on the Moon.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.8,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_8",
      text: "The stock price of Apple reached $500 per share in 2024.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.8,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_9",
      text: "Bitcoin was created by an anonymous person or group known as Satoshi Nakamoto.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.6,
      chunkIndex: 0,
      start: 0,
      end: 0
    },
    {
      claimId: "claim_10",
      text: "The 2024 Summer Olympics were held in Paris, France.",
      nature: ClaimNature.VERIFIABLE_FACT,
      framing: "ASSERTIVE" as any,
      confidence: 0.95,
      importance: 0.8,
      chunkIndex: 0,
      start: 0,
      end: 0
    }
  ];

  console.log(`📡 Verifying ${claims.length} claims with Google Search grounding...`);
  const t0 = Date.now();
  
  const verifiedClaims = await verificationService.verifyClaimBatch(
    claims,
    "General",
    {
      groundingMode: "always",
      forcePro: false,
      minSourcesRequired: 1,
      sourceDiversityRequired: false
    }
  );

  const durationSec = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(`\n✅ Verification completed in ${durationSec}s!\n`);

  console.log("==========================================================================================");
  console.log("                               VERIFICATION RESULTS                                       ");
  console.log("==========================================================================================");

  verifiedClaims.forEach((vc, idx) => {
    console.log(`\n[CLAIM ${idx + 1}] ID: ${vc.claimId}`);
    console.log(`🗣️ Claim:      "${vc.text}"`);
    console.log(`🚦 Status:     ${vc.status.toUpperCase()}`);
    console.log(`🎯 Rating:     ${vc.rating}/10`);
    console.log(`🧠 Summary:    ${vc.reasoning}`);
    console.log(`🔗 Sources (${vc.richSources?.length || 0}):`);
    (vc.richSources || []).forEach((src) => {
      console.log(`   - [Tier ${src.tier}] ${src.title} (${src.url})`);
    });
    console.log("------------------------------------------------------------------------------------------");
  });
}

main().catch((err) => {
  console.error("❌ Execution failed:", err);
});
