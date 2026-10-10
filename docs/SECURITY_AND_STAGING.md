# TruthWorld — Security, Access Control & Staging Environment Guide

This guide establishes the engineering protocols for onboarding developers, sandboxing access, segregating cloud environments, managing secrets, and enforcing quality gates.

---

## 1. Developer Access & Sandboxing Protocol (Principle of Least Privilege)

When hiring contractors or full-time developers, adhere to the **Zero-Trust Access Principle**:

```mermaid
graph TD
    Dev[New Developer]
    
    subgraph Day 1 to Month 1: Sandboxed
        Git[Git Repository Access<br/>(Feature Branches Only)]
        Emulators[Local Firebase Emulators<br/>(Offline / Zero Cloud Access)]
        DevStaging[Staging Cloud Project<br/>(truthworld-staging / Sandbox)]
    end
    
    subgraph Restricted: Tech Lead & Founder Only
        ProdGCP[Production Google Cloud<br/>(truthworld-1)]
        ProdDB[Production Firestore & RTDB]
        LiveKeys[Production Secrets: Cashfree Live, Gemini Live]
    end

    Dev --> Git
    Dev --> Emulators
    Dev -.-> DevStaging
    
    Dev -.x|Access Blocked| ProdGCP
    Dev -.x|Access Blocked| ProdDB
    Dev -.x|Access Blocked| LiveKeys
```

### Access Rules:
1. **Never grant `Owner` or `Editor` roles on production GCP**:
   * Developers should only receive `Developer` access on a dedicated staging project (`truthworld-staging`).
2. **Branch Protection on `main`**:
   * Direct pushes to `main` are disabled.
   * Pull Requests require approval and passing CI status checks before merging.
3. **Local Emulators First**:
   * All feature development and bug fixes must be verified on the local **Firebase Emulator Suite** (`firebase emulators:start`) before deployment.

---

## 2. Segregated Environments: Staging vs. Production

TruthWorld maintains two isolated Firebase & GCP projects:

| Parameter | Staging (`truthworld-staging`) | Production (`truthworld-1`) |
| :--- | :--- | :--- |
| **Purpose** | PR integration, QA testing, load benchmarks | Public live streaming platform |
| **Database** | Dummy seeded videos & test channels | Real users, paid creator channels |
| **Payment Gateway** | Cashfree Sandbox (`TEST` app ID & secret) | Cashfree Production (`PROD` credentials) |
| **AI Inference** | Free-tier / rate-limited Gemini & AssemblyAI keys | Production quota tier |
| **Cloud Functions** | `maxInstances: 10`, `minInstances: 0` | Scaled to production caps |
| **Deploy Trigger** | Automatic deploy on PR merge to `develop` | Manual tagged release tag (`vX.Y.Z`) to `main` |

---

## 3. Secret Management & Rotation Playbook

* **Local Development (`.env.local`)**:
  * Developers must populate their own local `.env.local` using `.env.example`.
  * The file `.env.local` is strictly excluded in `.gitignore`.
* **Cloud Functions Secrets**:
  * Secrets are stored in **Google Cloud Secret Manager** and accessed via:
    ```typescript
    import { defineSecret } from "firebase-functions/params";
    const cashfreeKey = defineSecret("CASHFREE_SECRET_KEY");
    ```
  * Never store raw API keys in `functions.yaml` or code repositories.
* **Automated Secret Scanning**:
  * Our CI pipeline executes automated **Gitleaks** scans on every commit to block accidental pushes of private keys, tokens, or credentials.

---

## 4. Video Player Telemetry & Quality of Service (QoS)

To ensure smooth video playback without buffering spikes:
* Client-side playback QoS is tracked via [`PlayerTelemetryService`](file:///c:/company/truthworld/lib/core/services/player_telemetry_service.dart).
* Tracks:
  * **Time to First Frame (TTFF)**
  * **Stall count & buffer duration (ms)**
  * **Adaptive resolution switching velocity**
  * **Fatal decode errors**
* If buffering exceeds 2,500ms on a stable network, an alert is surfaced to the observability pipeline.

---

## 5. Automated CI/CD Quality Gates

Every Pull Request must pass the following gates before merging:
1. **Dart Analyzer**: `dart analyze lib/routes lib/core` (Zero warnings/errors).
2. **Flutter Tests**: `flutter test --coverage` (Coverage must meet or exceed baseline threshold).
3. **Cloud Functions Compiler**: `npm run build` (Clean TypeScript compilation without `@ts-ignore` flags).
4. **Secret Scanner**: Zero uncommitted credentials detected by Gitleaks.
