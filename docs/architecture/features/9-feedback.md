# Feature 9: Feedback

## Overview
The **Feedback** feature is a dedicated module allowing users to report issues, seek help, or provide ratings and suggestions to the TruthWorld development team.

## Frontend (UI/UX)
- **Location**: `lib/features/feedback/presentation/views/`
- **Pages**:
  - `feedbacks.dart`: The primary form for submitting feedback, featuring text inputs, dropdowns for feedback categories, and star-rating selectors.
  - `help.dart`: An interface routing users to FAQ or support documentation.
  - `more_option.dart`: A localized settings or secondary menu interface linked to the support flow.

## Backend & State Management
- **Controller**: `FeedbackController`
- **Location**: `lib/features/feedback/presentation/controllers/feedback_controller.dart`
- **State Management (GetX)**:
  - Extends `BaseController` for robust error handling.
  - Uses `Rx` variables for form state: `feedbackType`, `feedbackText`, `rating`, and `isSubmitting`.
- **Data & Domain Layer**:
  - Connects directly to `FirebaseFirestore.instance` and pushes documents to a dedicated `feedback` collection. No complex intermediate data models are strictly required due to the simple nature of the data schema.
