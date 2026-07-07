# Feature 21: Settings

## Overview
The **Settings** feature manages the global user preferences, account security, billing management, and application-level configurations (like theme toggles and notification preferences).

## Architecture
- **Location**: `lib/features/settings/`
- **Role**: Provides the interface for users to update their profile, manage linked authentication providers (Google, Email), and adjust privacy toggles.
- **State Management**: Typically binds to an `AuthController` or `UserController` to push changes directly to the authenticated user's root Firestore document. Preferences like Dark/Light mode are routed to a local `SharedPreferences` cache for instant offline application on subsequent boots.
