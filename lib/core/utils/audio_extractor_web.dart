// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist

import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:truthworld/core/utils/audio_extractor_base.dart';
import 'package:universal_html/html.dart' as html;

class AudioExtractorImpl implements AudioExtractorBase {
  static const String _tag = 'AudioExtractorWeb';

  @override
  Future<Uint8List> extractAudio(Uint8List videoBytes) async {
    try {
      debugPrint(
        '[$_tag] Initializing browser AudioContext for audio decoding...',
      );
      final jsWindow = html.window;
      final Object? audioContextConstructor =
          js_util.getProperty(jsWindow, 'AudioContext') ??
          js_util.getProperty(jsWindow, 'webkitAudioContext');
      if (audioContextConstructor == null) {
        throw Exception('AudioContext is not supported in this browser.');
      }
      final dynamic audioCtx = js_util.callConstructor(
        audioContextConstructor,
        [],
      );

      final arrayBuffer = videoBytes.buffer;

      debugPrint('[$_tag] Decoding video track streams natively...');
      final promise = audioCtx.decodeAudioData(arrayBuffer);
      final dynamic audioBuffer = await js_util.promiseToFuture<dynamic>(
        promise,
      );

      final numChannels = audioBuffer.numberOfChannels as int? ?? 1;
      final sampleRate = (audioBuffer.sampleRate as num?)?.toInt() ?? 44100;
      final numSamples = audioBuffer.length as int? ?? 0;

      debugPrint(
        '[$_tag] Decoded video audio stream: $numChannels channels, $sampleRate Hz, $numSamples samples.',
      );

      final channels = <Float32List>[];
      for (var c = 0; c < numChannels; c++) {
        final channelData = audioBuffer.getChannelData(c) as Float32List;
        channels.add(channelData);
      }

      debugPrint('[$_tag] Encoding PCM samples into 16-bit WAV file format...');
      final wavBytes = _encodeWav(channels, sampleRate);

      audioCtx.close();
      debugPrint('[$_tag] Decoded WAV extraction complete successfully!');
      return wavBytes;
    } catch (e) {
      debugPrint(
        '[$_tag] Client-side audio extraction error: $e. Returning raw upload stream as fallback.',
      );
      return videoBytes;
    }
  }

  Uint8List _encodeWav(List<Float32List> channels, int sampleRate) {
    final numChannels = channels.length;
    final numSamples = channels[0].length;
    const numBytesPerSample = 2; // 16-bit PCM
    final blockAlign = numChannels * numBytesPerSample;
    final byteRate = sampleRate * blockAlign;
    final subChunk2Size = numSamples * blockAlign;
    final chunkSize = 36 + subChunk2Size;

    final header = ByteData(44);

    // "RIFF" header tag
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);

    header.setUint32(4, chunkSize, Endian.little);

    // "WAVE" format tag
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);

    // "fmt " subchunk tag
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);

    header.setUint32(16, 16, Endian.little); // Format chunk size (16)
    header.setUint16(
      20,
      1,
      Endian.little,
    ); // Compression code: 1 = uncompressed PCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(
      34,
      numBytesPerSample * 8,
      Endian.little,
    ); // Bits per sample (16)

    // "data" subchunk tag
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);

    header.setUint32(40, subChunk2Size, Endian.little);

    final wavBytes = Uint8List(44 + subChunk2Size);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());

    final wavData = ByteData.view(wavBytes.buffer, 44);
    var offset = 0;

    for (var i = 0; i < numSamples; i++) {
      for (var c = 0; c < numChannels; c++) {
        var sample = channels[c][i];
        if (sample < -1.0) sample = -1.0;
        if (sample > 1.0) sample = 1.0;

        final intSample = (sample < 0)
            ? (sample * 32768).toInt()
            : (sample * 32767).toInt();
        wavData.setInt16(offset, intSample, Endian.little);
        offset += 2;
      }
    }

    return wavBytes;
  }
}

AudioExtractorBase getAudioExtractor() => AudioExtractorImpl();
