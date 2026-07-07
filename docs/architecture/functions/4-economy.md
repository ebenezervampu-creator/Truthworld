# Cloud Function 4: Economy

## Overview
The **Economy** module is a highly secure set of functions managing the financial engine of TruthWorld. It handles ad revenue calculations, subscription splits, and payout processing based on the channel's chosen monetization plan.

## Backend Architecture
- **Location**: `functions/src/economy/`
- **Triggers**:
  - Scheduled Pub/Sub triggers (e.g., daily or monthly cron jobs).
  - Webhooks from third-party payment processors (e.g., Stripe).
- **Data Flow & Logic**:
  - **Revenue Splitting**: Reads a channel's plan (Standard vs Custom). If Standard, calculates the 75/25 split for the creator. If Custom, calculates the infrastructure costs owed by the creator against their 100% ad revenue.
  - **Ledger Generation**: Generates immutable `transaction` documents summarizing daily earnings based on the raw metrics provided by the `watchtime` and `analytics` modules.
