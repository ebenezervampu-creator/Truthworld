// ============================================================
// adaptive_bitrate_controller.dart
// Industry-standard ABR engine for Flutter Web
// Implements: BOLA-inspired + Throughput-based hybrid ABR
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:universal_html/js.dart' as js;
import 'package:video_player/video_player.dart';

/// Represents a single resolution tier in the quality ladder
class ResolutionTier {
  // Minimum bandwidth required (kbps) to sustain

  const ResolutionTier({
    required this.label,
    required this.url,
    required this.height,
    required this.bitrate,
    required this.minBandwidth,
  });

  /// Factory to normalize and convert a VideoResolutionV2 into a ResolutionTier.
  /// Handles bps vs kbps conversion automatically and calculates sustainable minBandwidth.
  factory ResolutionTier.fromVideoResolution(VideoResolutionV2 v) {
    final int kbps;
    if (v.bitrate > 50000) {
      // Bitrate was specified in bps (e.g. 4,500,000 for 1080p) -> convert to kbps (4500)
      kbps = (v.bitrate / 1000).round();
    } else if (v.bitrate > 0) {
      kbps = v.bitrate;
    } else {
      kbps = defaultBitrateForHeight(v.height);
    }

    return ResolutionTier(
      label: v.label,
      url: v.url,
      height: v.height,
      bitrate: kbps,
      minBandwidth: (kbps * 1.2).toInt(),
    );
  }

  static int defaultBitrateForHeight(int height) {
    if (height >= 2160) return 15000;
    if (height >= 1440) return 10000;
    if (height >= 1080) return 5000;
    if (height >= 1040) return 4500;
    if (height >= 720) return 2500;
    if (height >= 480) return 1000;
    if (height >= 360) return 600;
    if (height >= 240) return 300;
    return 100;
  }
  final String label; // e.g. "1080p", "720p"
  final String url; // HLS/DASH segment URL
  final int height; // Vertical pixels
  final int bitrate; // Target bitrate in kbps
  final int minBandwidth;

  /// Standard OTT resolution ladder (matches standard OTT encoding specs)
  static List<ResolutionTier> get defaultLadder => [
    const ResolutionTier(
      label: '144p',
      url: '',
      height: 144,
      bitrate: 100,
      minBandwidth: 150,
    ),
    const ResolutionTier(
      label: '240p',
      url: '',
      height: 240,
      bitrate: 300,
      minBandwidth: 400,
    ),
    const ResolutionTier(
      label: '360p',
      url: '',
      height: 360,
      bitrate: 600,
      minBandwidth: 800,
    ),
    const ResolutionTier(
      label: '480p',
      url: '',
      height: 480,
      bitrate: 1000,
      minBandwidth: 1200,
    ),
    const ResolutionTier(
      label: '720p',
      url: '',
      height: 720,
      bitrate: 2500,
      minBandwidth: 3000,
    ),
    const ResolutionTier(
      label: '1040p',
      url: '',
      height: 1040,
      bitrate: 4500,
      minBandwidth: 5200,
    ),
    const ResolutionTier(
      label: '1080p',
      url: '',
      height: 1080,
      bitrate: 5000,
      minBandwidth: 6000,
    ),
    const ResolutionTier(
      label: '1440p',
      url: '',
      height: 1440,
      bitrate: 10000,
      minBandwidth: 12000,
    ),
    const ResolutionTier(
      label: '2160p',
      url: '',
      height: 2160,
      bitrate: 15000,
      minBandwidth: 18000,
    ),
  ];

}

/// Playback state machine — industry standard FSM
enum PlaybackState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  stalled, // Network stall, attempting recovery
  error,
  ended,
}

/// Network quality tier classification
enum NetworkQuality {
  offline, // < 50 kbps
  terrible, // 50–300 kbps
  poor, // 300–800 kbps
  fair, // 800–2000 kbps
  good, // 2–5 Mbps
  excellent, // > 5 Mbps
}

/// ABR decision record for analytics
class AbrDecision {
  AbrDecision({
    required this.timestamp,
    required this.fromTierIndex,
    required this.toTierIndex,
    required this.measuredBandwidth,
    required this.reason,
  });
  final DateTime timestamp;
  final int fromTierIndex;
  final int toTierIndex;
  final double measuredBandwidth;
  final String reason;
}

