# YouTube Fullscreen Feature Implementation Guide

## Overview
This document describes the YouTube fullscreen feature implementation for the TruthWorld custom video player.

## Features

### 1. **YouTube-Style Fullscreen UI**
- Premium fullscreen interface with video info (title, channel)
- Auto-hiding controls with 3-second timeout
- Bottom control bar with playback controls
- Top gradient with exit button and stats button

### 2. **Enhanced Keyboard Shortcuts**
- **F** - Toggle YouTube fullscreen (automatic YouTube detection)
- **Escape** - Exit fullscreen
- **T** - Toggle theatre mode (in YouTube fullscreen)
- **Space** - Play/Pause
- **M** - Mute/Unmute
- **← →** - Seek ±5 seconds
- **↑ ↓** - Volume control
- **?** (Shift+/) - Show keyboard shortcuts dialog

### 3. **YouTube Video Detection**
The player automatically detects YouTube videos by checking if the URL contains:
- `youtube.com`
- `youtu.be`
- `youtube-nocookie.com`

### 4. **Multi-Platform Support**
- **Web**: Uses HTML5 Fullscreen API
- **Desktop** (Windows/macOS/Linux): Uses FullScreenWindow plugin
- **Mobile**: Fallback to standard fullscreen (if supported)

### 5. **Analytics Integration**
All fullscreen events are tracked with analytics:
- `youtube_fullscreen_enter`
- `youtube_fullscreen_exit`
- `theatre_mode_toggle`
- `fullscreen_controls_interaction`

## File Structure

```
lib/features/video/
├── presentation/
│   ├── controllers/
│   │   ├── custom_play.dart              # Enhanced with YouTube fullscreen
│   │   ├── youtube_fullscreen_controller.dart  # YouTube fullscreen controller
│   │   └── video_controller.dart
│   ├── views/
│   │   └── video_screen.dart
│   └── widgets/
│       ├── youtube_fullscreen_widget.dart     # YouTube fullscreen UI
│       ├── full_screen_helper.dart
│       └── ... (other widgets)
│   └── data/
│       └── models/
│           └── video.dart
```

## Implementation Details

### TowerPlayerController (custom_play.dart)

**New Properties:**
```dart
final RxBool isYouTubeFullscreen = false.obs;
final RxBool showYouTubeFullscreenUI = false.obs;
final RxString currentVideoUrl = ''.obs;
YouTubeFullscreenController? _youtubeFullscreenController;
```

**New Methods:**
```dart
// Initialize YouTube fullscreen controller
void initializeYouTubeFullscreen(VideoController videoController)

// Check if current video is YouTube
bool isCurrentVideoYouTube()

// Enter YouTube fullscreen
Future<void> enterYouTubeFullscreen()

// Exit YouTube fullscreen
Future<void> exitYouTubeFullscreen()

// Toggle YouTube fullscreen
Future<void> toggleYouTubeFullscreen()

// Set current video URL for detection
void setCurrentVideoUrl(String url)
```

### YouTubeFullscreenController

This controller manages all YouTube fullscreen-specific functionality:

```dart
class YouTubeFullscreenController extends GetxController {
  // Detect if video URL is YouTube
  bool isYouTubeUrl(String url)

  // Enter/Exit fullscreen
  Future<void> enterYouTubeFullscreen()
  Future<void> exitYouTubeFullscreen()

  // Theatre mode toggle
  void toggleTheatreMode()

  // Keyboard handling
  void handleFullscreenKeyboard(LogicalKeyboardKey key)

  // Preferences
  void saveFullscreenPreferences()
  void loadFullscreenPreferences()
}
```

### YouTubeFullscreenWidget

Premium fullscreen UI widget with:
- Auto-hiding controls
- Progress bar with time display
- Playback controls (Play/Pause, Rewind/Forward, Settings, Exit)
- Video info display (title, channel name)
- Tap-to-show-controls functionality

## Usage in VideoScreen

### 1. Initialize in VideoController

```dart
@override
void onInit() async {
  super.onInit();
  
  // ... existing initialization ...
  
  // Initialize YouTube fullscreen
  if (Get.isRegistered<TowerPlayerController>(tag: videoTag)) {
    final playerCtrl = Get.find<TowerPlayerController>(tag: videoTag);
    playerCtrl.initializeYouTubeFullscreen(this);
  }
}
```

### 2. Set Video URL

```dart
// After loading video
playerController.setCurrentVideoUrl(video.hlsUrl);
```

### 3. Handle Fullscreen in Video Screen

In your video player widget:

