# Cloud Function 1: Benchmark

## Overview
The **Benchmark** module contains cloud functions designed for internal performance testing and load simulation. It is typically used by administrators or automated CI/CD pipelines to ensure the TruthWorld backend can handle massive concurrent loads.

## Backend Architecture
- **Location**: `functions/src/benchmark/`
- **Triggers**: Mostly HTTP endpoints (HTTPS Callable) protected by admin authentication or internal VPC rules.
- **Data Flow**:
  - Functions here may artificially inject thousands of dummy `watch_session` or `interaction` documents into temporary Firestore collections to stress-test database indices.
  - Used to evaluate the cold-start times of more complex functions (like the video `pipeline` module).
- **Dependencies**: Relies heavily on the `shared` or `utils` directories to safely partition test data away from production data.
