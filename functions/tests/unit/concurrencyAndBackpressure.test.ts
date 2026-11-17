/**
 * ⚡ PHASE 4 UNIT TEST SUITE: CONCURRENCY, BACKPRESSURE & RESILIENCE
 *
 * Verifies:
 * 1. BoundedConcurrencyPool: strict concurrency limits, queueing, and complete task draining.
 * 2. ResilientExecutor: exponential backoff with full jitter, retry on 429/503/transients, and circuit breaker.
 * 3. ClaimPrioritizationScheduler: timeline-first sorting (TTFC), salience weighting, and micro-batching.
 * 4. Deterministic Ordering Preservation: exact input sequence restored despite asynchronous out-of-order resolution.
 * 5. Full Cascade Integration: micro-batched concurrent execution across the 4 tiers with resilient fallback.
 */

import {
  BoundedConcurrencyPool,
  ResilientExecutor,
  CircuitBreakerOpenError,
  ClaimPrioritizationScheduler,
  VerificationConcurrencyManager,
} from "../../src/pipeline/services/verificationConcurrencyManager";
import { FilteredClaim, VerifiedClaim, EvidenceLevel, ClaimNature, FramingStyle } from "../../src/pipeline/types";
import { VerificationCascadeService } from "../../src/pipeline/services/verificationCascadeService";
import { FusedGroundingService } from "../../src/pipeline/services/fusedGroundingService";
import { claimCacheService } from "../../src/pipeline/services/claimCacheService";

function createTestClaim(partial: Partial<FilteredClaim> & { claimId: string; text: string; start: number }): FilteredClaim {
  return {
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    confidence: 0.9,
    importance: 0.5,
    chunkIndex: 0,
    speaker: "Speaker",
    end: partial.start + 3000,
    ...partial,
  };
}

