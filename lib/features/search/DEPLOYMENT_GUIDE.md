# 🚀 Search System Deployment Quick Reference

## Pre-Deployment Checklist (30 min)

### Frontend Integration (10 min)
```
[ ] 1. Add route in lib/routes/app_pages.dart
      GetPage(name: '/search', page: () => SearchPage())

[ ] 2. Add navigation button in AppBar/BottomNav
      IconButton(icon: Icon(Icons.search), onPressed: () => Get.toNamed('/search'))

[ ] 3. Test app builds without errors
      flutter pub get && flutter run

[ ] 4. Navigate to search page - verify loads
```

### Firestore Setup (15 min)
```
[ ] 1. Go to Firebase Console → Firestore Database → Indexes

[ ] 2. Create Index #1: Keywords (primary)
      Collection: videos
      Fields:
        - keywords (Array)
        - status (Ascending)
        - uploadedAt (Descending)
      Status: Wait for "Enabled" (~5-10 min)

[ ] 3. Create Index #2: Title Prefix (fallback)
      Collection: videos
      Fields:
        - title_lower (Ascending)
        - status (Ascending)
        - uploadedAt (Descending)
      Status: Wait for "Enabled"

[ ] 4. Update Firestore Rules (lib/firestore.rules)
      match /videos/{videoId} {
        allow read: if request.auth != null;
        allow create, update, delete: if request.auth.uid == resource.data.ownerId;
      }
```

### Cloud Functions Deployment (5 min)
```
[ ] 1. Navigate to functions folder
      cd functions

[ ] 2. Create populateTitleLower() function
      Trigger: onCreate for videos collection
      Code: Updates video.title_lower = video.title.toLowerCase()

[ ] 3. Create generateKeywords() function
      Trigger: onCreate for videos collection
      Code: Extracts words from title+description → keywords array

[ ] 4. Deploy functions
      firebase deploy --only functions

[ ] 5. Backfill existing videos (one-time)
      Either run Cloud Function manually or use admin SDK script
```

---

## Testing Checklist (15 min)

### Debounce Test
```dart
// Open debug console, type slowly: "h-e-l-l-o"
// Expected: Only 1 query sent (not 5)
// Look for: "[Search] Executing search for: "hello""

// If you see 5 "[Search] Executing" lines → debounce broken
// If you see 1 line → ✅ Working
```

### Cache Test
```dart
// Search: "flutter" → Wait for results
// Search: "flutter" again → Should be <50ms
// Check console for: "✅ Cache HIT"

// If you don't see cache hit → cache broken
// If latency is >100ms → caching not working
```

### Firestore Query Test
```dart
// In SearchService, add breakpoint or log:
// "Executing PRIMARY query"
// 
// Expected: <200ms response
// If >2 seconds: Indexes not created
// If "FAILED_PRECONDITION": Missing index error
```

---

## Production Deployment Steps

### Step 1: Verify All Components
```bash
# 1. Build release
flutter build web

# 2. Check for errors
# 3. Test search functionality in release build
```

### Step 2: Firestore Verification
```
[ ] Both indexes showing "Enabled" (not "Creating")
[ ] Sample videos have: title_lower, keywords, status='processed'
[ ] Security rules deployed
```

### Step 3: Cloud Functions
```bash
# Deploy
firebase deploy --only functions

# Verify
firebase functions list

# Test new video upload generates keywords
```

### Step 4: Analytics Setup
```dart
// Add to search_controller.dart
FirebaseAnalytics.instance.logEvent(
  name: 'search_executed',
  parameters: {
    'query': query,
    'results_count': results.length,
    'latency_ms': stopwatch.elapsedMilliseconds,
  },
);
```

### Step 5: Deploy to Production
```bash
# Option A: Firebase Hosting
firebase deploy

# Option B: App Store/Play Store (if mobile)
flutter build apk; flutter build ios

# Option C: Custom hosting
# Copy build/web to your server
```

---

## Monitoring Dashboard (Setup Once)

