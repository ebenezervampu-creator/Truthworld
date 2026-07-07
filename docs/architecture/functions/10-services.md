# Cloud Function 10: Services

## Overview
The **Services** module houses integrations with third-party APIs and external microservices that aren't natively part of the Firebase ecosystem.

## Backend Architecture
- **Location**: `functions/src/services/`
- **Triggers**:
  - HTTPS Callable endpoints.
- **Data Flow & Logic**:
  - **Third-Party Brokers**: Acts as a secure proxy to interact with services like email providers (SendGrid, Mailgun) for sending creator digests, or external DRM (Digital Rights Management) license servers for protecting premium custom-plan video content.
  - Keeps API keys securely hidden in Google Cloud Secret Manager, preventing the frontend application from exposing sensitive tokens.
