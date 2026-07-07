# Feature 11: Home

## Overview
The **Home** feature serves as the central entry point and main feed of the TruthWorld web application. It is responsible for orchestrating the primary layout, managing global navigation bindings, and displaying the initial algorithm-driven video feed.

## Frontend (UI/UX)
- **Location**: `lib/features/home/presentation/views/home/`
- **Pages**:
  - `home.dart`: The core layout scaffold. This page typically manages the `BottomNavigationBar` (for mobile) or the persistent sidebar (for desktop) and acts as the parent view for the core video feed.
- **Navigation Flow**:
  - Implements dynamic routing and indexed stack layouts to preserve the state of different tabs (e.g., Home, Shorts, Subscriptions, Library) without forcing full reloads.

## Backend & State Management
- **Controllers**:
  - `HomeController`: Manages the specific state of the home video feed, including pagination, refreshing logic, and tracking the currently active category filters on the home page.
  - `MainController`: A global controller managing the overall app shell, handling tab switching logic, and maintaining the user's global session states across tabs.
- **Bindings**:
  - `main_presentation_binding.dart` & `home_binding.dart`: Ensures that the `MainController` and `HomeController` are instantiated immediately upon app launch and securely retained in memory.
