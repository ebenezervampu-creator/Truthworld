class VideoResolution {
  VideoResolution({
    required this.quality,
    required this.width,
    required this.height,
    required this.bitrate,
    required this.size,
    required this.path,
  });

  factory VideoResolution.fromMap(Map<String, dynamic> map) {
    return VideoResolution(
      quality: map['quality'] ?? '',
      width: map['width'] ?? 0,
      height: map['height'] ?? 0,
      bitrate: map['bitrate'] ?? 0,
      size: map['size'] ?? 0,
      path: map['path'] ?? '',
    );
  }
  final String quality;
  final int width;
  final int height;
  final int bitrate;
  final int size;
  final String path;

  Map<String, dynamic> toMap() {
    return {
      'quality': quality,
      'width': width,
      'height': height,
      'bitrate': bitrate,
      'size': size,
      'path': path,
    };
  }
}