/// Core ABR Controller
/// Uses a hybrid BOLA + Throughput approach:
///   - Throughput: measures real download speed
///   - Buffer occupancy: prevents unnecessary downgrades
///   - Hysteresis: prevents thrashing (rapid up/down switches)
///   - Safety margin: 80% of measured bandwidth to handle fluctuations
class AdaptiveBitrateController extends BaseController {
  // ── State ─────────────────────────────────────────────────
  final Rx<PlaybackState> playbackState = PlaybackState.idle.obs;
  final RxInt currentTierIndex = 3.obs; // Start at 480p (tier 3) for better UX
  final Rx<NetworkQuality> networkQuality = NetworkQuality.good.obs;
  final RxDouble measuredBandwidthKbps = 0.0.obs;
  final RxDouble bufferHealthSeconds = 0.0.obs;
  final RxBool isAutoMode = true.obs;
  final RxString stallReason = ''.obs;
  final RxInt switchCount = 0.obs;

  /// Callback when ABR decision requires a quality switch. bool isManual is true
  /// if the change was triggered by manual user selection.
  void Function(int index, bool isManual)? onTierChanged;

  // ── Configuration ─────────────────────────────────────────
  List<ResolutionTier> resolutionLadder = [];
  VideoPlayerController? _vpc;
  int? maxHeightCap;

  // ABR tuning constants (optimized for smooth progressive MP4 and HLS playback)
  static const double _bandwidthSafetyFactor = 0.80; // Use 80% of measured BW
  static const double _upgradeHysteresisFactor =
      1.25; // Need 25% more than tier BW to upgrade (prevents premature jumping)
  static const double _downgradeHysteresisFactor =
      0.70; // Must drop 30% below tier to downgrade (prevents oscillation on minor network dips)
  static const double _minBufferToUpgrade =
      15.0; // Seconds of buffer before allowing automatic upgrade (smooth playback buffer cushion)
  static const double _panicBufferLevel =
      1.0; // Drop to lowest tier only if buffer < 1s and outside startup grace
  static const int _measurementWindowCount =
      5; // Rolling average over 5 measurements
  static const Duration _startupGracePeriod = Duration(seconds: 15);
  static const Duration _minDwellDuration = Duration(seconds: 45);

  // ── Internal state ─────────────────────────────────────────
  final List<double> _bandwidthHistory = [];
  Timer? _abrTimer;
  Timer? _bandwidthProbeTimer;
  Timer? _stallDetectionTimer;
  DateTime? _lastDownloadStart;
  int _lastDownloadBytes = 0;
  Duration _lastKnownPosition = Duration.zero;
  DateTime _lastPositionUpdate = DateTime.now();
  DateTime _playbackStartTime = DateTime.now();
  DateTime _lastTierSwitchTime = DateTime.now();
  final List<AbrDecision> _decisionHistory = [];
  bool _isFirstDecision = true;

  // ── Public API ─────────────────────────────────────────────

  void initialize({
    required List<ResolutionTier> ladder,
    required VideoPlayerController vpc,
    int? maxHeightCap,
  }) {
    _playbackStartTime = DateTime.now();
    _lastTierSwitchTime = DateTime.now();
    this.maxHeightCap = maxHeightCap;
    resolutionLadder = ladder;
    _vpc = vpc;

    // Initial Bandwidth Hint from Browser
    final hint = _getInitialBandwidthHint();
    if (hint > 0) {
      _addBandwidthSample(hint);
    }

    // We keep the current tier or start as high as hint allows
    if (ladder.isNotEmpty) {
      // SAFETY: Clamp default currentTierIndex to new ladder bounds immediately
      currentTierIndex.value = currentTierIndex.value.clamp(
        0,
        ladder.length - 1,
      );
      _runAbrDecision(forceHighest: true);
    }

    _startAbrLoop();
    _startBandwidthProbing();
    _startStallDetection();
    _vpc!.addListener(_onVideoPlayerUpdate);
  }

  void updateMaxHeightCap(int? cap) {
    if (maxHeightCap == cap) return;
    maxHeightCap = cap;
    if (isAutoMode.value) {
      _runAbrDecision();
    } else if (cap != null &&
        currentTierIndex.value < resolutionLadder.length &&
        resolutionLadder[currentTierIndex.value].height > cap) {
      var fallback = 0;
      for (var i = resolutionLadder.length - 1; i >= 0; i--) {
        if (resolutionLadder[i].height <= cap) {
          fallback = i;
          break;
        }
      }
      _switchToTier(fallback, reason: 'Cap update enforcement: height > $cap');
    }
  }

