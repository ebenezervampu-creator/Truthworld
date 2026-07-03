import 'dart:typed_data';
import 'audio_extractor_base.dart';

class AudioExtractorImpl implements AudioExtractorBase {
  @override
  Future<Uint8List> extractAudio(Uint8List videoBytes) async {
    // Native fallback simply returns original bytes
    return videoBytes;
  }
}

AudioExtractorBase getAudioExtractor() => AudioExtractorImpl();
