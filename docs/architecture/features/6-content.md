# Feature 6: Content

## Overview
The **Content** feature acts as the central repository for TruthWorld's static and legal content components, primarily focusing on terms of service and privacy policies.

## Frontend (UI/UX)
- **Location**: `lib/features/content/presentation/views/mvp/privacy-policy/`
- **Pages**:
  - `privacy_polices.dart`: Renders the standardized privacy guidelines and data usage policies.
  - `terms.dart`: Renders the detailed terms of conditions for using the application and platform.
- **Design Pattern**: Consists entirely of stateless UI widgets presenting large blocks of text using standardized typography protocols.

## Backend & State Management
- **State Pattern**: Entirely stateless. Does not rely on complex GetX controllers for data fetching.
- **Data Flow**: Text is statically bundled into the application to ensure it is always available, even offline, guaranteeing legal compliance.
