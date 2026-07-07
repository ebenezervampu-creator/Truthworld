# Core Widgets

## Overview
The `lib/core/widgets/` directory acts as TruthWorld's shared design system. These components are used uniformly across all feature modules to ensure a consistent visual identity and to avoid code duplication.

## Key Widgets

### Video Cards
- **`VideoListCard`**: A highly interactive, horizontal layout typically used in Search Results, Liked Videos, and the Library. Implements `ObxValue` for high-performance hover states.
- **`VideoGridCard`**: A vertical, stacked layout used in the Home feed and Channel profiles. Optimizes image loading via `CachedNetworkImage` and Hero animations for smooth transitions to the `video_screen`.

### Media Optimization
- **`OptimizedThumbnail`**: A smart image wrapper that dynamically requests different resolution bounds from the Firebase CDN based on the `BuildContext` size constraints, dramatically reducing bandwidth usage.

### Interaction Elements
- **Stat Chips**: Reusable pills (`_buildStatChip`) for displaying views, likes, and dates using standard `AppColors.brand`.
- **Primary/Secondary Buttons**: Standardized action buttons integrating GetX state loaders (displaying a `CircularProgressIndicator` inside the button when `isLoading` is true).

## GetX Reactivity Rules
Core widgets are strictly built as `StatelessWidget` classes. Interactive elements like hovering or focusing are managed inline using `ObxValue<RxBool>` rather than converting the component to a heavy `StatefulWidget`.
