# Cloud Function: channels.ts

**Location:** `functions/src/channels/channels.ts`

## 📖 What it does & How it works
🚀 CREATE CHANNEL (Callable)
 Atomic creation of a channel with the new economic model.
 **Note:** Creating a channel strictly requires specifying the channel `type` as either `standard` or `custom`.

### 🖥️ UI & Client Implementation
- **Plan Selection Screen:** Users must choose their creator path (`standard` or `custom`) at `lib/features/channel/presentation/views/channel/channel_plan_selection_screen.dart` before entering the channel creation flow.
- **Direct Creation Flow:** When a channel is created from the UI via `ChannelController.createChannel()` (located in `channel_controller_unified.dart`), it writes both `planType` (for legacy/UI compatibility) and `type` (for backend compatibility) to Firestore.
- **Economic Integration:** The client-side direct creation initializes crucial fields required by the economy calculations:
  - `type` and `planType` (Standard vs. Custom)
  - `outstandingCosts` (starts at 0)
  - `hasPaidSubscriptionBuyout` (starts as false)
  - `settings` mapping with default `adsRevenueShare` and `memberRevenueShare` values tailored to standard (75% / 100%) or custom (100% / 75%) plans.

## ⚙️ Exports / Primary Functions
- **createChannel**
- **switchChannelType**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `firebase-functions/v2`
- 🔄 **Internal Dependency**: `../pipeline/types`
