# Feature 17: Notifications

## Overview
The **Notifications** feature powers the real-time alert system within TruthWorld. It aggregates events such as new video uploads from subscribed channels, comment replies, community post interactions, and system alerts into a unified inbox.

## Frontend (UI/UX)
- **Location**: `lib/features/notifications/presentation/views/notifications/`
- **Pages**:
  - `notification.dart`: The central UI rendering a chronological list of notifications. It supports visual indicators for read vs. unread states and implements swipe-to-dismiss functionality.

## Backend & Data Layer
- **Location**: `lib/features/notifications/data/`
- **Models**:
  - `user_notification.dart`: A strongly typed model parsing complex notification payloads (e.g., separating a 'comment_reply' notification from a 'new_video' notification, each carrying different routing metadata).
- **Services**:
  - `user_notification_service.dart`: Integrates directly with Firebase Cloud Messaging (FCM) and a Firestore `notifications` sub-collection. It handles real-time snapshot listeners to update the UI badge count instantaneously without requiring manual pull-to-refresh.
