import * as admin from "firebase-admin";
import { logger } from "./logger";

/**
 * Request flow:
 * 1. checkCircuitBreaker() → if 'wait', pause locally (no API call)
 * 2. if 'proceed' or 'half-open', attempt API call with withAiRetry()
 * 3. On 429: tripCircuitBreaker() → if fallback available, switch model immediately
 * 4. AdaptiveConcurrency reads wave outcomes (which include circuit-caused pauses)
 *    and throttles the next wave accordingly
 * 
 * The Circuit Breaker prevents stampedes across instances.
 * Waterfall Routing prevents retrying an expensive failed model.
 * Adaptive Concurrency prevents overwhelming the next wave after a bad one.
 * All three must be active simultaneously for full resilience.
 */

const db = () => admin.firestore();

// ─── AI PACER (Local) ───────────────────────────────────────────────────────

export class AiPacer {
  private static instance: AiPacer;
  private lastCall: number = 0;
  private minInterval: number = 200; // ms between calls

  private constructor() {}

  public static getInstance(): AiPacer {
    if (!AiPacer.instance) {
      AiPacer.instance = new AiPacer();
    }
    return AiPacer.instance;
  }

  public async pace(): Promise<void> {
    const now = Date.now();
    const elapsed = now - this.lastCall;
    if (elapsed < this.minInterval) {
      const wait = this.minInterval - elapsed;
      await new Promise(resolve => setTimeout(resolve, wait));
    }
    this.lastCall = Date.now();
  }
}

// ─── GLOBAL VERIFICATION SEMAPHORE (v11.1) ───────────────────────────────────

export class GlobalSemaphore {
  private static instance: GlobalSemaphore;
  private activeCount: number = 0;
  private maxConcurrent: number = 25; // platform-wide cap for Gemini calls
  private queue: (() => void)[] = [];

  private constructor() {}

  public static getInstance(): GlobalSemaphore {
    if (!GlobalSemaphore.instance) {
      GlobalSemaphore.instance = new GlobalSemaphore();
    }
    return GlobalSemaphore.instance;
  }

  public async acquire(): Promise<void> {
    if (this.activeCount < this.maxConcurrent) {
      this.activeCount++;
      return;
    }
    return new Promise(resolve => {
      this.queue.push(resolve);
    });
  }

  public release(): void {
    if (this.queue.length > 0) {
      const next = this.queue.shift();
      if (next) next();
    } else {
      this.activeCount--;
    }
  }

  public getStatus() {
    return { active: this.activeCount, queued: this.queue.length };
  }
}

// ─── GLOBAL CIRCUIT BREAKER ─────────────────────────────────────────────────

export interface CircuitBreakerState {
  status: 'closed' | 'open' | 'half-open';
  trippedAt: number | null;       // timestamp when tripped
  trippedBy: string | null;       // instance ID that tripped it
  tripCount: number;              // rolling count of trips in last hour
  openDurationMs: number;         // current open window (increases with repeated trips)
  lastCheckedAt: number;
}

export const CIRCUIT_DEFAULTS = {
  BASE_OPEN_DURATION_MS: 15_000,  // 15 seconds for first trip
  MAX_OPEN_DURATION_MS: 120_000,  // 2 minutes maximum
  HALF_OPEN_PROBE_DELAY_MS: 2_000,
  FIRESTORE_PATH: '_ai_health/circuit_breaker',
} as const;

export async function tripCircuitBreaker(instanceId: string): Promise<void> {
  const ref = db().doc(CIRCUIT_DEFAULTS.FIRESTORE_PATH);
  
  let finalOpenDuration: number = CIRCUIT_DEFAULTS.BASE_OPEN_DURATION_MS;

  await db().runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const current = doc.data() as CircuitBreakerState | undefined;
    
    // Exponential backoff on open duration for repeated trips
    let tripCount = (current?.tripCount ?? 0) + 1;

    // Reset tripCount if the last trip was over an hour ago
    if (current?.trippedAt && Date.now() - current.trippedAt > 3600_000) {
      tripCount = 1;
    }

    const openDuration = Math.min(
      CIRCUIT_DEFAULTS.BASE_OPEN_DURATION_MS * Math.pow(2, tripCount - 1),
      CIRCUIT_DEFAULTS.MAX_OPEN_DURATION_MS
    );
    finalOpenDuration = openDuration;
    
    tx.set(ref, {
      status: 'open',
      trippedAt: Date.now(),
      trippedBy: instanceId,
      tripCount,
      openDurationMs: openDuration,
      lastCheckedAt: Date.now(),
    } as CircuitBreakerState);
  });
  
  logger.warn(`[CircuitBreaker] Tripped by ${instanceId}. Open for ${finalOpenDuration}ms.`);
}

export async function checkCircuitBreaker(): Promise<'proceed' | 'wait' | 'half-open'> {
  const ref = db().doc(CIRCUIT_DEFAULTS.FIRESTORE_PATH);
  const doc = await ref.get();
  
  if (!doc.exists) return 'proceed';
  
  const state = doc.data() as CircuitBreakerState;
  
  if (state.status === 'closed') return 'proceed';
  
  const elapsed = Date.now() - (state.trippedAt ?? 0);
  
  if (elapsed >= state.openDurationMs) {
    // Transition to half-open — allow one probe request through
    await ref.update({ status: 'half-open', lastCheckedAt: Date.now() });
    return 'half-open';
  }
  
  return 'wait';
}

