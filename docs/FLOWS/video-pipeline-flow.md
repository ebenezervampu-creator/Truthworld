# Architecture Flow: Video Processing & Credibility Pipeline

TruthWorld features an automated multi-stage pipeline for video ingestion, AI transcription, claim fact-checking, speaker trust analysis, multi-language dubbing, and gated publishing.

---

## 1. End-to-End Pipeline Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Creator as Creator (Studio)
    participant Client as Flutter Client
    participant GCS as Cloud Storage
    participant CF_Upload as onVideoUpload
    participant PubSub as Cloud Pub/Sub
    participant CF_Trans as handleTranscription
    participant CF_Cred as handleCredibility
    participant CF_Dub as handleDubbing
    participant CF_Copy as handleCopyrightCheck
    participant DB as Cloud Firestore
    participant CF_Pub as onVideoPublished

    Creator->>Client: Selects Video File & Submits Upload
    Client->>GCS: Uploads raw video to uploads/raw_videos/{id}.mp4 via resumable upload
    GCS->>CF_Upload: Fires onObjectFinalized trigger
    
    CF_Upload->>DB: Create /videos/{id} (status: "processing", progress: 10%)
    CF_Upload->>PubSub: Fan out jobs to transcription-jobs, copyright-jobs, resolution-jobs
    
    par Parallel Execution
        PubSub->>CF_Copy: Worker processes copyright-jobs
        CF_Copy->>DB: Check audio fingerprint, update /videos/{id}/copyrightCheck
    and
        PubSub->>CF_Trans: Worker processes transcription-jobs
        CF_Trans->>CF_Trans: Calls AssemblyAI / Gemini API
        CF_Trans->>GCS: Writes VTT subtitles for Telugu, Hindi, English
        CF_Trans->>PubSub: Dispatches credibility-jobs & dubbing-jobs
        
        par Post-Transcription Steps
            PubSub->>CF_Cred: Worker processes credibility-jobs
            CF_Cred->>CF_Cred: scoringEngine: Extract claims, match against Tier 0 truth database
            CF_Cred->>CF_Cred: speakerTrustEngine: Calculate speaker credibility score
            CF_Cred->>DB: Writes /videos/{id}/credibility (score: 87, claims: [...])
        and
            PubSub->>CF_Dub: Worker processes dubbing-jobs
            CF_Dub->>CF_Dub: Synthesizes dubbed audio tracks (Telugu, Hindi) via TTS
            CF_Dub->>GCS: Saves dubbed audio streams
            CF_Dub->>DB: Updates /videos/{id}/dubbingStatus
        end
    end

    Note over DB, CF_Pub: Publish Gating Condition
    Creator->>Client: Clicks "Publish Now" in Creator Studio
    Client->>DB: Sets /videos/{id} status to "published"
    DB->>CF_Pub: Fires onVideoPublished (onDocumentUpdated)
    
    CF_Pub->>DB: Increment Channel video counter shard
    CF_Pub->>PubSub: Queue subscriber push notifications
    CF_Pub->>DB: Mark dirty sitemaps for search engine indexing
    Client-->>Creator: Video is now live on the public feed!
```

---

## 2. Pipeline State Transitions & Fail-Safe Mechanics

Every video document in Firestore moves through defined state machines:

```mermaid
stateDiagram-v2
    [*] --> Uploading: Client begins upload
    Uploading --> Processing: GCS finalize trigger
    
    state Processing {
        [*] --> Transcribing
        Transcribing --> CredibilityAnalysis
        Transcribing --> DubbingGeneration
        CredibilityAnalysis --> Complete
        DubbingGeneration --> Complete
    }
    
    Processing --> ReadyToPublish: All required tasks pass
    Processing --> ProcessingError: Transient failure (retries 3x)
    ProcessingError --> Processing: Retry successful
    ProcessingError --> ReviewRequired: Permanent failure / Flagged content
    
    ReadyToPublish --> Scheduled: If publishAt > now()
    Scheduled --> Published: scheduledVideoPublisher executes
    ReadyToPublish --> Published: Creator publishes immediately
    
    Published --> Archived: Creator archives video
    Published --> Deleted: Creator soft-deletes to /trash
```

---

## 3. Idempotency & Error Recovery

1. **At-Least-Once Delivery**: Because Cloud Pub/Sub guarantees at-least-once delivery, every pipeline worker checks `idempotency-engine.ts` before starting expensive AI inference.
2. **Reconciliation Cron**: If an encoding or transcription job halts mid-flight (e.g. timeout), the scheduled cron `reconcileStuckResolutionJobsScheduled` detects any video stuck in `"processing"` for more than 45 minutes and safely requeues the task.
