# Cloud Function 14: Verification

## Overview
The **Verification** module is the automated trust & safety shield of TruthWorld. It utilizes Machine Learning and specific rule engines to vet content before or immediately after it goes public.

## Backend Architecture
- **Location**: `functions/src/verification/`
- **Triggers**:
  - `onCreate` / `onUpdate` on `videos`, `community_posts`, and `comments`.
- **Data Flow & Logic**:
  - **AI Image Scanning**: Integrates with Google Cloud Vision API to scan uploaded thumbnails and channel avatars for explicit content, violence, or spoofing. Flags severe violations and immediately reverts the content status to `REMOVED`.
  - **Text Analysis**: Interfaces with Perspective API or Vertex AI to analyze video titles, descriptions, and comments for toxicity.
  - **Credibility Scoring**: Generates the `credibility_report` payload displayed on the frontend, summarizing the factual analysis and safety checks of a video.
