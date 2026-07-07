# Cloud Function: memory-cache.ts

**Location:** `functions/src/pipeline/utils/memory-cache.ts`

## 📖 What it does & How it works
💾 IN-MEMORY CACHE UTILITY

 Per-instance ephemeral LRU cache for hot data.
 Each instance maintains its own cache (no shared state).

 ✅ BENEFITS:
   - Zero network calls (in-process)
   - Zero cost (memory-based)
   - Automatic TTL + eviction
   - 5000-key capacity per instance
   - ~<1ms lookup time

## ⚙️ Exports / Primary Functions
- **getCache**
- **setCache**
- **deleteCache**
- **clearCache**
- **getCacheStats**

## 🔗 Dependencies (What it depends on to work)
*No dependencies detected.*
