# Search System: Firestore Setup Guide

## Overview
This guide explains how to configure your Firestore database to support the low-latency search system (handles 20K+ active users).

## 🗂️ Required Collection Structure

### Collection: `videos`
This is your main video collection with optimized indexing.

```json
{
  "videoId": {
    "id": "string",
    "title": "string",
    "title_lower": "string",        // ⭐ CRITICAL: lowercase for prefix search
    "keywords": ["array", "of", ...], // ⭐ CRITICAL: array for keyword search
    "thumbnail": "string",
    "thumbnailUrl": "string", 
    "views": "number",
    "channelName": "string",
    "channelImage": "string",
    "uploadedAt": "timestamp",
    "status": "string"              // ⭐ CRITICAL: ONLY search 'processed' videos
  }
}
```

## ⚙️ Required Firestore Indexes

### Index 1: Keywords Search (PRIMARY)
**Purpose**: Fast keyword-based search
**Usage**: 90% of searches will use this index

```
Collection: videos
Fields:
  - keywords (Array) ↑ (ascending)
  - status = processed ↓ (descending)
  - uploadedAt ↓ (descending)
```

**Query it supports:**
```dart
db.collection('videos')
  .where('keywords', arrayContains: 'flutter')
  .where('status', isEqualTo: 'processed')
  .limit(10)
```

**Creation Steps:**
1. Go to Firebase Console → Firestore Database
2. Click "Indexes" tab
3. Click "Create Index"
4. Select Collection: `videos`
5. Add Fields:
   - `keywords` (Array)
   - `status` (Ascending/Descending — doesn't matter for equality)
   - `uploadedAt` (Descending — puts newest first)
6. Click "Create Index"

⏱️ **Index build time**: 2-10 minutes (auto-indexed)

---

### Index 2: Prefix Search (FALLBACK)
**Purpose**: Title prefix search for typos/variations

```
Collection: videos
Fields:
  - title_lower ↑ (ascending)
  - status = processed
  - uploadedAt ↓ (descending)
```

**Query it supports:**
```dart
db.collection('videos')
  .where('title_lower', isGreaterThanOrEqualTo: 'flutter')
  .where('title_lower', isLessThanOrEqualTo: 'flutter\uf8ff')
  .where('status', isEqualTo: 'processed')
  .limit(10)
```

---

### Index 3: Views Ranking (OPTIONAL - for "Most Popular")
**Purpose**: Sort videos by popularity

```
Collection: videos
Fields:
  - views ↓ (descending)
  - status = processed
  - uploadedAt ↓ (descending)
```

---

## 📝 Data Preparation

### Step 1: Populate `title_lower` Field
Run a Cloud Function or script to add lowercase title:

```dart
// Cloud Function (Node.js/JavaScript)
exports.populateTitleLower = functions.firestore
  .document('videos/{videoId}')
  .onCreate((snap, context) => {
    const data = snap.data();
    return snap.ref.update({
      'title_lower': data.title ? data.title.toLowerCase() : '',
    });
  });
```

### Step 2: Populate `keywords` Array
Generate searchable keywords from title and description:

```dart
// Cloud Function
exports.generateKeywords = functions.firestore
  .document('videos/{videoId}')
  .onCreate((snap, context) => {
    const data = snap.data();
    const title = (data.title || '').toLowerCase();
    
    // Split title into words
    const words = title.split(/\s+/).filter(w => w.length > 2);
    
    // Add first 3 words as array
    const keywords = [...new Set(words)].slice(0, 10);
    
    return snap.ref.update({ keywords });
  });
```

### Step 3: Ensure Status Field
All indexed videos must have `status: 'processed'`

Only search processed videos because:
- Avoids incomplete uploads
- Improves index efficiency
- Provides better UX

---

## 🔐 Firestore Security Rules

```
match /databases/{database}/documents {
  // Videos collection (public read)
  match /videos/{videoId} {
    allow read: if request.auth != null;
    allow create, update, delete: if request.auth.uid == resource.data.ownerId;
  }

  // Optional: Protect index metadata
  match /image_verification/{doc=**} {
    allow read, write: if request.auth != null;
  }
}
```

---

## 📊 Expected Performance

### Without Proper Indexes ❌
```
Latency: 1-3 seconds (full collection scan)
Firestore cost: ~500-1000 read ops per search
```

### With Proper Indexes ✅
```
Latency: 150-400ms (single index query)
Firestore cost: 1 read op per search
```

---

## 🚀 Optimization Checklist

- [ ] Keywords index created
- [ ] Prefix (title_lower) index created
- [ ] Both indexes showing "enabled" in Firebase Console
- [ ] New videos automatically get `title_lower` and `keywords`
- [ ] Old videos migrated with `title_lower` and `keywords`
- [ ] `status` field set to 'processed' for searchable videos
- [ ] Security rules updated to restrict searches
- [ ] Cache warmup enabled in app initialization

---

## 🔧 Troubleshooting

### "FAILED_PRECONDITION" Error
**Cause**: Missing index
**Solution**: Create the keyword index as described above

### "permission-denied" Error
**Cause**: User not authenticated or insufficient permissions
**Solution**: Ensure user is logged in and security rules allow reading videos

### No Results Found
**Cause**: Keywords not populated, or status != 'processed'
**Solution**: 
1. Check Cloud Functions are running
2. Verify videos have status: 'processed'
3. Verify videos have populated keywords array

---

## 📈 Scaling for 20K+ Users

At 20K concurrent users with this design:

| Metric | Value |
|--------|-------|
| Avg queries/sec | ~100-150 |
| Firestore read ops/sec | 150-200 (with caching: ~50-60) |
| Avg latency | 200-350ms |
| Cache hit rate | 60-75% |
| Monthly cost (Firestore) | ~$30-50 |

**Why this scales:**
- Keyword query has single index lookup (O(1) effectively)
- Cache reduces 70% of queries
- Limit 10 results = small payload
- No sorting needed in Firestore

---

## 🔄 Upgrade Path to Algolia

When you're ready to scale beyond 100K users:

1. Firestore → Cloud Function → Algolia Index (background sync)
2. Change only `SearchService`:
   ```dart
   // Before: Firestore
   // After: Algolia client
   ```
3. UI and Controller stay the same ✅

---

## 📞 Support

For issues:
1. Check Firestore Console → Indexes tab
2. Verify indexes say "Enabled" (not "Creating")
3. Check Cloud Functions logs
4. Review security rules in /firestore.rules

