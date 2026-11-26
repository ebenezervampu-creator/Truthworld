# 🏛️ TruthWorld Cloud Functions — Architecture Blueprint

> Technical architecture, data pipelines, security models, and lifecycle execution flows for TruthWorld backend services.

---

## 1. High-Level System Architecture

```mermaid
flowchart TD
    Client["TruthWorld Flutter App / Web / Admin Portal"]
    
    subgraph EdgeLayer ["Edge & Ingress (asia-south1)"]
        CDN["Google Cloud CDN / SWR Cache"]
        Gate["API Gateway / Security Headers"]
    end
    
    subgraph CloudFunctions ["Firebase Cloud Functions (2nd Gen)"]
        CallableHandlers["Callable APIs (createCallableHandler)"]
        PubSubWorkers["Event-Driven Workers & PubSub"]
        Schedulers["Cloud Scheduler Cron Tasks"]
        Pipeline["10-Layer Video Pipeline"]
    end

    subgraph StorageAndDB ["Data & Storage Layer"]
        Firestore["Cloud Firestore (Real-time DB & Distributed Shards)"]
        GCS["Cloud Storage (Media, Transcripts, Dubbed Audio)"]
        BigQuery["BigQuery (Analytics & Unit Economics)"]
        Typesense["Typesense (Factual Search & Vector Engine)"]
    end

    subgraph ExternalAPIs ["Authoritative External APIs"]
        Gemini["Google Gemini 3.8 Flash (Credibility & AI)"]
        GoogleTranslate["Google Cloud Translation v3"]
        ElevenLabs["ElevenLabs v4 Turbo (Voice Synthesis)"]
        AssemblyAI["AssemblyAI (Transcription & Diarization)"]
        Cashfree["Cashfree Payment Gateway (INR)"]
    end

    Client --> Gate
    Gate --> CDN
    Gate --> CallableHandlers
    
    CallableHandlers --> Firestore
    CallableHandlers --> Cashfree
    
    GCS -. Video Upload .-> Pipeline
    Pipeline --> AssemblyAI
    Pipeline --> Gemini
    Pipeline --> GoogleTranslate
    Pipeline --> ElevenLabs
    Pipeline --> Firestore
    Pipeline --> Typesense
    
    Schedulers --> PubSubWorkers
    PubSubWorkers --> Firestore
    PubSubWorkers --> BigQuery
```

---

## 2. 10-Layer Video Processing Pipeline

Every video published to TruthWorld progresses through a strictly monitored multi-stage pipeline:

```mermaid
sequenceDiagram
    autonumber
    actor Creator as Creator Channel
    participant Ingress as 01-Edge / Ingress
    participant Validation as 02-Input / FFprobe
    participant PubSub as 04-Distribution (Pub/Sub)
    participant Transcription as 05-AssemblyAI Transcription
    participant Credibility as 06-Gemini Credibility & Fact Check
    participant Dubbing as 07-Translation & ElevenLabs Dubbing
    participant Aggregation as 09-Muxing & Chapter Generation
    participant Gate as Publish Gate (shardSync)

    Creator->>Ingress: Upload video file (.mp4/.mov)
    Ingress->>Validation: Inspect codecs, resolution, UUID integrity
    Validation->>PubSub: Fan out processing job
    
    par Parallel Analysis
        PubSub->>Transcription: Extract audio & transcribe multilingual diarization
        Transcription-->>Credibility: Pass normalized transcript & timestamps
        Credibility->>Credibility: Verify claims against Vertex AI Grounding
    and Parallel Dubbing
        Transcription-->>Dubbing: Translate to regional languages (hi, te, ta, etc.)
        Dubbing->>Dubbing: Synthesize natural voice with ElevenLabs v4 Turbo
    end
    
    Credibility->>Aggregation: Deliver verified factual scores & citations
    Dubbing->>Aggregation: Deliver synced audio stems & burned subtitles
    Aggregation->>Gate: Master video bundle packaged
    Gate->>Gate: Verify quality gates (resolution ≤ 1040p, safety pass, credibility pass)
    Gate-->>Creator: Video live on TruthWorld!
```

---

## 3. Security, Authorization & Collection Guards

```mermaid
flowchart LR
    Request["Incoming Request"] --> AuthCheck{"Has Bearer Token?"}
    AuthCheck -- No --> Reject401["401 Unauthorized"]
    AuthCheck -- Yes --> TokenVerify["Verify Firebase ID Token"]
    TokenVerify --> ClaimsCheck{"Admin / Director?"}
    
    ClaimsCheck -- Yes --> GrantSuperAdmin["Grant Admin Access + Role Audit"]
    ClaimsCheck -- No --> MemberDocCheck{"admin_members Collection Doc?"}
    MemberDocCheck -- Active Role --> GrantSuperAdmin
    MemberDocCheck -- None / Suspended --> StandardUser["Grant Standard User Context"]
    
    StandardUser --> CollectionGuard{"Targeting 'videos' collection?"}
    GrantSuperAdmin --> CollectionGuard
    
    CollectionGuard -- Yes --> UUIDGuard{"assertVideoId(id) Is Valid UUID v4?"}
    CollectionGuard -- No --> Write["Execute Firestore Write"]
    
    UUIDGuard -- Valid --> Write
    UUIDGuard -- Invalid / 'job_' --> GuardReject["Reject: Only UUIDs allowed in videos"]
```

---

## 4. Creator Economy & Financial Settlements

All monetization adheres strictly to the **Zero Charm-Pricing Policy** using clean round numbers:

1. **Cashfree Payments**:
   - Webhook signatures validated cryptographically using HMAC-SHA256.
   - Idempotency enforced via Firestore transaction L1/L2 lock before wallet updates.
2. **Channel Wallet**:
   - Micro-transactions tracked in immutable audit logs.
   - Automated monthly disbursal scheduler with anomaly detection.
3. **Ad Revenue Splits**:
   - View fraud detection checks for unnatural pulses or automated bot clusters.
   - Legitimate view impressions distributed proportionally to creator channels.
