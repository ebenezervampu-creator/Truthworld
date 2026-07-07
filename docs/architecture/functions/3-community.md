# Cloud Function 3: Community

## Overview
The **Community** module manages the backend logic for non-video creator interactions, including rich-text posts, polls, and quizzes.

## Backend Architecture
- **Location**: `functions/src/community/`
- **Triggers**:
  - `onCreate` triggers on the `community_posts` collection.
  - HTTPS Callable functions for complex voting mechanisms.
- **Data Flow & Logic**:
  - **Poll Aggregation**: When users submit a vote on a poll, a dedicated function safely increments the specific option's tally within a transaction to prevent race conditions during high-volume voting.
  - **Content Moderation**: May interface with the `verification` module to perform asynchronous text analysis on new community posts, automatically flagging or hiding posts containing hate speech or severe violations before manual review.
