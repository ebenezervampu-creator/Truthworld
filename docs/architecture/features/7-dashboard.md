# Feature 7: Dashboard (Creator Studio)

## Overview
The **Dashboard** is arguably the most extensive feature within the TruthWorld architecture, acting as the primary Creator Studio. It provides comprehensive tools for managing videos, engaging with audiences, configuring studio settings, managing monetization, and overseeing multilingual dubbing/subtitles.

## Frontend (UI/UX)
- **Location**: `lib/features/dashboard/presentation/views/`
- **Pages / Views**:
  - `dashboard_screen.dart`: The core hub displaying high-level creator metrics.
  - **Video Management**: `content_screen.dart`, `edit_videoscreen.dart`, `drafts_screen.dart`, `video_management.dart`.
  - **Engagement**: `dashboard_comments_page.dart`, `audience_page.dart`, `live_subscribers_screen.dart`.
  - **Localization**: `audio_tracks_page.dart` (for dubs), `subtitles_page.dart`.
  - **Monetization & Copyright**: `monetization_screen.dart`, `copyright_screen.dart`.
  - **Configuration**: `studio_settings_page.dart`, `customization_screen.dart`, `chapters_page.dart`.
- **UX Strategy**: Utilizes a highly modular `dashboard_wrapper.dart` to provide a persistent sidebar/navigation pane while sub-screens load reactively.

## Backend & State Management
- **Controllers**:
  - The dashboard relies on tightly scoped GetX controllers rather than a monolithic state.
  - `StudioSettingsController`: Manages creator configurations.
  - `AudioTracksController` & `SubtitlesController`: Manage the file picking, validation, and upload progression for alternative language dubs and VTT/SRT subtitles.
  - `DashboardCommentsController`: Handles bulk actions for comments (filtering, replying, holding for review).
  - `AudienceController` & `ReportsController`: Manages audience demographics and report generation.
- **Data Architecture**:
  - Connects securely to Firebase Storage for accepting user-uploaded assets (like dubbed audio).
  - Connects to Firestore to update nested arrays within the `videos` collection.
