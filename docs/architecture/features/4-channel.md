# Feature 4: Channel

## Overview
The **Channel** feature manages the entire lifecycle of a user's channel on TruthWorld. This ranges from the initial creation wizard and monetization plan selection (Standard vs Custom) to the intricate management of channel details like subscribing, video aggregation, and avatar uploading.

## Frontend (UI/UX)
- **Location**: `lib/features/channel/presentation/views/channel/`
- **Pages**:
  - `channel_plan_selection_screen.dart`: The mandatory premium gateway where users choose between YouTube-style revenue models or full control. Uses complex GetX reactive layout selection.
  - `channel_screen_wizard.dart`: A multi-step form to collect channel metadata, banners, and profile images.
  - `channel_details_screen.dart`: The public-facing profile of a channel displaying its latest videos and metrics.
  - `channelloader_screen.dart`: A bridging screen used to ensure all critical channel documents are loaded into memory securely before rendering components.

## Backend & State Management
- **Controller**: `ChannelControllerUnified`
- **Location**: `lib/features/channel/presentation/controllers/channel_controller_unified.dart`
- **State Management (GetX)**:
  - This monolithic controller integrates multiple domain concerns previously fragmented.
  - Utilizes `ContentValidationMixin` to enforce safety and community standards on user input before database commits.
  - Handles multi-step form validation, image uploading via `ImageVerificationService`, and real-time subscription status toggles (`isSubscribed`).
- **Data Persistence**: Heavy utilization of Firebase Firestore for document management, utilizing atomic `TransactionResult` patterns to ensure data consistency during channel creation.
