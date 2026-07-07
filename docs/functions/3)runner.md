# Cloud Function: runner.ts

**Location:** `functions/src/benchmark/runner.ts`

## 📖 What it does & How it works
🧪 TRUTHWORLD BENCHMARK RUNNER

 Feeds benchmark claims through the actual ClaimVerificationService
 and records results for scoring. Uses the same model routing,
 prompts, and grounding logic as production.

## ⚙️ Exports / Primary Functions
- **BenchmarkRunner**

## 🔗 Dependencies (What it depends on to work)
- 🔄 **Internal Dependency**: `../pipeline/config`
- 🔄 **Internal Dependency**: `../pipeline/services/claimVerification`
- 🔄 **Internal Dependency**: `../pipeline/types`
- 🔄 **Internal Dependency**: `./scorer`
