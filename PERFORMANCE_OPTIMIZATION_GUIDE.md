# Performance Optimization Guide for TruthWorld

## Overview

This guide documents the performance optimizations implemented in the TruthWorld Flutter application. These optimizations focus on:

1. **Image Loading & Caching**
2. **List Virtualization**
3. **Memory Management**
4. **Render Optimization**
5. **Network Efficiency**

---

## 1. Image Optimization

### Problem Identified
- Multiple instances of `NetworkImage` used instead of `CachedNetworkImage`
- No memory cache size limits
- Missing progressive loading patterns
- Redundant image downloads

### Solution Implemented

#### A. New Optimized Widgets

Created `/lib/core/widgets/optimized_network_image.dart`:

```dart
// Use this instead of NetworkImage or basic CachedNetworkImage
OptimizedNetworkImage(
  imageUrl: url,
  width: 200,
  height: 150,
  borderRadius: 8,
)

// For avatars (circular, optimized)
OptimizedAvatar(
  imageUrl: url,
  size: 40,
)

// For video thumbnails (16:9 aspect ratio)
OptimizedThumbnail(
  imageUrl: url,
  width: 320,
)
```

**Benefits:**
- Automatic memory caching with size constraints
- Shimmer placeholder while loading
- Fade-in animation
- Error handling with fallback UI
- Memory-efficient caching (memCacheWidth/memCacheHeight)

#### B. Optimized Playlist List

Created `/lib/components/performance/optimized_feed_view.dart`:

```dart
OptimizedPlaylistList(
  playlists: playlists,
  onTap: (id) => navigateToPlaylist(id),
)
```

**Features:**
- `cacheExtent` for preloading off-screen items
- `addAutomaticKeepAlives` to preserve list item state
- `addRepaintBoundaries` for render optimization
- Cached images with proper sizing

---

## 2. List Performance

### Best Practices Applied

1. **Always use ListView.builder** for dynamic lists
2. **Add cacheExtent** to preload items before they're visible
3. **Use const constructors** for list items when possible
4. **Extract widgets** to separate classes to avoid rebuilds

### Example: Before vs After

**Before:**
```dart
ListView(
  children: videos.map((v) => VideoCard(video: v)).toList(),
)
```

**After:**
```dart
ListView.builder(
  itemCount: videos.length,
  cacheExtent: 500, // Preload 500px ahead
  addAutomaticKeepAlives: true,
  itemBuilder: (context, index) {
    return VideoCard(key: ValueKey(videos[index].id), video: videos[index]);
  },
)
```

---

## 3. State Management Optimization

### Reduce setState Calls

**Problem:** Frequent `setState` calls cause unnecessary rebuilds

**Solution:**
1. Use `GetxController` for reactive state (already in use)
2. Extract widgets that don't need to rebuild
3. Use `const` widgets where possible
4. Implement `shouldRepaint` for CustomPainter

### Hover Effects Without setState

**Before:**
```dart
onEnter: (_) => setState(() => _isHovering = true),
onExit: (_) => setState(() => _isHovering = false),
```

**After:**
```dart
// Use MouseRegion with ValueNotifier or GetX reactive variables
final isHovering = false.obs;
MouseRegion(
  onEnter: (_) => isHovering.value = true,
  onExit: (_) => isHovering.value = false,
  child: Obx(() => AnimatedContainer(...)),
)
```

---

## 4. Memory Management

### Image Cache Configuration

Add to `main.dart` initialization:

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure image cache
  PaintingBinding.instance.imageCache.maximumSize = 2000; // Max 2000 images
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
  
  runApp(MyApp());
}
```

### Dispose Controllers

Ensure all controllers are disposed:

```dart
class MyController extends GetxController {
  final ScrollController scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();
  