```dart
Obx(() {
  final playerCtrl = controller.playerController;
  
  if (playerCtrl.isYouTubeFullscreen.value) {
    return YouTubeFullscreenWidget(
      controller: playerCtrl,
      playerWidget: _buildVideoPlayer(),
      videoTitle: controller.video.title,
      channelName: controller.video.channelName,
      onExitFullscreen: () => playerCtrl.exitYouTubeFullscreen(),
    );
  }
  
  return _buildNormalLayout();
})
```

## Styling

The YouTube fullscreen UI uses the TruthWorld theme:
- **Primary Color**: `AppColors.brand` (Crimson)
- **Background**: Black (#000000)
- **Surface**: Dark gray (#161616)
- **Text**: Light gray (#F2F2F2)

## Keyboard Shortcuts Table

| Key | Action | Context |
|-----|--------|---------|
| F | Toggle Fullscreen | Normal + YouTube videos |
| Esc | Exit Fullscreen | In fullscreen mode |
| T | Theatre Mode | In YouTube fullscreen |
| Space | Play/Pause | Always |
| M | Mute/Unmute | Always |
| → | Seek +5s | Always |
| ← | Seek -5s | Always |
| ↑ | Volume +10% | Always |
| ↓ | Volume -10% | Always |
| I | Picture-in-Picture | Web only |
| ? | Show Help | Always |

## Configuration

### Auto-Hide Controls Delay
Default: 3 seconds
```dart
playerCtrl._youtubeFullscreenController!
  .enableAutoHideControls(5); // 5 seconds
```

### Theatre Mode
Toggle between:
- **Normal**: True fullscreen (100% screen)
- **Theatre**: 90% screen width/height with padding

## Error Handling

The implementation includes graceful error handling:
- Fullscreen request failures fall back to normal mode
- Platform-specific errors are logged without crashing
- Unsupported platforms are handled silently

## Analytics Tracking

All fullscreen interactions are tracked:

```dart
PlayerEvent('youtube_fullscreen_enter', data: {
  'video_id': videoController.video.id,
  'mode': 'normal',
})

PlayerEvent('youtube_fullscreen_exit', data: {
  'video_id': videoController.video.id,
  'duration_seconds': playerController.vv.position.inSeconds,
})
```

## Mobile Considerations

### Orientation Handling
Consider adding landscape-only fullscreen for mobile:

```dart
SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeRight,
  DeviceOrientation.landscapeLeft,
]);
```

### Notch/Safe Area
The YouTube fullscreen widget uses `SafeArea` internally to handle notches and safe areas.

## Testing Checklist

- [ ] Fullscreen enters correctly for YouTube videos
- [ ] Fullscreen exits with Escape key
- [ ] Controls auto-hide after 3 seconds
- [ ] Controls show on tap
- [ ] Play/Pause works in fullscreen
- [ ] Seek buttons work (±10s)
- [ ] Progress bar is draggable
- [ ] Theatre mode toggle works
- [ ] Video info displays correctly
- [ ] Analytics events are tracked
- [ ] Works on Web
- [ ] Works on Desktop (Windows/macOS/Linux)
- [ ] Mobile orientation locks correctly

## Future Enhancements

1. **Captions Support**
   - Display available subtitles in fullscreen UI
   - Allow subtitle selection from fullscreen

2. **Quality Switcher**
   - Quick access quality menu in fullscreen
   - Show current quality in stats

3. **Playback Speed**
   - Show speed menu in fullscreen settings
   - Persistent speed selection

4. **Gesture Controls**
   - Double-tap zones for skip/back
   - Swipe for volume/brightness

5. **Persistent Preferences**
   - Save user's fullscreen mode preference
   - Remember last theatre mode setting

## Troubleshooting

### Fullscreen not working
1. Check if video URL is detected correctly
2. Verify browser supports Fullscreen API (if web)
3. Check FullScreenWindow plugin is installed (if desktop)
4. Review console logs for error messages

### Controls not hiding
1. Verify `autoHideControls.value` is `true`
2. Check if interaction is being detected
3. Increase `controlsAutoHideDelay` value

### YouTube detection failing
1. Verify video URL contains `youtube.com`, `youtu.be`, or `youtube-nocookie.com`
2. Check `isCurrentVideoYouTube()` returns correct value
3. Ensure `setCurrentVideoUrl()` is called before fullscreen

## Support

For issues or questions about the YouTube fullscreen feature:
1. Check console logs for error messages
2. Review keyboard shortcuts with `Shift+?`
3. Verify video URL contains YouTube domain
4. Check platform-specific fullscreen support

---

**Last Updated**: May 22, 2026
**Version**: 1.0.0
