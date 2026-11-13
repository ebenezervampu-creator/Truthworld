/**
 * ⚡ PHASE 4: VERIFICATION CONCURRENCY & BACKPRESSURE MANAGER (TRUTHWORLD)
 *
 * Epistemic & Engineering Guarantees:
 * 1. Bounded Concurrency: Strict worker pool limits per verification tier to prevent
 *    hitting Gemini / Vertex AI rate limits (RPM / TPM).
 * 2. Prioritized Scheduling: Prioritizes early-timeline claims (startMs) to optimize
 *    Time-To-First-Claim (TTFC) for viewers, with secondary salience/risk weighting.
 * 3. Resilient Retries: Exponential backoff with full jitter for transient 429/503 errors.
 * 4. Circuit Breaker: Prevents thundering herds during sustained upstream outages.
 * 5. Deterministic Ordering: Regardless of out-of-order worker completions, the final
 *    output array strictly preserves the input claims sequence.
 * 6. Micro-Batching: Chunks Tier 4 grounded verification into optimal slices (4-6 claims)
 *    to maximize search quality and avoid token/timeout limits.
 */

import { logger } from "../utils/logger";
import { FilteredClaim, VerifiedClaim } from "../types";

/**
 * Token-based semaphore for bounded asynchronous worker concurrency.
 */
export class BoundedConcurrencyPool {
  private activeWorkers = 0;
  private queue: Array<() => void> = [];

  constructor(public readonly maxConcurrency: number) {
    if (maxConcurrency < 1) {
      throw new Error(`[BoundedConcurrencyPool] maxConcurrency must be >= 1, received ${maxConcurrency}`);
    }
  }

  public async run<T>(task: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await task();
    } finally {
      this.release();
    }
  }

  private acquire(): Promise<void> {
    if (this.activeWorkers < this.maxConcurrency) {
      this.activeWorkers++;
      return Promise.resolve();
    }
    return new Promise<void>((resolve) => {
      this.queue.push(resolve);
    });
  }

  private release(): void {
    this.activeWorkers--;
    if (this.queue.length > 0 && this.activeWorkers < this.maxConcurrency) {
      this.activeWorkers++;
      const next = this.queue.shift();
      if (next) {
        next();
      }
    }
  }

  public get pendingCount(): number {
    return this.queue.length;
  }

  public get activeCount(): number {
    return this.activeWorkers;
  }
}

/**
 * Options for resilient execution with retry.
 */
export interface RetryOptions {
  maxRetries?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  retryableErrors?: (err: any) => boolean;
}

/**
 * Error thrown when the circuit breaker is open.
 */
export class CircuitBreakerOpenError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CircuitBreakerOpenError";
  }
}

/**
 * Resilient executor with exponential backoff, full jitter, and circuit breaker.
 */
export class ResilientExecutor {
  private static failureCount = 0;
  private static lastFailureTime = 0;
  private static circuitState: "CLOSED" | "OPEN" | "HALF_OPEN" = "CLOSED";

  private static readonly CIRCUIT_FAILURE_THRESHOLD = 5;
  private static readonly CIRCUIT_COOLDOWN_MS = 15_000;

  /**
   * Calculates exponential backoff with full jitter.
   * Full jitter produces delay uniformly distributed between 0 and min(maxDelay, baseDelay * 2^attempt).
   */
  public static calculateFullJitterDelay(attempt: number, baseDelayMs: number = 500, maxDelayMs: number = 8000): number {
    const exponentialCap = Math.min(maxDelayMs, baseDelayMs * Math.pow(2, attempt));
    return Math.floor(Math.random() * exponentialCap);
  }

  /**
   * Determines whether an error is transient and eligible for retry.
   */
  public static isRetryableError(err: any): boolean {
    if (!err) return false;
    const msg = (err?.message || "").toLowerCase();
    const code = err?.code || err?.status || err?.statusCode;

    // HTTP 429 Too Many Requests / Resource Exhausted
    if (code === 429 || msg.includes("resource_exhausted") || msg.includes("quota") || msg.includes("rate limit") || msg.includes("too many requests")) {
      return true;
    }

    // HTTP 503 / 502 / 504 / Service Unavailable
    if (code === 503 || code === 502 || code === 504 || msg.includes("unavailable") || msg.includes("overloaded")) {
      return true;
    }

    // Network / Socket transients
    if (msg.includes("etimedout") || msg.includes("econnreset") || msg.includes("socket hang up") || msg.includes("network error")) {
      return true;
    }

    return false;
  }

  /**
   * Resets the circuit breaker state (useful for tests or after confirmed service health).
   */
  public static resetCircuitBreaker(): void {
    this.failureCount = 0;
    this.lastFailureTime = 0;
    this.circuitState = "CLOSED";
  }

  /**
   * Checks the circuit breaker status.
   */
  private static checkCircuit(): void {
    const now = Date.now();
    if (this.circuitState === "OPEN") {
      if (now - this.lastFailureTime > this.CIRCUIT_COOLDOWN_MS) {
        this.circuitState = "HALF_OPEN";
        logger.info("[ResilientExecutor] Circuit breaker entering HALF_OPEN probe state");
      } else {
        throw new CircuitBreakerOpenError(
          `[ResilientExecutor] Circuit breaker is OPEN. Fast-failing upstream calls to protect API quota.`
        );
      }
    }
  }

