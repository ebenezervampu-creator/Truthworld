# TruthWorld Miniplayer - Quick Start Guide

## Installation (Already Done ✅)

The miniplayer is **fully integrated and ready to use**. No additional setup needed!

### What's Already in Place

✅ **main.dart** - Wrapped with `MiniplayerOverlayManager`  
✅ **initial_binding.dart** - `MiniplayerBinding` registered  
✅ **VideoScreen** - `PopScope` callback handles miniplayer  
✅ **All Components** - Controllers, widgets, services, utils ready

---

## Basic Usage

### 1️⃣ Navigate Away with Miniplayer (Recommended)

When user navigates away from video screen (e.g., clicks Home button):

```dart
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';

// In any button/action handler:
onPressed: () async {
  // Get current playback position
  final currentPos = controller.videoPlayerController?.value.position;
  
  // Navigate away with smooth miniplayer transition
  await MiniplayerNavigationHelper.navigateAwayWithMiniplayer(
    video: controller.video,
    currentPosition: currentPos,
    targetRoute: '/home',
  );
}
```

### 2️⃣ Access Miniplayer Controller Directly

```dart
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';

// Get singleton instance
final miniCtrl = MiniplayerController.to;

// Show miniplayer with video
await miniCtrl.showWithVideo(video, resumeFromPosition: Duration.zero);

// Collapse to small bar (bottom-right corner)
miniCtrl.collapse();

// Expand to full screen
miniCtrl.expand();

// Dismiss completely
miniCtrl.dismiss();

// Control playback
miniCtrl.togglePlayPause();
miniCtrl.seekForward(); // +10 seconds
miniCtrl.seekBackward(); // -10 seconds

// Navigate to full video screen
miniCtrl.openFullScreen();
```

### 3️⃣ Use the Service Layer (Best Practice)

```dart
import 'package:truthworld/features/miniplayer/data/services/miniplayer_service.dart';

// Inject the service
final service = Get.find<MiniplayerService>(
  tag: MiniplayerService.serviceName,
);

// Show miniplayer
await service.showWithVideo(
  video,
  resumeFromPosition: Duration(seconds: 30),
);

// Lifecycle hooks
await service.onNavigateAwayFromVideo(
  video: currentVideo,
  currentPosition: playbackPosition,
  shouldShow: true,
);

// Later: dismiss when returning to video screen
service.onReturnToVideoScreen(videoId: video.id);

// Check health
bool isHealthy = service.isHealthy;
if (!isHealthy) {
  await service.recover();
}
```

---

## Real-World Examples

### Example 1: Home Button Navigation

```dart
// In VideoScreen bottom navigation
BottomNavigationBar(
  onTap: (index) {
    if (index == 0) { // Home button
      MiniplayerNavigationHelper.navigateAwayWithMiniplayer(
        video: controller.video,
        currentPosition: controller.videoPlayerController?.value.position,
        targetRoute: '/home',
      );
    }
  },
)
```

### Example 2: Channel Info Click

```dart
// In _buildChannelInfo widget
GestureDetector(
  onTap: () async {
    await MiniplayerNavigationHelper.navigateAwayWithMiniplayer(
      video: controller.video,
      currentPosition: controller.videoPlayerController?.value.position,
      targetRoute: '/channel/${channel.id}',
    );
  },
  child: _buildChannelCard(channel),
)
```

### Example 3: Recommendation Video Click

```dart
// In recommendation feed
RecommendationCard(
  video: recommendedVideo,
  onTap: () async {
    // Show miniplayer for current video before navigating
    await MiniplayerNavigationHelper.navigateAwayWithMiniplayer(
      video: controller.video,
      currentPosition: controller.videoPlayerController?.value.position,
      targetRoute: '/videoscreen',
      arguments: {'video': recommendedVideo},
    );
  },
)
```

### Example 4: Manual Miniplayer Control

```dart
// Show miniplayer
onPressed: () async {
  final miniCtrl = MiniplayerController.to;
  await miniCtrl.showWithVideo(
    video,
    resumeFromPosition: Duration(seconds: 45),
  );
  miniCtrl.collapse();
}

// Expand
onPressed: () => MiniplayerController.to.expand()

// Close
onPressed: () => MiniplayerController.to.dismiss()
```

---

## Reactive UI Updates

Listen to miniplayer state changes in your UI:

```dart
class VideoControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final miniCtrl = MiniplayerController.to;
      
      return Column(
        children: [
          // Show "miniplayer visible" indicator
          if (miniCtrl.isVisible)
            Chip(label: Text('Playing in miniplayer')),
          
          // Play/Pause button
          IconButton(
            icon: Icon(
              miniCtrl.isPlaying.value 
                ? Icons.pause_rounded 
                : Icons.play_arrow_rounded,
            ),
            onPressed: miniCtrl.togglePlayPause,
          ),
          
          // Current position
          Text(
            'Position: ${miniCtrl.currentPosition.value.inSeconds}s',
          ),
        ],
      );
    });
  }
}
```

---

## Error Handling

Miniplayer has built-in error recovery:

```dart
try {
  await MiniplayerNavigationHelper.showMiniplayerWithCurrentVideo(
    video: video,
    currentPosition: Duration(seconds: 30),
  );
} catch (e) {
  // Miniplayer failed, but app continues
  print('Miniplayer error: $e');
  // User can still navigate and play videos normally
}
```

Check health before critical operations:

```dart
final service = Get.find<MiniplayerService>(tag: MiniplayerService.serviceName);

if (!service.isHealthy) {
  await service.recover();
}
```

---

