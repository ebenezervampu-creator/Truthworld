import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_config.dart';

/// Responsive layout calculations for TruthWorld Audio Themes.
/// Prevents RenderFlex overflow across bounded 16:9 players (e.g. 202px height),
/// compact split-screens, and full-screen viewports.
class AudioThemeResponsive {
  const AudioThemeResponsive({
    required this.maxWidth,
    required this.maxHeight,
  });

  factory AudioThemeResponsive.fromConstraints(BoxConstraints constraints) {
    return AudioThemeResponsive(
      maxWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0,
      maxHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 202.0,
    );
  }

  final double maxWidth;
  final double maxHeight;

  bool get isCompactHeight => maxHeight <= AudioThemeConfig.compactHeightBreakpoint;
  bool get isMediumHeight => maxHeight > AudioThemeConfig.compactHeightBreakpoint && maxHeight <= AudioThemeConfig.mediumHeightBreakpoint;
  bool get isCompactWidth => maxWidth <= AudioThemeConfig.compactWidthBreakpoint;

  /// Dynamic artwork size budget guaranteeing zero overflow.
  double get artworkSize {
    if (isCompactHeight) {
      // In a 202px height container, artwork must not exceed 84px
      final available = (maxHeight - 110.0).clamp(60.0, AudioThemeConfig.compactArtworkSize);
      return available;
    }
    if (isMediumHeight) {
      return (maxHeight * 0.35).clamp(90.0, AudioThemeConfig.mediumArtworkSize);
    }
    return (maxWidth * 0.45).clamp(140.0, AudioThemeConfig.largeArtworkSize);
  }

  /// Title font size budget
  double get titleFontSize {
    if (isCompactHeight) return 13.0;
    if (isMediumHeight) return 16.0;
    return 20.0;
  }

  /// Channel font size budget
  double get channelFontSize {
    if (isCompactHeight) return 11.0;
    if (isMediumHeight) return 12.5;
    return 14.0;
  }

  /// Safe vertical spacing budget
  double get spacing {
    if (isCompactHeight) return 6.0;
    if (isMediumHeight) return 10.0;
    return 16.0;
  }

  /// Safe horizontal padding budget
  EdgeInsets get padding {
    if (isCompactHeight) {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
    }
    return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
  }
}
