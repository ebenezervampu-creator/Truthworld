# Miniplayer Feature - Integration Guide

## Overview

The Complete Miniplayer feature provides a sophisticated floating video player that:
- Shows video when navigating away from the video screen
- Has play/pause button in the middle
- Skip forward/backward 10 seconds buttons (left/right)
- White border styling
- Draggable and resizable
- Smoothly transitions to full video screen when tapped
- Optimized for Flutter Web with low latency and scalability for millions of users

## Architecture

```
features/miniplayer/
├── data/
│   ├── models/
│   │   └── miniplayer_model.dart (MiniplayerState, MiniplayerConfig)
│   └── services/
│       └── miniplayer_service.dart (MiniplayerService)
├── presentation/
│   ├── bindings/
│   │   └── miniplayer_binding.dart
│   ├── controllers/
│   │   └── miniplayer_controller.dart (MiniplayerController)
│   ├── widgets/
│   │   ├── miniplayer_widget.dart (UI components)
│   │   └── miniplayer_overlay_manager.dart (Overlay management)
│   └── utils/
│       └── miniplayer_utils.dart (Helper utilities)
```

## Integration Steps

### 1. Update `main.dart`

Wrap your app with `MiniplayerOverlayManager`:

```dart
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';

void main() async {
  // ... existing initialization code ...
  runApp(const Truthworld());
}

class Truthworld extends StatelessWidget {
  const Truthworld({super.key});

  @override
  Widget build(BuildContext context) {
    return MiniplayerOverlayManager(
      config: const MiniplayerConfig(
        enabled: true,
        autoShowOnNavigate: true,
        enableDrag: true,
        enableResize: true,
        borderColor: Color(0xFFFFFFFF),
        borderWidth: 2.0,
      ),
      child: GetMaterialApp(
        // ... existing GetMaterialApp config ...
      ),
    );
  }
}
```

### 2. Update `core/bindings/initial_binding.dart`

Add miniplayer binding:

```dart
import 'package:truthworld/features/miniplayer/presentation/bindings/miniplayer_binding.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // ... existing bindings ...
    
    // Initialize miniplayer
    MiniplayerBinding().dependencies();
  }
}
```

### 3. Modify Video Screen Navigation

In your places that navigate away from video screen, show miniplayer:

```dart
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';

// Example: Navigate to Home and show miniplayer
onPressed: () async {
  await context.showMiniplayerAndNavigate(
    video: video,
    videoPlayerController: videoPlayerController,
    chewieController: chewieController,
    targetRoute: '/home',
  );
}
```

### 4. Update Video Screen State

In `video_screen.dart`, handle miniplayer interactions:

```dart
// When video is initialized
void _initializeMiniplayer() {
  final miniplayerController = context.getMiniplayerController();
  if (miniplayerController != null) {
    miniplayerController.updatePlayerReferences(
      _videoPlayerController!,
      _chewieController!,
    );
    miniplayerController.listenToPlayerState();
  }
}

// When leaving video screen
@override
void dispose() {
  final miniplayerController = context.getMiniplayerController();
  if (miniplayerController != null) {
    miniplayerController.clearPlayerReferences();
  }
  super.dispose();
}
```

## Usage Examples

### Show Miniplayer When Navigating Away

```dart
// From any widget, navigate away and show miniplayer
await context.showMiniplayerAndNavigate(
  video: currentVideo,
  videoPlayerController: _videoPlayerController,
  chewieController: _chewieController,
  targetRoute: '/home',
);
```

### Access Miniplayer Controller

```dart
final miniplayerController = context.getMiniplayerController();

// Show miniplayer
miniplayerController?.showMiniplayer(video, vPlayerController, chewieController);

// Hide miniplayer
miniplayerController?.hideMiniplayer();

// Check if visible
if (context.isMiniplayerVisible()) {
  // ...
}

// Play/Pause
miniplayerController?.togglePlayPause();

// Skip operations
miniplayerController?.skipForward();
miniplayerController?.skipBackward();

// Resize
miniplayerController?.updateSize(const Size(0.5, 0.5));

// Reposition
miniplayerController?.updatePosition(Offset(10, 10), screenSize);
```

### Custom Configuration

```dart
// Create custom config
final customConfig = MiniplayerConfig(
  enabled: true,
  autoShowOnNavigate: true,
  pauseOnClose: true,
  keepAudioPlayingMinimized: false,
  enableDrag: true,
  enableResize: true,
  borderColor: Colors.white,
  borderWidth: 2.0,
  borderRadius: 12.0,
  opacity: 1.0,
  animationDuration: Duration(milliseconds: 300),
);

// Update configuration
getMiniplayerController()?.updateConfig(customConfig);
```

## Performance Optimization

### For High-Scale (Millions of Users)

