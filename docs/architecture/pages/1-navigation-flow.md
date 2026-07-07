# Master Navigation Flow

## Overview
TruthWorld utilizes a hybrid routing architecture powered by **GetX routing (`Get.toNamed`)** combined with deeply nested `IndexedStack` navigators. This allows for persistent media playback (Miniplayer) while users traverse through different primary tabs.

## Primary Hierarchies

### 1. Main Application Shell
The outer-most layout wrapped by the `MainController`.
- **Bottom Navigation (Mobile) / NavigationRail (Desktop)**:
  - **Home** -> Routes to `lib/features/home/presentation/views/home/home.dart`
  - **Discover** -> Routes to `lib/features/discover/presentation/views/discover_channels.dart`
  - **Upload** -> Opens a Bottom Sheet routing to `create_content_screen.dart` (Video feature)
  - **Subscriptions** -> Routes to `subscriptions.dart`
  - **Library** -> Routes to `library_screen.dart`

### 2. The Video Playback Flow
Tapping any `VideoGridCard` or `VideoListCard` intercepts the route:
- Validates the current state.
- Executes `Get.toNamed("/watch?v={id}")`.
- If the user swipes back, the route pops, but the `MiniplayerOverlayManager` intercepts the video stream and seamlessly minimizes it into the corner, maintaining the audio context.

### 3. The Dashboard (Creator Studio) Flow
A completely separate visual shell accessed via the user's profile icon.
- Routes to `/dashboard` (`dashboard_wrapper.dart`).
- Contains its own internal router managing `content_screen`, `analytics_screen`, `monetization_screen`, and `studio_settings_page`. This separation ensures the massive dashboard controllers are completely flushed from memory when the user returns to the primary viewing app.
