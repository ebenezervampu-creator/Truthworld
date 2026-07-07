# Cloud Function: ai-utils.ts

**Location:** `functions/src/pipeline/utils/ai-utils.ts`

## 📖 What it does & How it works
Request flow:
 1. checkCircuitBreaker() → if 'wait', pause locally (no API call)
 2. if 'proceed' or 'half-open', attempt API call with withAiRetry()
 3. On 429: tripCircuitBreaker() → if fallback available, switch model immediately
 4. AdaptiveConcurrency reads wave outcomes (which include circuit-caused pauses)
    and throttles the next wave accordingly
 
 The Circuit Breaker prevents stampedes across instances.
 Waterfall Routing prevents retrying an expensive failed model.
 Adaptive Concurrency prevents overwhelming the next wave after a bad one.
 All three must be active simultaneously for full resilience.

## ⚙️ Exports / Primary Functions
- **AiPacer**
- **GlobalSemaphore**
- **CircuitBreakerState**
- **CIRCUIT_DEFAULTS**
- **ModelFallbackChain**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `./logger`
