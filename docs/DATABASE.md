# TruthWorld — Database Schema, Realtime Models & Security Rules

TruthWorld uses a hybrid persistence architecture: **Cloud Firestore** for structured, relational document models, and **Firebase Realtime Database (RTDB)** for ultra-low latency presence and live viewers.

---

## 1. Firestore Root Collections & Data Models

```text
/users/{userId}                         # User accounts, profiles, notification tokens
/channels/{channelId}                   # Creator channels, handles, badges, subscriber counts
/videos/{videoId}                       # Master video records, status, HLS links, metadata
  ├── /claims/{claimId}                 # Subcollection: Credibility claims verified by AI
  ├── /comments/{commentId}             # Subcollection: Threaded comments & replies
  └── /shards/{shardId}                 # Subcollection: Distributed view/like counter shards
/topics/{topicSlug}                     # Community discussion topics & claim trees
/orders/{orderId}                       # Cashfree checkout orders & transaction logs
/subscriptions/{userId}                 # Active Pro user subscriptions & renewal dates
/wallets/{userId}                       # Creator monetization balances & payout history
/payout_requests/{payoutId}             # Creator withdrawal requests & IMPS transfer status
/ad_campaigns/{campaignId}              # Advertiser campaigns, budgets, remaining impressions
/reports/{reportId}                     # User flag reports for content moderation
```

---

## 2. Realtime Database (RTDB) Schema

RTDB (`truthworld-1-default-rtdb.asia-southeast1.firebasedatabase.app`) handles ephemeral data:

```json
{
  "live_viewers": {
    "$videoId": {
      "$sessionId": {
        "uid": "string",
        "timestamp": 1718000000000
      }
    }
  }
}
```

---

## 3. Storage Bucket Structure (`truthworld-1.firebasestorage.app`)

| Path Prefix | Access Policy | Description |
| :--- | :--- | :--- |
| `uploads/raw_videos/{id}.mp4` | Creator Write (Resumable) | Raw uploaded video waiting for resolution & pipeline processing |
| `videos/{id}/hls/` | Public Read | Transcoded HLS master playlist (`master.m3u8`) and resolution slices |
| `videos/{id}/thumbnails/` | Public Read | AI generated or creator uploaded thumbnails |
| `videos/{id}/subtitles/` | Public Read | VTT multi-lingual subtitles (Telugu, Hindi, English) |
| `videos/{id}/dubbing/` | Public Read | Synthesized audio streams in target languages |
| `avatars/{userId}/` | Public Read / Owner Write | User channel banner and profile avatars |
| `kyc/{userId}/` | Admin Only Read / Owner Write | Government ID proof uploads for creator payout verification |

---

## 4. Security Rules Summary

TruthWorld includes over 2,000 lines of hardened production security rules across three engines:

1. **`firestore.rules`**:
   * Enforces that only backend Cloud Functions with Admin privileges can modify `credibilityScore`, `status == 'published'`, `walletBalance`, and `orderStatus`.
   * Enforces row-level ownership: Users can only write to their own profile and videos.
   * Requires authenticated App Check tokens to prevent automated bot scrapers.

2. **`storage.rules`**:
   * Enforces file size limits (max 2GB for raw videos, max 2MB for video thumbnails matching YouTube, max 10MB for community images, max 15MB for general images).
   * Validates MIME types (`video/mp4`, `image/webp`, `image/png`, `text/vtt`).

3. **`database.rules.json`**:
   * Restricts viewer presence updates to active session IDs.
