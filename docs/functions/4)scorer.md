# Cloud Function: scorer.ts

**Location:** `functions/src/benchmark/scorer.ts`

## 📖 What it does & How it works
🧮 TRUTHWORLD BENCHMARK SCORER

 Computes all metrics from benchmark results:
 - Model accuracy (exact + acceptable)
 - Error analysis (false accusations, false leniency)
 - Routing quality
 - Domain breakdown
 - Nuance recognition
 - Cost/performance estimates
 - TruthWorld-specific trust metrics

## ⚙️ Exports / Primary Functions
- **BenchmarkScorer**

## 🔗 Dependencies (What it depends on to work)
- 🔄 **Internal Dependency**: `./types`
- 🔄 **Internal Dependency**: `../pipeline/types`