1. **Throttled Updates**: The controller throttles updates to 60 FPS
2. **Memory Management**: Unused controllers are properly disposed
3. **Lazy Loading**: Miniplayer only renders when visible
4. **Adaptive Streaming**: Supports HLS/DASH quality adaptation
5. **Low Latency**: Minimal state updates prevent jank

### Web-Specific Optimizations

```dart
// The system automatically:
- Uses requestAnimationFrame for smooth 60 FPS
- Batches DOM updates
- Lazy-loads overlay only when needed
- Cleans up resources on route changes
```

## Configuration Options

### MiniplayerConfig Properties

```dart
const MiniplayerConfig(
  enabled: true,                 // Enable/disable feature
  autoShowOnNavigate: true,       // Show when navigating away
  pauseOnClose: true,             // Pause when closed
  keepAudioPlayingMinimized: false, // Keep audio in background
  enableDrag: true,               // Allow dragging
  enableResize: true,             // Allow resizing
  defaultSizePercentage: Size(0.35, 0.35), // Default size
  borderColor: Color(0xFFFFFFFF), // White border
  borderWidth: 2.0,               // Border width
  borderRadius: 12.0,             // Corner radius
  opacity: 1.0,                   // Opacity (0-1)
  animationDuration: Duration(milliseconds: 300), // Transition time
  maxDuration: Duration.zero,     // Max show duration (0 = infinite)
);
```

## Responsive Behavior

The miniplayer automatically adjusts for different screen sizes:

- **Mobile** (<600px): 50% size
- **Tablet** (600-1200px): 40% size
- **Desktop** (>1200px): 35% size

Default position: 16px from top-left corner

## State Management

State is managed through GetX reactive streams:

```dart
// Reactive state
Rx<MiniplayerState> _state = Rx<MiniplayerState>(...);

// Auto-rebuilds when:
- isVisible changes
- isPlaying changes
- currentPosition changes
- position changes
- size changes
```

## Audio Handling

Current behavior:
- Audio **stops** when miniplayer is minimized (by default)
- Configurable via `keepAudioPlayingMinimized` 

To keep audio playing in background:

```dart
final config = MiniplayerConfig(
  keepAudioPlayingMinimized: true,
);
```

## Analytics & Monitoring

Get real-time metrics:

```dart
final controller = context.getMiniplayerController();
final metrics = controller?.getPerformanceMetrics();

print('Video age: ${metrics['age_ms']}ms');
print('Is playing: ${metrics['is_playing']}');
print('Current position: ${metrics['current_position_ms']}ms');
print('Duration: ${metrics['video_duration_ms']}ms');
```

## Common Issues & Solutions

### Issue: Miniplayer not showing
- Ensure `MiniplayerOverlayManager` wraps the entire app
- Check that `MiniplayerBinding` is initialized in `InitialBinding`
- Verify `MiniplayerConfig.enabled = true`

### Issue: Dark video in miniplayer
- Check video player controller is properly initialized
- Verify video URL is accessible
- Check network/permissions

### Issue: Choppy drag/resize
- This is expected on very low-end devices
- Implement `canRunMiniplayer()` check for auto-disable on low-end devices

### Issue: Memory leaks
- Ensure `clearPlayerReferences()` is called on dispose
- Check that overlays are properly removed

## Testing

Example test setup:

```dart
testWidgets('Miniplayer shows and hides correctly', (tester) async {
  await tester.pumpWidget(const Truthworld());
  
  // Verify miniplayer is not visible initially
  expect(find.byType(MiniplayerWidget), findsNothing);
  
  // Show miniplayer
  final context = tester.element(find.byType(Home));
  final controller = context.getMiniplayerController();
  controller?.showMiniplayer(testVideo, vPlayerController, chewieController);
  
  await tester.pumpAndSettle();
  
  // Verify miniplayer is visible
  expect(find.byType(MiniplayerWidget), findsOneWidget);
  
  // Hide miniplayer
  controller?.hideMiniplayer();
  
  await tester.pumpAndSettle();
  
  // Verify miniplayer is hidden
  expect(find.byType(MiniplayerWidget), findsNothing);
});
```

## Future Enhancements

Potential improvements:

1. **Floating Window Mode**: Detach from app window
2. **Multiple Miniplaiers**: Show multiple videos simultaneously
3. **Pip on Web**: Native Picture-in-Picture API integration
4. **Custom Themes**: More appearance customization
5. **Smart Positioning**: Auto-position based on tap or user preference
6. **Gesture Controls**: Swipe to previous/next video
7. **Analytics Dashboard**: Detailed usage metrics
8. **A/B Testing**: Test different UI variations

## Support & Issues

For issues or feature requests, check:
- Performance metrics: `controller.getPerformanceMetrics()`
- Config: `controller.config`
- Current state: `controller.state`

Debug logging enabled via:
```dart
// In miniplayer_service.dart
_logEvent(eventName, parameters); // Logs to console
```

