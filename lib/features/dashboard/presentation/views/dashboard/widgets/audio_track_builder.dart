import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Utility that converts a [Video]'s raw `audioTracks` map plus its stream URL
/// into the typed [AudioTrackOption] list the player needs.
///
/// Language code → human-readable label mapping is intentionally kept here so
/// both the creator editor and the viewer player stay in sync automatically.
class AudioTrackBuilder {
  AudioTrackBuilder._();

  static const Map<String, String> _codeToLabel = {
    'en': 'English',
    'hi': 'Hindi',
    'te': 'Telugu',
    'ta': 'Tamil',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'mr': 'Marathi',
    'bn': 'Bengali',
    'gu': 'Gujarati',
    'pa': 'Punjabi',
    'ur': 'Urdu',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'ar': 'Arabic',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
  };

  /// Returns a human-readable label for a language code.
  /// Falls back to capitalised code if not in the dictionary.
  static String labelFor(String code) {
    final c = code.toLowerCase();
    if (_codeToLabel.containsKey(c)) return _codeToLabel[c]!;
    // Custom language names passed as full words (e.g. "German")
    if (code.length > 2) return code[0].toUpperCase() + code.substring(1);
    return code.toUpperCase();
  }

  /// Builds the full ordered list of [AudioTrackOption]s from a [Video].
  ///
  /// • The embedded video audio ("Original") always comes first.
  /// • Remaining tracks are sorted: known languages first (in [_codeToLabel]
  ///   order), then any custom languages alphabetically.
  static List<AudioTrackOption> fromVideo(Video video) {
    final tracks = <AudioTrackOption>[];

    // 1. Always add the original embedded audio first
    tracks.add(
      const AudioTrackOption(
        code: '__original__',
        label: 'Original',
        isEmbedded: true,
      ),
    );

    final audioMap = video.audioTracks; // Map<String, String>
    if (audioMap.isEmpty) return tracks;

    // 2. Sort: known-order languages first, then custom alphabetically
    final knownOrder = _codeToLabel.keys.toList();
    final sorted = audioMap.entries.toList()
      ..sort((a, b) {
        final ia = knownOrder.indexOf(a.key.toLowerCase());
        final ib = knownOrder.indexOf(b.key.toLowerCase());
        if (ia == -1 && ib == -1) return a.key.compareTo(b.key);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });

    for (final entry in sorted) {
      final url = entry.value.trim();
      if (url.isEmpty) continue; // skip unresolved placeholders

      tracks.add(
        AudioTrackOption(
          code: entry.key,
          label: labelFor(entry.key),
          audioUrl: url,
        ),
      );
    }

    return tracks;
  }

  /// Determines the best default track to open with.
  ///
  /// Priority:
  /// 1. Explicit [preferredCode] if available in tracks.
  /// 2. User device locale match.
  /// 3. Falls back to the Original (embedded) track.
  static String pickDefault(
    List<AudioTrackOption> tracks, {
    String? preferredCode,
    String? deviceLocaleCode,
  }) {
    if (preferredCode != null) {
      final match = tracks.firstWhereOrNull((t) => t.code == preferredCode);
      if (match != null) return match.code;
    }

    if (deviceLocaleCode != null) {
      final localeMatch = tracks.firstWhereOrNull(
        (t) => t.code.toLowerCase() == deviceLocaleCode.toLowerCase(),
      );
      if (localeMatch != null) return localeMatch.code;
    }

    return '__original__';
  }
}

// Simple local firstWhereOrNull helper (mirrors the GetX extension)
extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
