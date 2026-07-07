# Feature 26: Watch History

## Overview
The **Watch History** feature maintains a chronological log of every video the user has viewed. It allows users to resume partially watched videos across devices and powers the algorithmic recommendation engine.

## Frontend (UI/UX)
- **Location**: `lib/features/watchhistory/presentation/views/watchhistory/`
- **Pages**:
  - `watchhistory.dart`: A specialized list view capable of grouping videos by date (e.g., "Today", "Yesterday"). Includes controls to pause watch history tracking or clear the entire history log.

## Backend & State Management
- **Controller**: `WatchHistoryController`
- **Location**: `lib/features/watchhistory/presentation/controllers/watch_history_controller.dart`
- **Data Flow**:
  - Connects to the user's `history` sub-collection.
  - Often utilizes a specialized `watch_session.dart` model (from the Video feature) to record the exact playback timestamp where the user dropped off, ensuring seamless cross-device resume functionality.
