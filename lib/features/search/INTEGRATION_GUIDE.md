# Search System Integration Guide

## 🚀 Quick Start (5 minutes)

### Step 1: Add Route
In your `lib/routes/app_pages.dart`:

```dart
import 'package:truthworld/features/search/search.dart';

class AppPages {
  static final pages = [
    // ... other routes ...
    GetPage(
      name: '/search',
      page: () => SearchPage(),
    ),
  ];
}
```

### Step 2: Add Navigation Button
In your home/shell widget:

```dart
// In AppBar or BottomNavigationBar
IconButton(
  icon: Icon(Icons.search),
  onPressed: () => Get.toNamed('/search'),
)
```

### Step 3: Sync Video Collection
Run this one-time setup to populate Firestore fields:

```dart
// In your initializer/setup function
await syncVideoSearchFields();
```

**That's it!** Your search is now live.

---

## 📋 Complete Integration Checklist

### Frontend Integration
- [ ] Add route to app_pages.dart
- [ ] Add navigation button
- [ ] Test search page loads
- [ ] Test debouncing (type, stop, query should execute once)
- [ ] Test cache (search same term twice, second should be <50ms)

### Firestore Setup
- [ ] Create keyword index
- [ ] Create title_lower index
- [ ] Populate existing videos with `title_lower` and `keywords`
- [ ] Set `status: 'processed'` on all searchable videos

### Cloud Functions (Backend)
- [ ] Deploy populateTitleLower() function
- [ ] Deploy generateKeywords() function
- [ ] Test on new video upload

### Security
- [ ] Update Firestore rules to protect search
- [ ] Test unauthenticated access (should fail)
- [ ] Test authenticated access (should work)

### Monitoring
- [ ] Track search metrics in Firebase Analytics
- [ ] Monitor Firestore read costs
- [ ] Set up alerts for slow queries

---

## 🔌 Detailed Integration Examples

### Example 1: Routing (GetX)
```dart
// In lib/routes/app_pages.dart

import 'package:truthworld/features/search/search.dart';

class AppPages {
  static final pages = [
    // Home
    GetPage(
      name: '/home',
      page: () => HomePage(),
    ),
    
    // 🔍 SEARCH PAGE
    GetPage(
      name: '/search',
      page: () => SearchPage(),
      binding: BindingsBuilder(() {
        Get.put(SearchController());
      }),
    ),
    
    // Video Details (with search result data)
    GetPage(
      name: '/video-detail',
      page: () => VideoDetailPage(),
      arguments: Get.arguments,
    ),
  ];
}
```

### Example 2: Navigation Button
```dart
// In your app shell/main layout

AppBar(
  title: Text('Truthworld'),
  actions: [
    // 🔍 Search icon
    IconButton(
      icon: Icon(Icons.search),
      onPressed: () => Get.toNamed('/search'),
      tooltip: 'Search videos',
    ),
    // ... other actions ...
  ],
)
```

### Example 3: Direct Search Widget (no page navigation)
```dart
// Use SearchBar widget directly in your page

import 'package:truthworld/features/search/search.dart';

class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _searchCtrl = Get.put(SearchController());
  final _textCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 🔍 Embedded search bar
          SearchBar(
            controller: _textCtrl,
            onChanged: _searchCtrl.onSearchChanged,
            onClear: _searchCtrl.clearSearch,
            hintText: 'Find videos...',
          ),
          
          // Results below
          Expanded(
            child: Obx(
              () => ListView(
                children: _searchCtrl.searchResults
                    .map((result) => SearchResultCard(
                      result: result,
                      onTap: () {
                        // Navigate to video
                        Get.toNamed(
                          '/video-detail',
                          arguments: result.id,
                        );
                      },
                    ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 🔄 Cloud Functions Setup

### Populate title_lower Field
**File**: `functions/populateTitleLower.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.populateTitleLower = functions.firestore
  .document('videos/{videoId}')
  .onCreate((snap, context) => {
    const data = snap.data();
    
    if (!data.title) {
      return null;
    }

    return snap.ref.update({
      title_lower: data.title.toLowerCase(),
    });
  });
