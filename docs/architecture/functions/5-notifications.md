# Cloud Function 5: Notifications

## Overview
The **Notifications** module acts as the routing engine for real-time alerts. It connects internal platform events (like a new video being published) to the actual push notification delivery systems.

## Backend Architecture
- **Location**: `functions/src/notifications/`
- **Triggers**:
  - `onCreate` triggers across various collections (`videos`, `comments`, `community_posts`).
- **Data Flow & Logic**:
  - **Fan-out Architecture**: When a new video is published, this function queries the `subscriptions` collection for that channel. It batches push notification payloads and sends them via Firebase Cloud Messaging (FCM) to all active subscriber device tokens.
  - **In-App Inbox**: Simultaneously writes `user_notification` documents into the respective users' personal notification sub-collections so the alerts appear in their in-app notification center.
