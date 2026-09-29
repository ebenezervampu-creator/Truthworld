import 'package:truthworld/features/video/data/models/video_chapter.dart';

/// Comprehensive parser and validator for video chapters adhering strictly to YouTube's chapter specification.
class VideoChapterParser {
  const VideoChapterParser._();

  /// Regex matching timestamp pattern: (H:)MM:SS or HH:MM:SS
  /// Matches standard YouTube timestamps such as: 0:00, 00:00, 1:23, 01:23, 1:04:15, 01:04:15
  static final RegExp _timestampRegex =
      RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})');

  /// Parses YouTube-style description timestamps into a list of [VideoChapter].
  ///
  /// Strictly enforces YouTube's rules for manual description chapters:
  /// 1. The first chapter must begin at 0:00 (Duration.zero).
  /// 2. Must contain at least 3 chapters.
  /// 3. Each chapter must be at least 10 seconds long.
  /// 4. Chapters must be in ascending chronological order.
  ///
  /// Returns an empty list if any requirement is violated.
  static List<VideoChapter> extractDescriptionChapters(String description) {
    if (description.trim().isEmpty) return const [];

    final lines = description.split(RegExp(r'\r?\n'));
    final parsed = <VideoChapter>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = _timestampRegex.firstMatch(trimmed);
      if (match != null) {
        var hours = 0;
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        if (match.group(1) != null) {
          hours = int.parse(match.group(1)!);
        }
        final duration = Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        );

        var title = trimmed.replaceFirst(match.group(0)!, '').trim();
        // Remove standard separator characters (-, –, —, :, ;, |, brackets, parentheses)
        title = title.replaceAll(RegExp(r'^[\s\-–—:;\[\]\(\)\|]+'), '').trim();
        if (title.isEmpty) {
          title = 'Chapter ${parsed.length + 1}';
        }
        parsed.add(VideoChapter(title: title, startTime: duration));
      }
    }

    if (parsed.isEmpty) return const [];

    // Sort chronologically
    parsed.sort((a, b) => a.startTime.compareTo(b.startTime));

    // YouTube Requirement 1: First timestamp MUST start at 0:00 (Duration.zero)
    if (parsed.first.startTime != Duration.zero) {
      return const [];
    }

    // YouTube Requirement 2: Must have at least 3 timestamps
    if (parsed.length < 3) {
      return const [];
    }

    // YouTube Requirement 3: Each chapter must be at least 10 seconds long
    for (var i = 0; i < parsed.length - 1; i++) {
      final diff = parsed[i + 1].startTime - parsed[i].startTime;
      if (diff < const Duration(seconds: 10)) {
        return const [];
      }
    }

    return parsed;
  }

  /// Resolves the final display chapters for a video following YouTube's exact override logic:
  ///
  /// 1. **Manual Override**: If explicit chapters exist or valid description timestamps are present:
  ///    Manual chapters ALWAYS override auto-chapters, regardless of whether auto-chapters is ON or OFF.
  /// 2. **Auto-Chapters OFF**: If the channel turned OFF auto-chapters (`autoChaptersEnabled == false`),
  ///    and there are no manual chapters, auto-chapters are SUPPRESSED (returns empty list).
  /// 3. **Auto-Chapters ON**: If auto-chapters is ON and no manual chapters exist, returns AI [autoChapters].
  static List<VideoChapter> resolveChapters({
    required List<dynamic>? explicitChapters,
    required String description,
    required dynamic rawAutoChapters,
    required bool autoChaptersEnabled,
  }) {
    // 1. Explicit manual chapters (e.g. from studio editor)
    if (explicitChapters != null && explicitChapters.isNotEmpty) {
      final parsed = explicitChapters
          .whereType<Map>()
          .map((e) => VideoChapter.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }

    // 2. Manual chapter upload via video description timestamps
    final descChapters = extractDescriptionChapters(description);
    if (descChapters.isNotEmpty) {
      return descChapters;
    }

    // 3. If no manual chapters, check if auto-chapters is enabled
    if (!autoChaptersEnabled) {
      // Channel turned OFF auto-chapters: auto-chapters are suppressed!
      return const [];
    }

    // 4. Auto-chapters fallback when enabled
    if (rawAutoChapters is List && rawAutoChapters.isNotEmpty) {
      return rawAutoChapters
          .whereType<Map>()
          .map((e) => VideoChapter.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return const [];
  }
}
