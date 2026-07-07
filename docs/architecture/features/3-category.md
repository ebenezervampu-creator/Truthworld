# Feature 3: Category

## Overview
The **Category** feature provides the browsing and filtering infrastructure for TruthWorld, allowing users to discover content organized by genres and specialized sort criteria.

## Frontend (UI/UX)
- **Location**: `lib/features/category/presentation/views/category/`
- **Pages & Components**:
  - `category_page.dart`: The core visual layout, handling empty states, error states, and grid layouts.
  - `category_tabbar.dart`: Specialized tab navigation for switching between sub-genres.
  - `tandc_for_channel.dart`: Likely terms and conditions specific to category content or channel creation.
- **UX Strategy**:
  - **Custom Dialogs**: Implements specialized `_showFilterDialog` and `_showSortDialog` for advanced content filtering (e.g., sorting by 'Genre' using reactive `FilterChip` components).
  - **Custom Painters**: Utilizes `_CategoryPatternPainter` for drawing dynamic geometric patterns on canvas, creating a premium visual identity for category headers.
  - **Dynamic Styling**: Color schemes react to the selected genre via `_getCategoryColor()`.

## Backend & State Management
- **State Management Pattern**: The UI relies on a controller (referenced as `controller` in the views) to manage `selectedGenre` and `selectedSort` reactive variables.
- **Note**: The dedicated controller file is either shared from a global discover/search module or injected via bindings, as the `category` folder itself acts strictly as a presentation layer.
