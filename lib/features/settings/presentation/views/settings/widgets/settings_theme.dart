import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

const double kBorderRadius = 16;

ThemeData getSettingsTheme(BuildContext context) {
  final parentTheme = Theme.of(context);
  final parentColors = parentTheme.extension<TWColors>();
  final parentTypography = parentTheme.extension<TWTypography>();

  if (parentColors == null || parentTypography == null) {
    return buildAppTheme();
  }

  final homeColors = TWColors(
    brand: const Color(0xFF1976D2), // Professional blue
    brandContainer: const Color(0xFF1976D2).withValues(alpha: 0.12),
    brandVariant: const Color(0xFF42A5F5), // Lighter blue
    textPrimary: const Color(0xFFE8E8E8),
    textSecondary: const Color(0xFFB8B8B8),
    textTertiary: const Color(0xFFB8B8B8).withValues(alpha: 0.7),
    textDisabled: const Color(0xFFB8B8B8).withValues(alpha: 0.38),
    background: const Color(0xFF0F0F0F),
    surface: const Color(0xFF121212),
    surfaceContainer: const Color(0xFF1E1E1E),
    surfaceContainerHigh: const Color(0xFF1E1E1E),
    surfaceContainerHighest: const Color(0xFF1E1E1E),
    surfaceInput: const Color(0xFF121212),
    appBarSurface: const Color(0xFF121212),
    divider: const Color(0xFF1E1E1E),
    success: parentColors.success,
    warning: parentColors.warning,
    error: const Color(0xFFFF6B6B),
    info: const Color(0xFF42A5F5),
    successContainer: parentColors.successContainer,
    warningContainer: parentColors.warningContainer,
    errorContainer: parentColors.errorContainer,
    infoContainer: parentColors.infoContainer,
    selectedOverlay: parentColors.selectedOverlay,
    hoverOverlay: parentColors.hoverOverlay,
    pressedOverlay: parentColors.pressedOverlay,
    focusRing: parentColors.focusRing,
  );

  final homeTypography = TWTypography(
    logo: parentTypography.logo,
    hero: parentTypography.hero,
    display: parentTypography.display,
    headline: parentTypography.headline,
    title: parentTypography.title,
    body: parentTypography.body,
    bodySmall: parentTypography.bodySmall,
    label: parentTypography.label,
    caption: parentTypography.caption,
    button: parentTypography.button,
    overline: parentTypography.overline,
  );

  return buildAppTheme().copyWith(
    extensions: [
      homeColors,
      homeTypography,
      if (parentTheme.extension<TWSpacing>() != null)
        parentTheme.extension<TWSpacing>()!,
      if (parentTheme.extension<TWRadius>() != null)
        parentTheme.extension<TWRadius>()!,
      if (parentTheme.extension<TWMotion>() != null)
        parentTheme.extension<TWMotion>()!,
      if (parentTheme.extension<TWShadows>() != null)
        parentTheme.extension<TWShadows>()!,
      if (parentTheme.extension<TWGradients>() != null)
        parentTheme.extension<TWGradients>()!,
      if (parentTheme.extension<TWLayoutTokens>() != null)
        parentTheme.extension<TWLayoutTokens>()!,
    ],
  );
}
