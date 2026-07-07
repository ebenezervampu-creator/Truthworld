import { ScoringEngine } from "../pipeline/services/scoringEngine";
import { VerifiedClaim, TranscriptData, ClaimNature, FramingStyle } from "../pipeline/types";

const engine = new ScoringEngine();

const mockClaims: VerifiedClaim[] = [
  // 8 Verified True Claims
  {
    claimId: "1",
    text: "India produces over 22% of the world's milk.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.95,
    status: "verified_true",
    importance: 0.8,
    riskLevel: "low",
    verificationConfidence: 0.95,
    reasoning: "Verified true against global agricultural stats.",
    sources: [],
    richSources: []
  },
  {
    claimId: "2",
    text: "India has over 150,000 post offices.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.95,
    status: "verified_true",
    importance: 0.6,
    riskLevel: "low",
    verificationConfidence: 0.95,
    reasoning: "India's postal network is well documented.",
    sources: [],
    richSources: []
  },
  {
    claimId: "3",
    text: "India has the largest postal network on earth.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.95,
    status: "verified_true",
    importance: 0.7,
    riskLevel: "low",
    verificationConfidence: 0.95,
    reasoning: "Matches global postal union statistics.",
    sources: [],
    richSources: []
  },
  {
    claimId: "4",
    text: "India has a postal office floating on Lake Dal in Kashmir.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.90,
    status: "verified_true",
    importance: 0.4,
    riskLevel: "low",
    verificationConfidence: 0.90,
    reasoning: "Famous floating post office is real.",
    sources: [],
    richSources: []
  },
  {
    claimId: "5",
    text: "India is the spice capital of the world.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.95,
    status: "verified_true",
    importance: 0.7,
    riskLevel: "low",
    verificationConfidence: 0.95,
    reasoning: "Widely accepted classification historically and commercially.",
    sources: [],
    richSources: []
  },
  {
    claimId: "6",
    text: "India has the largest film industry.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.95,
    status: "verified_true",
    importance: 0.8,
    riskLevel: "low",
    verificationConfidence: 0.95,
    reasoning: "Correct by volume of movies produced.",
    sources: [],
    richSources: []
  },
  {
    claimId: "7",
    text: "India's milk production is more than the entire European Union combined.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.92,
    status: "verified_true",
    importance: 0.7,
    riskLevel: "low",
    verificationConfidence: 0.92,
    reasoning: "Correct, verified by FAO stats.",
    sources: [],
    richSources: []
  },
  {
    claimId: "8",
    text: "Bollywood releases more movies annually than Hollywood.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.95,
    status: "verified_true",
    importance: 0.6,
    riskLevel: "low",
    verificationConfidence: 0.95,
    reasoning: "Correct by volume comparisons.",
    sources: [],
    richSources: []
  },
  
  // 2 Numerical Exaggerations (false)
  {
    claimId: "9",
    text: "India produces 70% of global spices.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.90,
    status: "verified_false",
    importance: 0.5,
    riskLevel: "low",
    verificationConfidence: 0.90,
    reasoning: "Incorrect. The actual share is around 40-50%.",
    sources: [],
    richSources: []
  },
  {
    claimId: "10",
    text: "Bollywood releases over 10,000 movies each year.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.95,
    status: "verified_false",
    importance: 0.4,
    riskLevel: "low",
    verificationConfidence: 0.95,
    reasoning: "Incorrect exaggeration. Actual count is 1,500-2,000.",
    sources: [],
    richSources: []
  },

  // 1 Category Ambiguity (misleading)
  {
    claimId: "11",
    text: "RRR is a Bollywood film directed by S. S. Rajamouli.",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    chunkIndex: 0,
    confidence: 0.98,
    status: "partially_true",
    importance: 0.3,
    riskLevel: "low",
    verificationConfidence: 0.98,
    reasoning: "Incorrect category classification. RRR is Tollywood (Telugu), not Bollywood.",
    sources: [],
    richSources: []
  }
];

const mockTranscript: TranscriptData = {
  text: "Mock transcript text",
  utterances: [],
  language: "en",
  confidence: 1.0,
  duration: 60
};

console.log("Running scoring calibration simulation...");
const result = engine.calculateInstitutionalTrustScore(
  "mock_video",
  "mock_user",
  mockTranscript,
  mockClaims,
  mockClaims.length,
  "balanced",
  "medium",
  "General",
  {
    contentIntent: { primaryIntent: "educational" }
  }
);

console.log("\n--- SIMULATION RESULTS ---");
console.log(`Trust Index / Score: ${result.trustScore}`);
console.log(`Trust Label: ${result.trustLabel}`);
if (result.factors) {
  console.log(`Honesty Score: ${result.factors.honesty}`);
  console.log(`Rationality Score: ${result.factors.consistency}`);
}
console.log("\nDeductions Ledger:");
result.deductions?.forEach((d: any) => {
  console.log(`- [${d.factor.toUpperCase()}] -${d.points} pts: ${d.reason}`);
});