  @override
  void onClose() {
    scrollController.dispose();
    textController.dispose();
    super.onClose();
  }
}
```

---

## 5. Network Optimization

### Firestore Query Optimization

1. **Use indexes** for queries with multiple where/orderBy clauses
2. **Implement pagination** using startAfterDocument
3. **Cache results** locally when appropriate
4. **Use snapshots wisely** - detach listeners when not needed

### API Call Batching

Instead of multiple sequential calls:

```dart
// Bad
for (var video in videos) {
  await fetchDetails(video.id);
}

// Good
await Future.wait(videos.map((v) => fetchDetails(v.id)));
```

---

## 6. Render Optimization

### Use RepaintBoundary

Wrap expensive-to-render widgets:

```dart
RepaintBoundary(
  child: ComplexChartWidget(),
)
```

### Avoid Layout Thrashing

Don't nest Expanded/Flexible widgets without proper constraints.

### Use Slivers for Complex Scrolls

For pages with multiple sections:

```dart
CustomScrollView(
  slivers: [
    SliverAppBar(...),
    SliverToBoxAdapter(child: FeaturedSection()),
    SliverList(delegate: SliverChildBuilderDelegate(...)),
  ],
)
```

---

## 7. Deferred Loading

Already implemented for feature modules:

```dart
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart'
    deferred as settings;

// Load when needed
await settings.loadLibrary();
Navigator.push(context, MaterialPageRoute(builder: (_) => settings.SettingsPage()));
```

---

## 8. Performance Monitoring

Use the existing `PerformanceMonitor` service:

```dart
import 'package:truthworld/core/services/performance/performance_monitor.dart';

// Track page loads
PerformanceMonitor.trackPageLoad('home_page');

// Measure operation duration
final duration = await measure(() => expensiveOperation());
PerformanceMonitor.trackApiResponse('videos_api', duration);

// Track Core Web Vitals
PerformanceMonitor.trackFCP(fcpMs);
PerformanceMonitor.trackLCP(lcpMs);
PerformanceMonitor.trackCLS(clsValue);
```

---

## Migration Checklist

### Immediate Actions (High Impact)

- [ ] Replace all `NetworkImage` with `OptimizedNetworkImage` or `CachedNetworkImage`
- [ ] Add `cacheExtent` to all horizontal ListViews
- [ ] Configure image cache limits in `main.dart`
- [ ] Add `key` properties to dynamic list items

### Medium Priority

- [ ] Implement pagination for large lists (>50 items)
- [ ] Add shimmer placeholders to all image loads
- [ ] Extract heavy widgets to separate files
- [ ] Profile app with DevTools and identify jank

### Long-term Improvements

- [ ] Implement service workers for web caching
- [ ] Add lazy loading for below-fold content
- [ ] Optimize bundle size with tree shaking
- [ ] Consider using Isolates for heavy computations

---

## Testing Performance

### Using Flutter DevTools

1. Run app in profile mode: `flutter run --profile`
2. Open DevTools: `flutter pub global activate devtools && flutter pub global run devtools`
3. Monitor:
   - Frame rendering times (aim for <16ms)
   - Memory usage
   - CPU profiler
   - Network tab

### Key Metrics to Track

- **First Contentful Paint (FCP)**: <1.5s
- **Largest Contentful Paint (LCP)**: <2.5s
- **Cumulative Layout Shift (CLS)**: <0.1
- **Time to Interactive (TTI)**: <3.8s
- **Frame drop rate**: <1%

---

## Files Modified/Created

1. `/lib/core/widgets/optimized_network_image.dart` - New optimized image widgets
2. `/lib/components/performance/optimized_feed_view.dart` - Optimized list components
3. `/lib/core/services/performance/performance_monitor.dart` - Existing monitoring
4. `/PERFORMANCE_OPTIMIZATION_GUIDE.md` - This documentation

---

## Additional Resources

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/rendering/performance)
- [Flutter DevTools](https://docs.flutter.dev/tools/devtools)
- [Core Web Vitals](https://web.dev/vitals/)
- [Cached Network Image Package](https://pub.dev/packages/cached_network_image)