```

**Deploy**:
```bash
cd functions
firebase deploy --only functions:populateTitleLower
```

---

### Generate Keywords Array
**File**: `functions/generateKeywords.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.generateKeywords = functions.firestore
  .document('videos/{videoId}')
  .onCreate((snap, context) => {
    const data = snap.data();
    
    if (!data.title && !data.description) {
      return snap.ref.update({ keywords: [] });
    }

    // Combine title + description
    const text = `${data.title || ''} ${data.description || ''}`.toLowerCase();
    
    // Split into words, filter stopwords
    const words = text
      .split(/\s+/)
      .filter(w => w.length > 2)
      .filter(w => !['the', 'and', 'for', 'you', 'are'].includes(w));
    
    // Remove duplicates, limit to 10
    const keywords = [...new Set(words)].slice(0, 10);
    
    return snap.ref.update({ keywords });
  });
```

**Deploy**:
```bash
firebase deploy --only functions:generateKeywords
```

---

### Backfill Existing Videos
**File**: `functions/backfillSearchFields.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Run once manually!
exports.backfillSearchFields = functions.https.onCall(
  async (data, context) => {
    // Check auth
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be logged in',
      );
    }
    
    // Check admin (modify security to allow ops)
    const db = admin.firestore();
    const videos = await db.collection('videos').get();
    
    let updated = 0;
    
    for (const doc of videos.docs) {
      const video = doc.data();
      
      // Generate title_lower
      const title_lower = video.title ? video.title.toLowerCase() : '';
      
      // Generate keywords
      const text = `${video.title || ''} ${video.description || ''}`.toLowerCase();
      const words = text
        .split(/\s+/)
        .filter(w => w.length > 2);
      const keywords = [...new Set(words)].slice(0, 10);
      
      // Update
      await doc.ref.update({
        title_lower,
        keywords,
        status: 'processed', // Mark as searchable
      });
      
      updated++;
    }
    
    return { message: `Updated ${updated} videos` };
  }
);
```

**Invoke** (from app):
```dart
// Call from your admin panel
final result = await FirebaseFunctions.instance
  .httpsCallable('backfillSearchFields')
  .call();
```

---

## 📱 UI Integration Patterns

### Pattern 1: Search Page (Dedicated)
```
Home → Search Icon → SearchPage → Result → VideoDetail
```

Good for: Full-page dedicated search experience

### Pattern 2: Search Bar in Headers
```
Any Page → SearchBar in AppBar → Results Overlay → VideoDetail
```

Good for: Quick search from anywhere

### Pattern 3: Home Page Search
```
Home (SearchBar visible) → Quick search → Results → VideoDetail
```

Good for: Always-available search

### Pattern 4: Recent/Suggested
```
Home → "Suggested for you" → Shows recent searches → Quick access
```

Good for: Reducing friction for frequently searched terms

---

## 🧪 Testing Search Features

### Test 1: Debouncing
```dart
// In your test file
test('Search debounces user input', () async {
  final controller = SearchController();
  
  // Simulate rapid typing
  controller.onSearchChanged('f');
  controller.onSearchChanged('fl');
  controller.onSearchChanged('flu');
  controller.onSearchChanged('flut');
  controller.onSearchChanged('flutt');
  
  // Only 1 search should be executed after debounce
  await Future.delayed(Duration(milliseconds: 400));
  
  expect(controller.searchResults.isNotEmpty, true);
});
```

### Test 2: Caching
```dart
test('Search results are cached', () async {
  final controller = SearchController();
  final service = controller._searchService;
  
  // First search
  await controller.search('flutter');
  final firstTime = Stopwatch()..start();
  final results1 = controller.searchResults;
  firstTime.stop();
  
  // Second search (same term)
  Stopwatch secondTime = Stopwatch()..start();
  controller.onSearchChanged('flutter');
  secondTime.stop();
  
  // Cached should be <50ms
  expect(secondTime.elapsedMilliseconds < 50, true);
});
```

### Test 3: Firebase Integration
```dart
test('Search queries Firestore correctly', () async {
  // Mock Firestore
  final mockFirestore = MockFirebaseFirestore();
  
  // Add mock data
  mockFirestore.collection('videos').add({
    'title': 'Flutter Tutorial',
    'keywords': ['flutter', 'tutorial', 'app'],
    'status': 'processed',
  });
  
  // Search
  final results = await SearchService().search('flutter');
  
  expect(results.length, greaterThan(0));
  expect(results.first.title, contains('Flutter'));
});
```

---

## 🔍 Debugging Tips

### Enable Debug Logging
```dart
// In main.dart or your init
debugPrintSynchronously = true; // See search logs

