# Cloud Function: scoringEngine.ts

**Location:** `functions/src/pipeline/services/scoringEngine.ts`

## 📖 What it does & How it works
🏛 SCORING ENGINE (v11.0 — Path 1 Epistemic Framework)
 
 Centralized engine for TruthWorld trust scoring.
 Implements the Truth Index formula: (Truth * 0.35) + (Honesty * 0.40) + (Rationality * 0.25).

## ⚙️ Exports / Primary Functions
- **ScoringEngine**

## 🔗 Dependencies (What it depends on to work)
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `./categoryWeights`
