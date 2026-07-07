# Feature 5: Community

## Overview
The **Community** feature allows creators to engage directly with their audience outside of standard video uploads. It supports rich text posts, multi-image galleries, dynamic polls, and structured quizzes.

## Frontend (UI/UX)
- **Location**: `lib/features/commnuity/` (Note: spelled `commnuity` in the file tree)
- **Pages**:
  - `community_post_upload_screen.dart`: A robust form for selecting 1-10 images and authoring text.
  - `poll_upload_screen.dart`: A dynamic interface for adding/removing 3-5 poll options.
  - `quiz_upload_screen.dart`: Interface for creators to test audience knowledge.

## Backend & State Management
- **Controllers**:
  - `CommunityPostUploadController`: Manages parallel image uploads with per-image progression indicators. Integrates `ContentValidationMixin` and `ImageVerificationService` to automatically flag explicit or harmful imagery prior to Firestore commits.
  - `PollUploadController` & `QuizUploadController`: Manage specialized data structures representing voting systems and correct-answer architectures.
- **Data & Domain Layer**:
  - `data/models/`: Contains the specific data schemas mapping to Firestore documents.
  - `community_post_model.dart`, `poll_model.dart`, `quiz_model.dart`.
  - `community_draft.dart`: Enables users to save local or remote drafts before publishing to the live timeline.