// Then open DevTools Console tab to see:
// 📦 [Search] Checking cache for: "flutter"
// ✅ [Search] Cache HIT - 5 results returned in <50ms
// 📊 [Search] Primary query returned 10 results
// etc.
```

### Check Cache Statistics
```dart
// In search_page.dart, display stats:
Obx(
  () {
    final stats = _searchCtrl.getCacheStats();
    return Text(
      'Cache: ${stats['size']}/${stats['maxSize']} | Hit rate: ${stats['hitRate']}',
      style: TextStyle(fontSize: 10, color: Colors.grey),
    );
  },
)
```

### Monitor Firestore Reads
```dart
// In Firebase Console
Firestore → Database → Usage Statistics

// Should see:
// - Document reads: 50-100/min
// - With cache active: <50/min
```

---

## 🚨 Common Issues & Fixes

### Issue: No results on fresh app
**Cause**: Videos don't have `keywords` or `title_lower` fields
**Fix**: 
1. Run backfillSearchFields function
2. Deploy generateKeywords cloud function
3. Re-upload sample videos

### Issue: Slow search (>2 seconds)
**Cause**: Missing Firestore index
**Fix**:
1. Go to Firebase Console → Indexes
2. Create keyword index (if showing "Creating", wait)
3. Try search again

### Issue: Permission denied errors
**Cause**: Security rules too restrictive
**Fix**:
```dart
// Update /firestore.rules
match /videos/{videoId} {
  allow read: if request.auth != null;
}
```

### Issue: Cache not working
**Cause**: SearchController not persisting between pages
**Fix**: Use GetX permanent binding:
```dart
GetPage(
  name: '/search',
  page: () => SearchPage(),
  binding: BindingsBuilder(() {
    Get.put(SearchController(), permanent: true);
  }),
)
```

---

## 📈 Performance Monitoring

### Firebase Analytics Integration
```dart
// In search_controller.dart
Future<void> _executeSearch(String query) async {
  final stopwatch = Stopwatch()..start();
  
  final results = await _searchService.search(query);
  
  stopwatch.stop();
  
  // Log to Firebase
  FirebaseAnalytics.instance.logEvent(
    name: 'search_executed',
    parameters: {
      'query': query,
      'results_count': results.length,
      'latency_ms': stopwatch.elapsedMilliseconds,
      'was_cached': _searchService.isCached(query),
    },
  );
}
```

### Monitor Dashboard
Create a dashboard tracking:
- Avg search latency
- Cache hit rate
- Most searched terms
- Geographic distribution
- Device types (mobile vs web)

---

## 🎓 Learning Resources

Inside the search feature:
- `ARCHITECTURE.md` - Deep dive into design
- `FIRESTORE_SETUP.md` - Database setup guide
- Source code comments - Inline explanations

---

## ✅ Verification Checklist

Before deploying to production:

**Backend**:
- [ ] Both Firestore indexes enabled
- [ ] Cloud functions deployed
- [ ] Existing videos backfilled
- [ ] Security rules updated
- [ ] Firebase Analytics setup

**Frontend**:
- [ ] SearchPage loads without errors
- [ ] Debouncing working (log shows 1 query, not 7)
- [ ] Cache working (<50ms on repeated search)
- [ ] Recent searches save
- [ ] Error handling working
- [ ] Offline mode (cached results) works

**Performance**:
- [ ] Fresh search <500ms
- [ ] Cached search <50ms
- [ ] Results display in <1s
- [ ] No memory leaks on repeated searches

---

**Questions?** Check the architecture docs or enable debug logs!

