# Feature 22: Subscriptions

## Overview
The **Subscriptions** feature serves the chronological feed of content strictly from channels the authenticated user has explicitly subscribed to, bypassing the standard algorithmic recommendation engine.

## Frontend (UI/UX)
- **Location**: `lib/features/subscriptions/presentation/views/Subscriptions/`
- **Pages**:
  - `subscriptions.dart`: The root layout.
  - `subscriptions_content.dart`: The feed renderer. Usually features a top horizontal carousel of active channels (with blue dots indicating unwatched new uploads) followed by a reverse-chronological vertical list of videos.

## Backend & State Management
- **Controller**: `SubscriptionController`
- **Data Flow**:
  - Queries the user's `subscriptions` array or sub-collection.
  - Performs complex `whereIn` queries against the `videos` collection to fetch recent uploads from the subscribed channel IDs.
  - Highly reliant on pagination and indexing to ensure the feed loads efficiently even if a user is subscribed to hundreds of active creators.
