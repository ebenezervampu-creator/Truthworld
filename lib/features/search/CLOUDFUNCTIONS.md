# Firestore Search - Cloud Functions & Scripts

As part of the search feature implementation, the following Cloud Functions and backfill scripts are required to maintain the `keywords` and `titleLowercase` indexes.

## Cloud Functions (Node.js)

### 1. `onVideoCreated`
Trigger: `onCreate` on `videos/{videoId}`
Action: Generate and write `keywords[]` and `titleLowercase` fields.

### 2. `onVideoUpdated`
Trigger: `onUpdate` on `videos/{videoId}`
Action: Re-generate `keywords` and `titleLowercase` if `title`, `tags`, or `channelName` changed.

```javascript
// Example implementation logic
const admin = require('firebase-admin');
const functions = require('firebase-functions');

exports.onVideoCreated = functions.firestore
  .document('videos/{videoId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const { title = '', channelName = '', tags = [] } = data;
    
    return snap.ref.update({
      keywords: generateKeywords(title, channelName, tags),
      titleLowercase: title.toLowerCase().trim()
    });
  });

function generateKeywords(title, channelName, tags) {
  const stopwords = new Set(['the','a','an','in','on','at','to','for','of','and','is','it']);
  const tokens = [title, channelName, ...tags]
    .join(' ')
    .toLowerCase()
    .split(/[\s\W]+/)
    .filter(w => w.length > 1 && !stopwords.has(w));

  const keywords = new Set(tokens);
  // Add prefixes for partial matching
  tokens.forEach(token => {
    for (let i = 2; i <= token.length; i++) {
      keywords.add(token.substring(0, i));
    }
  });
  return Array.from(keywords);
}
```

## Backfill Script

Use this script to populate indexes for existing videos.

```javascript
// scripts/backfill_search_fields.js
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function backfill() {
  const snap = await db.collection('videos')
    .where('status', '==', 'processed')
    .get();

  const batch = db.batch();
  snap.docs.forEach(doc => {
    const { title = '', channelName = '', tags = [] } = doc.data();
    const keywords = generateKeywords(title, channelName, tags);
    batch.update(doc.ref, {
      keywords,
      titleLowercase: title.toLowerCase().trim(),
    });
  });

  await batch.commit();
  console.log(`Backfilled ${snap.size} videos.`);
}
// ... include generateKeywords function from above ...
```
