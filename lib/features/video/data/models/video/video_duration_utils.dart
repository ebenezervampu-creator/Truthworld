/// Utility methods for parsing and formatting video playback durations.
class VideoDurationUtils {
  const VideoDurationUtils._();

  /// Parses diverse duration inputs (Duration, int ms/seconds, double, string 'mm:ss' / 'hh:mm:ss') into a [Duration].
  static Duration parseDuration(dynamic duration) {
    if (duration is Duration) return duration;
    if (duration == null) return Duration.zero;
    if (duration is int) {
      if (duration > 100000) {
        return Duration(milliseconds: duration);
      }
      return Duration(seconds: duration);
    }
    if (duration is double) {
      return Duration(seconds: duration.toInt());
    }
    if (duration is String) {
      final str = duration.trim();
      if (str.isEmpty) return Duration.zero;
      final parts = str.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return Duration(minutes: m, seconds: s);
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        return Duration(hours: h, minutes: m, seconds: s);
      } else {
        final val = int.tryParse(str);
        if (val != null) {
          if (val > 100000) return Duration(milliseconds: val);
          return Duration(seconds: val);
        }
      }
    }
    return Duration.zero;
  }

  /// Formats a [Duration] into standard 'mm:ss' or 'hh:mm:ss' format.
  static String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return '${twoDigits(d.inHours)}:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
