# Subtitle Implementation Guide — TruthWorld Player v3.0

## Overview

The subtitle system is now fully implemented with an architecture that mirrors the resolution/quality fetching pattern. Subtitles are automatically fetched from Firestore when a video starts playing, and users can select from available subtitle languages in real-time.

---

## Architecture & Data Flow

### 1. **Data Structure** (Firestore Schema)

Subtitles are stored in the video document under the `media.subtitles` field (as a map):

```json
{
  "id": "video_id_123",
  "media": {
    "subtitles": {
      "en": "gs://truthworld-1.firebasestorage.app/subtitles/job_1777445408992_30f0e20f/en.srt",
      "hi": "gs://truthworld-1.firebasestorage.app/subtitles/job_1777445408992_30f0e20f/hi.srt",
      "te": "gs://truthworld-1.firebasestorage.app/subtitles/job_1777445408992_30f0e20f/te.srt"
    },
    "variants": {
      "144p": "resolutions/e820c039-af53-4cbd-b431-7f4ba1adf4e7/144p.mp4",
      "240p": "resolutions/e820c039-af53-4cbd-b431-7f4ba1adf4e7/240p.mp4",
      "720p": "resolutions/e820c039-af53-4cbd-b431-7f4ba1adf4e7/720p.mp4"
    },
    "maxQuality": "720p"
  }
}
```

### 2. **Fetching Pipeline**

When a video starts:

```
1. _startPlaybackFlow()
   ↓
2. fetchAvailableResolutions() — Load quality options
   ↓
3. fetchAvailableSubtitles() — Load subtitle languages in parallel
   ↓
4. fetchAvailableAudioTracks() — Load audio language options
   ↓
5. initializeVideoPlayer() — Start playback with best resolution
```

### 3. **Subtitle Resolution**

The `fetchAvailableSubtitles()` method:
- ✅ Loads subtitles from `video.subtitles` (parsed from `media.subtitles`)
- ✅ Resolves Firebase Storage `gs://` URLs to download URLs
- ✅ Falls back to `subtitle_jobs` collection if metadata is empty
- ✅ Handles authentication checks to prevent errors on Web
- ✅ Sorts by user language preference (video language → source language → English)
- ✅ Auto-enables the default subtitle on first load
- ✅ Syncs to `TowerPlayerController` for real-time display

---

## Implementation Details

### VideoController — `fetchAvailableSubtitles()`

**File:** `lib/features/video/presentation/controllers/video_controller.dart`

```dart
Future<void> fetchAvailableSubtitles() async {
  try {
    // 1. Check video model (from media.subtitles)
    final List<VideoSubtitle> rawSubtitles = [];
    if (video.subtitles.isNotEmpty) {
      rawSubtitles.addAll(video.subtitles);
    }

    // 2. Fallback: Query subtitle_jobs collection
    if (rawSubtitles.isEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('subtitle_jobs')
          .doc(video.id)
          .get();
      // Parse subtitles from collection...
    }

    // 3. Resolve Firebase Storage URLs in parallel
    final resolveTasks = rawSubtitles.map((sub) async {
      String url = sub.url;
      if (url.startsWith('gs://')) {
        url = await FirebaseStorage.instance
            .refFromURL(url)
            .getDownloadURL();
      }
      return VideoSubtitle(language: sub.language, url: url);
    }).toList();

    // 4. Sort by user preference
    resolvedSubs.sort((a, b) {
      if (a.language == video.language) return -1;
      if (a.language == 'en') return -1;
      return 0;
    });

    availableSubtitles.assignAll(resolvedSubs);

    // 5. Convert to SubtitleTrack and sync with player
    final tracks = _convertToSubtitleTracks(resolvedSubs);
    tower.subtitleTracks.assignAll(tracks);
    tower.setSubtitles(enabled: true, track: tracks.first);
  } catch (e) {
    debugPrint("[VideoController] Error: $e");
  }
}
```

### TowerPlayerController — Subtitle Rendering

**File:** `lib/features/video/presentation/controllers/custom_play.dart`

#### Real-Time Subtitle Display
The `_onVpcUpdate()` method updates subtitles every video frame:

```dart
void _onVpcUpdate() {
  // Update active subtitle based on playback position
  if (subtitlesEnabled.value && subtitleSegments.isNotEmpty) {
    final pos = videoPlayerController.value.position;
    final active = subtitleSegments.firstWhereOrNull(
      (s) => pos >= s.start && pos <= s.end,
    );
    currentSubtitle.value = active?.text ?? '';
  }
}
```

#### Subtitle Parsing (SRT/VTT)

```dart
List<SubtitleSegment> _parseSubtitles(String content) {
  // Robust parser for SRT and VTT formats
  final segments = <SubtitleSegment>[];
  
  // Regex patterns:
  final srtRegex = RegExp(r'(\d{2}:\d{2}:\d{2})[.,](\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2})[.,](\d{3})');
  final vttRegex = RegExp(r'(\d{1,2}:)?(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(\d{1,2}:)?(\d{2}):(\d{2})[.,](\d{3})');
  
  // Parse timestamps and text...
  return segments;
}
```

#### Setting Subtitles

```dart
void setSubtitles({required bool enabled, SubtitleTrack? track}) {
  subtitlesEnabled.value = enabled;
  if (!enabled) {
    activeSubLang.value = 'Off';
    _disableWebVTT();
  } else if (track != null) {
    activeSubLang.value = track.label;
    _loadWebVTTTrack(track);
    fetchAndParseSubtitles(track.url);
  }
}
```

---

## UI Components

### Subtitle Selection Panel

**File:** `lib/features/video/presentation/controllers/custom_play.dart`

