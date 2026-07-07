# Feature 25: Video

## Overview
The **Video** feature is the most complex and critical module in TruthWorld. It encompasses the entire playback engine, the content upload pipeline, comment threads, AI-driven fact-checking, credibility scoring, and adaptive bitrate streaming.

## Frontend (UI/UX)
- **Location**: `lib/features/video/presentation/`
- **Pages**:
  - `video_screen.dart`: The core playback view containing the video player, interactive buttons, description, and metadata.
  - `upload_screen.dart` & `create_content_screen.dart`: The multi-step ingestion flow for creators.
  - `download_page.dart`: Interface for offline playback management.
- **Widgets**:
  - **Playback**: `full_screen_helper.dart`, `sliver_tab_bar_delegate.dart`.
  - **Comments & Interaction**: `comment_card_widget.dart`, `reply_widget.dart`, `premium_comment_input.dart`.
  - **Trust & Safety**: `credibility_label_widget.dart`, `fact_check_report_widget.dart`, `truth_index_badge.dart`.
  - **AI & Processing**: `job_status_widget.dart`, `pipeline_configuration_widget.dart`.

## Backend & State Management
- **Controllers** (Highly Specialized):
  - `VideoController`: The central orchestrator binding the video UI to the player.
  - `CommentsController` & `ReplyInputController`: Manage infinite scrolling and nested replies.
  - `AdaptiveBirateController`: Monitors network conditions to dynamically shift stream quality.
  - `PipelineController`: Tracks the server-side processing state (transcoding, AI fact-checking) of newly uploaded content.
  - `UploadController`: Handles chunked uploading of massive video files to Firebase Storage.
- **Data & Domain Layer**:
  - **Location**: `lib/features/video/data/`
  - **Models**: Massive array of complex schemas including `video.dart`, `transcript.dart`, `credibility_report.dart`, `watch_session.dart`, `pipeline_status.dart`.
  - **Services**: `comment_service.dart`, `pipeline_service.dart`.
  - **Domain Logic**: Heavily integrates with cloud functions. Features like `ai_features.dart` and `content_verification.dart` rely on backend pub/sub pipelines to process audio, generate subtitles, and verify factual accuracy before publishing.
