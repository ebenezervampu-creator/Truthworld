import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MINIPLAYER STATE — Immutable, granular state for optimal rebuilds
// ═════════════════════════════════════════════════════════════════════════════

/// Core video information cached in the miniplayer.
/// Separated from playback state to prevent unnecessary rebuilds.
@immutable
class MiniplayerVideoInfo {
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
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final String videoUrl;
  final Duration totalDuration;

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
  /// Floating miniplayer (default).
  collapsed,

  /// Dragging between collapsed and expanded.
  dragging,

  /// Fully expanded to fill screen.
  expanded,

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
/// Sizing matches standard web miniplayer: a 16:9 video frame approximately
/// 400px wide with a compact info row beneath. The whole panel is draggable
/// around the viewport, dismissable, and expandable to fullscreen.
@immutable
class MiniplayerConfig {
  const MiniplayerConfig({
    this.enabled = true,
    this.autoShowOnNavigate = true,
    this.pauseOnClose = true,
    this.enableDrag = true,
  });
  // ── Feature Toggles ──
  final bool enabled;
  final bool autoShowOnNavigate;
  final bool pauseOnClose;
  final bool enableDrag;

  // ── Standard miniplayer sizing (logical pixels) ──
  /// Default width of the floating miniplayer card on desktop.
  static const double defaultWidth = 400;

  /// Minimum width on desktop viewports.
  static const double minWidth = 280;

  /// Maximum width on desktop viewports.
  static const double maxWidth = 480;

  /// Height of the info row beneath the 16:9 video frame on desktop.
  static const double infoBarHeight = 56;

  /// Aspect ratio of the video portion.
  static const double videoAspectRatio = 16.0 / 9.0;

  /// Edge inset from viewport when docked (desktop).
  static const double dockInset = 16;

  /// Edge inset from right edge on mobile devices.
  static const double mobileDockInset = 12;

  /// Bottom inset above the mobile bottom navigation bar (~56px bar + ~14px margin).
  static const double mobileDockBottomInset = 70;

  /// Fraction of screen width on mobile devices (matching mobile PiP: exactly 50%).
  static const double mobileWidthFraction = 0.50;

  /// Minimum width on mobile devices.
  static const double minMobileWidth = 160;

  /// Maximum width on mobile devices.
  static const double maxMobileWidth = 240;

  /// Checks whether the current platform or viewport represents a mobile layout.
  /// When [screenWidth] is supplied, it evaluates against the standard mobile breakpoint (<600px),
  /// allowing tablets on Android and iOS (e.g. iPad Pro, Galaxy Tab) to use the expanded tablet/desktop miniplayer.
  static bool isMobileLayout([double? screenWidth]) {
    if (screenWidth != null) {
      return screenWidth < 600;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Legacy alias — kept for backwards-compat with code that read the old
  /// "collapsed bar" height. New layout computes height from width.
  static const double collapsedHeight = 72;

  /// Expanded panel reserved fraction of screen height (0.0–1.0).
  static const double expandedHeightFraction = 1;

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
  /// Drag distance (fraction of screen) to commit expand/collapse.
  static const double snapThreshold = 0.3;

  /// Drag distance (fraction of screen height) to dismiss when already collapsed.
  static const double dismissThreshold = 0.15;

  // ── Styling ──
  static const double borderRadius = 12;
  static const double elevation = 24;

  /// Compute the total panel height for a given width.
  /// On mobile devices (Android, iOS, Web Android/iOS), the floating miniplayer
  /// matches the reference image: strictly the 16:9 video frame with no bottom info bar.
  /// On desktop, the info row beneath the video frame is included.
  static double heightForWidth(double width, {bool isMobile = false}) {
    final videoH = width / videoAspectRatio;
    if (isMobile) return videoH;
    return videoH + infoBarHeight;
  }

  /// Compute a responsive miniplayer width.
  /// On mobile devices (Android, iOS, Web Android/iOS), sets width to 50% of screen width
  /// (clamped between [minMobileWidth] and [maxMobileWidth]), matching the reference image.
  /// On desktop, preserves the existing desktop width calculation.
  static double widthForScreen(double screenWidth) {
    if (screenWidth <= 0) return defaultWidth;
    if (isMobileLayout(screenWidth)) {
      return (screenWidth * mobileWidthFraction).clamp(
        minMobileWidth,
        maxMobileWidth,
      );
    }
    final target = screenWidth * 0.30;
    return target.clamp(minWidth, maxWidth);
  }

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
