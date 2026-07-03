import 'dart:typed_data';

abstract class AudioExtractorBase {
  Future<Uint8List> extractAudio(Uint8List videoBytes);
}

AudioExtractorBase getAudioExtractor() => throw UnsupportedError(
  'Cannot create an audio extractor without platform implementation.',
);
