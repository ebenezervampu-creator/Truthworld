# TruthWorld — Cloud Functions & Serverless API Catalog

TruthWorld's backend runs on **Firebase Functions (2nd Gen)** powered by Node.js 24 and TypeScript. All functions run in region `asia-south1` with `minInstances: 0` (scale-to-zero) for cost efficiency and configured concurrency limits.

---

## 1. Global Serverless Configuration
* **Region**: `asia-south1` (Mumbai)
* **SDK**: `firebase-functions/v2`
* **Firestore Setting**: `{ ignoreUndefinedProperties: true }`
* **Realtime Database**: `truthworld-1-default-rtdb.asia-southeast1.firebasedatabase.app`
* **Storage Bucket**: `truthworld-1.firebasestorage.app`

---

## 2. Core Functional Domains

```mermaid
graph TD
    subgraph 1. AI Video Ingestion & Processing
        F_Upload["onVideoUpload<br/>(Storage Trigger)"]
        F_Trans["handleTranscription<br/>(PubSub Worker)"]
        F_Cred["handleCredibility<br/>(PubSub Worker)"]
        F_Dub["handleDubbing<br/>(PubSub Worker)"]
        F_Copy["handleCopyrightCheck<br/>(PubSub Worker)"]
        F_AITrigger["triggerVideoAIFeatures<br/>(HTTPS onRequest)"]
    end

    subgraph 2. Publishing & Feed Fan-Out
        F_PubGate["onVideoPublished<br/>(Firestore Trigger)"]
        F_SchedPub["scheduledVideoPublisher<br/>(PubSub Cron)"]
        F_Shard["shardSync<br/>(Counter Aggregator)"]
    end

    subgraph 3. Cashfree Payments & Creator Economy
        F_Order["createCashfreeOrder<br/>(Callable onCall)"]
        F_Verify["verifyCashfreePayment<br/>(Callable onCall)"]
        F_WebHook["cashfreeWebhook<br/>(HTTPS onRequest)"]
        F_Payout["onPayoutRequestCreated<br/>(Firestore Trigger)"]
        F_PremRev["distributePremiumRevenue<br/>(Cron Scheduled)"]
    end

    subgraph 4. Watchtime, Live Viewers & Analytics
        F_Watch["trackWatchEvent<br/>(Callable onCall)"]
        F_Live["onActiveViewerWrite<br/>(RTDB Trigger)"]
        F_Rollup["rollupVideoCounterShards<br/>(Cron Scheduled)"]
    end

    subgraph 5. SEO, Search & Edge Delivery
        F_SEO["seoServer<br/>(SSR Express App)"]
        F_Search["searchTruthWorld / aiSearchAssistant<br/>(Callable / REST)"]
        F_Feed["publicFeedServer<br/>(Edge Feed CDN)"]
    end
```

---

## 3. Function Domain Catalogs

### 1. AI Video Pipeline & Ingestion
These functions process every uploaded video file into multi-lingual audio, transcripts, and fact-checking reports.

| Function Name | Trigger Type | Event / Route | Secrets / Environment | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `onVideoUpload` | Storage Trigger | `storage.onObjectFinalized` | None | Detects raw video in `uploads/`, generates unique video ID, dispatches Pub/Sub tasks |
| `handleTranscription` | Pub/Sub Worker | `transcription-jobs` | `ASSEMBLYAI_KEY`, `GEMINI_API_KEY` | Extracts audio, generates word-level timestamps and multi-lingual subtitles (Telugu, Hindi, English) |
| `handleCredibility` | Pub/Sub Worker | `credibility-jobs` | `GEMINI_API_KEY` | Evaluates claims using `scoringEngine.ts` and `speakerTrustEngine.ts`, computes credibility score (0-100) |
| `handleDubbing` | Pub/Sub Worker | `dubbing-jobs` | `ELEVENLABS_KEY` / Cloud TTS | Synthesizes translated audio tracks matched to speaker pitch |
| `handleFactComplete` | Pub/Sub Worker | `fact-complete-jobs` | None | Aggregates all claim verifications into `/videos/{id}/claims` |
| `handleDubbingComplete` | Pub/Sub Worker | `dubbing-complete-jobs`| None | Merges dubbed audio tracks into master HLS playlist |
| `handleCopyrightCheck`| Pub/Sub Worker | `copyright-jobs` | None | Fingerprints audio/video against copyright database |
| `triggerVideoAIFeatures`| HTTPS (CORS) | `POST /triggerVideoAIFeatures` | `GEMINI_API_KEY`, `ASSEMBLYAI_KEY` | On-demand regeneration of chapters, summaries, or dubbing from creator studio |

---

### 2. Video Resolution & Transcoding
Handles multi-bitrate delivery (1080p, 720p, 480p, 360p) for adaptive streaming.

| Function Name | Trigger Type | Purpose |
| :--- | :--- | :--- |
| `onVideoUploadedForResolution` | Storage Trigger | Triggers resolution profiles generation |
| `handleResolution` | Cloud Task Worker | Encodes video slices into standard HLS resolution profiles |
| `getVideoResolutionStatus` | Callable `onCall` | Informs creator studio of video encoding progress percentage |
| `reconcileStuckResolutionJobsScheduled` | Pub/Sub Cron (`0 */2 * * *`) | Recovers jobs interrupted by transient container shutdowns |

---

### 3. Publish Gate & Fan-Out
Ensures videos are only visible to the public after passing all safety checks.

