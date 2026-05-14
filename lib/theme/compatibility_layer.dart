import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

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

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;

  static const Duration animDuration = Duration(milliseconds: 300);
  static const Curve animCurveEaseOut = Curves.easeOutCubic;

  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 10.0;

  static const List<BoxShadow> elevationSmall = [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))];
}

class AppTokens {
  static const colors = CompatColors();
  static const spacing = CompatSpacing();
  static const radius = CompatRadius();
  static const typography = CompatTypography();
  static const sizes = CompatSizes();
}

class AppTextStyles {
  static TextStyle get labelSmall => GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get videoTitleSmall => GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary);
  static TextStyle get videoTitleMedium => GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary);
  static TextStyle get videoTitleLarge => GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static TextStyle get titleMedium => GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary);
  static TextStyle get channelNameSmall => GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get channelName => GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get videoMetadataSmall => GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary);
  static TextStyle get videoMetadata => GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textTertiary);
  static TextStyle get headlineSmall => GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static TextStyle get bodyMedium => GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle get bodyLarge => GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle get bodySmall => GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get titleLarge => GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
}

class InteractionStyles {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  
  static Widget interactiveCard({required Widget child, required VoidCallback onTap}) => InkWell(onTap: onTap, child: child);
}

class ComponentStyles {
  static List<BoxShadow> get shadowSmall => [BoxShadow(color: Colors.black12, blurRadius: 4)];
  static BoxDecoration getCardDecoration({BuildContext? context}) => BoxDecoration(
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
  double get xxs => 2.0;
  double get xs => 4.0;
  double get sm => 8.0;
  double get md => 16.0;
  double get lg => 24.0;
  double get xl => 32.0;
  
  double get space4 => 4.0;
  double get space8 => 8.0;
  double get space12 => 12.0;
  double get space16 => 16.0;
  double get space20 => 20.0;
  double get space24 => 24.0;
  double get space32 => 32.0;
}

class CompatTypography {
  const CompatTypography();
  TextStyle get h1 => GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  TextStyle get h2 => GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  TextStyle get h3 => GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  TextStyle get label => GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary, letterSpacing: 1.2);
  TextStyle get body => GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  TextStyle get bodyLarge => GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  TextStyle get bodyMedium => GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  TextStyle get bodySmall => GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  TextStyle get caption => GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary);
}

class CompatSizes {
  const CompatSizes();
  double get sidebarWidth => 240.0;
  double get sidebarWidthCollapsed => 72.0;
  double get iconSm => 18.0;
  double get iconMd => 24.0;
  double get iconLg => 32.0;
  double get avatarSm => 32.0;
  double get avatarMd => 48.0;
  double get avatarLg => 64.0;
  double get thumbnailMediumWidth => 160.0;
  double get thumbnailMediumHeight => 90.0;
  int get imageCacheMediumWidth => 320;
  int get imageCacheMediumHeight => 180;
  int get imageCacheSmallWidth => 160;
  int get imageCacheSmallHeight => 90;
}

class CompatRadius {
  const CompatRadius();
  double get sm => 4.0;
  double get md => 8.0;
  double get lg => 12.0;
  double get xl => 24.0;
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
  List<BoxShadow> get elevationSm => [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))];
  List<BoxShadow> get elevationMd => [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))];
  List<BoxShadow> get elevationLg => [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))];
}

class CompatComponents {
  const CompatComponents();
  double get dividerThickness => 0.5;
  double get cardPadding => 16.0;
  double get gridSpacing => 16.0;
  double get buttonPaddingSmall => 8.0;
  double get buttonPaddingMedium => 12.0;
  double get buttonPaddingLarge => 16.0;
  
  List<BoxShadow> get shadowSmall => [BoxShadow(color: Colors.black12, blurRadius: 4)];
  
  BoxDecoration getCardDecoration(BuildContext context) => BoxDecoration(
    color: AppColors.bgSurface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.bgDivider),
  );
}



