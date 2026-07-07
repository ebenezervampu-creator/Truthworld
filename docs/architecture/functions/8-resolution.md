# Cloud Function 8: Resolution

## Overview
The **Resolution** module acts as an administrative arbitration system. It handles user reports, copyright claims, and community guideline strikes.

## Backend Architecture
- **Location**: `functions/src/resolution/`
- **Triggers**:
  - `onCreate` triggers on the `reports` or `claims` collections.
- **Data Flow & Logic**:
  - **Automated Triage**: When a user reports a video, this function evaluates the severity based on the reporter's trust score and the total volume of reports.
  - **Strike System**: If a copyright claim is validated by an admin (or a highly trusted automated system), this function automatically issues a 'strike' to the offending `channel` document, potentially limiting their upload capabilities or monetized status.
  - **Content Takedown**: Can automatically switch a video's status to `REMOVED` if reports cross a critical threshold.
