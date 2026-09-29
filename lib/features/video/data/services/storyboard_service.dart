import 'dart:ui';

/// Represents a single storyboard preview frame at a specific timestamp range.
class StoryboardCue {
  const StoryboardCue({
    required this.start,
    required this.end,
    required this.imageUrl,
    this.cropRect,
  });

  final Duration start;
  final Duration end;
  final String imageUrl;
  final Rect? cropRect;

  bool contains(Duration position) => position >= start && position < end;

  @override
  String toString() =>
      'StoryboardCue(${start.inSeconds}s..${end.inSeconds}s, $imageUrl, crop: $cropRect)';
}

/// An ordered collection of storyboard cues for trick-play scrubbing preview.
class StoryboardTrack {
  const StoryboardTrack({required this.cues});

  final List<StoryboardCue> cues;

  bool get isEmpty => cues.isEmpty;
  bool get isNotEmpty => cues.isNotEmpty;
  int get length => cues.length;

  /// Fast binary search to find the active cue for the given [position].
  StoryboardCue? getCueAt(Duration position) {
    if (cues.isEmpty) return null;
    if (position < cues.first.start) return cues.first;
    if (position >= cues.last.end) return cues.last;

    var low = 0;
    var high = cues.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final cue = cues[mid];

      if (position < cue.start) {
        high = mid - 1;
      } else if (position >= cue.end) {
        low = mid + 1;
      } else {
        return cue;
      }
    }

    // Nearest fallback
    final clampedIdx = low.clamp(0, cues.length - 1);
    return cues[clampedIdx];
  }

  /// Returns all unique image URLs referenced by cues within the time window
  /// [position - window, position + window].
  Set<String> getImageUrlsAround(
    Duration position, {
    Duration window = const Duration(seconds: 30),
  }) {
    if (cues.isEmpty) return const {};
    final startTime = position > window ? position - window : Duration.zero;
    final endTime = position + window;
    final urls = <String>{};

    for (final cue in cues) {
      if (cue.end >= startTime && cue.start <= endTime) {
        if (cue.imageUrl.isNotEmpty) {
          urls.add(cue.imageUrl);
        }
      }
      if (cue.start > endTime) {
        break;
      }
    }
    return urls;
  }
}

/// Parser and generator for storyboard trick-play scrubbing tracks.
class StoryboardService {
  /// Parse a WebVTT storyboard file content.
  /// Standard WebVTT storyboard cues format:
  /// ```vtt
  /// WEBVTT
  ///
  /// 00:00:00.000 --> 00:00:05.000
  /// sprite.jpg#xywh=0,0,160,90
  ///
  /// 00:00:05.000 --> 00:00:10.000
  /// sprite.jpg#xywh=160,0,160,90
  /// ```
  static StoryboardTrack parseWebVtt(
    String vttContent, {
    String? baseUrl,
  }) {
    final cues = <StoryboardCue>[];
    final lines = vttContent.split(RegExp(r'\r?\n'));

    final timestampRegex = RegExp(
      r'((?:\d{2}:)?\d{2}:\d{2}(?:\.\d{3})?)\s*-->\s*((?:\d{2}:)?\d{2}:\d{2}(?:\.\d{3})?)',
    );
    final xywhRegex = RegExp(r'#xywh=(?:pixel:)?(\d+),(\d+),(\d+),(\d+)');

    Duration? currentStart;
    Duration? currentEnd;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('WEBVTT') || line.startsWith('NOTE')) {
        continue;
      }

      final tsMatch = timestampRegex.firstMatch(line);
      if (tsMatch != null) {
        currentStart = _parseVttTimestamp(tsMatch.group(1)!);
        currentEnd = _parseVttTimestamp(tsMatch.group(2)!);
        continue;
      }

