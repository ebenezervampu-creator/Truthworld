# Feature 24: Topics

## Overview
The **Topics** feature provides the high-level horizontal scrolling chip navigation often seen at the top of the Home or Discover feeds. It allows users to rapidly filter the global video feed without diving deep into the Category or Search screens.

## Architecture
- **Location**: `lib/features/topics/`
- **Role**: Maintains a dynamic list of trending topics (e.g., "Gaming", "News", "Podcasts").
- **State Management**: Often binds to the `HomeController` to trigger local feed re-renders when a topic chip is tapped. Topics are usually fetched dynamically from a Firestore `topics` configuration document so the platform administrators can update them without requiring an app store update.
