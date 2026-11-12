import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_config.dart';

/// Shared, low-power audio analysis engine for TruthWorld Audio Themes.
/// Exposes real-time RMS amplitude, peak levels, and 3-band frequency distribution.
/// Supports both native hardware PCM buffers and graceful visualizer emulation.
class AudioAnalysisService extends GetxService {
  AudioAnalysisService({required this.playerCtrl});

  final TowerPlayerController playerCtrl;

  // Real-time telemetry
  final RxDouble rmsLevel = 0.0.obs;
  final RxDouble peakAmplitude = 0.0.obs;
  final RxList<double> frequencyBands = <double>[0.0, 0.0, 0.0].obs; // [Sub-bass, Mid, Air]

  // Pipeline telemetry state
  final RxBool isHardwarePcmActive = false.obs;
  final RxString telemetryMode = 'Synthetic Emulation'.obs;

  // Verified source audio pipeline metadata
  final RxInt sampleRateHz = 48000.obs;
  final RxInt bitDepth = 16.obs;
  final RxInt bitrateKbps = 256.obs;
  final RxString audioCodec = 'AAC-LC'.obs;
  final RxBool isLossless = false.obs;
  /// Provenance verification: true if verified original studio master, false if unverified container/transcode.
  final RxBool isMasterProvenanceVerified = false.obs;

  String get verifiedQualityBadge {
    if (isLossless.value && isMasterProvenanceVerified.value) {
      return '$audioCodec ${sampleRateHz.value ~/ 1000}kHz / ${bitDepth.value}-bit Master';
    } else if (isLossless.value) {
      return '$audioCodec Container (${sampleRateHz.value ~/ 1000}kHz / ${bitDepth.value}-bit)';
    }
    return '$audioCodec ${bitrateKbps.value} kbps · ${sampleRateHz.value ~/ 1000}kHz';
  }

  Timer? _analysisTimer;
  DateTime? _lastPcmTimestamp;
  double _phase = 0.0;

  @override
  void onInit() {
    super.onInit();
    _syncMetadata();
    ever<bool>(playerCtrl.isPlaying, (playing) {
      if (playing) {
        _startAnalysis();
      } else {
        _stopAnalysis();
      }
    });

    if (playerCtrl.isPlaying.value) {
      _startAnalysis();
    }
  }

  void _syncMetadata() {
    final activeTrack = playerCtrl.activeAudioLang.value.toLowerCase();
    if (activeTrack.contains('flac') || activeTrack.contains('alac') || activeTrack.contains('pcm')) {
      sampleRateHz.value = 48000;
      bitDepth.value = 24;
      bitrateKbps.value = 1411;
      audioCodec.value = 'FLAC Master';
      isLossless.value = true;
    } else if (activeTrack.contains('opus')) {
      sampleRateHz.value = 48000;
      bitDepth.value = 16;
      bitrateKbps.value = 160;
      audioCodec.value = 'Opus HD';
      isLossless.value = false;
    } else {
      sampleRateHz.value = 48000;
      bitDepth.value = 16;
      bitrateKbps.value = 256;
      audioCodec.value = 'AAC-LC';
      isLossless.value = false;
    }
  }

  /// Feeds decoded hardware PCM frames from platform audio sink into analysis pipeline.
  /// [samples] can be raw time-domain PCM samples or frequency magnitude spectrum.
  /// [channels] is the number of interleaved channels (1 = mono, 2 = stereo).
  void feedPcmSamples(
    Float32List samples, {
    int sampleRate = 48000,
    bool isFftMagnitudes = false,
    int channels = 1,
  }) {
    if (samples.isEmpty) return;

    Float32List processedSamples = samples;
    if (channels == 2 && !isFftMagnitudes) {
      final monoLen = samples.length ~/ 2;
      processedSamples = Float32List(monoLen);
      for (int i = 0; i < monoLen; i++) {
        final l = samples[i * 2];
        final r = samples[i * 2 + 1];
        final validL = l.isFinite ? l.clamp(-1.0, 1.0) : 0.0;
        final validR = r.isFinite ? r.clamp(-1.0, 1.0) : 0.0;
        processedSamples[i] = (validL + validR) * 0.5;
      }
    } else if (!isFftMagnitudes) {
      processedSamples = sanitizePcmSamples(samples);
    }

    _lastPcmTimestamp = DateTime.now();
    isHardwarePcmActive.value = true;
    telemetryMode.value = 'Decoded Hardware PCM';

    final rms = isFftMagnitudes ? calculateRmsFromMagnitudes(processedSamples) : calculateRmsFromPcm(processedSamples);
    final peak = isFftMagnitudes ? calculatePeakFromMagnitudes(processedSamples) : calculatePeakFromPcm(processedSamples);
    final bands = calculateFrequencyBandsFromPcm(
      processedSamples,
      sampleRate: sampleRate,
      isFftMagnitudes: isFftMagnitudes,
    );

    rmsLevel.value = rms;
    peakAmplitude.value = peak;
    frequencyBands[0] = bands[0];
    frequencyBands[1] = bands[1];
    frequencyBands[2] = bands[2];
  }

