class ShareUtils {
  const ShareUtils._();

  static String detectType({
    required String url,
    String? type,
    double? clipStartTime,
    double? clipEndTime,
    Duration? currentPosition,
    int? durationMs,
    int? subscriberCount,
    String? handle,
    int? videoCount,
    String? subtitle,
    int? followerCount,
  }) {
    if (type != null) return type;
    if (clipStartTime != null ||
        clipEndTime != null ||
        url.contains('clipTitle') ||
        (url.contains('start=') && url.contains('end='))) {
      return 'clip';
    }
    if (url.contains('/claim')) {
      return 'claim';
    }
    if (currentPosition != null ||
        durationMs != null ||
        url.contains('/watch')) {
      return 'video';
    }
    if (subscriberCount != null ||
        url.contains('/channel/') ||
        (handle != null && handle.startsWith('@'))) {
      return 'channel';
    }
    if (videoCount != null &&
        (url.contains('/playlist') ||
            (subtitle?.toLowerCase().contains('playlist') ?? false))) {
      return 'playlist';
    }
    if (followerCount != null ||
        url.contains('/topic/') ||
        url.contains('/T/')) {
      return 'topic';
    }
    return 'video'; // Default fallback
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  static String formatMsDuration(int ms) {
    return formatDuration(Duration(milliseconds: ms));
  }

  static String formatCount(int count) {
    if (count < 0) return '0';
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}B';
    } else if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return count.toString();
  }

  static String extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v']!;
      }
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    }
    return 'video_id';
  }

  static String getShareUrl({
    required String url,
    required bool startAtChecked,
    Duration? currentPosition,
  }) {
    if (!startAtChecked || currentPosition == null) {
      return url;
    }
    final seconds = currentPosition.inSeconds;
    if (url.contains('?')) {
      return '$url&t=$seconds';
    } else {
      return '$url?t=$seconds';
    }
  }

  static String getIframeCode({
    required String url,
    required bool showControls,
    required bool privacyMode,
    required bool startAtChecked,
    Duration? currentPosition,
  }) {
    final videoId = extractVideoId(url);
    var embedUrl = 'https://www.truthworld.in/embed/$videoId';
    final params = <String>[];
    if (!showControls) params.add('controls=0');
    if (privacyMode) params.add('privacy=1');
    if (startAtChecked && currentPosition != null) {
      params.add('start=${currentPosition.inSeconds}');
    }
    if (params.isNotEmpty) {
      embedUrl += '?${params.join('&')}';
    }
    return '<iframe width="560" height="315" src="$embedUrl" title="TruthWorld video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>';
  }
}
