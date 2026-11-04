import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class AppTheme {
  static CompatColors get colors => const CompatColors();
  static CompatSpacing get spacing => const CompatSpacing();
  static CompatTypography get typography => const CompatTypography();
  static CompatSizes get sizes => const CompatSizes();
  static CompatRadius get radius => const CompatRadius();
  static CompatInteraction get interaction => const CompatInteraction();
  static CompatInteraction get animations => const CompatInteraction(); // Alias
  static CompatShadows get shadows => const CompatShadows();
  static CompatComponents get components => const CompatComponents();

  static const Color primaryColor = AppColors.brand;
  static const Color scaffoldBackgroundColor = AppColors.bgPage;
  static const Color cardColor = AppColors.bgSurface;
  static const Color dividerColor = AppColors.bgDivider;

  // Legacy Theme Compatibility
  static const Color primaryBackground = AppColors.bgPage;
  static const Color secondaryBackground = AppColors.bgSurface;
  static const Color cardBackground = AppColors.bgSurface;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textTertiary = AppColors.textTertiary;
  static const Color deepCrimson = AppColors.brand;
  static const Color divider = AppColors.bgDivider;
  static const Color border = AppColors.bgDivider;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;
  static const Color info = AppColors.textLink;
  static const Color hoverAccent = AppColors.brandOverlay;

  static const Gradient gradientCrimsonSubtle = LinearGradient(
    colors: [AppColors.bgSurface, AppColors.bgSurfaceHover],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  static const double radiusSmall = 4;
  static const double radiusMedium = 8;
  static const double radiusLarge = 12;

  static const Duration animDuration = Duration(milliseconds: 300);
  static const Curve animCurveEaseOut = Curves.easeOutCubic;

  static const double labelLarge = 14;
  static const double labelMedium = 12;
  static const double labelSmall = 10;

  static const List<BoxShadow> elevationSmall = [
    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
  ];
}

class AppTokens {
  static const colors = CompatColors();
  static const spacing = CompatSpacing();
  static const radius = CompatRadius();
  static const typography = CompatTypography();
  static const sizes = CompatSizes();
}

class AppTextStyles {
  static TextStyle get labelSmall => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle get videoTitleSmall => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static TextStyle get videoTitle => videoTitleMedium;
  static TextStyle get videoTitleMedium => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static TextStyle get videoTitleLarge => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static TextStyle get titleMedium => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static TextStyle get channelNameSmall => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle get channelName => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle get channelNameLarge => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static TextStyle get videoMetadataSmall => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
  static TextStyle get videoMetadata => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
  static TextStyle get headlineSmall => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static TextStyle get bodySmall => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle get titleLarge => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static TextStyle get displaySmall => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static TextStyle get inputText => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static TextStyle get inputHint => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
  static TextStyle get buttonText => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static TextStyle get labelLarge => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static TextStyle get labelMedium => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static TextStyle get badge => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static TextStyle get pageTitle => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static TextStyle get sectionHeader => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static TextStyle get caption => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
  static TextStyle get captionBold => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppColors.textTertiary,
  );
}

class InteractionStyles {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);

  static Widget interactiveCard({
    required Widget child,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: child,
      );
}

class ComponentStyles {
  static List<BoxShadow> get shadowSmall => [
    const BoxShadow(color: Colors.black12, blurRadius: 4),
  ];
  static BoxDecoration getCardDecoration({BuildContext? context}) =>
      BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      );
}

class CompatColors {
  const CompatColors();
  Color get primary => AppColors.brand;
  Color get brand => AppColors.brand;
  Color get background => AppColors.bgPage;
  Color get surface => AppColors.bgSurface;
  Color get surfaceVariant => AppColors.bgSurfaceHover;
  Color get textPrimary => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textTertiary => AppColors.textTertiary;
  Color get divider => AppColors.bgDivider;
  Color get border => AppColors.bgDivider;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get error => AppColors.error;
  Color get info => AppColors.textLink;
  Color get overlay => AppColors.brandOverlay;
  Color get overlayLight => AppColors.brandOverlay.withValues(alpha: 0.1);
  Color get hoverAccent => AppColors.brandOverlay;
  Color get successDark => AppColors.success;

