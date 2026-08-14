import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme definitions for VideoScreen
/// Extracted to reduce duplication and improve maintainability
class VideoScreenTheme {
  VideoScreenTheme._();

  // Color Palette
  static const Color primary = AppColors.brand;
  static const Color background = AppColors.bgPage;
  static const Color surface = AppColors.bgSurface;
  static const Color surfaceAlt = Color(0xFF1E2A3A);
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textMuted = AppColors.textHint;
  static const Color divider = AppColors.bgDivider;
  static const Color border = AppColors.bgDivider;
  static const Color accent = AppColors.brand;
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;

  // Spacing Constants
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border Radius
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusFull = 9999.0;

  // Typography
  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.3,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.4,
      );

  static TextStyle get titleSmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.4,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMuted,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textMuted,
        letterSpacing: 0.5,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  // Widget Themes
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: divider, width: 1),
      );

  static BoxDecoration get surfaceDecoration => BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(radiusMd),
      );

  static BoxDecoration get avatarDecoration => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: divider, width: 2),
      );

  static BoxDecoration get badgeDecoration => BoxDecoration(
        color: primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(color: primary.withOpacity(0.3)),
      );

  static BoxDecoration get skeletonDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusSm),
      );

  // Button Styles
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
        foregroundColor: textPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
      );

  static ButtonStyle get iconButtonStyle => IconButton.styleFrom(
        foregroundColor: textSecondary,
        padding: const EdgeInsets.all(spacingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
      );

  static ButtonStyle get filledButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        elevation: 0,
      );

  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: divider),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
      );

  // Input Decoration
  static InputDecoration get inputDecoration => InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingMd,
        ),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider),
        ),
      );

  // Divider
  static const Widget dividerVertical = SizedBox(height: spacingMd);
  static const Widget dividerHorizontal = SizedBox(width: spacingMd);
  static Widget get dividerLine => Divider(color: divider, height: 1);

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Responsive Breakpoints
  static const double breakpointMobile = 600;
  static const double breakpointTablet = 1050;
  static const double breakpointDesktop = 1400;

  static bool isMobile(double width) => width < breakpointMobile;
  static bool isTablet(double width) =>
      width >= breakpointMobile && width < breakpointTablet;
  static bool isDesktop(double width) => width >= breakpointTablet;

  // Animation Durations
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // Curve Types
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveDecelerate = Curves.easeOutCubic;
}
