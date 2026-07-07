# Feature 13: Library

## Overview
The **Library** feature is the user's personal content hub. It aggregates their watch history, saved playlists, liked videos, and downloaded content into a single accessible dashboard.

## Frontend (UI/UX)
- **Location**: `lib/features/library/presentation/views/library/`
- **Pages**:
  - `library_screen.dart`: The master layout displaying horizontal scrolling carousels for 'Recent History', list views for 'Playlists', and quick-access buttons for 'Liked Videos' and 'Watch Later'.

## Backend & State Management
- **Controller**: `LibraryController`
- **Location**: `lib/features/library/presentation/controllers/library_controller.dart`
- **Logic**:
  - Acts as an orchestrator, fetching limited preview datasets from multiple different backend collections (e.g., pulling the last 10 documents from the `history` collection, the last 5 from `playlists`).
  - Manages the local caching of these lists so the Library tab opens instantly when navigated to via the bottom navigation bar.
