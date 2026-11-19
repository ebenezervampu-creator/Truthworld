import 'package:truthworld/core/services/user_languages_service.dart';

class VideoChapter {
  VideoChapter({
    required this.title,
    required this.startTime,
    this.thumbnailUrl,
    this.localizedTitles = const {},
  });

  factory VideoChapter.fromMap(Map<String, dynamic> map) {
    // Support 'startTimeMs' (manual chapters in Firestore), 'startMs' (AI pipeline), and 'startTime' (seconds or ms or Duration)
    var parsedStartTime = Duration.zero;
    final rawStart =
        map['startTimeMs'] ??
        map['startMs'] ??
        map['startTime'] ??
        map['startSeconds'];

    if (rawStart is Duration) {
      parsedStartTime = rawStart;
    } else if (rawStart is num) {
      if (map.containsKey('startTimeMs') || map.containsKey('startMs')) {
        parsedStartTime = Duration(milliseconds: rawStart.toInt());
      } else if (rawStart > 100000) {
        parsedStartTime = Duration(milliseconds: rawStart.toInt());
      } else {
        parsedStartTime = Duration(seconds: rawStart.toInt());
      }
    }

    final rawLocalized =
        map['localizedTitles'] ?? map['translations'] ?? map['titles'];
    final localizedMap = <String, String>{};
    if (rawLocalized is Map) {
      for (final entry in rawLocalized.entries) {
        if (entry.key != null && entry.value != null) {
          localizedMap[UserLanguagesService.normalizeCode(entry.key.toString())] =
              entry.value.toString();
        }
      }
    }

    return VideoChapter(
      title: map['title'] ?? '',
      startTime: parsedStartTime,
      thumbnailUrl: map['thumbnailUrl'],
      localizedTitles: localizedMap,
    );
  }
  final String title;
  final Duration startTime;
  final String? thumbnailUrl;
  final Map<String, String> localizedTitles;

  /// Returns the chapter title translated into the requested [langCode] or the user's
  /// active primary language. Seamlessly falls back to the default canonical [title].
  String localizedTitle([String? langCode]) {
    final code = (langCode != null && langCode.trim().isNotEmpty)
        ? UserLanguagesService.normalizeCode(langCode)
        : (UserLanguagesService.isRegistered
            ? UserLanguagesService.to.primaryLanguageCode
            : 'en');

    if (localizedTitles.containsKey(code)) {
      final loc = localizedTitles[code];
      if (loc != null && loc.trim().isNotEmpty) return loc;
    }

    // Cleanse cross-script hallucination: if user is requesting Telugu or title is in Hindi for intro
    if (code == 'te' && (title == 'परिचय' || title == 'Introduction')) {
      return 'పరిచయం';
    }

    return title;
  }

  VideoChapter copyWith({
    String? title,
    Duration? startTime,
    String? thumbnailUrl,
    Map<String, String>? localizedTitles,
  }) {
    return VideoChapter(
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localizedTitles: localizedTitles ?? this.localizedTitles,
    );
  }

  /// Canonical sanitizer for cross-script hallucinations (e.g. Hindi 'परिचय' in Telugu context)
  static String sanitizeTitle(
    String title, {
    String? targetLanguage,
    bool isTeluguContext = false,
    Duration startTime = Duration.zero,
  }) {
    final trimmed = title.trim();
    final isTe = targetLanguage == 'te' || isTeluguContext;

    if (isTe) {
      if (trimmed == 'परिचय' ||
          trimmed == 'Introduction' ||
          trimmed.toLowerCase() == 'introduction') {
        return 'పరిచయం';
      }
      if (startTime == Duration.zero &&
          RegExp(r'[\u0900-\u097F]').hasMatch(trimmed)) {
        return 'పరిచయం';
      }
    }
    return trimmed;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'startTimeMs': startTime.inMilliseconds,
      'thumbnailUrl': thumbnailUrl,
      if (localizedTitles.isNotEmpty) 'localizedTitles': localizedTitles,
    };
  }

  String get formattedStartTime {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(startTime.inMinutes.remainder(60));
    final seconds = twoDigits(startTime.inSeconds.remainder(60));
    if (startTime.inHours > 0) {
      return '${twoDigits(startTime.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoChapter &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          startTime == other.startTime;

  @override
  int get hashCode => title.hashCode ^ startTime.hashCode;
}
