# Cloud Function 15: Watchtime

## Overview
The **Watchtime** module is a high-throughput data processing engine. It ingests thousands of micro-session payloads from users watching videos and aggregates them into meaningful metrics for creators.

## Backend Architecture
- **Location**: `functions/src/watchtime/`
- **Triggers**:
  - `onCreate` triggers on the highly-ephemeral `watch_sessions` collection.
  - Scheduled Cron Jobs (hourly).
- **Data Flow & Logic**:
  - **Real-time Aggregation**: Validates incoming `watch_session` chunks (preventing view-botting by analyzing IPs via the `analytics` services) and atomicly increments the `views` and `totalWatchTime` counters on the parent video document.
  - **Batching**: To prevent Firestore hot-spotting (writing to the same video document thousands of times a second), this module utilizes distributed counters or processes watch sessions in batches every few minutes.