describe("Phase 4: Concurrency, Backpressure & Resilience Suite", () => {
  beforeEach(() => {
    ResilientExecutor.resetCircuitBreaker();
    jest.clearAllMocks();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 1. BOUNDED CONCURRENCY POOL
  // ──────────────────────────────────────────────────────────────────────────
  describe("BoundedConcurrencyPool", () => {
    it("strictly enforces max concurrency ceiling under heavy concurrent load", async () => {
      const maxConcurrency = 3;
      const pool = new BoundedConcurrencyPool(maxConcurrency);

      let currentActive = 0;
      let peakActive = 0;
      const totalTasks = 15;
      const completionOrder: number[] = [];

      const tasks = Array.from({ length: totalTasks }, (_, i) => {
        return pool.run(async () => {
          currentActive++;
          peakActive = Math.max(peakActive, currentActive);

          // Simulate asynchronous work
          await new Promise((res) => setTimeout(res, 20));

          completionOrder.push(i);
          currentActive--;
          return i;
        });
      });

      const results = await Promise.all(tasks);

      expect(results).toHaveLength(totalTasks);
      expect(peakActive).toBeLessThanOrEqual(maxConcurrency);
      expect(completionOrder).toHaveLength(totalTasks);
      expect(pool.activeCount).toBe(0);
      expect(pool.pendingCount).toBe(0);
    });

    it("throws error if constructed with invalid maxConcurrency < 1", () => {
      expect(() => new BoundedConcurrencyPool(0)).toThrow();
      expect(() => new BoundedConcurrencyPool(-2)).toThrow();
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 2. RESILIENT EXECUTOR & EXPONENTIAL BACKOFF WITH FULL JITTER
  // ──────────────────────────────────────────────────────────────────────────
  describe("ResilientExecutor & Full Jitter Backoff", () => {
    it("executes successful operation immediately without retries", async () => {
      const mockOp = jest.fn().mockResolvedValue("success_payload");

      const result = await ResilientExecutor.executeWithRetry("test_op", mockOp, { maxRetries: 3 });

      expect(result).toBe("success_payload");
      expect(mockOp).toHaveBeenCalledTimes(1);
    });

    it("calculates non-negative full jitter delay within exponential boundaries", () => {
      for (let attempt = 0; attempt < 5; attempt++) {
        const delay = ResilientExecutor.calculateFullJitterDelay(attempt, 200, 2000);
        const maxExpected = Math.min(2000, 200 * Math.pow(2, attempt));
        expect(delay).toBeGreaterThanOrEqual(0);
        expect(delay).toBeLessThanOrEqual(maxExpected);
      }
    });

    it("identifies retryable errors (429, 503, ETIMEDOUT) vs fatal errors", () => {
      expect(ResilientExecutor.isRetryableError({ status: 429, message: "RESOURCE_EXHAUSTED" })).toBe(true);
      expect(ResilientExecutor.isRetryableError({ statusCode: 503, message: "Service Unavailable" })).toBe(true);
      expect(ResilientExecutor.isRetryableError({ message: "read ETIMEDOUT" })).toBe(true);
      expect(ResilientExecutor.isRetryableError({ message: "socket hang up" })).toBe(true);

      // Non-retryable
      expect(ResilientExecutor.isRetryableError({ status: 400, message: "Invalid JSON argument" })).toBe(false);
      expect(ResilientExecutor.isRetryableError({ message: "Syntax error in query" })).toBe(false);
    });

    it("retries on transient 429 errors and succeeds when service recovers", async () => {
      let attempts = 0;
      const flakyOp = jest.fn().mockImplementation(async () => {
        attempts++;
        if (attempts < 3) {
          const err: any = new Error("RESOURCE_EXHAUSTED: Quota exceeded for gemini-3.5-flash-lite");
          err.status = 429;
          throw err;
        }
        return { verified: true, claimId: "c_recovered" };
      });

      const result = await ResilientExecutor.executeWithRetry("gemini_call", flakyOp, {
        maxRetries: 3,
        baseDelayMs: 10,
        maxDelayMs: 50,
      });

      expect(result).toEqual({ verified: true, claimId: "c_recovered" });
      expect(flakyOp).toHaveBeenCalledTimes(3);
    });

    it("aborts and throws after exhausting max retries", async () => {
      const failingOp = jest.fn().mockImplementation(async () => {
        const err: any = new Error("Rate limit 429");
        err.status = 429;
        throw err;
      });

      await expect(
        ResilientExecutor.executeWithRetry("failing_op", failingOp, {
          maxRetries: 2,
          baseDelayMs: 5,
          maxDelayMs: 20,
        })
      ).rejects.toThrow("Rate limit 429");

      expect(failingOp).toHaveBeenCalledTimes(3); // 1 initial + 2 retries
    });

    it("trips circuit breaker after consecutive failures and fast-fails upstream calls", async () => {
      const failingOp = jest.fn().mockImplementation(async () => {
        const err: any = new Error("Downstream service down");
        err.status = 503;
        throw err;
      });

      // Cause 5 consecutive failures to trip circuit breaker
      for (let i = 0; i < 5; i++) {
        await expect(
          ResilientExecutor.executeWithRetry(`trip_${i}`, failingOp, {
            maxRetries: 0,
            baseDelayMs: 1,
            maxDelayMs: 5,
          })
        ).rejects.toThrow();
      }

      // Next call must be blocked immediately by circuit breaker without invoking operation
      const callAfterTrip = jest.fn().mockResolvedValue("should_not_run");
      await expect(
        ResilientExecutor.executeWithRetry("blocked_call", callAfterTrip)
      ).rejects.toThrow(CircuitBreakerOpenError);

      expect(callAfterTrip).not.toHaveBeenCalled();
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 3. CLAIM PRIORITIZATION SCHEDULER & MICRO-BATCHING
  // ──────────────────────────────────────────────────────────────────────────
  describe("ClaimPrioritizationScheduler", () => {
    it("prioritizes early-timeline claims (lower startMs) to minimize TTFC for viewers", () => {
      const claimEarly = createTestClaim({
        claimId: "c_early",
        text: "Claim spoken at 2 seconds",
        start: 2000,
        end: 5000,
        speaker: "Host",
      });

      const claimLate = createTestClaim({
        claimId: "c_late",
        text: "Claim spoken at 120 seconds",
        start: 120000,
        end: 125000,
        speaker: "Host",
      });

      const sorted = ClaimPrioritizationScheduler.prioritizeClaims([claimLate, claimEarly]);

      expect(sorted[0].claimId).toBe("c_early");
      expect(sorted[1].claimId).toBe("c_late");
    });

    it("prioritizes high-salience claims within near-simultaneous timeline windows", () => {
      const claimLowImportance = createTestClaim({
        claimId: "c_low",
        text: "Minor casual statement",
        start: 10000,
        end: 13000,
        speaker: "Host",
        importance: 0.2,
      });

      const claimHighImportance = createTestClaim({
        claimId: "c_high",
        text: "Crucial breaking allegation",
        start: 12000, // within 2 seconds of c_low
        end: 15000,
        speaker: "Host",
        importance: 0.95,
      });

      const sorted = ClaimPrioritizationScheduler.prioritizeClaims([claimLowImportance, claimHighImportance]);

      expect(sorted[0].claimId).toBe("c_high");
      expect(sorted[1].claimId).toBe("c_low");
    });

    it("chunks large claim sets into optimal micro-batches for Tier 4 grounding", () => {
      const dummyClaims: FilteredClaim[] = Array.from({ length: 14 }, (_, i) =>
        createTestClaim({
          claimId: `c_${i}`,
          text: `Claim ${i}`,
          start: i * 1000,
          end: (i + 1) * 1000,
          speaker: "Host",
        })
      );

      const microBatches = ClaimPrioritizationScheduler.chunkIntoMicroBatches(dummyClaims, 5);

      expect(microBatches).toHaveLength(3);
      expect(microBatches[0]).toHaveLength(5);
      expect(microBatches[1]).toHaveLength(5);
      expect(microBatches[2]).toHaveLength(4);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 4. DETERMINISTIC ORDERING PRESERVATION
  // ──────────────────────────────────────────────────────────────────────────
  describe("Deterministic Ordering Preservation", () => {
    it("restores exact original sequence regardless of out-of-order completion", () => {
      const original: FilteredClaim[] = [
        createTestClaim({ claimId: "c1", text: "First in video", start: 1000, end: 3000 }),
        createTestClaim({ claimId: "c2", text: "Second in video", start: 5000, end: 7000 }),
        createTestClaim({ claimId: "c3", text: "Third in video", start: 9000, end: 11000 }),
      ];

      // Simulated results arrived in reverse/random order: c3, c1, c2
      const resultsMap = new Map<string, VerifiedClaim>();
      resultsMap.set("c3", {
        ...original[2],
        status: "false_claim",
        verificationConfidence: 0.9,
        evidenceConfidence: 0.9,
        reasoning: "Contradicted.",
        sources: [],
        richSources: [],
        isGrounded: true,
        verificationMethod: "grounded",
      });
      resultsMap.set("c1", {
        ...original[0],
        status: "verified_true",
        verificationConfidence: 1.0,
        evidenceConfidence: 1.0,
        reasoning: "Cached hit.",
        sources: [],
        richSources: [],
        isGrounded: true,
        verificationMethod: "cache_hit",
      });
      resultsMap.set("c2", {
        ...original[1],
        status: "opinion_claim",
        verificationConfidence: 0.85,
        evidenceConfidence: 0.85,
        reasoning: "Subjective.",
        sources: [],
        richSources: [],
        isGrounded: false,
        verificationMethod: "llm_training",
      });

      const restored = VerificationConcurrencyManager.restoreDeterministicOrder(original, resultsMap);

      expect(restored.map((r) => r.claimId)).toEqual(["c1", "c2", "c3"]);
      expect(restored[0].verificationMethod).toBe("cache_hit");
      expect(restored[1].verificationMethod).toBe("llm_training");
      expect(restored[2].verificationMethod).toBe("grounded");
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 5. FULL CASCADE WITH BOUNDED CONCURRENCY & RESILIENCE
  // ──────────────────────────────────────────────────────────────────────────
  describe("VerificationCascadeService with Concurrency & Backpressure", () => {
    it("processes a multi-tier batch concurrently and preserves deterministic sequence", async () => {
      // Mock Tier 1 cache: Miss for all
      jest.spyOn(claimCacheService, "getBatch").mockResolvedValue(new Map());

      // Mock Tier 4 Fused Grounding: Resolves empirical claims
      jest.spyOn(FusedGroundingService, "verifyBatchFused").mockImplementation(async (batch) => {
        return batch.map((c) => ({
          ...c,
          status: "verified_true",
          verificationConfidence: 0.92,
          evidenceConfidence: 0.92,
          reasoning: "Empirical source corroborated.",
          sources: ["https://reuters.com/news"],
          richSources: [{
            title: "Reuters News",
            url: "https://reuters.com/news",
            directUrl: "https://reuters.com/news",
            domain: "reuters.com",
            tier: "A",
            snippet: "Corroborated.",
          }],
          isGrounded: true,
          verificationMethod: "grounded",
          evidenceLevel: EvidenceLevel.STRONG,
        }));
      });

      const testClaims: FilteredClaim[] = [
        // 1. Settled physics constant -> Tier 2 Deterministic
        createTestClaim({
          claimId: "claim_physics",
          text: "Water boils at 100°C at standard atmospheric pressure",
          start: 500,
          end: 3500,
          speaker: "Host",
        }),
        // 2. Purely subjective opinion -> Tier 3 Fast-Track
        createTestClaim({
          claimId: "claim_opinion",
          text: "In my personal opinion, this movie is the greatest masterpiece ever made",
          start: 4000,
          end: 7000,
          speaker: "Host",
        }),
        // 3. Statistical economic claim -> Tier 4 Deep Grounding
        createTestClaim({
          claimId: "claim_stats",
          text: "India's GDP grew by 8.2% in the second quarter of 2024",
          start: 8000,
          end: 12000,
          speaker: "Host",
        }),
      ];

      const cascadeResults = await VerificationCascadeService.executeCascade(
        "", // offline / no videoId
        testClaims,
        "General"
      );

      expect(cascadeResults).toHaveLength(3);
      expect(cascadeResults.map((r) => r.claimId)).toEqual(["claim_physics", "claim_opinion", "claim_stats"]);

      // Verify tier resolutions
      expect(cascadeResults[0].status).toBe("verified_true");
      expect(cascadeResults[0].verificationMethod).toBe("deterministic");

      expect(cascadeResults[1].status).toBe("opinion_claim");
      expect(cascadeResults[1].verificationMethod).toBe("llm_training");

      expect(cascadeResults[2].status).toBe("verified_true");
      expect(cascadeResults[2].verificationMethod).toBe("grounded");
    });

    it("assigns unproven fallback when Tier 4 grounding encounters persistent failure (never manufacturing certainty)", async () => {
      jest.spyOn(claimCacheService, "getBatch").mockResolvedValue(new Map());

      // Mock Tier 4 Fused Grounding failure (e.g. repeated 503 or timeout)
      jest.spyOn(FusedGroundingService, "verifyBatchFused").mockRejectedValue(
        new Error("Gemini 503: Service Unavailable")
      );

      const empiricalClaim = createTestClaim({
        claimId: "claim_breaking",
        text: "A foreign diplomatic mission was secretly closed yesterday",
        start: 1000,
        end: 4000,
        speaker: "Host",
      });

      const results = await VerificationCascadeService.executeCascade("", [empiricalClaim], "General");

      expect(results).toHaveLength(1);
      expect(results[0].status).toBe("unproven");
      expect(results[0].verificationConfidence).toBe(0.0);
      expect(results[0].isGrounded).toBe(false);
      expect(results[0].reasoning).toContain("unproven");
    });
  });
});
