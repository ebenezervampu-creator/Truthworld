# Feature 8: Discover

## Overview
The **Discover** feature provides users with an exploratory interface to find new channels and trending creators within the TruthWorld ecosystem.

## Frontend (UI/UX)
- **Location**: `lib/features/discover/presentation/views/`
- **Pages**:
  - `discover_channels.dart`: A specialized layout focused entirely on surfacing creator channels rather than individual video content. Features horizontal scrolling lists and grid views of channel avatars and bios.

## Backend & State Management
- **State Management**:
  - Currently, this feature acts as a presentation layer. The actual discovery logic, search queries, and channel retrieval are likely handled by a shared global `SearchController` or `MainController`.