### Firebase Analytics
```
Go to: Firebase Console → Analytics

Create custom events:
- "search_executed" → track latency
- "search_cache_hit" → track cache effectiveness
- "search_error" → track failures

Create dashboard:
- Avg search latency (should be <400ms)
- Cache hit rate (should be >60%)
- Searches per user
- Top search queries
```

### Firestore Console
```
Go to: Firebase Console → Firestore → Stats

Monitor:
- Document reads/day (should be <10K with cache)
- Document writes/day
- Storage usage
- Network egress

Set budget alert: $10/month
```

---

## Rollback Plan

If search breaks in production:

### Immediate (2 min)
```
1. Disable search route (comment out in app_pages.dart)
2. Remove navigation button
3. Deploy app hotfix
```

### Investigation (10 min)
```
1. Check Firestore Console → Indexes (are they "Enabled"?)
2. Check Cloud Functions logs (any errors?)
3. Check Security Rules (can users read videos?)
4. Check Firestore structure (do videos have required fields?)
```

### Recovery (varies)
```
If indexes not created:
  → Create indexes and wait for "Enabled"
  → Re-enable search route

If security rules too strict:
  → Fix rules, deploy, wait 1 min

If keywords/title_lower missing:
  → Run backfill Cloud Function
  → Re-upload test videos
  
If Cloud Functions broken:
  → Redeploy functions
  → Or disable functions and script backfill
```

---

## Post-Launch (First 24 Hours)

### Hour 1
```
[ ] Monitor Firebase Console for errors
[ ] Test on device (mobile + web)
[ ] Check latency in Analytics
[ ] Verify cache hit rate
```

### Hour 6
```
[ ] Check Firestore costs (should be <$0.01)
[ ] Review any error logs
[ ] Load test with 10 concurrent searchers
[ ] Monitor performance metrics
```

### Day 1
```
[ ] Full investigation of all metrics
[ ] User feedback collection
[ ] Performance optimization notes
[ ] Document any issues for future iterations
```

---

## Commands Reference

### View Firestore Indexes
```bash
firebase firestore:indexes
```

### Deploy Functions Only
```bash
firebase deploy --only functions:populateTitleLower,functions:generateKeywords
```

### View Function Logs
```bash
firebase functions:log --follow
```

### Manually Backfill Videos
```bash
# Run from admin SDK (if Firestore trigger doesn't work)
# Script goes in Cloud Function or local script
```

### Clear Local Cache (for testing)
```dart
// In search_controller.dart
searchController.clearServiceCache();
```

---

## Troubleshooting Quick Links

| Issue | Check |
|-------|-------|
| No results | Keywords field exists? Index "Enabled"? |
| Slow search | Indexes created? Status field set? |
| Permission denied | User authenticated? Rules allow read? |
| Cache not working | SearchController permanent? Repeated searches? |
| High costs | Indexes created? Cache working? |

See INTEGRATION_GUIDE.md for detailed troubleshooting.

---

## Success Verification

✅ **Feature is live when:**
- Search page loads
- Can search videos
- Debounce working (1 query for typing)
- Cache working (<50ms repeats)
- Results show in <500ms
- No permission errors
- Firestore costs <$1

✅ **Ready to scale when:**
- 100+ concurrent searches handled
- Latency consistent <400ms
- Cache hit rate >60%
- <$10/month Firestore cost
- No error spikes

---

## Support Resources

**If stuck:**
1. Check logs: `firebase functions:log --follow`
2. Read FIRESTORE_SETUP.md
3. Read ARCHITECTURE.md for design overview
4. Review INTEGRATION_GUIDE.md troubleshooting section

**Key decision points:**
- If latency >2s → Missing index
- If permission errors → Check rules + auth
- If no results → Keywords field missing or not populated

---

**Estimated Total Deployment Time**: 1-2 hours (including testing)
**Expected Cost After Launch**: $2-5/month (Firestore only)
**Expected Performance**: <400ms searches, <50ms cached

Good luck! 🚀

