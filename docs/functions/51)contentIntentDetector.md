# Cloud Function: contentIntentDetector.ts

**Location:** `functions/src/pipeline/services/contentIntentDetector.ts`

## 📖 What it does & How it works
🎯 CONTENT INTENT DETECTOR (v4.3)

 Classifies the **intent** of video content before scoring.
 This prevents promotional/opinion/entertainment content from being
 unfairly penalized by the factual verification pipeline.

 Architecture: Fast keyword + structural analysis (no LLM call needed).

## ⚙️ Exports / Primary Functions
- **ContentIntentType**
- **ContentIntent**
- **ContentIntentDetector**
- **contentIntentDetector**
- **containsVerifiablePredicate**
- **isSubjectiveClaim**

## 🔗 Dependencies (What it depends on to work)
- 🔄 **Internal Dependency**: `../types`