  Color get crimsonLight => AppColors.brand.withValues(alpha: 0.2);

  // Opacity variations
  Color get textPrimary38 => AppColors.textPrimary.withValues(alpha: 0.38);
  Color get textPrimary54 => AppColors.textPrimary.withValues(alpha: 0.54);
  Color get textPrimary60 => AppColors.textPrimary.withValues(alpha: 0.60);
  Color get textPrimary70 => AppColors.textPrimary.withValues(alpha: 0.70);
  Color get textPrimary30 => AppColors.textPrimary.withValues(alpha: 0.30);

  Color get background54 => AppColors.bgPage.withValues(alpha: 0.54);
  Color get background45 => AppColors.bgPage.withValues(alpha: 0.45);
  Color get background87 => AppColors.bgPage.withValues(alpha: 0.87);
  Color get bgPage54 => AppColors.bgPage.withValues(alpha: 0.54);

  Color get bgSurfaceContainerHighest => AppColors.bgSurfaceHover;
  Color get surfaceContainerHighest => AppColors.bgSurfaceHover;
}

class CompatSpacing {
  const CompatSpacing();
  double get xxs => 2;
  double get xs => 4;
  double get sm => 8;
  double get md => 16;
  double get lg => 24;
  double get xl => 32;

  double get space4 => 4;
  double get space8 => 8;
  double get space12 => 12;
  double get space16 => 16;
  double get space20 => 20;
  double get space24 => 24;
  double get space32 => 32;
}

class CompatTypography {
  const CompatTypography();
  TextStyle get h1 => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  TextStyle get h2 => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  TextStyle get h3 => const TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  TextStyle get label => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 1.2,
  );
  TextStyle get body => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  TextStyle get bodyLarge => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  TextStyle get bodyMedium => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  TextStyle get bodySmall => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  TextStyle get caption => const TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
}

class CompatSizes {
  const CompatSizes();
  double get sidebarWidth => 240;
  double get sidebarWidthCollapsed => 72;
  double get iconSm => 18;
  double get iconMd => 24;
  double get iconLg => 32;
  double get avatarSm => 32;
  double get avatarMd => 48;
  double get avatarLg => 64;
  double get thumbnailMediumWidth => 160;
  double get thumbnailMediumHeight => 90;
  int get imageCacheMediumWidth => 320;
  int get imageCacheMediumHeight => 180;
  int get imageCacheSmallWidth => 160;
  int get imageCacheSmallHeight => 90;
}

class CompatRadius {
  const CompatRadius();
  double get sm => 4;
  double get md => 8;
  double get lg => 12;
  double get xl => 24;
  BorderRadius get circularSm => BorderRadius.circular(4);
  BorderRadius get circularMd => BorderRadius.circular(8);
  BorderRadius get circularLg => BorderRadius.circular(12);
  BorderRadius get circularXl => BorderRadius.circular(24);
}

class CompatInteraction {
  const CompatInteraction();
  Duration get fast => const Duration(milliseconds: 150);
  Duration get normal => const Duration(milliseconds: 300);
  Duration get slow => const Duration(milliseconds: 500);
  Curve get easeOutCubic => Curves.easeOutCubic;
}

class CompatShadows {
  const CompatShadows();
  List<BoxShadow> get elevationSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  List<BoxShadow> get elevationMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  List<BoxShadow> get elevationLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];
}

class CompatComponents {
  const CompatComponents();
  double get dividerThickness => 0.5;
  double get cardPadding => 16;
  double get gridSpacing => 16;
  double get buttonPaddingSmall => 8;
  double get buttonPaddingMedium => 12;
  double get buttonPaddingLarge => 16;

  List<BoxShadow> get shadowSmall => [
    const BoxShadow(color: Colors.black12, blurRadius: 4),
  ];

  BoxDecoration getCardDecoration(BuildContext context) => BoxDecoration(
    color: AppColors.bgSurface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.bgDivider),
  );
}
