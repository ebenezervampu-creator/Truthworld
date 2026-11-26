# TruthWorld — Claude Code Configuration & Project Guide

TruthWorld is an enterprise video streaming and AI platform focused on:
- **AI-Powered Fact-Checking & Credibility Analysis** (10-layer pipeline)
- **Multilingual Content Dubbing & Localization** (Telugu, Hindi, English, etc.)
- **Creator Economy & Monetization** (Cashfree UPI/card, revenue sharing)
- **High-Performance Video Feeds & Search** (Flutter Web/Mobile, Typesense, HLS)

---

## 🛠️ Key Commands & Workflows

### Cloud Functions Backend (`functions/`)
```bash
cd functions
npm run build              # Compile TypeScript & generate function manifest
npm run test               # Run all backend unit & integration tests
npm run test:pipeline      # Test 10-layer video & credibility pipeline
npm run test:dubbing       # Test translation, ElevenLabs v4, and dubbing gates
npm run serve              # Run local Firebase emulator
```

### Flutter Frontend (`lib/`)
```bash
flutter analyze            # Run Dart static analyzer
flutter test               # Run all Flutter tests
flutter test test/core/ui_contrast_guard_test.dart  # Mandatory UI contrast verification
flutter build web          # Build web release
```

---

## 🛡️ Mandatory TruthWorld Engineering Rules (NON-NEGOTIABLE)

1. **Zero `setState` Policy (GetX Only)**:
   - **NEVER** use `setState()` anywhere in Flutter views or widgets.
   - All screens must be `StatelessWidget`, `GetView<T>`, or `GetWidget<T>`.
   - Wrap only micro-widgets that mutate inside `Obx(() => ...)`.
   - All mutable state, flags, and logic belong exclusively inside `GetxController`.

2. **Zero Mock Data Policy**:
   - **NEVER** introduce dummy records, mock arrays, simulated endpoints, or fake IDs (`acct_mock_`, `po_mock_`).
   - All code must integrate with real Firestore collections, authentic Cloud Functions, and authoritative APIs.

3. **Zero Raw Developer Error Policy**:
   - **NEVER** leak raw technical errors (`$e`, `e.toString()`, `[cloud_firestore/...]`, `SocketException`) to end users.
   - UI notifications must use friendly, polite, actionable standard English via `AppSnackbar` / `AppToast`.
   - Never use aggressive toast titles like `"Error"` or `"Validation Error"`.

4. **Zero White-on-White Contrast Policy (WCAG AA Compliant)**:
   - White / brand surfaces (`AppColors.brand`, `Colors.white`) **MUST** use black foreground (`Colors.black` or `Colors.black87` for icons, text, and loading spinners).
   - Always run `flutter test test/core/ui_contrast_guard_test.dart` to verify contrast.

5. **Zero Charm-Pricing Policy**:
   - TruthWorld stands for absolute truth and transparency.
   - **NEVER** use marketing gimmick numbers ($9, $9.99, $14.99, $29.99, $99, 9999).
   - Use clean, transparent round numbers only ($10, $15, $20, $25, $30, $50, $100).

6. **Preserve Working Architecture**:
   - Never rewrite working systems unnecessarily.
   - Inspect existing architecture before modifying code.
   - Preserve backward compatibility.
   - Prefer small, testable changes.

7. **Zero Unmeasured Claims Policy**:
   - **NEVER** state an accuracy, success rate, quality score, speed, cost or "production" figure unless it comes from a real measurement you can name (test run, log, report file, dataset).
   - Cite the source with every figure, e.g. "5 of 10 speakers correct (local-dub-output/.../report.json)".
   - If nothing has been measured, say **"not measured"** and describe how to measure it. Never estimate a percentage from how the code is designed.
   - Unit tests show the logic does what it was written to do. They are **not** accuracy evidence. Report which tests ran and how many, never "100% accurate".
   - Never say "in production", "deployed" or "verified" unless that actually happened in this session or a cited record shows it.
   - If you wrote or changed the code, say so. Your own work is not independent verification.

---

## 📁 Architecture Overview

- **Flutter Client (`lib/`)**:
  - `lib/core`: Shared themes, bindings, network clients, contrast guards.
  - `lib/features`: GetX controllers, views, data providers.
  - Entry points: `main.dart` (Consumer), `main_studio.dart` (Creator Studio), `main_admin.dart` (Admin), `main_advertiser.dart` (Advertiser).

- **Cloud Functions (`functions/src/`)**:
  - `pipeline/`: 10-layer video processing & credibility pipeline.
    - `01-edge.ts` to `04-distribution.ts`: Upload ingress, probe, GCS archive, PubSub fan-out.
    - `05-transcription.ts`: Speech recognition with AssemblyAI & diarization.
    - `06-credibility.ts` & `claimVerification.ts`: Gemini on Vertex AI with Google Search Grounding.
    - `07-dubbing.ts`: Google Cloud Translation LLM + ElevenLabs v4 Turbo voice cloning.
    - `09-aggregation.ts`: FFmpeg muxing, subtitle burning, master packager.
  - `shared/`: Structured logging (`logger.ts`), error sanitizer (`errors.ts`), `callableHandler.ts`.
  - `economy/`: Cashfree payments, creator revenue splits, wallet.
