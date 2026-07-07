# Cloud Function: categoryWeights.ts

**Location:** `functions/src/pipeline/services/categoryWeights.ts`

## 📖 What it does & How it works
🎯 CATEGORY WEIGHTS SERVICE (v8.0 — Epistemic Trust Engine)
 
 Drop-in replacement for getVerticalWeights() in scoringEngine.ts.
 Adds the 9th dimension (honesty), category-specific weight profiles,
 penalty multipliers, harm cap logic, and contextual flag detection.

## ⚙️ Exports / Primary Functions
- **mapUploadCategory**
- **getCategoryWeights**
- **computeHonestyScore**
- **applyHarmCap**
- **detectContextualFlags**
- **ComputedScore**
- **computeCategoryAwareScore**
- **getTrustLabelFromScore**

## 🔗 Dependencies (What it depends on to work)
*No dependencies detected.*
