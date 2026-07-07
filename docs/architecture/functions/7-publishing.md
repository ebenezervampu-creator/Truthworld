# Cloud Function 7: Publishing

## Overview
The **Publishing** module handles the state transitions of content from 'Draft' to 'Public', specifically managing scheduled releases and premier events.

## Backend Architecture
- **Location**: `functions/src/publishing/`
- **Triggers**:
  - Scheduled Pub/Sub triggers (checking every minute or 5 minutes).
  - `onUpdate` triggers on video documents observing the `status` field.
- **Data Flow & Logic**:
  - **Scheduled Sweeper**: A cron job queries the `videos` collection for any document where `status == 'SCHEDULED'` and the `publishDate` is in the past. It then atomicly flips the status to `PUBLIC`.
  - **Handoff**: Upon successfully flipping a video to `PUBLIC`, it seamlessly invokes the `notifications` module to alert subscribers that the scheduled video is now live.
