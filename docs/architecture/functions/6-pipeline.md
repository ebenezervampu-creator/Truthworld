# Cloud Function 6: Pipeline

## Overview
The **Pipeline** module is arguably the most resource-intensive backend service. It orchestrates the asynchronous processing of raw video uploads into platform-ready assets.

## Backend Architecture
- **Location**: `functions/src/pipeline/`
- **Triggers**:
  - Cloud Storage `onFinalize` triggers monitoring the `/raw_uploads` bucket.
- **Data Flow & Logic**:
  - **Transcoding Orchestration**: Detects a new raw video file and securely dispatches it to external transcoders (e.g., Google Cloud Transcoder API or AWS MediaConvert) to generate adaptive bitrate streams (HLS/DASH).
  - **Thumbnail Generation**: Automatically extracts keyframes to generate preview thumbnails if the user hasn't uploaded a custom one.
  - **Status Updates**: Continuously updates the `pipeline_status` sub-collection on the video document so the frontend `JobStatusWidget` can reflect real-time encoding progress to the creator.