| Function Name | Trigger Type | Purpose |
| :--- | :--- | :--- |
| `onVideoPublished` | Firestore `onDocumentUpdated` | When `status` changes to `"published"`, fans out updates to channel subscribers, marks dirty sitemaps, and syncs search index |
| `scheduledVideoPublisher` | Pub/Sub Cron (`* * * * *`) | Checks `/videos` where `publishAt <= now()` and flips status to `"published"` |
| `shardSync` | Firestore Trigger | Updates distributed counter shards for creator channel video totals |

---

### 4. Payments, Subscriptions & Creator Economy (Cashfree)
Manages the complete financial lifecycle: subscriptions, tips, ad payouts, and fraud prevention.

| Function Name | Trigger Type | Purpose |
| :--- | :--- | :--- |
| `createCashfreeOrder` | Callable `onCall` | Creates a Cashfree checkout session order for Pro subscriptions or tips |
| `verifyCashfreePayment` | Callable `onCall` | Verifies Cashfree payment token against the Cashfree PG API |
| `verifyCashfreeSubscription`| Callable `onCall` | Validates recurring subscription mandate status |
| `cancelCashfreeSubscription`| Callable `onCall` | Terminates active recurring subscription |
| `cashfreeWebhook` | HTTPS `onRequest` | Verifies Cashfree signature header and fulfills successful transactions asynchronously |
| `onPayoutRequestCreated` | Firestore `onCreate` | Validates creator balance, checks KYC status, and queues bank disbursement |
| `detectRevenueAnomalies` | Cron / Trigger | Flags suspicious surges in clicks, watchtime, or repeated micro-payments |
| `distributePremiumRevenue`| Pub/Sub Cron (Monthly) | Distributes pooled Pro subscription fees to creators based on watchtime minutes |

---

### 5. Watchtime, Live Viewers & Analytics
Handles real-time streaming telemetry and view counting at high scale without database contention.

| Function Name | Trigger Type | Purpose |
| :--- | :--- | :--- |
| `trackWatchEvent` | Callable `onCall` | Batches heartbeat watch events (every 10s of playback) and credits monetizable watch seconds |
| `onActiveViewerWrite` | RTDB `onWrite` | Increments/decrements concurrent viewer counter for active livestreams in RTDB |
| `cleanupStaleSessions` | Pub/Sub Cron (`*/5 * * * *`) | Purges abandoned viewer heartbeats older than 60 seconds |
| `aggregateVideoImpressions`| Cloud Task | Increments impression counters using distributed shards |
| `rollupVideoCounterShards` | Pub/Sub Cron (`*/15 * * * *`)| Rolls up sharded view/impression documents into the master `/videos/{id}` document |

---

### 6. Search, SEO & Edge Feed Server
Powers global discoverability, social sharing, and search engine ranking.

| Function Name | Trigger Type | Purpose |
| :--- | :--- | :--- |
| `seoServer` | HTTPS `onRequest` | Express server that intercepts web crawlers (WhatsApp, Twitter/X, Googlebot) and returns pre-rendered Open Graph tags and JSON-LD schema |
| `searchTruthWorld` | Callable `onCall` | In-house hybrid search combining full-text indexing and semantic vector embeddings |
| `aiSearchAssistant` | Callable `onCall` | Conversational search agent answering user questions grounded in video transcripts |
| `publicFeedServer` | HTTPS `onRequest` | High-speed edge API serving public cached video feeds to unauthenticated viewers |
| `rebuildDirtySitemapsScheduler`| Pub/Sub Cron (`0 2 * * *`) | Re-generates XML sitemaps and triggers IndexNow API notifications to search engines |

---

### 7. Moderation, Safety & Community
| Function Name | Trigger Type | Purpose |
| :--- | :--- | :--- |
| `onContentUploadedForModeration` | Storage / Firestore | Runs frame-by-frame and audio moderation for NSFW/hate speech |
| `ingestUploadedImage` | Storage Trigger | Evaluates thumbnails and avatars through tiered moderation queues (High, Medium, Low) |
| `addCommentNested` | Callable `onCall` | Creates threaded comments with automated spam filtering |
| `onCommentCreated` | Firestore `onCreate` | Sends push notifications to the creator and parent commenter |
| `purgeUserAccount` | Callable (Admin) | Executes GDPR / DPDP compliant hard deletion of user data |

---

### 8. Admin Telemetry, Unit Economics & Infrastructure Governance
Provides real-time visibility into cloud infrastructure expenses, channel-level unit economics, and platform profitability margins.

| Function Name | Trigger Type | Purpose |
| :--- | :--- | :--- |
| `getUnitEconomicsDashboard` | Callable `onCall` | Authenticated admin endpoint calculating real-time gross revenue, provider cost rollups (Gemini AI, CDN egress, STT, TTS, compute), contribution margins, and break-even CPM |
| `getUnitEconomicsReport` | HTTPS `onRequest` | External BI REST endpoint secured with `requireRecentAdmin` returning comprehensive monthly unit economics reports |
| `getChannelSpendingsAndRevenue` | Callable `onCall` | Super Admin endpoint aggregating revenue, infrastructure spend breakdown, and wallet transactions for a specific channel |
| `monthlyZeroWasteRollover` | Pub/Sub Cron (`0 0 1 * *`) | Automatically runs on the 1st of every month to compute exact unspent Pro plan budgets (`planBudget - currentSpent`) and rolls over 100% of unused balance into creator wallet credits |
