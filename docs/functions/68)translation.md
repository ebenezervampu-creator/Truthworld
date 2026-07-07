# Cloud Function: translation.ts

**Location:** `functions/src/pipeline/services/translation.ts`

## 📖 What it does & How it works
🌍 TRANSLATION SERVICE — Google Cloud Translation v3 (Advanced)

 ✅ UPGRADED from v2 → v3:
   - Uses `TranslationServiceClient` (not `v2.Translate`)
   - Supports glossaries, batch processing, regional endpoints
   - Better enterprise quality controls for Indian + global languages
   - Location-aware routing (asia-south1 for India-first)

 ✅ FALLBACK: If v3 client fails to initialize, falls back to v2 Basic API

## ⚙️ Exports / Primary Functions
- **TranslationService**
- **translationService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `@google-cloud/translate`
- 📦 **External Package**: `@google/generative-ai`
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `./speaker-profiling`
- 🔄 **Internal Dependency**: `./cost-engine`
- 🔄 **Internal Dependency**: `../config`
