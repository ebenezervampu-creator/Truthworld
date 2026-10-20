import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';

/// Mixin owning all player timeline state, scrubbing interactions,
/// precision scrubbing rates, haptic ticks, chapters, and claim associations.
mixin TowerPlayerTimelineMixin on GetxController {
  // ── Scrubbing & Hover Observables ─────────────────────────
  final RxBool isScrubbing = false.obs;
  final Rx<Duration> scrubPosition = Duration.zero.obs;
  final RxBool isTimelineHovered = false.obs;
  final Rx<Duration> hoverPosition = Duration.zero.obs;
  final RxDouble hoverFraction = 0.0.obs;
  final RxDouble hoverXPixel = 0.0.obs;
  final Rxn<ClaimResult> hoveredClaim = Rxn<ClaimResult>();
  final RxList<double> adCuePoints = <double>[].obs;
  List<double> get adBreaks => adCuePoints;

  // ── Precision Scrubbing (Vertical Drag Fine Seeking) ──────
  final RxDouble scrubRate = 1.0.obs;
  final RxBool isPrecisionScrubbing = false.obs;
  final RxString precisionScrubLabel = ''.obs;

  double _anchorFraction = 0.0;
  double _anchorX = 0.0;
  DateTime _lastHapticTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Setting to control whether dragging snaps to claim markers.
  /// Strictly false by default per TruthWorld engineering guidelines.
  bool enableSnapToMarkers = false;

  // ── Contract required from controller / other mixins ──────
  Future<void> seekTo(Duration position);
  void cancelHideTimer();
  void startHideTimer([Duration? timeout]);
  void hideSeekPreview();

  // ── Scrubbing Lifecycle ───────────────────────────────────

  /// Initiates scrubbing at a normalized fraction [0.0, 1.0].
  void onScrubStart(
    double fraction,
    Duration totalDuration, {
    double startX = 0.0,
  }) {
    isScrubbing.value = true;
    _anchorFraction = fraction.clamp(0.0, 1.0);
    _anchorX = startX;
    scrubRate.value = 1.0;
    isPrecisionScrubbing.value = false;
    precisionScrubLabel.value = '';
    cancelHideTimer();

    final targetMs = (totalDuration.inMilliseconds * _anchorFraction).toInt();
    scrubPosition.value = Duration(milliseconds: targetMs);
  }

  /// Updates scrub target position with vertical-drag precision sensitivity (1.0x, 0.5x, 0.25x)
  /// and marker-crossing micro-haptics.
  void onScrubUpdate(
    double fraction,
    Duration totalDuration, {
    double currentX = 0.0,
    double upwardDisplacement = 0.0,
    double barWidth = 1.0,
    List<ClaimResult>? claims,
    List<VideoChapter>? chapters,
  }) {
    isScrubbing.value = true;
    cancelHideTimer();

    // Determine precision rate based on upward drag displacement (YouTube / iOS standard)
    if (upwardDisplacement >= 75.0) {
      if (scrubRate.value != 0.25) {
        _anchorFraction = scrubPosition.value.inMilliseconds /
            (totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds : 1);
        _anchorX = currentX;
      }
      scrubRate.value = 0.25;
      isPrecisionScrubbing.value = true;
      precisionScrubLabel.value = 'Ultra-Fine Scrubbing (0.25×)';
    } else if (upwardDisplacement >= 35.0) {
      if (scrubRate.value != 0.50) {
        _anchorFraction = scrubPosition.value.inMilliseconds /
            (totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds : 1);
        _anchorX = currentX;
      }
      scrubRate.value = 0.50;
      isPrecisionScrubbing.value = true;
      precisionScrubLabel.value = 'Fine Scrubbing (0.5×)';
    } else {
      if (scrubRate.value != 1.0) {
        _anchorFraction = fraction.clamp(0.0, 1.0);
        _anchorX = currentX;
      }
      scrubRate.value = 1.0;
      isPrecisionScrubbing.value = false;
      precisionScrubLabel.value = '';
    }

    double computedFraction;
    if (scrubRate.value < 1.0 && barWidth > 0) {
      final deltaX = currentX - _anchorX;
      final effectiveDeltaFrac = (deltaX * scrubRate.value) / barWidth;
      computedFraction = (_anchorFraction + effectiveDeltaFrac).clamp(0.0, 1.0);
    } else {
      computedFraction = fraction.clamp(0.0, 1.0);
      _anchorFraction = computedFraction;
      _anchorX = currentX;
    }

    var targetMs = totalDuration.inMilliseconds * computedFraction;

    // Optional claim snapping (strictly disabled by default)
    if (enableSnapToMarkers && claims != null && claims.isNotEmpty && totalDuration.inMilliseconds > 0) {
      final thresholdMs = totalDuration.inMilliseconds * 0.015;
      for (final claim in claims) {
        if (claim.start != null) {
          final claimMs = claim.start! * 1000.0;
          if ((targetMs - claimMs).abs() <= thresholdMs) {
            targetMs = claimMs;
            break;
          }
        }
      }
    }

    final oldPos = scrubPosition.value;
    final newPos = Duration(milliseconds: targetMs.toInt());

    // Trigger micro-haptics when crossing chapter boundaries or claim markers
    _checkMarkerHaptics(oldPos, newPos, chapters, claims);

    scrubPosition.value = newPos;
  }

  /// Concludes scrubbing and commits the final seek operation.
  void onScrubEnd([Duration? explicitTarget]) {
    final finalTarget = explicitTarget ?? scrubPosition.value;
    seekTo(finalTarget);
    isScrubbing.value = false;
    scrubRate.value = 1.0;
    isPrecisionScrubbing.value = false;
    precisionScrubLabel.value = '';
    hideTimelineHover();
    hideSeekPreview();
    startHideTimer();
  }

  /// Cancels scrubbing and resets state without committing an explicit seek.
  void onScrubCancel() {
    isScrubbing.value = false;
    scrubRate.value = 1.0;
    isPrecisionScrubbing.value = false;
    precisionScrubLabel.value = '';
    hideTimelineHover();
    hideSeekPreview();
    startHideTimer();
  }

  /// Triggers sensory haptic feedback when crossing chapter boundaries or verified claim diamonds.
  void _checkMarkerHaptics(
    Duration oldPos,
    Duration newPos,
    List<VideoChapter>? chapters,
    List<ClaimResult>? claims,
  ) {
    if (oldPos == newPos) return;

    final now = DateTime.now();
    if (now.difference(_lastHapticTime).inMilliseconds < 75) return;

    try {
      if (chapters != null && chapters.length > 1) {
        for (final ch in chapters.skip(1)) {
          final chMs = ch.startTime;
          if ((oldPos < chMs && newPos >= chMs) || (oldPos > chMs && newPos <= chMs)) {
            HapticFeedback.selectionClick();
            _lastHapticTime = now;
            return;
          }
        }
      }

      if (claims != null && claims.isNotEmpty) {
        for (final cl in claims) {
          if (cl.start != null) {
            final clMs = Duration(milliseconds: (cl.start! * 1000).toInt());
            if ((oldPos < clMs && newPos >= clMs) || (oldPos > clMs && newPos <= clMs)) {
              HapticFeedback.lightImpact();
              _lastHapticTime = now;
              return;
            }
          }
        }
      }
    } catch (_) {
      // Safe fallback on desktop / non-vibrating devices
    }
  }

  // ── Hover Preview Lifecycle ───────────────────────────────

  /// Updates hover position and detects nearby verified claims for intelligent tooltips.
  void updateTimelineHover(
    double fraction,
    double xPixel,
    Duration totalDuration, {
    List<ClaimResult>? claims,
  }) {
    isTimelineHovered.value = true;
    hoverFraction.value = fraction.clamp(0.0, 1.0);
    hoverXPixel.value = xPixel;

    final targetMs = (totalDuration.inMilliseconds * hoverFraction.value).toInt();
    hoverPosition.value = Duration(milliseconds: targetMs);

    // Detect if hovering within ~1.5% window of a claim
    ClaimResult? nearbyClaim;
    if (claims != null && claims.isNotEmpty && totalDuration.inMilliseconds > 0) {
      final thresholdMs = totalDuration.inMilliseconds * 0.015;
      for (final claim in claims) {
        if (claim.start != null) {
          final claimMs = claim.start! * 1000.0;
          if ((targetMs - claimMs).abs() <= thresholdMs) {
            nearbyClaim = claim;
            break;
          }
        }
      }
    }
    hoveredClaim.value = nearbyClaim;
  }

  /// Hides the hover preview tooltip.
  void hideTimelineHover() {
    isTimelineHovered.value = false;
    hoveredClaim.value = null;
  }
}
