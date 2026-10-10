# TruthWorld Developer Onboarding Runbook: "Day 1 to First PR"

Welcome to the **TruthWorld** engineering team! This guide walks you through setting up your local development environment so you can run the client applications, execute Cloud Functions emulators, and submit your first Pull Request on **Day 1**.

---

## 1. Prerequisites Checklist

Before you start, verify you have the required tool versions installed:
* **Flutter SDK**: `3.22.x+` (`flutter --version`)
* **Dart SDK**: Bundled with Flutter (`dart --version`)
* **Node.js**: `v24.x LTS` (`node -v`)
* **Firebase CLI**: `firebase-tools@latest` (`npm install -g firebase-tools`)
* **Java Runtime**: JDK 17+ (Required for Firebase Local Emulators)
* **Chrome**: Required for Flutter Web development and debugging

---

## 2. Repository Setup

```bash
# Clone the repository
git clone <GIT_REPO_URL>
cd truthworld

# Fetch Flutter dependencies
flutter pub get

# Install Cloud Functions backend dependencies
cd functions
npm install
npm run build
cd ..
```

---

## 3. Running Flutter Client Portals (Flavors)

TruthWorld has 4 application entrypoints. You can run any of them on Flutter Web, Android, or iOS:

### 1. Consumer Video Streaming App (Default)
```bash
flutter run -d chrome -t lib/main.dart
```

### 2. Creator Studio App (`/studio`)
```bash
flutter run -d chrome -t lib/main_studio.dart
```

### 3. TruthWorld Admin Portal (`/admin`)
```bash
flutter run -d chrome -t lib/main_admin.dart
```

### 4. Advertiser Portal (`/advertiser`)
```bash
flutter run -d chrome -t lib/main_advertiser.dart
```

---

## 4. Running Backend Cloud Functions & Firebase Emulators

You can develop and test backend triggers completely locally without deploying to Google Cloud:

```bash
# Start the full Firebase Emulator Suite
firebase emulators:start
```

This starts:
* **Authentication**: `http://localhost:9099`
* **Firestore**: `http://localhost:8080`
* **Realtime Database**: `http://localhost:9000`
* **Cloud Storage**: `http://localhost:9199`
* **Cloud Functions**: `http://localhost:5001`
* **Emulator UI Dashboard**: [http://localhost:4000](http://localhost:4000) *(Use this to inspect database records, trigger auth users, and view logs!)*

---

## 5. Running Tests & Quality Checks

Always run quality checks locally before submitting code:

```bash
# 1. Run Flutter static analysis
flutter analyze

# 2. Run Flutter unit & widget tests
flutter test

# 3. Run Cloud Functions tests & linting
cd functions
npm run lint
npm test
cd ..
```

---

## 6. Git Branching & Pull Request (PR) Checklist

We use the standard feature branch workflow:
* `feat/feature-name` $\rightarrow$ New features
* `fix/bug-description` $\rightarrow$ Bug fixes
* `docs/update-spec` $\rightarrow$ Documentation enhancements

### Pull Request Checklist:
- [ ] `flutter analyze` passes with zero errors or warnings.
- [ ] Cloud Functions compile cleanly (`npm run build`).
- [ ] If you created a new screen or route, it is documented in [`docs/ROUTES.md`](./ROUTES.md).
- [ ] If you created or modified a Cloud Function, it is documented in [`docs/FUNCTIONS.md`](./FUNCTIONS.md).
- [ ] No API keys, secret credentials, or `.env` files are included in the commit.
