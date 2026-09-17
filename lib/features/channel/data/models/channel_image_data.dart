import 'dart:typed_data';

class ImageData {
  ImageData({
    required this.bytes,
    required this.name,
    required this.size,
    required this.aspectRatio,
  });
  final Uint8List bytes;
  final String name;
  final int size;
  final double aspectRatio;
}