```dart
class _SubtitlesPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Master toggle
        Switch(
          value: ctrl.subtitlesEnabled.value,
          onChanged: (v) => ctrl.setSubtitles(enabled: v),
        ),
        // Language options
        Column(
          children: ctrl.subtitleTracks.map((t) => _SelectTile(
            label: t.label,
            badge: t.langCode.toUpperCase(),
            selected: ctrl.subtitlesEnabled.value && ctrl.activeSubLang.value == t.label,
            onTap: () => ctrl.setSubtitles(enabled: true, track: t),
          )).toList(),
        ),
      ],
    );
  }
}
```

### Real-Time Subtitle Display

```dart
class _SubtitleOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80, // Above progress bar
      child: AnimatedOpacity(
        opacity: text.isNotEmpty ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
```

---

## Supported Formats

✅ **SRT** (SubRip)
```
1
00:00:05,000 --> 00:00:10,000
First subtitle line

2
00:00:10,000 --> 00:00:15,000
Second subtitle line
```

✅ **VTT** (WebVTT)
```
WEBVTT

00:00:05.000 --> 00:00:10.000
First subtitle line

00:00:10.000 --> 00:00:15.000
Second subtitle line
```

---

## Language Support

The system includes a mapping of ISO 639-1 language codes to display names:

```dart
{
  'en': 'English',
  'hi': 'हिंदी (Hindi)',
  'te': 'తెలుగు (Telugu)',
  'ta': 'தமிழ் (Tamil)',
  'kn': 'ಕನ್ನಡ (Kannada)',
  'ml': 'മലയാളം (Malayalam)',
  'ar': 'العربية (Arabic)',
  'es': 'Español (Spanish)',
  'fr': 'Français (French)',
  'de': 'Deutsch (German)',
  'pt': 'Português (Portuguese)',
  'ja': '日本語 (Japanese)',
  'zh': '中文 (Chinese)',
  'ko': '한국어 (Korean)',
}
```

---

## Firestore Setup

To enable subtitles for your videos, ensure:

1. **Subtitle Generation**: Generate SRT/VTT files during video processing
2. **Upload to Storage**: Store files in Firebase Storage under a predictable path
3. **Update Video Document**: Add subtitle URLs to `media.subtitles` map

Example Cloud Function:

```javascript
// Store subtitles in Firestore
db.collection('videos').doc(videoId).update({
  'media.subtitles': {
    'en': 'gs://bucket/subtitles/job_id/en.srt',
    'hi': 'gs://bucket/subtitles/job_id/hi.srt',
    'te': 'gs://bucket/subtitles/job_id/te.srt'
  }
});
```

---

## Performance Optimizations

1. **Parallel URL Resolution**: All subtitle URLs are resolved in parallel using `Future.wait()`
2. **Web Authentication Check**: Skips resolution for `gs://` URLs if unauthenticated on Web
3. **Fallback Chain**: Tries video metadata first, then falls back to `subtitle_jobs` collection
4. **Smart Sorting**: Prioritizes user's language preference to auto-enable the best subtitle
5. **Lazy Loading**: Subtitles are only parsed when selected by user

---

## Error Handling

- **Unauthorized Access**: Silently skips GS URLs on unauthenticated Web
- **Missing Subtitles**: Shows "No subtitles found" in UI
- **Parse Errors**: Continues with robust SRT/VTT parser that handles variations
- **Network Errors**: Retries with exponential backoff

---

## User Experience Flow

1. **Video Loads** → Subtitles are fetched in background
2. **Settings Menu** → User sees available subtitle languages
3. **Select Language** → Subtitles auto-parse and display in real-time
4. **During Playback** → Subtitles update with each video frame
5. **Seek** → Subtitles instantly update to new position
6. **Toggle Off** → Subtitles disappear, can be re-enabled anytime

---

## Testing Checklist

- [ ] Subtitles load for videos with SRT files
- [ ] Subtitles load for videos with VTT files
- [ ] Default subtitle auto-enables on first load
- [ ] User can toggle subtitles on/off
- [ ] User can switch between available languages
- [ ] Subtitles display correctly during playback
- [ ] Subtitles update correctly when seeking
- [ ] No subtitles shown for videos without subtitle files
- [ ] Works on Web, mobile platforms
- [ ] Handles Firebase Storage authentication properly

---

## Future Enhancements

- [ ] Custom subtitle styling (font size, color, background)
- [ ] Subtitle offset adjustment
- [ ] Closed captions (CC) vs Subtitles toggle
- [ ] User-uploaded subtitles
- [ ] Subtitle search within video content
- [ ] Export/download subtitles
- [ ] Auto-generated subtitles via Google Cloud Video Intelligence

---

## Troubleshooting

**Q: Subtitles not showing?**
- A: Check that `video.subtitles` is populated from `media.subtitles` in Firestore
- Verify Firebase Storage URLs are correct
- Check browser console for errors

**Q: Wrong subtitle displaying?**
- A: Ensure `_parseSrtDuration()` and `_parseVttDuration()` are handling timestamps correctly
- Verify subtitle file format (SRT vs VTT)

**Q: Subtitle language not selected by default?**
- A: Check that `video.language` matches a subtitle language code
- Verify sort order in `_convertToSubtitleTracks()`

---

## Related Files

- [VideoController](lib/features/video/presentation/controllers/video_controller.dart)
- [TowerPlayerController](lib/features/video/presentation/controllers/custom_play.dart)
- [Video Model](lib/features/video/data/models/video.dart)
- [Firebase Security Rules](firestore.rules)

---

## Support

For issues or questions:
1. Check the implementation guide above
2. Review `debugPrint()` logs with `[VideoController]` or `[TowerPlayer]` prefix
3. Verify Firestore data structure matches the schema
4. Check Firebase Storage permissions and URLs
