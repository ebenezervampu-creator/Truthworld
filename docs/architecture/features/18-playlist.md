# Feature 18: Playlist

## Overview
The **Playlist** feature manages the creation, modification, and playback of curated video collections. It handles both user-generated custom playlists and system-generated smart playlists (like 'Watch Later').

## Frontend (UI/UX)
- **Location**: `lib/features/playlist/presentation/views/playlist/`
- **Pages**:
  - `playlist_screen.dart`: A grid or list overview of all playlists owned or saved by the user.
  - `playlist_detail_screen.dart`: The deep-dive view into a specific playlist, showing the ordered list of videos, total duration metadata, and bulk action buttons (e.g., 'Play All', 'Shuffle').
  - `show_diaglog.dart` / `playlist_loader_screen.dart`: UI components for handling the "Save to Playlist" bottom sheet workflow when a user interacts with a video card.

## Backend & State Management
- **Controllers**:
  - `PlaylistController`: Manages the high-level retrieval and caching of the user's playlist library.
  - `PlaylistDetailController`: Manages the specific state of a single opened playlist, allowing users to reorder videos, remove items, or edit the playlist's privacy settings.
  - `PlaylistDialogController`: Handles the transient state of the "Add to Playlist" dialog, allowing users to quickly create a new playlist inline or toggle video presence across multiple lists simultaneously.
- **Data Flow**: Connects to the Firestore `playlists` collection, maintaining arrays of video document references to avoid massive data duplication.
