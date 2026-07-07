# Cloud Function: speaker-profiling.ts

**Location:** `functions/src/pipeline/services/speaker-profiling.ts`

## 📖 What it does & How it works
👥 SPEAKER INTELLIGENCE SERVICE
 
 Uses Gemini 2.0 to profile speakers in a transcript, enabling 
 accurate voice matching and identity preservation.

## ⚙️ Exports / Primary Functions
- **SpeakerProfile**
- **SpeakerProfilingService**
- **speakerProfilingService**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `@google/generative-ai`
- 🔄 **Internal Dependency**: `../config`
- 🔄 **Internal Dependency**: `../types`
- 🔄 **Internal Dependency**: `../utils/logger`
