# Feature 20: Search

## Overview
The **Search** feature is a highly advanced, heavily optimized module within TruthWorld. It relies on a combination of fast client-side caching, debounced algorithmic queries, and specialized Firestore indices to deliver real-time autocomplete and deep content discovery.

## Frontend (UI/UX)
- **Location**: `lib/features/search/presentation/`
- **Pages**: `search_page.dart` (The primary search results engine).
- **Widgets**:
  - `search_bar_widget.dart`: Provides real-time typing feedback and clears.
  - `recent_searches_list.dart` & `trending_searches_view.dart`: Pre-search exploration surfaces.
  - `advanced_filter_sheet.dart` & `search_filter_chips.dart`: Allow users to narrow queries by date, duration, or credibility scores.
  - `search_result_skeleton.dart`: Provides smooth shimmer loading states to reduce perceived latency.

## Backend & State Management
- **Controller**: `SearchController`
- **State Pattern**: Implements a highly robust state machine utilizing `search_state.dart` enums (Idle, Loading, Success, Empty, Error) to prevent UI tearing during rapid successive queries.
- **Data & Domain Layer**:
  - **Models**: `search_result.dart`, `search_cache.dart`.
  - **Services**: `firestore_search_service.dart`, `search_analytics_service.dart`, `search_service.dart`.
  - **Optimization**: Implements strict local caching to minimize Firestore document reads. Searches are debounced, and duplicate identical queries immediately return cached `SearchResult` objects.
  - **Cloud Integration**: Documented heavily within internal Markdown files (`CLOUDFUNCTIONS.md`, `FIRESTORE_SETUP.md`), search often ties into dedicated Cloud Functions that tokenize video titles and descriptions for complex fuzzy matching.
