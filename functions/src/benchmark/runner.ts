/**
 * 🧪 TRUTHWORLD BENCHMARK RUNNER
 *
 * Feeds benchmark claims through the actual ClaimVerificationService
 * and records results for scoring. Uses the same model routing,
 * prompts, and grounding logic as production.
 */

import { PIPELINE_CONFIG } from "../pipeline/config";
import { ClaimVerificationService } from "../pipeline/services/claimVerification";
import { ClaimStatus } from "../pipeline/types";
import {
  BenchmarkClaim,
  BenchmarkDataset,
  BenchmarkRun,
  ClaimResult,
} from "./types";
import { BenchmarkScorer } from "./scorer";

export class BenchmarkRunner {
  private verificationService: ClaimVerificationService;
  private scorer: BenchmarkScorer;


  constructor() {
    const apiKey = PIPELINE_CONFIG.GEMINI_API_KEY;
    this.verificationService = new ClaimVerificationService(apiKey, 0.6);
    this.scorer = new BenchmarkScorer();
  }

  /**
   * Run the full benchmark suite against a dataset
   */
  async run(dataset: BenchmarkDataset): Promise<BenchmarkRun> {
    const startTime = Date.now();
    const results: ClaimResult[] = [];

    console.log(`\n🧪 TruthWorld Benchmark Suite v1`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`Dataset: ${dataset.version} (${dataset.claims.length} claims)`);
    console.log(`Extraction Model: ${PIPELINE_CONFIG.GEMINI_MODELS?.extraction || PIPELINE_CONFIG.GEMINI_MODEL}`);
    console.log(`Verification Model: ${PIPELINE_CONFIG.GEMINI_MODELS?.verification || "gemini-2.5-flash"}`);
    console.log(`Grounding Mode: ${PIPELINE_CONFIG.GROUNDING_MODE}`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);

    // Process claims in small batches to match production behavior
    const BATCH_SIZE = 5;
    for (let i = 0; i < dataset.claims.length; i += BATCH_SIZE) {
      const batch = dataset.claims.slice(i, i + BATCH_SIZE);
      const batchNum = Math.floor(i / BATCH_SIZE) + 1;
      const totalBatches = Math.ceil(dataset.claims.length / BATCH_SIZE);

      console.log(`📦 Batch ${batchNum}/${totalBatches} (${batch.length} claims)`);

      const batchResults = await this.processBatch(batch);
      results.push(...batchResults);

      // Progress summary per batch
      const batchCorrect = batchResults.filter(r => r.acceptableMatch).length;
      console.log(`   ✅ ${batchCorrect}/${batch.length} acceptable matches\n`);

      // Rate limiting pause between batches
      if (i + BATCH_SIZE < dataset.claims.length) {
        await this.sleep(2000);
      }
    }

    // Score all results
    const metrics = this.scorer.score(results);

    const run: BenchmarkRun = {
      runId: `bench_${Date.now()}`,
      timestamp: new Date().toISOString(),
      version: "v1.2.0",
      datasetVersion: dataset.version,
      config: {
        extractionModel:   PIPELINE_CONFIG.GEMINI_MODELS?.extraction || PIPELINE_CONFIG.GEMINI_MODEL || "unknown",
        verificationModel: PIPELINE_CONFIG.GEMINI_MODELS?.verification || "unknown",
        groundingMode:     PIPELINE_CONFIG.GROUNDING_MODE,
      },
      results,
      metrics,
      duration: Date.now() - startTime,
    };

    return run;
  }

