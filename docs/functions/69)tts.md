# Cloud Function: tts.ts

**Location:** `functions/src/pipeline/services/tts.ts`

## 📖 What it does & How it works
🎙️ TTS SERVICE — ElevenLabs v3 / Multilingual v2
 
 Generates audio speech from translated text segments using ElevenLabs API.
 Supports 70+ languages via model auto-selection.

## ⚙️ Exports / Primary Functions
- **TTSService**
- **ttsService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `axios`
- 📦 **External Package**: `uuid`
- 📦 **External Package**: `firebase-admin`
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `./cost-engine`
- 🔄 **Internal Dependency**: `../config`
- 🔄 **Internal Dependency**: `../utils/logger`
