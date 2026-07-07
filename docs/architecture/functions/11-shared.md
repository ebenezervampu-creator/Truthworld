# Cloud Function 11: Shared

## Overview
The **Shared** module is not a standalone trigger module, but rather a central library of reusable models, typed interfaces, and core configurations utilized by all other cloud functions in the TruthWorld backend.

## Backend Architecture
- **Location**: `functions/src/shared/`
- **Role**: Ensures code maintainability and DRY (Don't Repeat Yourself) principles across the heavily decoupled serverless architecture.
- **Contents**:
  - Contains TypeScript interfaces mapping directly to the Dart models found on the frontend (e.g., `IVideo`, `IChannel`, `IUser`).
  - Holds globally shared constants like Firestore collection names (`COLLECTIONS.VIDEOS`, `COLLECTIONS.USERS`) to prevent typos in path routing during database transactions.