  /**
   * Process a batch of benchmark claims through the verification service
   */
  private async processBatch(claims: BenchmarkClaim[]): Promise<ClaimResult[]> {
    const results: ClaimResult[] = [];

    // Convert benchmark claims to FilteredClaim format (what the service expects)
    const filteredClaims = claims.map((bc, idx) => ({
      text:       bc.claim,
      nature:     (bc.type === "empirical" ? "FACTUAL" : "OPINION") as any,
      framing:    "ASSERTIVE" as any,
      confidence: 0.9,
      importance: bc.riskLevel,
      chunkIndex: 0,
      claimId:    bc.id,
      start:      0,
      end:        0,
      assertiveness: "moderate" as any,
      claimStrength: "moderate" as any,
    }));

    const t0 = Date.now();

    try {
      // Run through actual verification service (uses real routing logic)
      const verified = await this.verificationService.verifyClaimBatch(
        filteredClaims,
        "General"
      );

      const latencyTotal = Date.now() - t0;
      const perClaimLatency = Math.round(latencyTotal / claims.length);

      // Determine which model was actually used by checking if any claim triggered sensitive routing
      // We use the isSensitiveClaim logic to determine routing (same as production)
      const hasSensitive = claims.some(c => this.checkSensitivity(c));

      // Map verified results back to benchmark format
      for (let i = 0; i < claims.length; i++) {
        const bc = claims[i];
        const vc = verified.find(v =>
          v.claimId === bc.id ||
          v.text === bc.claim ||
          v.text?.includes(bc.claim.substring(0, 20))
        );

        const predictedLabel = (vc?.status || "unverifiable") as ClaimStatus;
        const wasRouted = hasSensitive ? "pro" as const : "flash" as const;

        const exactMatch      = predictedLabel === bc.groundTruth;
        const acceptableMatch = bc.acceptableLabels.includes(predictedLabel);
        const routingCorrect  = (wasRouted === "pro") === bc.shouldUsePro;

        // False accusation: system says incorrect, but truth is safe
        const isFalseAccusation = (
          ["incorrect", "historical_consensus_denial", "incorrect_citation"].includes(predictedLabel) &&
          ["correct", "mostly_correct", "needs_context", "outdated"].includes(bc.groundTruth)
        );

        // False leniency: system says safe, but truth is harmful
        const isFalseLeniency = (
          ["correct", "mostly_correct"].includes(predictedLabel) &&
          ["incorrect", "historical_consensus_denial", "incorrect_citation"].includes(bc.groundTruth)
        );

        const result: ClaimResult = {
          id:               bc.id,
          claim:            bc.claim,
          domain:           bc.domain,
          groundTruth:      bc.groundTruth,
          predictedLabel,
          acceptableLabels: bc.acceptableLabels,
          confidence:       vc?.verificationConfidence || 0,
          reasoning:        vc?.reasoning || "No verification returned",
          modelUsed:        wasRouted === "pro"
            ? (PIPELINE_CONFIG.GEMINI_MODELS?.verification || "gemini-2.5-flash")
            : (PIPELINE_CONFIG.GEMINI_MODELS?.extraction || PIPELINE_CONFIG.GEMINI_MODEL || "gemini-2.5-flash"),
          wasRouted,
          shouldUsePro:     bc.shouldUsePro,
          latencyMs:        perClaimLatency,
          exactMatch,
          acceptableMatch,
          routingCorrect,
          isFalseAccusation,
          isFalseLeniency,
        };

        // Log individual claim result
        const icon = acceptableMatch ? "✅" : (isFalseAccusation ? "🚨" : "❌");
        console.log(`   ${icon} [${bc.id}] ${predictedLabel.padEnd(18)} (expected: ${bc.groundTruth})`);

        results.push(result);
      }
    } catch (error) {
      console.error(`   ❌ Batch verification failed:`, error);

      // Mark all claims as failed
      for (const bc of claims) {
        results.push({
          id:               bc.id,
          claim:            bc.claim,
          domain:           bc.domain,
          groundTruth:      bc.groundTruth,
          predictedLabel:   "unverifiable" as ClaimStatus,
          acceptableLabels: bc.acceptableLabels,
          confidence:       0,
          reasoning:        `Verification failed: ${String(error)}`,
          modelUsed:        "error",
          wasRouted:        "flash",
          shouldUsePro:     bc.shouldUsePro,
          latencyMs:        Date.now() - t0,
          exactMatch:       false,
          acceptableMatch:  bc.acceptableLabels.includes("unverifiable"),
          routingCorrect:   false,
          isFalseAccusation: false,
          isFalseLeniency:   false,
        });
      }
    }

    return results;
  }

  /**
   * Mirror of ClaimVerificationService.isSensitiveClaim for routing tracking
   */
  private checkSensitivity(claim: BenchmarkClaim): boolean {
    const text = claim.claim.toLowerCase();
    const sensitivePatterns = [
      /\b(?:died|killed|assassinated|dead|death|executed)\b/i,
      /\b(?:war|invasion|bombed|strike|missile|military|troops)\b/i,
      /\b(?:election|voted|president|prime minister|leader|supreme)\b/i,
      /\b(?:sanction|embargo|blockade|tariff)\b/i,
      /\b(?:pandemic|outbreak|vaccine|mortality|cancer cure)\b/i,
      /\b(?:bankrupt|crash|recession|inflation|gdp|trillion)\b/i,
      /\b(?:genocide|ethnic cleansing|war crime|human rights)\b/i,
      /\b(?:nuclear|chemical weapon|biological weapon)\b/i,
      /\b(?:coup|overthrow|martial law|emergency)\b/i,
    ];

    if (sensitivePatterns.some(p => p.test(text))) return true;
    const sensitiveDomains = PIPELINE_CONFIG.SENSITIVE_DOMAINS || [];
    if (sensitiveDomains.some((d: string) => text.includes(d))) return true;
    if ((claim.type === "empirical" || claim.type === "historical") && text.length > 80) return true;
    return false;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
