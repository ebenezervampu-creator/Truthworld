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
  });

  factory VideoResolutionV2.fromMap(Map<String, dynamic> map) =>
      VideoResolutionV2(
        label: map['label'] ?? '',
        url: map['url'] ?? '',
        width: map['width'] ?? 0,
        height: map['height'] ?? 0,
        bitrate: map['bitrate'] ?? 0,
      );

  final String label; // e.g., "1080p", "720p"
  final String url;
  final int width;
  final int height;
  final int bitrate;

  Map<String, dynamic> toMap() => {
    'label': label,
    'url': url,
    'width': width,
    'height': height,
    'bitrate': bitrate,
  };
}

/// Compatibility wrapper for resolution paths.
class ResolutionV2 {
  ResolutionV2(this.path);
  final String path;
}
