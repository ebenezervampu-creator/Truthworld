# Cloud Function: 07-dubbing.ts

**Location:** `functions/src/pipeline/layers/07-dubbing.ts`

## 📖 What it does & How it works
🌍 LAYER 07 — DUBBING ENGINE (PATH 2)

 Translation + TTS + video merge. Full parallel execution per language and per segment.

 ✅ UPGRADED PIPELINE:
   - Translation: Google Cloud Translation v3 (TranslationServiceClient) with v2 fallback
   - TTS: ElevenLabs v3 (English) / Multilingual v2 (29+ languages) with auto-selection
   - Subtitles: Native AssemblyAI subtitles for source lang; custom alignment for translated

 ✅ ALL PROBLEMS FIXED:
   1. Consumer idempotency gate — eventId checked before any work starts
   2. TTS cache FULLY WIRED    — checkTTSCache() called before every ElevenLabs call
   3. Language skip if source  — no translation API calls when target == source language
   4. Translation cache wired  — checks cache before every translation batch
   5. Graceful language failure — one language failing doesn't abort other languages
   6. Progress updates         — granular per-language progress emitted to Edge Layer
   7. Event emitted after write — dubbing-complete only fires after Firestore write succeeds
   8. Native subtitle reuse    — checks for AssemblyAI source subtitles before regenerating

## ⚙️ Exports / Primary Functions
- **DubbingEngine**
- **dubbingEngine**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `uuid`
- 🔄 **Internal Dependency**: `../services/translation`
- 🔄 **Internal Dependency**: `../services/tts`
- 🔄 **Internal Dependency**: `../services/media`
- 🔄 **Internal Dependency**: `../services/cost-engine`
- 🔄 **Internal Dependency**: `../services/speaker-profiling`
- 🔄 **Internal Dependency**: `../services/audio-identity`
- 🔄 **Internal Dependency**: `./04-distribution`
- 🔄 **Internal Dependency**: `./01-edge`
- 🔄 **Internal Dependency**: `./09-aggregation`
- 🔄 **Internal Dependency**: `./10-performance`
- 🔄 **Internal Dependency**: `../services/creatorStyleService`
- 🔄 **Internal Dependency**: `../utils/logger`
