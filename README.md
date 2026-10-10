# Truthworld

A video-sharing platform built with Flutter, Firebase, and Cloud Functions — focused on credibility scoring, multi-language content, and transparent media.

---

## 📚 Developer Onboarding & Architecture Hub

To help any incoming developer immediately understand every page, Cloud Function, feature, and flow in the codebase:

| Guide | Description |
| :--- | :--- |
| 🚀 [**Developer Onboarding Runbook**](file:///c:/company/truthworld/docs/ONBOARDING.md) | "Day 1 to First PR": Flutter setup, flavors, Firebase emulators, and PR checklist |
| 🏗️ [**System Architecture & C4 Model**](file:///c:/company/truthworld/docs/ARCHITECTURE.md) | Multi-flavor design, C4 container diagram, tech stack, and key ADRs |
| 🖥️ [**Frontend Pages & Screen Catalog**](file:///c:/company/truthworld/docs/ROUTES.md) | Complete 80+ route map, GetX bindings, controllers, and access guards |
| ⚡ [**Cloud Functions & API Catalog**](file:///c:/company/truthworld/docs/FUNCTIONS.md) | Pipeline workers, Cashfree payments, watchtime rollup, SEO SSR, and AI search |
| 🎬 [**Video Processing & Credibility Flow**](file:///c:/company/truthworld/docs/FLOWS/video-pipeline-flow.md) | Sequence diagram of raw upload $\rightarrow$ transcription $\rightarrow$ fact-check $\rightarrow$ dubbing |
| 💳 [**Payments & Creator Economy Flow**](file:///c:/company/truthworld/docs/FLOWS/payments-and-economy-flow.md) | Cashfree checkout, webhook verification, and creator payouts |
| ⏱️ [**Watchtime & Live Viewers Flow**](file:///c:/company/truthworld/docs/FLOWS/watchtime-and-analytics-flow.md) | Heartbeat watch events, RTDB live viewers, and counter sharding |
| 🗄️ [**Database & Security Models**](file:///c:/company/truthworld/docs/DATABASE.md) | Firestore collections, RTDB schemas, GCS buckets, and security rules |
| 🔒 [**Security & Staging Environment Guide**](file:///c:/company/truthworld/docs/SECURITY_AND_STAGING.md) | Developer sandboxing, least privilege access, secret rotation, and CI gates |

---

## Architecture

```
lib/
├── core/           # Shared infrastructure
│   ├── base/       # BaseController, BaseRepository
│   ├── bindings/   # GetX dependency injection
│   ├── mixins/     # Content validation, scroll behavior
│   ├── network/    # Result<T>, AppException
│   ├── services/   # Logger, auth, connectivity, SEO
│   └── utils/      # Helpers, formatters, URL strategy
├── data/
│   └── models/     # Shared data models (Channel, etc.)
├── domain/
│   ├── entities/   # Pure domain entities (no framework deps)
│   └── repositories/ # Repository interfaces
├── features/       # Feature modules (GetX pattern)
│   ├── video/      # Video player, upload, processing
│   ├── home/       # Home feed, sidebar navigation
│   ├── channel/    # Channel management
│   ├── community/  # Community posts, interactions
│   ├── comments/   # Comment system
│   ├── playlist/   # Playlist management
│   ├── trending/   # Trending videos
│   ├── notifications/ # Push & in-app notifications
│   ├── admin/      # Admin dashboard
│   ├── analytics/  # Video analytics, impressions
│   ├── settings/   # User settings
│   └── ...
├── routes/         # App routing (GetX pages)
├── shared/         # Shared widgets
└── theme/          # AppTheme, AppColors, dark/light mode
```

Each feature follows the pattern:
```
feature/
├── data/
│   ├── models/      # Firestore data models (fromMap/toMap)
│   └── services/    # Data access services
├── presentation/
│   ├── controllers/ # GetX controllers (extends BaseController)
│   ├── views/       # Screen widgets
│   └── widgets/     # Reusable feature-specific widgets
└── bindings/        # GetX bindings for DI
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.x (Web, Android, iOS) |
| **State Management** | GetX |
| **Backend** | Firebase (Auth, Firestore, RTDB, Storage, Functions) |
| **Cloud Functions** | Node.js 24, TypeScript, Firebase Functions v2 |
| **CI/CD** | GitHub Actions |
| **Monitoring** | Firebase Crashlytics, Firebase Performance |
| **Video Streaming** | HLS/DASH adaptive streaming |

## Getting Started

### Prerequisites

- Flutter SDK 3.x (`flutter --version`)
- Node.js 24+ (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project configured

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd truthworld

# Install Flutter dependencies
flutter pub get

# Install Cloud Functions dependencies
cd functions && npm install && cd ..

# Run the app
flutter run -d chrome        # Web
flutter run -d <device_id>   # Mobile
```

### Firebase Emulator (for local development)

```bash
firebase emulators:start
```

Emulates: Auth, Firestore, RTDB, Storage, Functions.

## Development

### Code Generation

After modifying `freezed` or `json_serializable` models:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Linting

```bash
flutter analyze        # Static analysis
dart format lib/ test/  # Code formatting
```

### Testing

```bash
flutter test                      # All tests
flutter test --coverage           # With coverage
flutter test test/features/video  # Feature-specific
```

### Cloud Functions

```bash
cd functions
npm run build          # Compile TypeScript
npm test               # Run tests
npm run lint           # ESLint
```

## Deployment

### Flutter Web
```bash
flutter build web --release
firebase deploy --only hosting
```

### Security Rules (MUST validate with emulator first!)
```bash
firebase emulators:start
# Test rules in emulator
firebase deploy --only database,storage,firestore:rules
```

### Cloud Functions
```bash
cd functions && npm run build
firebase deploy --only functions
```

## Key Design Decisions

1. **GetX over Riverpod**: Existing codebase uses GetX extensively; migration cost outweighs benefits.
2. **Clean Architecture (pragmatic)**: Use cases only for complex workflows (upload pipeline, credibility scoring). Simple CRUD goes directly from controller to repository.
3. **Firebase-first**: Firestore as primary database, RTDB for real-time features (active viewers, live stats), Storage for media.
4. **Multi-language content**: AI-powered dubbing and subtitle generation via Cloud Functions pipeline.
5. **Credibility scoring**: Trust index computed server-side for each video using fact-checking pipeline.

## Security

- All Firebase rules enforce ownership validation
- Storage writes require `uploaderId` metadata
- Community engagement updates enforce ±1 increment/decrement
- Server-only writes for aggregate counters (videoList, commentCounts)
- Firebase App Check (reCAPTCHA Enterprise + Play Integrity + Device Check)

## License

Proprietary. All rights reserved.
