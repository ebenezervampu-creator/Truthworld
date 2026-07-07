# Cloud Function 2: Channels

## Overview
The **Channels** module handles the server-side logic associated with creator channels. It ensures data consistency across the platform when a channel's metadata is updated.

## Backend Architecture
- **Location**: `functions/src/channels/`
- **Triggers**:
  - `onWrite` or `onUpdate` triggers attached to the `channels/{channelId}` Firestore collection.
- **Data Flow & Logic**:
  - **Data Denormalization**: If a creator changes their channel avatar or name, these functions fan out the updates to all associated `videos`, `comments`, and `community_posts` documents to ensure the frontend doesn't need to perform expensive join queries.
  - **Subscriber Aggregation**: Reacts to updates in the `subscriptions` collections to safely increment or decrement the global `subscriberCount` on the main channel document using Firestore Transactions.
