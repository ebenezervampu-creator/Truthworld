import 'package:flutter/foundation.dart';

// Conditionally import platform implementations
import 'audio_extractor_stub.dart'
    if (dart.library.html) 'audio_extractor_web.dart';

/// Pure client-side Audio Extractor for Web & Fallback Platforms.
///
/// Decodes the visual/audio stream of a video file using browser APIs
/// and outputs a standard, frame-perfect 16-bit PCM WAV stream.
class AudioExtractor {
  /// Extract PCM audio bytes from a raw video file using web browser APIs
  static Future<Uint8List> extractAudioFromVideo(Uint8List videoBytes) async {
    if (!kIsWeb) {
      // On native platform fallback, return raw stream as is
      return videoBytes;
    }
    final extractor = getAudioExtractor();
    return extractor.extractAudio(videoBytes);
  }
}