  private static recordSuccess(): void {
    if (this.circuitState === "HALF_OPEN" || this.failureCount > 0) {
      logger.info("[ResilientExecutor] Circuit breaker recovered to CLOSED");
    }
    this.failureCount = 0;
    this.circuitState = "CLOSED";
  }

  private static recordFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.CIRCUIT_FAILURE_THRESHOLD) {
      this.circuitState = "OPEN";
      logger.warn(`[ResilientExecutor] Circuit breaker TRIPPED to OPEN after ${this.failureCount} consecutive failures`);
    }
  }

  /**
   * Executes a task with automatic retries, backoff, and circuit breaker protection.
   */
  public static async executeWithRetry<T>(
    operationName: string,
    operation: () => Promise<T>,
    options: RetryOptions = {}
  ): Promise<T> {
    const maxRetries = options.maxRetries ?? 3;
    const baseDelayMs = options.baseDelayMs ?? 500;
    const maxDelayMs = options.maxDelayMs ?? 8000;
    const isRetryable = options.retryableErrors ?? this.isRetryableError;

    this.checkCircuit();

    let lastError: any = null;
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const result = await operation();
        this.recordSuccess();
        return result;
      } catch (err: any) {
        lastError = err;

        if (attempt === maxRetries || !isRetryable(err)) {
          this.recordFailure();
          logger.warn(`[ResilientExecutor] ${operationName} failed (attempt ${attempt + 1}/${maxRetries + 1}): ${err?.message}`);
          throw err;
        }

        const delay = this.calculateFullJitterDelay(attempt, baseDelayMs, maxDelayMs);
        logger.info(`[ResilientExecutor] ${operationName} retrying after ${delay}ms backoff (attempt ${attempt + 1}/${maxRetries}): ${err?.message}`);
        await new Promise((res) => setTimeout(res, delay));
      }
    }

    this.recordFailure();
    throw lastError;
  }
}

/**
 * Claim Prioritization Scheduler.
 *
 * Sorts claims so viewers get verified badges on the early timeline as fast as possible (TTFC),
 * while prioritizing high-urgency or high-salience claims within near-simultaneous windows.
 */
export class ClaimPrioritizationScheduler {
  /**
   * Compares two claims for execution priority:
   * - Lower startMs (earlier in video) is prioritized.
   * - If within 15 seconds of each other, high-importance/high-risk claims take precedence.
   */
  public static comparePriority(a: FilteredClaim, b: FilteredClaim): number {
    const aStart = typeof a.start === "number" ? a.start : 0;
    const bStart = typeof b.start === "number" ? b.start : 0;
    const timeDelta = aStart - bStart;

    // If separated by more than 15 seconds, strict timeline order dictates priority
    if (Math.abs(timeDelta) > 15_000) {
      return timeDelta;
    }

    // Within a 15-second window, compare salience/importance
    const aImportance = (a as any).importance ?? 0.5;
    const bImportance = (b as any).importance ?? 0.5;
    if (Math.abs(aImportance - bImportance) >= 0.2) {
      return bImportance - aImportance; // Higher importance first
    }

    return timeDelta;
  }

  /**
   * Sorts a slice of claims according to priority.
   */
  public static prioritizeClaims(claims: FilteredClaim[]): FilteredClaim[] {
    return [...claims].sort(this.comparePriority);
  }

  /**
   * Partitions an array of claims into micro-batches for Tier 4 Grounded Verification.
   */
  public static chunkIntoMicroBatches<T>(items: T[], microBatchSize: number = 5): T[][] {
    if (!items || items.length === 0) return [];
    const batches: T[][] = [];
    for (let i = 0; i < items.length; i += microBatchSize) {
      batches.push(items.slice(i, i + microBatchSize));
    }
    return batches;
  }
}

/**
 * Global or Video-Scoped Verification Concurrency Manager.
 */
export class VerificationConcurrencyManager {
  // Tier-specific bounded concurrency pools
  public static readonly tier1Pool = new BoundedConcurrencyPool(50); // In-memory cache
  public static readonly tier2Pool = new BoundedConcurrencyPool(50); // Deterministic registry
  public static readonly tier3Pool = new BoundedConcurrencyPool(8);  // Fast-Track LLM
  public static readonly tier4Pool = new BoundedConcurrencyPool(4);  // Fused Grounding Search micro-batches

  public static readonly TIER4_MICRO_BATCH_SIZE = 5;

  /**
   * Assembles a collection of verified claims into the strict original sequence
   * of the input array, ensuring deterministic order preservation.
   */
  public static restoreDeterministicOrder(
    originalClaims: FilteredClaim[],
    resultsMap: Map<string, VerifiedClaim>
  ): VerifiedClaim[] {
    return originalClaims.map((original) => {
      const result = resultsMap.get(original.claimId);
      if (result) {
        return result;
      }

      // Safe fallback if a claim was unexpectedly missing
      return {
        ...original,
        status: "unproven",
        verificationConfidence: 0.0,
        evidenceConfidence: 0.0,
        reasoning: "Verification was not finalized. Claim remains unproven.",
        sources: [],
        richSources: [],
        isGrounded: false,
        verificationMethod: "not_verified",
      };
    });
  }
}