  double _getInitialBandwidthHint() {
    if (!kIsWeb) return 5000; // Default 5Mbps on mobile if unknown
    try {
      // Access Navigator Network Information API via JS context
      final dynamic nav = js.context['navigator'];
      if (nav != null) {
        final dynamic conn = nav['connection'];
        if (conn != null) {
          final downlink = conn['downlink']; // Mbps
          if (downlink != null) {
            return (downlink as num).toDouble() * 1000; // to kbps
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AdaptiveBitrateController.getNetworkInformationHint',
      );
    }
    return 5000;
  }

  void setManualTier(int index) {
    if (index < 0 || index >= resolutionLadder.length) return;
    if (maxHeightCap != null && resolutionLadder[index].height > maxHeightCap!) {
      debugPrint(
        '[ABR] Manual switch to ${resolutionLadder[index].label} blocked by maxHeightCap ($maxHeightCap)',
      );
      return;
    }
    isAutoMode.value = false;
    _switchToTier(index, reason: 'Manual selection', isManual: true);
  }

  void enableAutoMode() {
    isAutoMode.value = true;
  }

  void attachVideoController(VideoPlayerController vpc) {
    _vpc?.removeListener(_onVideoPlayerUpdate);
    _vpc = vpc;
    _vpc!.addListener(_onVideoPlayerUpdate);
  }

  ResolutionTier get currentTier {
    if (resolutionLadder.isEmpty) {
      return const ResolutionTier(
        label: 'Auto',
        url: '',
        height: 0,
        bitrate: 0,
        minBandwidth: 0,
      );
    }
    return resolutionLadder[currentTierIndex.value.clamp(
      0,
      resolutionLadder.length - 1,
    )];
  }

  List<AbrDecision> get decisionHistory => List.unmodifiable(_decisionHistory);

  // ── Core ABR Logic ─────────────────────────────────────────

  void _startAbrLoop() {
    _abrTimer?.cancel();
    _abrTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (isAutoMode.value) _runAbrDecision();
    });
    trackTimer(_abrTimer!);
  }

  void _runAbrDecision({bool forceHighest = false}) {
    if (_vpc == null || resolutionLadder.isEmpty) return;
    if (playbackState.value == PlaybackState.error) return;

    final now = DateTime.now();
    final isWithinStartupGrace =
        now.difference(_playbackStartTime) < _startupGracePeriod;

    final buffer = bufferHealthSeconds.value;
    final bw = _getSmoothedBandwidth();
    final effectiveBw = bw * _bandwidthSafetyFactor;

    // ── PANIC MODE: Critically low buffer (< 1s) outside startup grace period ──
    if (!isWithinStartupGrace &&
        buffer < _panicBufferLevel &&
        buffer > 0 &&
        bw > 0 &&
        !forceHighest) {
      _switchToTier(0, reason: 'Panic: buffer=${buffer.toStringAsFixed(1)}s');
      return;
    }

    // ── Find best sustainable tier ──
    var bestTier = 0;
    for (var i = 0; i < resolutionLadder.length; i++) {
      if (maxHeightCap == null || resolutionLadder[i].height <= maxHeightCap!) {
        bestTier = i;
        break;
      }
    }
    for (var i = resolutionLadder.length - 1; i >= 0; i--) {
      if (maxHeightCap != null && resolutionLadder[i].height > maxHeightCap!) {
        continue;
      }
      if (effectiveBw >= resolutionLadder[i].minBandwidth) {
        bestTier = i;
        break;
      }
    }

    // INDUSTRY STANDARD: On first decision or manual force, select optimal tier immediately
    if (_isFirstDecision || forceHighest) {
      _isFirstDecision = false;
      _switchToTier(
        bestTier,
        reason: 'First load ABR | hint=${bw.toStringAsFixed(0)}kbps',
      );
      return;
    }

    // During startup grace period, let stream establish buffer without auto-switch jitter
    if (isWithinStartupGrace) {
      _updateNetworkQuality(bw);
      return;
    }

    final current = currentTierIndex.value;

    // ── Upgrade logic with hysteresis, buffer gate, and minimum dwell duration ──
    if (bestTier > current) {
      final dwellElapsed = now.difference(_lastTierSwitchTime);
      if (dwellElapsed < _minDwellDuration) {
        _updateNetworkQuality(bw);
        return;
      }

      final requiredBw =
          resolutionLadder[bestTier].minBandwidth * _upgradeHysteresisFactor;
      if (effectiveBw >= requiredBw && buffer >= _minBufferToUpgrade) {
        _switchToTier(
          bestTier,
          reason:
              'Upgrade: bw=${effectiveBw.toStringAsFixed(0)}kbps buf=${buffer.toStringAsFixed(1)}s',
        );
      }
    }
    // ── Downgrade logic with hysteresis & cap enforcement ──
    else if (bestTier < current) {
      final isOverCap = maxHeightCap != null &&
          current < resolutionLadder.length &&
          resolutionLadder[current].height > maxHeightCap!;
      final currentRequired =
          resolutionLadder[current].minBandwidth * _downgradeHysteresisFactor;
      if (isOverCap || effectiveBw < currentRequired) {
        _switchToTier(
          bestTier,
          reason: isOverCap
              ? 'Cap enforcement: height > $maxHeightCap'
              : 'Downgrade: bw=${effectiveBw.toStringAsFixed(0)}kbps required=${currentRequired.toStringAsFixed(0)}',
        );
      }
    }

    _updateNetworkQuality(bw);
  }

