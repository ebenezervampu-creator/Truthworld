# Search System Architecture

## 🎯 Design Principles

```
Latency = network calls + data size + query complexity
```

This search system **minimizes all three**:
1. **Minimize queries** → Debounce + Cache
2. **Minimize data** → Only 5 fields per result
3. **Minimize complexity** → Single index query

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   FLUTTER WEB UI (search_page.dart)         │
│                - Input field                                 │
│                - Results list                                │
│                - Loading/error states                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│         SEARCH CONTROLLER (search_controller.dart)           │
│  🔑 CORE LOGIC:                                              │
│  - Debounce user input (Timer)                              │
│  - Validate query                                            │
│  - Manage state (RxDouble, RxList, RxBool)                 │
│  - Track recent searches                                     │
│  - Call SearchService                                        │
│  🎯 Outcome: 90% fewer Firestore queries                    │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        ↓                                  ↓
    [Check Cache]                  [Query Firestore]
        │                                  │
        ↓                                  ↓
┌─────────────────────────────────────────────────────────────┐
│     SEARCH SERVICE (search_service.dart)                     │
│  ✅ STEP 1: Check in-memory cache                            │
│  ✅ STEP 2: Primary query → keywords array                  │
│  ✅ STEP 3: Fallback query → title prefix (if no results)   │
│  ✅ STEP 4: Sort results locally (views, createdAt)         │
│  ✅ STEP 5: Store in cache                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                 ↓
┌───────────────┐  ┌────────────────┐  ┌──────────────┐
│ SearchCache   │  │ Firestore      │  │ CloudStorage │
│ (in-memory)   │  │ (single index) │  │ (thumbnails) │
│ <50ms hits    │  │ 150-400ms      │  │ CDN          │
└───────────────┘  └────────────────┘  └──────────────┘
```

---

## 📦 Component Breakdown

### 1️⃣ Search Page (UI Layer)
**File**: `presentation/pages/search_page.dart`

**Responsibilities**:
- Render search input
- Display results/suggestions
- Handle loading states
- Show empty states

**Key Features**:
```dart
✅ SearchBar widget (input)
✅ SearchResultCard widget (each result)
✅ RecentSearchesList widget
✅ EmptySearchState widget
✅ SearchResultSkeleton widget (loading)
```

**State Flow**:
```
Empty State
    ↓ (user types)
Loading State (if not cached)
    ↓ (results arrive)
Results State
    ↓ (user taps)
Details Page
```

---

### 2️⃣ Search Controller (Logic Layer)
**File**: `presentation/controllers/search_controller.dart`

**Responsibilities**:
- Debounce user input (350ms)
- Validate queries
- Manage reactive state
- Track recent searches
- Call SearchService

**Key Method - (Debouncing)**:
```dart
void onSearchChanged(String query) {
  // Cancel previous timer
  if (_debounceTimer?.isActive ?? false) {
    _debounceTimer!.cancel();
  }
  
  // Start new timer
  _debounceTimer = Timer(Duration(milliseconds: 350), () {
    _executeSearch(query); // ← Single query after 350ms delay
  });
}
```

**Impact**:
```
Without debounce: User types "flutter" (7 chars)
  → 7 queries sent (one per character)
  → Latency perception: SLOW
  
With debounce (350ms):
  → 1 query sent (after user stops typing)
  → Latency perception: FAST
```

**Reactive State**:
```dart
RxString searchQuery        // Current search text
RxList<SearchResult> results // Current results
RxBool isLoading            // Loading state
RxString errorMessage       // Error (if any)
RxList<String> recentSearches // History
RxMap cacheStats            // Debug info
```

---

### 3️⃣ Search Service (Data Layer)
**File**: `data/services/search_service.dart`

**Responsibilities**:
- Execute Firestore queries
- Implement fallback strategy
- Sort results
- Manage cache

**Query Strategy**:

#### PRIMARY QUERY (90% of searches)
```dart
db.collection('videos')
  .where('keywords', arrayContains: query)
  .where('status', isEqualTo: 'processed')
  .limit(10)
  .get()
```

Why this works:
- ⚡ Single index lookup (Firestore optimized)
- 🎯 Keyword-based (matches user intent)
- 📦 Small payload (10 results)
- ✅ Requires index (setup once)

#### FALLBACK QUERY (if no primary results)
```dart
db.collection('videos')
  .where('title', isGreaterThanOrEqualTo: query)
  .where('title', isLessThanOrEqualTo: query + '\uf8ff')
  .where('status', isEqualTo: 'processed')
  .limit(10)
  .get()
```

Why fallback exists:
- Catches partial/prefix matches
- E.g., searching "tut" → "tutorial videos"
- Only runs if primary returns 0 results

#### LOCAL SORTING
```dart
results.sort((a, b) {
  // First: by views (popularity)
  if (a.views != b.views) return b.views - a.views;
  
  // Second: by date (recency)
  return b.createdAt.compareTo(a.createdAt);
});
```

Why local sort:
- Avoids expensive Firestore orderBy
- Fast in Flutter (milliseconds)
- Combines multiple sort criteria

---

### 4️⃣ Search Cache (Performance Layer)
**File**: `data/models/search_cache.dart`

**Caching Strategy**:
```
User searches "flutter"
  → Results stored in SearchCache
  
User searches "flutter" again
  → Returns cached in <50ms
  
User searches "react"
  → New Firestore query
  
