# Cloud Function: revenue.ts

**Location:** `functions/src/economy/revenue.ts`

## 📖 What it does & How it works
💰 CALCULATE REVENUE SHARE
 Internal utility to compute creator's cut based on channel type and buyout status.

### 🏦 Revenue Models
The platform supports two distinct channel types, each with its own revenue model:

**1. Standard Channel (YouTube-style Model)**
- **Ads Revenue:** 75% to Creator, 25% to Platform
- **Memberships:** 100% to Creator
- **Infrastructure:** Fully managed, no out-of-pocket costs

**2. Custom Channel (Maximum Revenue)**
- **Ads Revenue:** 100% to Creator, 0% Platform Fee
- **Memberships:** 75% to Creator, 25% Platform Fee
- **Subscription Buyout:** If a Custom channel purchases the Subscription Buyout, they keep 100% of Membership revenue.
- **Infrastructure Costs:** Creator pays for infrastructure used (storage, transcoding, streaming)

## ⚙️ Exports / Primary Functions
- **calculateShare**
- **getCreatorRevenue**
- **generateMonthlyStatement**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `firebase-functions/v2`
- 🔄 **Internal Dependency**: `./types`
- 🔄 **Internal Dependency**: `../pipeline/types`
