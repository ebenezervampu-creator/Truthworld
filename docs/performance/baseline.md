# Truthworld — Performance Baseline

> Captured BEFORE any refactoring (Phase 4+). Re-measure after each phase to verify no regression.

## Baseline Metrics (Pre-Refactoring)

| Metric | Value | Date | Notes |
|--------|-------|------|-------|
| **Cold startup (web)** | _TODO: measure_ | | Chrome DevTools → First Contentful Paint |
| **Cold startup (Android)** | _TODO: measure_ | | `flutter run --trace-startup` |
| **Memory (idle, 60s)** | _TODO: measure_ | | DevTools Memory tab |
| **Memory (video playback)** | _TODO: measure_ | | During 1080p playback |
| **Frame time (home scroll)** | _TODO: measure_ | | 90th percentile, DevTools Performance |
| **Web bundle size** | _TODO: measure_ | | `flutter build web --release` → `build/web/` total |
| **APK size** | _TODO: measure_ | | `flutter build apk --release` |
| **Firestore reads (home)** | _TODO: measure_ | | Firebase Console on fresh home load |
| **Firestore reads (video)** | _TODO: measure_ | | Firebase Console on single video navigation |

### How to Measure

```bash
# Web bundle size
flutter build web --release
du -sh build/web/

# Android APK size
flutter build apk --release
ls -la build/app/outputs/flutter-apk/app-release.apk

# Android startup trace
flutter run --trace-startup -d <device>

# Firestore reads
# Firebase Console → Usage → monitor read count spike during specific action
```

### Phase Comparison Table

| Phase | Startup (web) | Bundle Size | Memory (idle) | Frame Time (p90) |
|-------|--------------|-------------|---------------|-------------------|
| Baseline | — | — | — | — |
| After Phase 4 | — | — | — | — |
| After Phase 5 | — | — | — | — |
| After Phase 6 | — | — | — | — |
| After Phase 8 | — | — | — | — |
| After Phase 12 | — | — | — | — |
