# Cloud Function: factExtraction.ts

**Location:** `functions/src/pipeline/services/factExtraction.ts`

## 📖 What it does & How it works
🔹 A. Fact Extraction Service
 
 Extracts atomic factual claims from transcript chunks
 Input: transcript chunks (30-60 sec)
 Output: classified claims (fact/opinion/speculation/unclear)

## ⚙️ Exports / Primary Functions
- **FactExtractionService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `@google/generative-ai`
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `../config`
- 🔄 **Internal Dependency**: `../registry/RegistryService`
- 🔄 **Internal Dependency**: `./contentIntentDetector`
- 🔄 **Internal Dependency**: `../utils/logger`
- 🔄 **Internal Dependency**: `../utils/ai-utils`