  void _switchToTier(
    int index, {
    required String reason,
    bool isManual = false,
  }) {
    final clamped = index.clamp(0, resolutionLadder.length - 1);
    if (clamped == currentTierIndex.value) return;

    _lastTierSwitchTime = DateTime.now();

    _decisionHistory.add(
      AbrDecision(
        timestamp: DateTime.now(),
        fromTierIndex: currentTierIndex.value,
        toTierIndex: clamped,
        measuredBandwidth: measuredBandwidthKbps.value,
        reason: reason,
      ),
    );

    debugPrint(
      '[ABR] Switch: ${currentTierIndex.value < resolutionLadder.length ? resolutionLadder[currentTierIndex.value].label : "Initial"} → '
      '${resolutionLadder[clamped].label} | $reason',
    );

    currentTierIndex.value = clamped;
    switchCount.value++;
    onTierChanged?.call(clamped, isManual);
  }

  // ── Bandwidth Measurement ──────────────────────────────────

  void _startBandwidthProbing() {
    _bandwidthProbeTimer?.cancel();
    _bandwidthProbeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _measureBandwidth();
    });
    trackTimer(_bandwidthProbeTimer!);
  }

  void _measureBandwidth() {
    if (_vpc == null) return;

    // Use the video player's buffered bytes as a proxy for download rate
    // This is the most reliable method in Flutter Web without dart:io
    final value = _vpc!.value;
    if (!value.isInitialized) return;

    final buffered = value.buffered;
    if (buffered.isEmpty) return;

    final bufferedEnd = buffered.last.end;
    final now = DateTime.now();

    if (_lastDownloadStart != null) {
      final elapsed = now.difference(_lastDownloadStart!).inMilliseconds;
      if (elapsed > 0) {
        // Estimate bytes from buffered duration × bitrate
        final bufferedSeconds = bufferedEnd.inMilliseconds / 1000.0;
        final prevBufferedSeconds = _lastDownloadBytes / 1000.0;
        final deltaSeconds = bufferedSeconds - prevBufferedSeconds;

        if (deltaSeconds > 0) {
          // Estimate using current tier's expected bitrate
          final tierBitrate = currentTier.bitrate; // kbps
          final estimatedKbits = deltaSeconds * tierBitrate;
          final bwKbps = (estimatedKbits / elapsed) * 1000;

          if (bwKbps > 0) {
            _addBandwidthSample(bwKbps);
          }
        }

        _lastDownloadBytes = bufferedEnd.inMilliseconds;
      }
    }

    _lastDownloadStart = now;
    _lastDownloadBytes = bufferedEnd.inMilliseconds;
  }

  /// Web Navigator API bandwidth probe (most accurate on web)
  /// Falls back to buffer-based estimation if unavailable
  void reportSegmentDownload({required int bytes, required int durationMs}) {
    if (durationMs <= 0) return;
    final bwKbps = (bytes * 8) / durationMs; // bits/ms = kbps
    _addBandwidthSample(bwKbps);
  }

  void _addBandwidthSample(double kbps) {
    _bandwidthHistory.add(kbps);
    if (_bandwidthHistory.length > _measurementWindowCount) {
      _bandwidthHistory.removeAt(0);
    }
    measuredBandwidthKbps.value = _getSmoothedBandwidth();
  }

  double _getSmoothedBandwidth() {
    if (_bandwidthHistory.isEmpty) {
      return 5000; // Default to 5Mbps until measured
    }
    // Harmonic mean — industry standard for bandwidth (better than arithmetic for rates)
    final sumReciprocals = _bandwidthHistory.fold(
      0.0,
      (sum, v) => sum + (1.0 / max(v, 1)),
    );
    return _bandwidthHistory.length / sumReciprocals;
  }

  // ── Stall Detection ────────────────────────────────────────

  void _startStallDetection() {
    _stallDetectionTimer?.cancel();
    _stallDetectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkForStall();
    });
    trackTimer(_stallDetectionTimer!);
  }

  bool Function()? isAdPlaying;

  void _checkForStall() {
    if (_vpc == null) return;
    if (isAdPlaying?.call() == true) {
      _lastPositionUpdate = DateTime.now();
      return;
    }
    final value = _vpc!.value;
    if (!value.isPlaying) return;

    final now = DateTime.now();
    final currentPos = value.position;

    // Update buffer health first so stall check has fresh buffer metrics
    if (value.buffered.isNotEmpty) {
      final bufferEnd = value.buffered.last.end;
      final bufferAhead = bufferEnd - currentPos;
      bufferHealthSeconds.value = max(0, bufferAhead.inMilliseconds / 1000.0);
    }

    final buffer = bufferHealthSeconds.value;

    // Genuine stall condition: position hasn't moved in 3.5+ seconds while playing AND buffer is depleted (< 0.5s)
    if (currentPos == _lastKnownPosition &&
        now.difference(_lastPositionUpdate).inMilliseconds >= 3500 &&
        buffer < 0.5) {
      if (playbackState.value != PlaybackState.stalled) {
        _onStallDetected();
      }
    } else if (currentPos != _lastKnownPosition) {
      if (playbackState.value == PlaybackState.stalled) {
        _onStallRecovered();
      }
      _lastKnownPosition = currentPos;
      _lastPositionUpdate = now;
    }
  }

  void _onStallDetected() {
    playbackState.value = PlaybackState.stalled;
    stallReason.value = 'Network congestion';
    debugPrint('[ABR] STALL detected at ${_vpc?.value.position}');

    // Emergency downgrade
    if (isAutoMode.value && currentTierIndex.value > 0) {
      _switchToTier(
        max(0, currentTierIndex.value - 1),
        reason: 'Stall recovery downgrade',
      );
    }

    // Gracefully reduce bandwidth estimate by 30% without poisoning history with 50kbps
    if (_bandwidthHistory.isNotEmpty) {
      final currentSmooth = _getSmoothedBandwidth();
      _bandwidthHistory.clear();
      _bandwidthHistory.add(max(200.0, currentSmooth * 0.70));
      measuredBandwidthKbps.value = _getSmoothedBandwidth();
    }
  }

  void _onStallRecovered() {
    playbackState.value = PlaybackState.playing;
    stallReason.value = '';
    debugPrint('[ABR] Stall recovered');
  }

  void _onVideoPlayerUpdate() {
    if (_vpc == null) return;
    final value = _vpc!.value;

    // Update FSM state
    final err = value.errorDescription ?? '';
    final isTransient = err.contains('removed from the document') ||
        err.contains('play() request was interrupted') ||
        err.contains('The play() request was interrupted') ||
        err.contains('AbortError') ||
        err.contains('NotAllowedError');

    if (value.hasError && !isTransient) {
      playbackState.value = PlaybackState.error;
    } else if (value.isBuffering) {
      if (playbackState.value != PlaybackState.stalled) {
        playbackState.value = PlaybackState.buffering;
      }
    } else if (value.isPlaying) {
      playbackState.value = PlaybackState.playing;
    } else if (value.position >= value.duration &&
        value.duration > Duration.zero) {
      playbackState.value = PlaybackState.ended;
    } else {
      playbackState.value = PlaybackState.paused;
    }
  }

  void _updateNetworkQuality(double kbps) {
    if (kbps < 50) {
      networkQuality.value = NetworkQuality.offline;
    } else if (kbps < 300) {
      networkQuality.value = NetworkQuality.terrible;
    } else if (kbps < 800) {
      networkQuality.value = NetworkQuality.poor;
    } else if (kbps < 2000) {
      networkQuality.value = NetworkQuality.fair;
    } else if (kbps < 5000) {
      networkQuality.value = NetworkQuality.good;
    } else {
      networkQuality.value = NetworkQuality.excellent;
    }
  }

  @override
  void onClose() {
    _vpc?.removeListener(_onVideoPlayerUpdate);
    super.onClose();
  }
}