export async function closeCircuitBreaker(): Promise<void> {
  await db().doc(CIRCUIT_DEFAULTS.FIRESTORE_PATH).update({
    status: 'closed',
    trippedAt: null,
    lastCheckedAt: Date.now(),
  });
  logger.info('[CircuitBreaker] Closed — capacity restored.');
}

export async function getCircuitState(): Promise<CircuitBreakerState> {
  const ref = db().doc(CIRCUIT_DEFAULTS.FIRESTORE_PATH);
  const doc = await ref.get();
  if (!doc.exists) {
    return {
      status: 'closed',
      trippedAt: null,
      trippedBy: null,
      tripCount: 0,
      openDurationMs: 0,
      lastCheckedAt: Date.now()
    };
  }
  return doc.data() as CircuitBreakerState;
}

// ─── WATERFALL ROUTING ──────────────────────────────────────────────────────

export interface ModelFallbackChain {
  primary: string;           // e.g. 'gemini-2.5-pro'
  fallback: string | null;   // e.g. 'gemini-2.5-flash' or null if forcePro
  forcePrimary: boolean;     // if true, never fall back — wait and retry on primary
}

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

export async function withAiRetry<T>(
  fn: (model: string) => Promise<T>,
  chain: ModelFallbackChain,
  options: { maxAttempts: number; instanceId: string; signal?: AbortSignal }
): Promise<T> {
  const pacer = AiPacer.getInstance();
  const semaphore = GlobalSemaphore.getInstance();
  let currentModel = chain.primary;
  let attempts = 0;

  await semaphore.acquire();
  try {
  
  while (attempts < options.maxAttempts) {
    if (options.signal?.aborted) throw new Error('ABORTED');
    // Step 1: Check circuit breaker before every attempt
    const circuitStatus = await checkCircuitBreaker();
    
    if (circuitStatus === 'wait') {
      // Circuit is open — pause locally, do not hit the API
      const state = await getCircuitState();
      const remainingMs = (state.openDurationMs) - (Date.now() - (state.trippedAt ?? 0));
      logger.info(`[CircuitBreaker] Open. Pausing ${remainingMs}ms before retry.`);
      await sleep(Math.max(remainingMs, 0) + CIRCUIT_DEFAULTS.HALF_OPEN_PROBE_DELAY_MS);
      attempts++;
      continue;
    }
    
    try {
      await pacer.pace();

      const timeoutMs = 180_000; // v18.0: 180s for grounding + multi-source verification batches
      let timeoutId: any;
      const result = await Promise.race([
        fn(currentModel),
        new Promise<T>((_, reject) => {
          timeoutId = setTimeout(() => {
            logger.warn(`[withAiRetry] Internal ${timeoutMs}ms timeout reached for model ${currentModel}`);
            reject(Object.assign(new Error('AI_INTERNAL_TIMEOUT'), { status: 503 }));
          }, timeoutMs);

          if (options.signal) {
            if (options.signal.aborted) {
              clearTimeout(timeoutId);
              reject(new Error('ABORTED'));
            }
            options.signal.addEventListener('abort', () => {
              clearTimeout(timeoutId);
              reject(new Error('ABORTED'));
            });
          }
        })
      ]);
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
      
      // Successful call — close circuit if it was half-open
      if (circuitStatus === 'half-open') {
        await closeCircuitBreaker();
      }
      
      // If we succeeded on fallback, log it for monitoring
      if (currentModel !== chain.primary) {
        logger.info(`[WaterfallRouting] Completed on fallback model: ${currentModel}`);
      }
      
      return result;
      
    } catch (error: any) {
      attempts++;
      
      const status = error?.status || (error?.message?.includes("429") ? 429 : error?.message?.includes("503") ? 503 : 500);
      const isCapacityError = status === 429 || status === 503 || 
                             error?.message?.toLowerCase().includes("resource exhausted") ||
                             error?.message?.toLowerCase().includes("quota");

      if (isCapacityError) {
        // Trip the circuit breaker
        await tripCircuitBreaker(options.instanceId);
        
        // Waterfall: try fallback model if available and not forcePrimary
        if (chain.fallback && !chain.forcePrimary && currentModel === chain.primary) {
          logger.info(`[WaterfallRouting] 429 on ${chain.primary} → falling back to ${chain.fallback}`);
          currentModel = chain.fallback;
          // No sleep — switch model immediately, don't wait
          continue;
        }
        
        // forcePrimary or no fallback — exponential backoff on same model
        if (attempts < options.maxAttempts) {
           const backoffMs = Math.min(1000 * Math.pow(2, attempts), 30_000);
           logger.warn(`[WaterfallRouting] Capacity exceeded. forcePrimary=${chain.forcePrimary}. Backing off ${backoffMs}ms.`);
           await sleep(backoffMs);
           continue;
        }
      }
      
      // Non-429 error — do not trip circuit, do not fall back, throw immediately
      logger.error(`[WaterfallRouting] Permanent error or retries exhausted`, { status, error: String(error) });
      throw error;
    }
  }
  
  throw new Error(`[withAiRetry] Exhausted ${options.maxAttempts} attempts on model chain.`);
  } finally {
    semaphore.release();
  }
}
