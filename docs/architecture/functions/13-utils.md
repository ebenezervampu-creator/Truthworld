# Cloud Function 13: Utils

## Overview
The **Utils** module provides pure, side-effect-free helper functions and wrappers utilized by the more complex event-driven modules.

## Backend Architecture
- **Location**: `functions/src/utils/`
- **Role**: Houses robust error logging wrappers, standardized API response formatters, and mathematical utilities.
- **Contents**:
  - **Time Formatting**: Standardized ISO parsers.
  - **Retry Logic**: Exponential backoff wrappers for interacting with flaky third-party APIs (like external transcoders).
  - **Admin Initializers**: The core `firebase-admin` initialization logic shared across all functions.
