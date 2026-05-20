import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MINIPLAYER STATE — Immutable, granular state for optimal rebuilds
// ═════════════════════════════════════════════════════════════════════════════

/// Core video information cached in the miniplayer.
/// Separated from playback state to prevent unnecessary rebuilds.
@immutable
class MiniplayerVideoInfo {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final String videoUrl;
  final Duration totalDuration;

  const MiniplayerVideoInfo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.totalDuration,
  });

  factory MiniplayerVideoInfo.fromVideo(Video video) {
    return MiniplayerVideoInfo(
      id: video.id,
      title: video.title,
      channelName: video.channelName,
      thumbnailUrl: video.thumbnailUrl,
      videoUrl: video.videoUrl,
      totalDuration: video.durationValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiniplayerVideoInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Enum representing the visual state of the miniplayer panel.
enum MiniplayerMode {
  /// Floating TruthWorld-style miniplayer (default).
  collapsed,

  /// Transitioning to full video screen page.
  transitioning,

  /// Hidden / disposed.
  dismissed,
}

// ═════════════════════════════════════════════════════════════════════════════
// MINIPLAYER CONFIG — Compile-time constants, no runtime allocation
// ═════════════════════════════════════════════════════════════════════════════

/// Immutable configuration for the miniplayer.
///
/// Sizing matches TruthWorld's web miniplayer: a 16:9 video frame approximately
/// 400px wide with a compact info row beneath. The whole panel is draggable
/// around the viewport, dismissable, and expandable to fullscreen.
@immutable
class MiniplayerConfig {
  // ── Feature Toggles ──
  final bool enabled;
  final bool autoShowOnNavigate;
  final bool pauseOnClose;
  final bool enableDrag;

  // ── TruthWorld-style sizing (logical pixels) ──
  /// Default width of the floating miniplayer card.
  static const double defaultWidth = 400.0;

  /// Minimum width on small viewports.
  static const double minWidth = 280.0;

  /// Maximum width on large viewports.
  static const double maxWidth = 480.0;

  /// Height of the info row beneath the 16:9 video frame.
  static const double infoBarHeight = 56.0;

  /// Aspect ratio of the video portion.
  static const double videoAspectRatio = 16.0 / 9.0;

  /// Edge inset from viewport when docked.
  static const double dockInset = 16.0;

  /// Legacy alias — kept for backwards-compat with code that read the old
  /// "collapsed bar" height. New layout computes height from width.
  static const double collapsedHeight = 72.0;

  /// Expanded panel reserved fraction of screen height (0.0–1.0).
  static const double expandedHeightFraction = 1.0;

  /// Width fraction of screen when collapsed (legacy).
  static const double collapsedWidthFraction = 0.30;

  /// Minimum collapsed width in px (legacy alias of [minWidth]).
  static const double minCollapsedWidth = minWidth;

  /// Maximum collapsed width in px (legacy alias of [maxWidth]).
  static const double maxCollapsedWidth = maxWidth;

  // ── Animation ──
  static const Duration animationDuration = Duration(milliseconds: 260);
  static const Curve animationCurve = Curves.easeOutCubic;

  // ── Thresholds ──
  /// Drag distance (fraction of screen height) to dismiss.
  static const double dismissThreshold = 0.15;

  // ── Styling ──
  static const double borderRadius = 12.0;
  static const double elevation = 24.0;

  /// Compute the total panel height for a given width (16:9 video + info row).
  /// Adds 2.0px to account for the top/bottom border.
  static double heightForWidth(double width) =>
      (width / videoAspectRatio) + infoBarHeight + 2.0;

  /// Compute a responsive miniplayer width clamped between [minWidth]/[maxWidth].
  static double widthForScreen(double screenWidth) {
    if (screenWidth <= 0) return defaultWidth;
    final target = screenWidth * 0.30;
    return target.clamp(minWidth, maxWidth);
  }

  const MiniplayerConfig({
    this.enabled = true,
    this.autoShowOnNavigate = true,
    this.pauseOnClose = true,
    this.enableDrag = true,
  });

  MiniplayerConfig copyWith({
    bool? enabled,
    bool? autoShowOnNavigate,
    bool? pauseOnClose,
    bool? enableDrag,
  }) {
    return MiniplayerConfig(
      enabled: enabled ?? this.enabled,
      autoShowOnNavigate: autoShowOnNavigate ?? this.autoShowOnNavigate,
      pauseOnClose: pauseOnClose ?? this.pauseOnClose,
      enableDrag: enableDrag ?? this.enableDrag,
    );
  }
}