## Configuration

All miniplayer behavior is controlled via `MiniplayerConfig`:

```dart
// In main.dart, you can customize:
MiniplayerOverlayManager(
  config: const MiniplayerConfig(
    enabled: true,                  // Enable/disable entirely
    autoShowOnNavigate: true,       // Auto-show when navigating away
    pauseOnClose: true,             // Pause when dismissing
    enableDrag: true,               // Allow dragging
  ),
  child: GetMaterialApp(/* ... */),
)
```

For advanced configuration, edit static constants in `miniplayer_model.dart`:

```dart
class MiniplayerConfig {
  static const double collapsedHeight = 72.0;           // Bar height
  static const double collapsedWidthFraction = 0.30;    // Bar width (30% of screen)
  static const double minCollapsedWidth = 320.0;        // Min width
  static const double maxCollapsedWidth = 480.0;        // Max width
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Curve animationCurve = Curves.easeOutCubic;
  static const double snapThreshold = 0.3;              // Snap drag threshold
  static const double dismissThreshold = 0.15;          // Dismiss threshold
  static const double borderRadius = 12.0;              // Corner radius
  static const double elevation = 16.0;                 // Shadow elevation
}
```

---

## Performance Tips

### ✅ DO

1. **Use `navigateAwayWithMiniplayer()`** - handles async loading smoothly
2. **Cache video URLs** - don't recreate Video objects unnecessarily
3. **Let service manage lifecycle** - don't manually show/dismiss every frame
4. **Use Obx() for reactive UI** - only rebuilds when state changes

### ❌ DON'T

1. **Don't** create multiple controllers - it's a singleton
2. **Don't** call `dismiss()` unnecessarily - wastes resources
3. **Don't** hold direct controller references in widget state
4. **Don't** update video URL while playing

---

## Troubleshooting

### Miniplayer doesn't appear

1. Check that `MiniplayerBinding` is in `InitialBinding`:
   ```dart
   // core/bindings/initial_binding.dart
   MiniplayerBinding().dependencies(); // ✅ Must be present
   ```

2. Verify video URL is valid:
   ```dart
   assert(video.videoUrl.isNotEmpty, 'Video URL is empty!');
   ```

3. Check if miniplayer is registered:
   ```dart
   bool isRegistered = Get.isRegistered<MiniplayerController>(tag: 'miniplayer');
   ```

### Video doesn't play

1. Verify video file exists at URL
2. Check internet connectivity
3. Enable logging to see errors:
   ```dart
   final error = MiniplayerController.to.error.value;
   print('Error: $error');
   ```

### Performance issues

1. Position updates are throttled at 4 Hz - this is intentional
2. If still slow, check device capabilities
3. Use `MiniplayerPerformanceUtils.canRunMiniplayer()` to detect

### Memory leaks

1. Ensure `onClose()` is called on controller disposal
2. Check that listeners are properly cleaned up
3. Use DevTools Memory tab to profile

---

## Integration Checklist

- [ ] ✅ `main.dart` wrapped with `MiniplayerOverlayManager`
- [ ] ✅ `InitialBinding` includes `MiniplayerBinding()`
- [ ] ✅ `VideoScreen` has `PopScope` with `_handleBackToMiniplayer()`
- [ ] ✅ Video URLs are valid and accessible
- [ ] ✅ Theme colors match YouTubeTheme
- [ ] ✅ Tested: Navigate away → miniplayer appears
- [ ] ✅ Tested: Tap expand → full screen without pause
- [ ] ✅ Tested: Close button → miniplayer dismissed
- [ ] ✅ Tested: Multiple video plays correctly

---

## Common Patterns

### Pattern: Auto-dismiss on certain conditions

```dart
// Dismiss miniplayer when user signs out
AuthService.to.onLogout.listen((_) {
  MiniplayerController.to.dismiss();
});
```

### Pattern: Show custom message

```dart
// Before navigating
await MiniplayerNavigationHelper.showMiniplayerWithCurrentVideo(
  video: video,
  currentPosition: pos,
  autoShow: false, // Start expanded
);

Get.snackbar(
  'Tip',
  'Tap the miniplayer to continue watching',
);
```

### Pattern: Conditional miniplayer

```dart
// Only show miniplayer on mobile
if (Theme.of(context).platform == TargetPlatform.android ||
    Theme.of(context).platform == TargetPlatform.iOS) {
  await MiniplayerNavigationHelper.navigateAwayWithMiniplayer(
    video: video,
    currentPosition: pos,
    targetRoute: '/home',
  );
} else {
  // Desktop: just navigate
  Get.toNamed('/home');
}
```

---

## Theme Customization

The miniplayer uses **YouTubeTheme theme colors** exclusively:

```dart
// All colors from YouTubeTheme theme
static const _bg = YouTubeTheme.primaryBackground;
static const _card = YouTubeTheme.cardBackground;
static const _crimson = YouTubeTheme.deepCrimson;
static const _textPrimary = YouTubeTheme.textPrimary;
static const _textSecondary = YouTubeTheme.textSecondary;
static const _border = YouTubeTheme.border;
```

To customize colors, edit `miniplayer_widget.dart` theme shortcuts.

---

## Getting Help

For issues or questions:

1. Check `MINIPLAYER_PRODUCTION_SETUP.md` for detailed architecture
2. Review `miniplayer_controller.dart` inline documentation
3. Check logs: Set `logger.init(minLogLevel: 2)` for verbose output
4. Test in isolation: Create a standalone test app

---

**Ready to use! Start integrating the miniplayer into your video navigation flows.** 🎬
