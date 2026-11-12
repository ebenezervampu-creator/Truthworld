import 'package:flutter/material.dart';

/// Configuration constants and default limits for TruthWorld Audio Themes.
class AudioThemeConfig {
  const AudioThemeConfig._();

  // Color constants adhering to Zero White-on-White & High Contrast Policy
  static const Color obsidianBackground = Color(0xFF000000);
  static const Color darkCanvas = Color(0xFF08090C);
  static const Color studioSurface = Color(0xFF12131A);

  // Animation & refresh cadence
  static const Duration lowFrequencyCycle = Duration(seconds: 6);
  static const Duration standardTransition = Duration(milliseconds: 300);
  static const Duration visualizerTickInterval = Duration(milliseconds: 50); // 20 FPS cap for battery safety

  // Breakpoints for responsive scaling
  static const double compactHeightBreakpoint = 230.0;
  static const double mediumHeightBreakpoint = 420.0;
  static const double compactWidthBreakpoint = 400.0;

  // Safe Artwork dimensions
  static const double compactArtworkSize = 84.0;
  static const double mediumArtworkSize = 120.0;
  static const double largeArtworkSize = 200.0;
}
