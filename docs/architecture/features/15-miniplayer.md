# Feature 15: Miniplayer

## Overview
The **Miniplayer** feature provides seamless picture-in-picture (PiP) functionality natively within the TruthWorld app. It allows users to minimize a currently playing video and navigate across other pages (like Home, Search, or Dashboard) without interrupting audio or video playback.

## Frontend (UI/UX)
- **Location**: `lib/features/miniplayer/presentation/widgets/`
- **Components**:
  - `miniplayer_widget.dart`: The actual floating overlay component. It handles drag gestures (swipe down to dismiss, tap to expand) and houses a condensed version of the video player.
  - `miniplayer_overlay_manager.dart`: Acts as the global structural overlay injected above the main app navigator, ensuring the miniplayer renders on top of all other routes.
- **Utils**: `miniplayer_utils.dart` handles dimension calculations based on the screen's safe areas and responsive breakpoints.

## Backend & State Management
- **Controller**: `MiniplayerController`
- **State Management**:
  - Monitors complex state transitions (Expanded vs Minimized vs Hidden).
  - Synchronizes its internal state with the global `TowerPlayerController` to ensure the video source and playback timeline remain perfectly in sync when transitioning between the full video screen and the miniplayer overlay.
- **Data & Domain**:
  - `miniplayer_model.dart` and `miniplayer_service.dart` orchestrate the handoff of `Video` objects and metadata from the main view into the isolated miniplayer state.
