# Architecture Flow: Payments & Creator Economy (Cashfree)

TruthWorld integrates with **Cashfree Payment Gateway** for subscription billing (Pro tier), creator tipping/superchats, and automated creator earnings payouts.

---

## 1. Cashfree Checkout & Webhook Lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor User as User / Subscriber
    participant Client as Flutter Client
    participant CF_Order as Cloud Function (createCashfreeOrder)
    participant Cashfree as Cashfree API
    participant DB as Cloud Firestore
    participant CF_Hook as Cloud Function (cashfreeWebhook)
    participant CF_Verify as Cloud Function (verifyCashfreePayment)

    User->>Client: Chooses Pro Subscription Plan (or Superchat)
    Client->>CF_Order: onCall: createCashfreeOrder({ planId, amount, customerPhone })
    
    CF_Order->>CF_Order: Verify Auth Token
    CF_Order->>Cashfree: POST /pg/orders (Creates order with order_id, order_expiry)
    Cashfree-->>CF_Order: Returns { payment_session_id, order_token }
    CF_Order->>DB: Saves /orders/{orderId} (status: "PENDING", userId)
    CF_Order-->>Client: Returns payment_session_id
    
    Client->>Cashfree: Opens Cashfree Drop-in Checkout / Seamless UPI
    User->>Cashfree: Enters UPI PIN / Card Details
    Cashfree-->>User: Payment Processed
    
    alt Asynchronous Webhook (Primary Channel)
        Cashfree->>CF_Hook: POST /cashfreeWebhook (PAYMENT_SUCCESS_WEBHOOK)
        CF_Hook->>CF_Hook: Verifies x-webhook-signature using CASHFREE_WEBHOOK_SECRET
        CF_Hook->>DB: Check if /processed_events/{orderId} exists (Idempotency)
        CF_Hook->>DB: Update /orders/{orderId} (status: "PAID", paymentId)
        CF_Hook->>DB: Update /users/{userId} custom claims & subscription doc
        CF_Hook-->>Cashfree: Returns HTTP 200 OK
    else Client Immediate Verification (Fallback Channel)
        Client->>CF_Verify: onCall: verifyCashfreePayment({ orderId })
        CF_Verify->>Cashfree: GET /pg/orders/{orderId}
        CF_Verify->>DB: Confirm status, grant Pro features
        CF_Verify-->>Client: Returns { status: "SUCCESS" }
    end

    DB-->>Client: Realtime Firestore snapshot listener updates UI
    Client->>User: Displays "Welcome to Pro!" confirmation badge
```

---

## 2. Creator Payouts & Monetization Flow

Creators earn money through two streams:
1. **Ad Revenue Share**: Distributed according to verified video impressions and view duration.
2. **Pro Subscription Pool**: Distributed monthly via `distributePremiumRevenue` based on minutes watched by Pro subscribers.

```mermaid
sequenceDiagram
    autonumber
    actor Creator as Creator (Studio)
    participant Client as Flutter Client
    participant DB as Cloud Firestore
    participant CF_Payout as Cloud Function (onPayoutRequestCreated)
    participant Fraud as Fraud Engine (detectRevenueAnomalies)
    participant CashfreePayout as Cashfree Payouts API

    Creator->>Client: Enters Bank Account & Submits Payout Request in /wallet
    Client->>DB: Writes /payout_requests/{payoutId}
    
    DB->>CF_Payout: Fires onPayoutRequestCreated trigger
    CF_Payout->>Fraud: Check creator trust score, inspect view fraud flags
    
    alt Suspicious Activity Detected
        CF_Payout->>DB: Mark payout as "UNDER_REVIEW", notify admin
    else Legitimate Payout
        CF_Payout->>DB: Verify /kyc_documents/{creatorId} status == "VERIFIED"
        CF_Payout->>CashfreePayout: POST /payout/transfers (Initiates bank transfer / IMPS)
        CashfreePayout-->>CF_Payout: Transfer Queued
        CF_Payout->>DB: Deduct creator wallet balance in /wallets/{creatorId}
        CF_Payout->>DB: Update payout status to "COMPLETED"
        CF_Payout-->>Creator: Dispatches payment receipt email
    end
```
