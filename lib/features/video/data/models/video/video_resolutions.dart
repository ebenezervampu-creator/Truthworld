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

  bool get is60Fps => fps >= 50 || label.toLowerCase().contains('60');

  Map<String, dynamic> toMap() => {
    'label': label,
    'url': url,
    'width': width,
    'height': height,
    'bitrate': bitrate,
    'fps': fps,
  };
}

/// Compatibility wrapper for resolution paths.
class ResolutionV2 {
  ResolutionV2(this.path);
  final String path;
}
