# ⚡ TruthWorld k6 & Performance Testing Suite

This directory contains the production-grade **k6 Load & Stress Testing Suite** for TruthWorld, defining scenarios, SLA budgets, and **P95 / P99 latency thresholds**.

---

## 🎯 SLA Latency Budgets & Percentile Targets

| Scenario | Path / Endpoint | Target P95 | Target P99 | Max Error Rate |
| :--- | :--- | :--- | :--- | :--- |
| **Edge Public Feed CDN** | `/publicFeedServer` | **< 150 ms** | **< 300 ms** | < 0.5% |
| **Dynamic SEO Server** | `/seoServer/*` | **< 120 ms** | **< 250 ms** | < 0.5% |
| **In-House Search** | `/searchTruthWorld` | **< 350 ms** | **< 700 ms** | < 2.0% |
| **Watchtime Heartbeat** | `/trackWatchEvent` | **< 100 ms** | **< 250 ms** | < 0.5% |
| **Community Comments** | `/addCommentNested` | **< 200 ms** | **< 400 ms** | < 1.0% |
| **E2E User Journey** | Complete flow | **< 1500 ms** | **< 3000 ms** | < 1.0% |

---

## 🚀 Running with Official k6 CLI

If you have `k6` installed ([k6 Installation Guide](https://k6.io/docs/get-started/installation/)):

```bash
# 1. Run individual scenario against local emulator:
k6 run tests/k6/scenarios/public_feed_load_test.js

# 2. Run against staging or production:
k6 run -e BASE_URL=https://asia-south1-truthworld-1.cloudfunctions.net tests/k6/scenarios/public_feed_load_test.js

# 3. Run E2E User Journey load test:
k6 run tests/k6/scenarios/end_to_end_user_journey.js
```

---

## ⚡ Running Standalone via Node.js

No k6 binary required! Run directly using Node.js:

```bash
node tests/k6/runner.js
```

Or via functions scripts:
```bash
cd functions
npm run test:p95-p99
```