      if (currentStart != null && currentEnd != null) {
        // Line is payload (e.g., "sprite_0.jpg#xywh=0,0,160,90" or "frame_12.jpg")
        var imgUrl = line;
        Rect? crop;

        final xywhMatch = xywhRegex.firstMatch(line);
        if (xywhMatch != null) {
          final x = double.parse(xywhMatch.group(1)!);
          final y = double.parse(xywhMatch.group(2)!);
          final w = double.parse(xywhMatch.group(3)!);
          final h = double.parse(xywhMatch.group(4)!);
          crop = Rect.fromLTWH(x, y, w, h);
          imgUrl = line.substring(0, xywhMatch.start);
        }

        if (baseUrl != null && baseUrl.isNotEmpty && !imgUrl.startsWith('http://') && !imgUrl.startsWith('https://')) {
          final separator = baseUrl.endsWith('/') ? '' : '/';
          imgUrl = '$baseUrl$separator$imgUrl';
        }

        if (imgUrl.isNotEmpty) {
          cues.add(
            StoryboardCue(
              start: currentStart,
              end: currentEnd,
              imageUrl: imgUrl,
              cropRect: crop,
            ),
          );
        }

        currentStart = null;
        currentEnd = null;
      }
    }

    return StoryboardTrack(cues: cues);
  }

  /// Create a storyboard track from an ordered list of thumbnail variant URLs (equidistantly distributed).
  static StoryboardTrack fromThumbnailVariants(
    List<String> variants,
    Duration totalDuration,
  ) {
    if (variants.isEmpty || totalDuration <= Duration.zero) {
      return const StoryboardTrack(cues: []);
    }

    final validVariants = variants.where((v) => v.trim().isNotEmpty).toList();
    if (validVariants.isEmpty) return const StoryboardTrack(cues: []);

    final segmentMs = totalDuration.inMilliseconds / validVariants.length;
    final cues = <StoryboardCue>[];

    for (var i = 0; i < validVariants.length; i++) {
      final startMs = (i * segmentMs).round();
      final endMs = ((i + 1) * segmentMs).round();
      cues.add(
        StoryboardCue(
          start: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
          imageUrl: validVariants[i],
        ),
      );
    }

    return StoryboardTrack(cues: cues);
  }

  /// Generate a storyboard track for an M×N sprite sheet grid.
  static StoryboardTrack fromGrid({
    required String spriteUrl,
    required int columns,
    required int rows,
    required double frameWidth,
    required double frameHeight,
    required Duration totalDuration,
    required Duration interval,
  }) {
    if (columns <= 0 || rows <= 0 || interval <= Duration.zero) {
      return const StoryboardTrack(cues: []);
    }

    final totalFrames = columns * rows;
    final cues = <StoryboardCue>[];

    for (var i = 0; i < totalFrames; i++) {
      final start = Duration(milliseconds: interval.inMilliseconds * i);
      if (start >= totalDuration && totalDuration > Duration.zero) break;

      final end = Duration(milliseconds: interval.inMilliseconds * (i + 1));
      final col = i % columns;
      final row = i ~/ columns;

      final crop = Rect.fromLTWH(
        col * frameWidth,
        row * frameHeight,
        frameWidth,
        frameHeight,
      );

      cues.add(
        StoryboardCue(
          start: start,
          end: end,
          imageUrl: spriteUrl,
          cropRect: crop,
        ),
      );
    }

    return StoryboardTrack(cues: cues);
  }

  /// Generate a high-density storyboard track across multiple sprite sheets.
  /// Ideal for long-form content (> 1 hour) with 1-second interval precision,
  /// avoiding giant texture sizes that exceed GPU memory limits.
  static StoryboardTrack fromMultiSheetGrid({
    required List<String> spriteUrls,
    required int columns,
    required int rows,
    required double frameWidth,
    required double frameHeight,
    required Duration totalDuration,
    Duration interval = const Duration(seconds: 1),
  }) {
    final validUrls = spriteUrls.where((u) => u.trim().isNotEmpty).toList();
    if (validUrls.isEmpty || columns <= 0 || rows <= 0 || interval <= Duration.zero) {
      return const StoryboardTrack(cues: []);
    }

    final framesPerSheet = columns * rows;
    final cues = <StoryboardCue>[];
    final totalDurationMs = totalDuration.inMilliseconds;
    final intervalMs = interval.inMilliseconds;
    var globalFrameIndex = 0;

    for (var sheetIndex = 0; sheetIndex < validUrls.length; sheetIndex++) {
      final sheetUrl = validUrls[sheetIndex];
      for (var frameInSheet = 0; frameInSheet < framesPerSheet; frameInSheet++) {
        final startMs = globalFrameIndex * intervalMs;
        if (totalDurationMs > 0 && startMs >= totalDurationMs) break;

        final endMs = (globalFrameIndex + 1) * intervalMs;
        final col = frameInSheet % columns;
        final row = frameInSheet ~/ columns;

        final crop = Rect.fromLTWH(
          col * frameWidth,
          row * frameHeight,
          frameWidth,
          frameHeight,
        );

        cues.add(
          StoryboardCue(
            start: Duration(milliseconds: startMs),
            end: Duration(
              milliseconds: (totalDurationMs > 0 && endMs > totalDurationMs)
                  ? totalDurationMs
                  : endMs,
            ),
            imageUrl: sheetUrl,
            cropRect: crop,
          ),
        );

        globalFrameIndex++;
      }
      if (totalDurationMs > 0 && globalFrameIndex * intervalMs >= totalDurationMs) {
        break;
      }
    }

    return StoryboardTrack(cues: cues);
  }

  /// Automatically generate a high-density trick-play track with 1-second precision,
  /// selecting the best available source representation:
  /// 1. Multi-sheet sprite grids (for long-form/multi-hour content)
  /// 2. Single-sheet sprite grid
  /// 3. WebVTT parsed cues
  /// 4. Equidistant variants with 1-second sub-interval sampling (guaranteeing 0 dead-zones)
  static StoryboardTrack generateHighDensityTrack({
    required Duration totalDuration,
    List<String>? multiSheetUrls,
    String? singleSheetUrl,
    String? webVttContent,
    List<String>? thumbnailVariants,
    int columns = 10,
    int rows = 10,
    double frameWidth = 160,
    double frameHeight = 90,
    Duration interval = const Duration(seconds: 1),
  }) {
    if (multiSheetUrls != null && multiSheetUrls.any((u) => u.trim().isNotEmpty)) {
      return fromMultiSheetGrid(
        spriteUrls: multiSheetUrls,
        columns: columns,
        rows: rows,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        totalDuration: totalDuration,
        interval: interval,
      );
    }

    if (singleSheetUrl != null && singleSheetUrl.trim().isNotEmpty) {
      return fromGrid(
        spriteUrl: singleSheetUrl.trim(),
        columns: columns,
        rows: rows,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        totalDuration: totalDuration,
        interval: interval,
      );
    }

    if (webVttContent != null && webVttContent.trim().isNotEmpty) {
      return parseWebVtt(webVttContent);
    }

    if (thumbnailVariants != null && thumbnailVariants.isNotEmpty) {
      final validVariants = thumbnailVariants.where((v) => v.trim().isNotEmpty).toList();
      if (validVariants.isEmpty || totalDuration <= Duration.zero) {
        return const StoryboardTrack(cues: []);
      }

      final totalSeconds = (totalDuration.inMilliseconds / interval.inMilliseconds).ceil();
      if (totalSeconds <= 0) return const StoryboardTrack(cues: []);

      final cues = <StoryboardCue>[];
      final segmentMs = totalDuration.inMilliseconds / validVariants.length;

      for (var sec = 0; sec < totalSeconds; sec++) {
        final startMs = sec * interval.inMilliseconds;
        final endMs = ((sec + 1) * interval.inMilliseconds).clamp(0, totalDuration.inMilliseconds);
        final midMs = startMs + (endMs - startMs) / 2;
        final variantIndex = (midMs / segmentMs).floor().clamp(0, validVariants.length - 1);

        cues.add(
          StoryboardCue(
            start: Duration(milliseconds: startMs),
            end: Duration(milliseconds: endMs),
            imageUrl: validVariants[variantIndex],
          ),
        );
      }

      return StoryboardTrack(cues: cues);
    }

    return const StoryboardTrack(cues: []);
  }

  /// Hook for preloading sprite sheets around the active scrub/hover position.
  static Future<void> preloadAround(
    StoryboardTrack track,
    Duration position, {
    Duration window = const Duration(seconds: 30),
    Future<void> Function(String url)? loader,
  }) async {
    final urls = track.getImageUrlsAround(position, window: window);
    if (urls.isEmpty) return;

    if (loader != null) {
      for (final url in urls) {
        await loader(url);
      }
    }
  }

  static Duration _parseVttTimestamp(String ts) {
    final parts = ts.split(':');
    var hours = 0;
    var minutes = 0;
    var seconds = 0.0;

    if (parts.length == 3) {
      hours = int.tryParse(parts[0]) ?? 0;
      minutes = int.tryParse(parts[1]) ?? 0;
      seconds = double.tryParse(parts[2]) ?? 0.0;
    } else if (parts.length == 2) {
      minutes = int.tryParse(parts[0]) ?? 0;
      seconds = double.tryParse(parts[1]) ?? 0.0;
    }

    final totalMs = ((hours * 3600 + minutes * 60 + seconds) * 1000).round();
    return Duration(milliseconds: totalMs);
  }
}
