import 'package:flutter/material.dart';

/// Custom color roles for TruthWorld.
///
/// Backed by a permanent dark theme. Exposes semantic color roles
/// not supported natively by Flutter's standard ColorScheme.
class TWColors extends ThemeExtension<TWColors> {
  // ── Brand
  final Color brand;
  final Color brandContainer;
  final Color brandVariant;

  // ── Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // ── Surface / Background
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceInput;
  final Color appBarSurface;
  final Color divider;

  // ── Status
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color successContainer;
  final Color warningContainer;
  final Color errorContainer;
  final Color infoContainer;

  // ── Interaction Overlays
  final Color selectedOverlay;
  final Color hoverOverlay;
  final Color pressedOverlay;
  final Color focusRing;

  const TWColors({
    required this.brand,
    required this.brandContainer,
    required this.brandVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceInput,
    required this.appBarSurface,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.successContainer,
    required this.warningContainer,
    required this.errorContainer,
    required this.infoContainer,
    required this.selectedOverlay,
    required this.hoverOverlay,
    required this.pressedOverlay,
    required this.focusRing,
  });

  @override
  ThemeExtension<TWColors> copyWith({
    Color? brand,
    Color? brandContainer,
    Color? brandVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? background,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? surfaceInput,
    Color? appBarSurface,
    Color? divider,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? successContainer,
    Color? warningContainer,
    Color? errorContainer,
    Color? infoContainer,
    Color? selectedOverlay,
    Color? hoverOverlay,
    Color? pressedOverlay,
    Color? focusRing,
  }) {
    return TWColors(
      brand: brand ?? this.brand,
      brandContainer: brandContainer ?? this.brandContainer,
      brandVariant: brandVariant ?? this.brandVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceInput: surfaceInput ?? this.surfaceInput,
      appBarSurface: appBarSurface ?? this.appBarSurface,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      successContainer: successContainer ?? this.successContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      errorContainer: errorContainer ?? this.errorContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      selectedOverlay: selectedOverlay ?? this.selectedOverlay,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      pressedOverlay: pressedOverlay ?? this.pressedOverlay,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  ThemeExtension<TWColors> lerp(ThemeExtension<TWColors>? other, double t) {
    if (other is! TWColors) return this;
    return TWColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandContainer: Color.lerp(brandContainer, other.brandContainer, t)!,
      brandVariant: Color.lerp(brandVariant, other.brandVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerHighest: Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t)!,
      surfaceInput: Color.lerp(surfaceInput, other.surfaceInput, t)!,
      appBarSurface: Color.lerp(appBarSurface, other.appBarSurface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      selectedOverlay: Color.lerp(selectedOverlay, other.selectedOverlay, t)!,
      hoverOverlay: Color.lerp(hoverOverlay, other.hoverOverlay, t)!,
      pressedOverlay: Color.lerp(pressedOverlay, other.pressedOverlay, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

/// Helper extension to easily access TruthWorld colors from [BuildContext].
extension TWColorsExtension on BuildContext {
  TWColors get colors => Theme.of(this).extension<TWColors>()!;
}
