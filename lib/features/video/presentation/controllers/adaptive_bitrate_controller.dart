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
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
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
    this.isSynthetic = false,
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
      kbps = defaultBitrateForHeight(v.height, fps: v.fps);
    }

    return ResolutionTier(
      label: v.label,
      url: v.url,
      height: v.height,
      bitrate: kbps,
      minBandwidth: (kbps * 1.2).toInt(),
      isSynthetic: v.isSynthetic,
    );
  }

  static int defaultBitrateForHeight(int height, {int fps = 30}) {
    final is60 = fps >= 50;
    if (height >= 2160) return is60 ? 22000 : 15000;
    if (height >= 1440) return is60 ? 14000 : 10000;
    if (height >= 1080) return is60 ? 7500 : 5000;
    if (height >= 1040) return is60 ? 6750 : 4500;
    if (height >= 720) return is60 ? 3800 : 2500;
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
  final bool isSynthetic;

  bool get is60Fps => label.contains('60');
  int get fps => is60Fps ? 60 : 30;

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

  /// Whether the ladder has concrete playable stream URLs (not generic placeholders)
  bool get hasConcreteStreams => resolutionLadder.any((t) => t.url.isNotEmpty);

  // ABR tuning constants (Optimized for CMAF Ultra-Low Latency 500ms chunking)
  static const double _bandwidthSafetyFactor = 0.85; // 85% of measured BW with CMAF
  static const double _upgradeHysteresisFactor =
      1.15; // 15% margin for upgrade (responsive step-up)
  static const double _downgradeHysteresisFactor =
      0.75; // Downgrade if throughput drops 25% below tier
  static const double _minBufferToUpgrade =
      4.0; // 4.0s of buffer (8x 500ms CMAF chunks) allows near-instant quality shifts
  static const double _panicBufferLevel =
      1.5; // Trigger emergency downgrade if buffer drops below 1.5s
  static const int _measurementWindowCount =
      4; // Rolling average over 4 measurements for quick adaptation
  static const Duration _startupGracePeriod = Duration(seconds: 4);
  static const Duration _minDwellDuration = Duration(seconds: 5);

  /// Flag indicating CMAF Ultra-Low Latency chunking profile is active
  bool get isCmafUllEnabled => true;

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
    int? initialTierIndex,
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
      if (initialTierIndex != null) {
        currentTierIndex.value = initialTierIndex.clamp(0, ladder.length - 1);
        _isFirstDecision = false;
      } else {
        // SAFETY: Clamp default currentTierIndex to new ladder bounds immediately
        currentTierIndex.value = currentTierIndex.value.clamp(
          0,
          ladder.length - 1,
        );
        _runAbrDecision(forceHighest: true);
      }
    }

    _startAbrLoop();
    _startBandwidthProbing();
    _startStallDetection();
    _vpc!.addListener(_onVideoPlayerUpdate);
  }

  /// Seamlessly updates the resolution ladder with concrete variants once resolved from storage/backend,
  /// preserving active playback alignment without spurious downgrades or upgrades.
  void updateLadder(
    List<ResolutionTier> newLadder, {
    int? activeHeight,
    int? activeFps,
  }) {
    if (newLadder.isEmpty) return;
    resolutionLadder = newLadder;

    var matchingIdx = -1;
    if (activeHeight != null) {
      matchingIdx = newLadder.indexWhere(
        (t) => t.height == activeHeight && (activeFps == null || t.fps == activeFps),
      );
      if (matchingIdx == -1) {
        matchingIdx = newLadder.indexWhere((t) => t.height == activeHeight);
      }
    }

    if (matchingIdx != -1) {
      currentTierIndex.value = matchingIdx;
    } else {
      currentTierIndex.value = currentTierIndex.value.clamp(0, newLadder.length - 1);
    }
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
    if (!kIsWeb) {
      if (Get.isRegistered<ConnectivityService>()) {
        final isWifi = ConnectivityService.to.isWifi;
        if (!isWifi) return 1500; // Mobile / cellular data: conservative 1.5 Mbps start (480p)
      }
      return 5000;
    }
    return WebPlatformUtils.getInitialBandwidthHint();
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
    _runAbrDecision();
  }

  void attachVideoController(VideoPlayerController vpc) {
    _vpc?.removeListener(_onVideoPlayerUpdate);
    _vpc = vpc;
    _lastKnownPosition = Duration.zero;
    final now = DateTime.now();
    _lastPositionUpdate = now;
    _playbackStartTime = now;
    _lastTierSwitchTime = now;
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
    _abrTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isAutoMode.value) _runAbrDecision();
    });
    trackTimer(_abrTimer!);
  }

  void _runAbrDecision({bool forceHighest = false}) {
    if (_vpc == null || resolutionLadder.isEmpty || !hasConcreteStreams) return;
    if (playbackState.value == PlaybackState.error) return;

    final now = DateTime.now();
    final isWithinStartupGrace =
        now.difference(_playbackStartTime) < _startupGracePeriod;

    final buffer = bufferHealthSeconds.value;
    final bw = _getSmoothedBandwidth();
    final effectiveBw = bw * _bandwidthSafetyFactor;

    // ── PANIC MODE: Critically low buffer (< 1.5s) outside startup grace period and not initial buffering ──
    final isBufferingOrStarting = (_vpc?.value.isBuffering ?? false) ||
        (_vpc?.value.position ?? Duration.zero) == Duration.zero;
    if (!isWithinStartupGrace &&
        !isBufferingOrStarting &&
        buffer < _panicBufferLevel &&
        buffer > 0 &&
        bw > 0 &&
        !forceHighest) {
      final stepDownIndex = max(0, currentTierIndex.value - 1);
      _switchToTier(
        stepDownIndex,
        reason: 'Panic: buffer=${buffer.toStringAsFixed(1)}s',
      );
      return;
    }

    // ── Find best sustainable tier ──
    // Industry standard: Only concrete, non-synthetic tiers with distinct bitrate streams are eligible for auto-switching
    final eligibleIndices = <int>[];
    for (var i = 0; i < resolutionLadder.length; i++) {
      final tier = resolutionLadder[i];
      if (maxHeightCap != null && tier.height > maxHeightCap!) continue;
      if (!tier.isSynthetic) {
        eligibleIndices.add(i);
      }
    }
    // If no tiers are explicitly marked non-synthetic, allow all within cap
    if (eligibleIndices.isEmpty) {
      for (var i = 0; i < resolutionLadder.length; i++) {
        if (maxHeightCap == null || resolutionLadder[i].height <= maxHeightCap!) {
          eligibleIndices.add(i);
        }
      }
    }

    var bestTier = eligibleIndices.isNotEmpty ? eligibleIndices.first : 0;
    for (var k = eligibleIndices.length - 1; k >= 0; k--) {
      final idx = eligibleIndices[k];
      if (effectiveBw >= resolutionLadder[idx].minBandwidth) {
        bestTier = idx;
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
    if (clamped == currentTierIndex.value && !isManual) return;

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
    if (isClosed || _vpc == null) return;

    // Use the video player's buffered bytes as a proxy for download rate
    // This is the most reliable method in Flutter Web without dart:io
    final VideoPlayerValue value;
    try {
      value = _vpc!.value;
      if (!value.isInitialized) return;
    } catch (_) {
      return;
    }

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
    if (isClosed || _vpc == null) return;
    if (isAdPlaying?.call() == true) {
      _lastPositionUpdate = DateTime.now();
      return;
    }
    final VideoPlayerValue value;
    try {
      value = _vpc!.value;
      if (!value.isPlaying) return;
    } catch (_) {
      return;
    }

    final now = DateTime.now();
    final currentPos = value.position;

    // During initial startup grace period, tier switch dwell period, active pre-roll buffering,
    // before the video is initialized, or before the first frame has rendered (currentPos == Duration.zero),
    // let stream establish initial playback buffer and start decoding without false stalls.
    final isWithinStartupGrace =
        now.difference(_playbackStartTime) < _startupGracePeriod;
    final isWithinDwellPeriod =
        now.difference(_lastTierSwitchTime) < _minDwellDuration;

    if (isWithinStartupGrace ||
        isWithinDwellPeriod ||
        value.isBuffering ||
        currentPos == Duration.zero ||
        !value.isInitialized) {
      _lastPositionUpdate = now;
      _lastKnownPosition = currentPos;
      return;
    }

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

    // Emergency downgrade (ABR degrades down to tier 0 / 144p minimum)
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
    if (isClosed || _vpc == null) return;
    final VideoPlayerValue value;
    try {
      value = _vpc!.value;
    } catch (_) {
      return;
    }

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
      if (playbackState.value == PlaybackState.stalled &&
          value.position > _lastKnownPosition) {
        _onStallRecovered();
      } else if (playbackState.value != PlaybackState.stalled) {
        playbackState.value = PlaybackState.playing;
      }
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
    try {
      _vpc?.removeListener(_onVideoPlayerUpdate);
    } catch (_) {}
    _vpc = null;
    super.onClose();
  }
}
