# Cloud Function 9: Search

## Overview
The **Search** module is responsible for indexing content into highly efficient search models, ensuring the frontend `SearchController` can perform rapid fuzzy matching.

## Backend Architecture
- **Location**: `functions/src/search/`
- **Triggers**:
  - `onWrite` triggers on `videos` and `channels` collections.
- **Data Flow & Logic**:
  - **Tokenization**: When a video is published or its metadata updated, this function extracts the title, description, and tags. It breaks these down into search tokens (n-grams or keyword arrays) and writes them to a dedicated `search_index` collection.
  - **External Sync**: In highly scaled environments, this function acts as the bridge that synchronizes Firestore data into advanced external search engines like Algolia, ElasticSearch, or Typesense.
