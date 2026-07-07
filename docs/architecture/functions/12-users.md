# Cloud Function 12: Users

## Overview
The **Users** module handles identity lifecycle events, synchronizing Firebase Authentication states with the Firestore `users` collection.

## Backend Architecture
- **Location**: `functions/src/users/`
- **Triggers**:
  - Firebase Authentication triggers (`onCreate`, `onDelete`).
- **Data Flow & Logic**:
  - **Onboarding Pipeline**: When a user registers via the app (Google or Email), the `onCreate` trigger automatically provisions a new document in the `users` collection, injecting default preferences, an empty `watch_history` sub-collection, and establishing their initial `trust_score`.
  - **GDPR Deletion**: When a user deletes their account, the `onDelete` trigger executes a massive cascading delete, recursively wiping their channel, videos, comments, and personal data from all Firestore collections and Storage buckets to comply with data privacy laws.
