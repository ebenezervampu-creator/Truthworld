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
  /// Collapsed bar at the bottom (default).
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
/// Uses static const values wherever possible for zero-allocation access.
@immutable
class MiniplayerConfig {
  // ── Feature Toggles ──
  final bool enabled;
  final bool autoShowOnNavigate;
  final bool pauseOnClose;
  final bool enableDrag;

  // ── Layout Constants ──
  /// Collapsed bar height in logical pixels (72.0 for better touch targets)
  static const double collapsedHeight = 72.0;

  /// Expanded panel reserved fraction of screen height (0.0–1.0)
  static const double expandedHeightFraction = 1.0;

  /// Width fraction of screen when collapsed (web-only: bottom-right)
  static const double collapsedWidthFraction = 0.30;

  /// Minimum collapsed width in px (for very small screens)
  static const double minCollapsedWidth = 320.0;

  /// Maximum collapsed width in px (for ultra-wide screens)
  static const double maxCollapsedWidth = 480.0;

  // ── Animation ──
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Curve animationCurve = Curves.easeOutCubic;

  // ── Thresholds ──
  /// Drag distance (fraction of screen) to commit expand/collapse
  static const double snapThreshold = 0.3;

  /// Drag distance (fraction of screen height) to dismiss when already collapsed
  static const double dismissThreshold = 0.15;

  // ── Styling ──
  static const double borderRadius = 12.0;
  static const double elevation = 16.0;

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