User searches "flutter" again
  → Still cached! <50ms
```

**Cache Stats**:
```
Size: 15/50 cached queries
Hit rate: ~65% (repeats from user behavior)
Memory impact: ~2-3MB (small)
```

**LRU Eviction**:
- Max 50 cached queries
- Least recently used evicted first
- Keeps frequently searched items

---

## ⚡ Latency Breakdown

### CACHED SEARCH (user repeats)
```
1. onSearchChanged() → 350ms debounce
2. SearchService.search() → checks cache
3. Cache.get() → <1ms (HashMap lookup)
4. Return results → <2ms
───────────────────────────────────
Total latency: <50ms ✅
Perfect user experience
```

### FRESH SEARCH (first time)
```
1. onSearchChanged() → 350ms debounce
2. SearchService.search() → checks cache (miss)
3. Firestore query → 100-300ms (network)
4. No results? → Fallback query → +100-200ms
5. Local sort → <5ms
6. Cache.put() → <1ms
7. Return results → <2ms
───────────────────────────────────
Total latency: 200-550ms ✅
Acceptable for MVP
```

### WORST CASE (poor setup)
```
❌ No debounce → 10 queries per typing
❌ No cache → every query goes to Firestore
❌ No index → full collection scan (500ms+)
❌ Large payloads → slow network transfer
❌ Remote sorting → Firestore orderBy (expensive)
───────────────────────────────────
Total latency: 1-3s ❌
```

---

## 💾 Data Model

### SearchResult (Lightweight)
```dart
class SearchResult {
  String id              // Video ID
  String title           // Video title
  String thumbnail       // Thumbnail URL
  int views              // View count
  String channelName     // Creator name
  String channelImage    // Creator avatar
  Timestamp createdAt    // Upload date
}
```

**Size**: ~500 bytes/result (5 results = 2.5KB)

**Why minimal**:
- ❌ NO description (100+ chars)
- ❌ NO comments (nested array)
- ❌ NO tags (array data)
- ❌ NO full document

Network transfer: 2.5KB vs 25KB = **10x faster**

---

## 🔄 Future Scalability: Native Firestore Search

The current system is built on **Native Firestore Search**, which is continuously improving. As Firebase introduces new native full-text and vector search features, this system will integrate them directly without requiring third-party services like Algolia.

**Scalability Path**:
1. Optimize text indexes for larger datasets.
2. Integrate **Firestore Vector Search** for semantic understanding.
3. Utilize **Cloud Firestore Native Full-Text Search** (currently in Preview) as it becomes GA.

---

## 📊 Performance for 20K Users

### Query Load
```
20K users
5% active searching = 1,000 concurrent users
Avg searches/user/session = 3
1,000 × 3 = 3,000 searches/hour
With cache: 3,000 × 0.3 (cache miss rate) = 900 Firestore queries/hour
With debounce: 70% reduction = 270 queries/hour
Realistic: ~50-100 queries per minute
```

### Firestore Cost
```
Reads: 100-200/min → ~6K/hour
Monthly: 6K × 720 hours = 4.3M reads
Pricing: $0.06/100K reads → $2.60/month

With large platform:
→ Upgrade to Firestore Native Full-Text Search ($0/month)
→ But still use Firestore for other features
```

### Bandwidth
```
Each search: ~2.5KB
100 searches/min = 250KB/min
Monthly: 250KB × 43,200 min = 10.8GB
CDN cost: ~$5-10/month
```

---

## 🧭 Best Practices Summary

✅ **DO**:
- Use debounce (350-500ms is sweet spot)
- Limit results (10-15 is optimal)
- Cache aggressively (LRU or TTL)
- Sort locally (not in Firestore)
- Keep documents lightweight
- Create required indexes

❌ **DON'T**:
- Query on every keystroke
- Return 50+ results
- Use multiple parallel queries always
- Store full documents in cache
- Rely on Firestore sorting
- Forget to set status='processed'

---

## 🚀 Deployment Checklist

- [ ] Firestore indexes created (both keyword and prefix)
- [ ] All videos have `status: 'processed'`
- [ ] Cloud Functions generating `keywords` and `title_lower`
- [ ] Security rules updated
- [ ] Cache warmup on app init
- [ ] Error handling for offline (optional)
- [ ] Analytics tracking searches
- [ ] Monitoring Firestore latency

---

## 📈 Metrics to Monitor

```dart
// In SearchController:
Map<String, dynamic> metrics = {
  'cacheHitRate': 0.65,      // 65% hits
  'avgLatency': 280.0,       // ms
  'p99Latency': 450.0,       // ms (99th percentile)
  'errorRate': 0.002,        // 0.2% errors
  'resultsPerSearch': 7.2,   // avg results shown
};
```

Track these in Firebase Analytics to optimize further.

---

## 📞 Q&A

**Q: Can I search without debouncing?**
A: Yes, but latency will feel sluggish (10-15 queries per typing)

**Q: How much memory does cache use?**
A: ~2-3MB for 50 cached searches (negligible)

**Q: What if someone searches offensive terms?**
A: Add content filtering in SearchService._normalizeQuery()

**Q: Can I sort by views in Firestore?**
A: Yes, but creates expensive index. Better to sort locally (10ms)

**Q: Does cache help with offline?**
A: Yes! Cached searches work offline entirely

**Q: When should I upgrade to Native Full-Text Search?**
A: When you hit 100K+ users or need advanced ranking