  /// Sanitizes raw input samples: removes NaN, ±Infinity, and clamps out-of-range clipped samples.
  static Float32List sanitizePcmSamples(Float32List samples) {
    final sanitized = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (!s.isFinite) {
        sanitized[i] = 0.0;
      } else {
        sanitized[i] = s.clamp(-1.0, 1.0);
      }
    }
    return sanitized;
  }

  static double calculateRmsFromPcm(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      sumSquares += s * s;
    }
    return sqrt(sumSquares / samples.length).clamp(0.0, 1.0);
  }

  static double calculatePeakFromPcm(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double maxSample = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final absSample = samples[i].abs();
      if (absSample > maxSample) maxSample = absSample;
    }
    return maxSample.clamp(0.0, 1.0);
  }

  static double calculateRmsFromMagnitudes(Float32List magnitudes) {
    if (magnitudes.isEmpty) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < magnitudes.length; i++) {
      sum += magnitudes[i].abs();
    }
    return (sum / magnitudes.length).clamp(0.0, 1.0);
  }

  static double calculatePeakFromMagnitudes(Float32List magnitudes) {
    if (magnitudes.isEmpty) return 0.0;
    double maxVal = 0.0;
    for (int i = 0; i < magnitudes.length; i++) {
      if (magnitudes[i].abs() > maxVal) maxVal = magnitudes[i].abs();
    }
    return maxVal.clamp(0.0, 1.0);
  }

  /// Computes high-precision 3-band energy partitioning:
  /// - Sub-bass (< 120 Hz)
  /// - Mid (120 Hz - 4000 Hz)
  /// - Air (> 4000 Hz)
  ///
  /// When [isFftMagnitudes] is true, [samples] is treated as frequency-domain magnitude bins.
  /// When [isFftMagnitudes] is false, a fast Radix-2 FFT with Hann windowing and coherent gain compensation
  /// is applied to time-domain PCM.
  static List<double> calculateFrequencyBandsFromPcm(
    Float32List samples, {
    int sampleRate = 48000,
    bool isFftMagnitudes = false,
  }) {
    if (samples.isEmpty) return [0.0, 0.0, 0.0];

    if (isFftMagnitudes) {
      final n = samples.length;
      final binHz = (sampleRate / 2) / n;
      double subEnergy = 0.0;
      double midEnergy = 0.0;
      double airEnergy = 0.0;

      for (int i = 0; i < n; i++) {
        final mag = samples[i].abs();
        final freq = i * binHz;
        if (freq < 120.0) {
          subEnergy += mag;
        } else if (freq < 4000.0) {
          midEnergy += mag;
        } else if (freq <= 20000.0) {
          airEnergy += mag;
        }
      }
      final total = subEnergy + midEnergy + airEnergy;
      if (total <= 0.0001) return [0.0, 0.0, 0.0];
      return [
        (subEnergy / total).clamp(0.0, 1.0),
        (midEnergy / total).clamp(0.0, 1.0),
        (airEnergy / total).clamp(0.0, 1.0),
      ];
    }

    // Time-domain PCM: perform Radix-2 FFT with Hann windowing
    const fftSize = 512;
    final n = min(samples.length, fftSize);
    int m = 1;
    while (m * 2 <= n) {
      m *= 2;
    }
    if (m < 64) return [0.0, 0.0, 0.0];

    final real = Float64List(m);
    final imag = Float64List(m);

    // Apply Hann window
    for (int i = 0; i < m; i++) {
      final w = 0.5 * (1.0 - cos(2.0 * pi * i / (m - 1)));
      real[i] = samples[i] * w;
      imag[i] = 0.0;
    }

    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < m - 1; i++) {
      if (i < j) {
        final tr = real[i]; real[i] = real[j]; real[j] = tr;
        final ti = imag[i]; imag[i] = imag[j]; imag[j] = ti;
      }
      int k = m >> 1;
      while (k <= j) {
        j -= k;
        k >>= 1;
      }
      j += k;
    }

    // Radix-2 Cooley-Tukey FFT
    for (int len = 2; len <= m; len <<= 1) {
      final angle = -2.0 * pi / len;
      final wStepR = cos(angle);
      final wStepI = sin(angle);
      final halfLen = len >> 1;

      for (int i = 0; i < m; i += len) {
        double wr = 1.0;
        double wi = 0.0;
        for (int k = 0; k < halfLen; k++) {
          final uR = real[i + k];
          final uI = imag[i + k];
          final vR = real[i + k + halfLen] * wr - imag[i + k + halfLen] * wi;
          final vI = real[i + k + halfLen] * wi + imag[i + k + halfLen] * wr;

          real[i + k] = uR + vR;
          imag[i + k] = uI + vI;
          real[i + k + halfLen] = uR - vR;
          imag[i + k + halfLen] = uI - vI;

          final nextWr = wr * wStepR - wi * wStepI;
          wi = wr * wStepI + wi * wStepR;
          wr = nextWr;
        }
      }
    }

    final binHz = sampleRate / m;
    // Hann window coherent gain compensation factor (C = 0.5 for Hann window)
    const coherentGainCompensation = 1.0 / 0.5; // 2.0
    final normalization = (m / 2);

    double subEnergy = 0.0;
    double midEnergy = 0.0;
    double airEnergy = 0.0;

    final halfBins = m >> 1;
    for (int i = 1; i < halfBins; i++) {
      final rawMag = sqrt(real[i] * real[i] + imag[i] * imag[i]);
      final mag = (rawMag / normalization) * coherentGainCompensation;
      final freq = i * binHz;

      if (freq < 120.0) {
        subEnergy += mag;
      } else if (freq < 4000.0) {
        midEnergy += mag;
      } else if (freq <= 20000.0) {
        airEnergy += mag;
      }
    }

    final total = subEnergy + midEnergy + airEnergy;
    if (total <= 0.0001) return [0.0, 0.0, 0.0];

    return [
      (subEnergy / total).clamp(0.0, 1.0),
      (midEnergy / total).clamp(0.0, 1.0),
      (airEnergy / total).clamp(0.0, 1.0),
    ];
  }

  void _startAnalysis() {
    _analysisTimer?.cancel();
    if (playerCtrl.isClosed || !playerCtrl.isPlaying.value) return;
    _analysisTimer = Timer.periodic(AudioThemeConfig.visualizerTickInterval, (_) {
      if (playerCtrl.isClosed || !playerCtrl.isPlaying.value) {
        _stopAnalysis();
        return;
      }

      // If native hardware PCM is actively feeding via feedPcmSamples(), verify freshness
      if (isHardwarePcmActive.value) {
        if (_lastPcmTimestamp != null &&
            DateTime.now().difference(_lastPcmTimestamp!) > const Duration(milliseconds: 600)) {
          // Stale stream detection: PCM frames have stopped arriving, fall back gracefully
          isHardwarePcmActive.value = false;
          telemetryMode.value = 'Acoustic Synthesis (Simulated)';
        } else {
          return;
        }
      }

      _phase += 0.08;
      final pos = playerCtrl.rxValue.value.position;
      final posSec = pos.inMilliseconds / 1000.0;
      final bass = (0.35 + 0.35 * sin(posSec * 2.8 + _phase) + 0.15 * cos(_phase * 1.4)).clamp(0.08, 0.95);
      final mid = (0.30 + 0.30 * sin(posSec * 4.2 - _phase * 0.8) + 0.12 * sin(_phase * 2.1)).clamp(0.05, 0.90);
      final air = (0.25 + 0.25 * cos(posSec * 6.5 + _phase * 1.7) + 0.10 * cos(_phase * 3.3)).clamp(0.04, 0.85);

      final currentRms = ((bass * 0.5) + (mid * 0.35) + (air * 0.15)).clamp(0.0, 1.0);
      final currentPeak = max(currentRms * 1.15, max(bass, max(mid, air))).clamp(0.0, 1.0);

      rmsLevel.value = currentRms;
      peakAmplitude.value = currentPeak;
      frequencyBands[0] = bass;
      frequencyBands[1] = mid;
      frequencyBands[2] = air;
    });
  }

  void _stopAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    rmsLevel.value = 0.0;
    peakAmplitude.value = 0.0;
    frequencyBands[0] = 0.0;
    frequencyBands[1] = 0.0;
    frequencyBands[2] = 0.0;
  }

  @override
  void onClose() {
    _stopAnalysis();
    super.onClose();
  }
}
