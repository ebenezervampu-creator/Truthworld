/// Status of a video in the upload, moderation, and publication pipeline.
enum VideoStatus {
  uploading,
  processing, // Transcoding to HLS/Dash
  ready, // Published
  flagged, // Under review
  deleted,
  private,
  scheduled,
  rejected, // Failed moderation — content violates guidelines
  pending_review, // Awaiting manual admin review (ambiguous moderation)
  draft, // Draft video
}

/// Adaptive bitrate resolution model containing stream URL, dimensions, and bitrate.
class VideoResolutionV2 {
  VideoResolutionV2({
    required this.label,
    required this.url,
    required this.width,
    required this.height,
    required this.bitrate,
    this.fps = 30,
    this.isSynthetic = false,
  });

  factory VideoResolutionV2.fromMap(Map<String, dynamic> map) {
    final labelStr = map['label'] as String? ?? '';
    final parsedFps = (map['fps'] as num?)?.toInt() ?? inferFpsFromLabel(labelStr);
    return VideoResolutionV2(
      label: labelStr,
      url: map['url'] as String? ?? '',
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      bitrate: (map['bitrate'] as num?)?.toInt() ?? 0,
      fps: parsedFps,
      isSynthetic: map['isSynthetic'] as bool? ?? false,
    );
  }

  /// Extracts target framerate from label strings (e.g. "1080p60" -> 60, "720p" -> 30)
  static int inferFpsFromLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('p60') ||
        lower.contains('60fps') ||
        lower.contains('60 fps') ||
        lower.endsWith('60')) {
      return 60;
    }
    if (lower.contains('p50') || lower.contains('50fps')) return 50;
    if (lower.contains('p120') || lower.contains('120fps')) return 120;
    return 30;
  }

  final String label; // e.g., "1080p", "1080p60", "720p60"
  final String url;
  final int width;
  final int height;
  final int bitrate;
  final int fps;
  final bool isSynthetic;

  bool get is60Fps => fps >= 50 || label.toLowerCase().contains('60');

  /// Standard OTT resolution tiers (descending order).
  static const List<Map<String, dynamic>> standardTiers = [
    {'height': 1080, 'width': 1920, 'label': '1080p', 'bitrate': 4500000},
    {'height': 720, 'width': 1280, 'label': '720p', 'bitrate': 2500000},
    {'height': 480, 'width': 854, 'label': '480p', 'bitrate': 1200000},
    {'height': 360, 'width': 640, 'label': '360p', 'bitrate': 800000},
    {'height': 240, 'width': 426, 'label': '240p', 'bitrate': 400000},
    {'height': 144, 'width': 256, 'label': '144p', 'bitrate': 200000},
  ];

  /// Guarantees that the resolution ladder is complete down to 144p.
  /// If higher resolutions exist (e.g. 1080p and 720p), this ensures lower standard
  /// tiers (480p, 360p, 240p, 144p) are NEVER missing.
  /// Any missing tier is synthesized with the lowest available stream URL or [fallbackUrl].
  static List<VideoResolutionV2> ensureCompleteLadder(
    List<VideoResolutionV2> existing, {
    required String fallbackUrl,
  }) {
    final validExisting = existing.where((r) => r.url.trim().isNotEmpty).toList();

    // Determine the best stream URL to use for missing tiers:
    // 1. Lowest available existing stream URL <= 720p (saves bandwidth for mobile)
    // 2. Lowest available existing stream URL
    // 3. fallbackUrl
    var resolvedFallbackUrl = fallbackUrl.trim();
    if (validExisting.isNotEmpty) {
      final sdOrHd = validExisting.where((r) => r.height <= 720 && r.height > 0).toList();
      if (sdOrHd.isNotEmpty) {
        sdOrHd.sort((a, b) => a.height.compareTo(b.height));
        resolvedFallbackUrl = sdOrHd.first.url;
      } else {
        final sorted = [...validExisting]..sort((a, b) => a.height.compareTo(b.height));
        resolvedFallbackUrl = sorted.first.url;
      }
    }

    if (validExisting.isEmpty) {
      return const [];
    }

    final result = List<VideoResolutionV2>.from(validExisting);

    // Determine highest resolution present — never synthesize above the authentic ceiling
    final maxHeight = validExisting.map((r) => r.height).fold(0, (a, b) => a > b ? a : b);
    final targetMax = maxHeight;

    if (targetMax > 0) {
      for (final tier in standardTiers) {
        final tierHeight = tier['height'] as int;
        final tierLabel = tier['label'] as String;

        // Only add tiers <= targetMax (strictly respect native source ceiling)
        if (tierHeight <= targetMax) {
          final exists = result.any(
            (r) =>
                r.height == tierHeight ||
                r.label.toLowerCase() == tierLabel.toLowerCase() ||
                r.label.toLowerCase().startsWith('${tierHeight}p'),
          );
          if (!exists && resolvedFallbackUrl.isNotEmpty) {
            result.add(
              VideoResolutionV2(
                label: tierLabel,
                url: resolvedFallbackUrl,
                width: tier['width'] as int,
                height: tierHeight,
                bitrate: tier['bitrate'] as int,
                isSynthetic: true,
              ),
            );
          }
        }
      }
    }

    // Sort descending by height, then fps
    result.sort((a, b) {
      final cmp = b.height.compareTo(a.height);
      if (cmp != 0) return cmp;
      return b.fps.compareTo(a.fps);
    });

    return result;
  }

  Map<String, dynamic> toMap() => {
    'label': label,
    'url': url,
    'width': width,
    'height': height,
    'bitrate': bitrate,
    'fps': fps,
    'isSynthetic': isSynthetic,
  };
}

/// Compatibility wrapper for resolution paths.
class ResolutionV2 {
  ResolutionV2(this.path);
  final String path;
}
