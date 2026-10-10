# Architecture Flow: Watchtime, Live Viewers & High-Concurrency Analytics

TruthWorld handles high-frequency events (watchtime ticks, view counting, live viewer presence, and impressions) without running into Firestore document contention bottlenecks.

---

## 1. Real-Time Watchtime & Video View Counting Flow

```mermaid
sequenceDiagram
    autonumber
    actor Viewer as Video Viewer
    participant Player as Flutter Video Player
    participant CF_Watch as Cloud Function (trackWatchEvent)
    participant RTDB as Firebase Realtime Database
    participant Shards as Firestore Counter Shards
    participant CF_Rollup as Cloud Function (rollupVideoCounterShards)
    participant MasterDoc as Firestore (/videos/{id})

    Viewer->>Player: Plays Video
    
    loop Every 10 Seconds of Playback
        Player->>RTDB: Updates presence heartbeat /live_viewers/{videoId}/{sessionId}
        Player->>CF_Watch: onCall: trackWatchEvent({ videoId, elapsedSeconds: 10, currentPosition })
        CF_Watch->>CF_Watch: Detect view fraud (throttle bots, check play speed)
        
        alt First 30s threshold reached (Qualified View)
            CF_Watch->>Shards: Increment random shard /videos/{id}/shards/{random_0_to_19}
        end
        CF_Watch->>Shards: Increment watch_seconds shard
    end

    Note over Shards, MasterDoc: Periodic Rollup Cron (Every 15 minutes)
    CF_Rollup->>Shards: Reads sum of all 20 counter shards
    CF_Rollup->>MasterDoc: Atomically updates master viewCount & totalWatchSeconds
    CF_Rollup->>Shards: Resets ephemeral shard counters
```

---

## 2. Live Stream Viewers & Chat Architecture

* **High-Throughput Presence**: Realtime Database (RTDB) handles concurrent live viewer counts. When a client connects, Firebase RTDB `.info/connected` attaches an `onDisconnect()` handler:
  ```json
  /live_sessions/{videoId}/{userId}: {
    "active": true,
    "joinedAt": 1718000000000
  }
  ```
* **Disconnect Automation**: When a viewer closes their browser or app, Firebase RTDB automatically removes the session key server-side.
* **Aggregated Count**: The `onActiveViewerWrite` trigger calculates the active count and updates `/live_streams/{videoId}/viewerCount` for display on the player UI.
