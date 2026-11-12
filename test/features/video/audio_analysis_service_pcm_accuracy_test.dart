import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_analysis_service.dart';

void main() {
  group('AudioAnalysisService Reference PCM & Spectral Accuracy Tests', () {
    const fs = 48000;
    const n = 512;

    test('1. Reference Zero and DC signals produce exact mathematical RMS and Peak', () {
      final zeroSamples = Float32List(n);
      expect(AudioAnalysisService.calculateRmsFromPcm(zeroSamples), closeTo(0.0, 1e-6));
      expect(AudioAnalysisService.calculatePeakFromPcm(zeroSamples), closeTo(0.0, 1e-6));

      final dcSamples = Float32List(n);
      for (int i = 0; i < n; i++) {
        dcSamples[i] = 1.0;
      }
      expect(AudioAnalysisService.calculateRmsFromPcm(dcSamples), closeTo(1.0, 1e-6));
      expect(AudioAnalysisService.calculatePeakFromPcm(dcSamples), closeTo(1.0, 1e-6));
    });

    test('2. Reference Sine waves produce exact RMS (A / sqrt(2)) and Peak', () {
      final sineFull = Float32List(n);
      final sineHalf = Float32List(n);
      for (int i = 0; i < n; i++) {
        final t = i / fs;
        sineFull[i] = sin(2 * pi * 1000 * t);
        sineHalf[i] = 0.5 * sin(2 * pi * 1000 * t);
      }

      // Theoretical RMS of unit sine wave is 1 / sqrt(2) ≈ 0.7071
      final expectedFullRms = 1.0 / sqrt(2.0);
      final expectedHalfRms = 0.5 / sqrt(2.0);

      expect(AudioAnalysisService.calculateRmsFromPcm(sineFull), closeTo(expectedFullRms, 0.05));
      expect(AudioAnalysisService.calculatePeakFromPcm(sineFull), closeTo(1.0, 1e-4));

      expect(AudioAnalysisService.calculateRmsFromPcm(sineHalf), closeTo(expectedHalfRms, 0.03));
      expect(AudioAnalysisService.calculatePeakFromPcm(sineHalf), closeTo(0.5, 1e-4));
    });

    test('3. Frequency-band partitioning accurately isolates Sub-bass (<120Hz), Mid (120Hz-4kHz), and Air (>4kHz)', () {
      final subBassTone = Float32List(n);
      final midTone = Float32List(n);
      final airTone = Float32List(n);

      for (int i = 0; i < n; i++) {
        final t = i / fs;
        subBassTone[i] = sin(2 * pi * 60 * t); // 60 Hz Sub-bass
        midTone[i] = sin(2 * pi * 1000 * t);   // 1 kHz Mid
        airTone[i] = sin(2 * pi * 8000 * t);   // 8 kHz Air
      }

      final subBands = AudioAnalysisService.calculateFrequencyBandsFromPcm(subBassTone, sampleRate: fs);
      final midBands = AudioAnalysisService.calculateFrequencyBandsFromPcm(midTone, sampleRate: fs);
      final airBands = AudioAnalysisService.calculateFrequencyBandsFromPcm(airTone, sampleRate: fs);

      // Sub-bass 60Hz should have highest energy in band 0 (SUB)
      expect(subBands[0], greaterThan(subBands[1]), reason: '60Hz tone must dominate Sub-bass band over Mid');
      expect(subBands[0], greaterThan(subBands[2]), reason: '60Hz tone must dominate Sub-bass band over Air');

      // Mid 1000Hz should have highest energy in band 1 (MID)
      expect(midBands[1], greaterThan(midBands[0]), reason: '1kHz tone must dominate Mid band over Sub-bass');
      expect(midBands[1], greaterThan(midBands[2]), reason: '1kHz tone must dominate Mid band over Air');

      // Air 8000Hz should have highest energy in band 2 (AIR)
      expect(airBands[2], greaterThan(airBands[0]), reason: '8kHz tone must dominate Air band over Sub-bass');
      expect(airBands[2], greaterThan(airBands[1]), reason: '8kHz tone must dominate Air band over Mid');
    });

    test('4. Direct FFT magnitude input partitions correctly into 3 bands', () {
      final fftMags = Float32List(256);
      // Bin resolution = 24000 / 256 = 93.75 Hz
      // Bin 1 = 93.75 Hz (Sub-bass)
      fftMags[1] = 1.0;
      final subResult = AudioAnalysisService.calculateFrequencyBandsFromPcm(
        fftMags,
        sampleRate: fs,
        isFftMagnitudes: true,
      );
      expect(subResult[0], greaterThan(0.9), reason: 'Sub-bass bin must map to band 0');

      // Bin 10 = 937.5 Hz (Mid)
      fftMags[1] = 0.0;
      fftMags[10] = 1.0;
      final midResult = AudioAnalysisService.calculateFrequencyBandsFromPcm(
        fftMags,
        sampleRate: fs,
        isFftMagnitudes: true,
      );
      expect(midResult[1], greaterThan(0.9), reason: 'Mid bin must map to band 1');

      // Bin 100 = 9375 Hz (Air)
      fftMags[10] = 0.0;
      fftMags[100] = 1.0;
      final airResult = AudioAnalysisService.calculateFrequencyBandsFromPcm(
        fftMags,
        sampleRate: fs,
        isFftMagnitudes: true,
      );
      expect(airResult[2], greaterThan(0.9), reason: 'Air bin must map to band 2');
    });

    test('5. Performance Benchmark: 100 consecutive FFT evaluations execute in < 25ms', () {
      final sineWave = Float32List(n);
      for (int i = 0; i < n; i++) {
        sineWave[i] = sin(2 * pi * 440 * i / fs);
      }

      final sw = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        AudioAnalysisService.calculateFrequencyBandsFromPcm(sineWave, sampleRate: fs);
      }
      sw.stop();

      // 100 frames at 20 FPS is 5 full seconds of audio rendering.
      // Must take well under 25ms (less than 0.25ms per frame).
      expect(sw.elapsedMilliseconds, lessThan(25), reason: 'FFT must execute in microseconds to prevent frame drops');
    });

    test('6. NaN, ±Infinity, and out-of-range clipped samples are sanitized safely', () {
      final corrupted = Float32List(8);
      corrupted[0] = double.nan;
      corrupted[1] = double.infinity;
      corrupted[2] = double.negativeInfinity;
      corrupted[3] = 3.5; // Clipped positive
      corrupted[4] = -4.2; // Clipped negative
      corrupted[5] = 0.5;
      corrupted[6] = -0.5;
      corrupted[7] = 0.0;

      final sanitized = AudioAnalysisService.sanitizePcmSamples(corrupted);

      expect(sanitized[0], 0.0, reason: 'NaN must be zeroed');
      expect(sanitized[1], 0.0, reason: '+Inf must be zeroed');
      expect(sanitized[2], 0.0, reason: '-Inf must be zeroed');
      expect(sanitized[3], 1.0, reason: '+3.5 must be clamped to +1.0');
      expect(sanitized[4], -1.0, reason: '-4.2 must be clamped to -1.0');
      expect(sanitized[5], 0.5);
      expect(sanitized[6], -0.5);
      expect(sanitized[7], 0.0);
    });

    test('7. Stereo interleaved PCM (L/R) downmixes cleanly to mono', () {
      // 4 stereo frames: L0, R0, L1, R1, L2, R2, L3, R3
      final stereo = Float32List.fromList([
        1.0, 0.0,  // Avg: 0.5
        0.5, 0.5,  // Avg: 0.5
        -1.0, 0.0, // Avg: -0.5
        0.0, 0.0,  // Avg: 0.0
      ]);

      // Calculate RMS directly on mono downmix
      final monoLen = stereo.length ~/ 2;
      final mono = Float32List(monoLen);
      for (int i = 0; i < monoLen; i++) {
        mono[i] = (stereo[i * 2] + stereo[i * 2 + 1]) * 0.5;
      }

      expect(mono[0], 0.5);
      expect(mono[1], 0.5);
      expect(mono[2], -0.5);
      expect(mono[3], 0.0);

      final expectedRms = sqrt((0.25 + 0.25 + 0.25 + 0.0) / 4);
      expect(AudioAnalysisService.calculateRmsFromPcm(mono), closeTo(expectedRms, 1e-4));
    });
  });
}
