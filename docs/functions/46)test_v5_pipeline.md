# Cloud Function: test_v5_pipeline.ts

**Location:** `functions/src/pipeline/scripts/test_v5_pipeline.ts`

## 📖 What it does & How it works
🧪 TEST SCRIPT: Pipeline v5.0 Verification
 
 This script injects a test job into Firestore with the specific
 Ishaan Sharma "Claude Design" transcript to verify that:
  1. containsVerifiablePredicate() rescues the launch claim.
  2. isLaunchNews is correctly detected.
  3. Parallel verification executes.
  4. Honest labeling (Unverified vs Unsupported) works.

## ⚙️ Exports / Primary Functions
*No explicit exports found.*

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
