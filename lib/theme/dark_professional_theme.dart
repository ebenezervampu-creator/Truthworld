// ==========================================================================
// ENHANCED DARK PROFESSIONAL THEME — Home Dashboard
// Extracted from home.dart for clean separation of concerns.
// ==========================================================================

import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

const Color darkBackground = AppColors.bgPage; // Deeper black
const Color darkSurface = AppColors.bgInput; // Rich dark surface
const Color darkSurfaceVariant = Color(0xFF1E1E1E); // Elevated surfaces
const Color darkOnSurface = Color(0xFFE8E8E8); // Crisp white text
const Color darkOnSurfaceVariant = Color(0xFFB8B8B8); // Muted text
const Color primaryAccent = Color(0xFFFFFFFF); // Brand Pure White
const Color secondaryAccent = Color(0xFFE0E0E0); // Accent Light Grey
const Color tertiaryAccent = Color(0xFFCCCCCC); // Subtle Grey

ThemeData darkProfessionalTheme = ThemeData(
  brightness: Brightness.dark,

  primaryColor: primaryAccent,
  colorScheme: ColorScheme.dark(
    primary: primaryAccent,
    primaryContainer: primaryAccent.withValues(alpha: 0.12),
    onPrimaryContainer: Colors.black,
    secondary: secondaryAccent,
    secondaryContainer: secondaryAccent.withValues(alpha: 0.12),
    onSecondaryContainer: Colors.black,
    tertiary: tertiaryAccent,
    onTertiary: Colors.black,
    tertiaryContainer: tertiaryAccent.withValues(alpha: 0.12),
    onTertiaryContainer: Colors.black,
    onSurface: darkOnSurface,
    surfaceContainerHighest: darkSurfaceVariant,
    onSurfaceVariant: darkOnSurfaceVariant,
    error: const Color(0xFFFF6B6B),
    onError: Colors.white,
    outline: darkSurfaceVariant,
    outlineVariant: darkOnSurfaceVariant.withValues(alpha: 0.3),
    surfaceTint: primaryAccent.withValues(alpha: 0.05),
  ),
  scaffoldBackgroundColor: darkBackground,
  cardColor: darkSurface,
  dividerColor: darkSurfaceVariant.withValues(alpha: 0.3),
  // ── Material Design 3 Type Scale — Roboto ──
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      color: Color(0xFFE8E8E8),
      letterSpacing: -0.25,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.16,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.22,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.29,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.33,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.27,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0.15,
      height: 1.5,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0.1,
      height: 1.43,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0.5,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0.25,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Color(0xFFB8B8B8),
      letterSpacing: 0.4,
      height: 1.33,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFFB8B8B8),
      letterSpacing: 0.5,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Color(0xFFB8B8B8),
      letterSpacing: 0.5,
      height: 1.45,
    ),
  ),
  // Enhanced AppBar Theme
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF161618), // matching darkSurface
    foregroundColor: Color(0xFFE8E8E8), // darkOnSurface
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.4,
    ),
    iconTheme: IconThemeData(color: Color(0xFFB8B8B8), size: 24),
    actionsIconTheme: IconThemeData(color: Color(0xFFB8B8B8), size: 24),
  ),
  // Enhanced Card Theme
  cardTheme: CardThemeData(
    color: darkSurface,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
  ),
  // Enhanced Button Themes
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.black,
      backgroundColor: primaryAccent,
      disabledForegroundColor: Colors.white54,
      disabledBackgroundColor: primaryAccent.withValues(alpha: 0.3),
      elevation: 2,
      shadowColor: primaryAccent.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryAccent,
      disabledForegroundColor: primaryAccent.withValues(alpha: 0.3),
      side: BorderSide(color: primaryAccent.withValues(alpha: 0.6), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryAccent,
      disabledForegroundColor: primaryAccent.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
    ),
  ),
  // Enhanced Navigation Themes
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: darkSurface.withValues(alpha: 0.95),
    indicatorColor: primaryAccent.withValues(alpha: 0.15),
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    surfaceTintColor: primaryAccent.withValues(alpha: 0.05),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: primaryAccent, size: 24);
      }
      return const IconThemeData(color: Color(0xFFB8B8B8), size: 24);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      const style = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
      );
      if (states.contains(WidgetState.selected)) {
        return style.copyWith(color: primaryAccent);
      }
      return style.copyWith(color: const Color(0xFFB8B8B8));
    }),
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: darkSurface,
    indicatorColor: primaryAccent.withValues(alpha: 0.15),
    elevation: 1,
    groupAlignment: -1,
    labelType: NavigationRailLabelType.none,
    selectedLabelTextStyle: const TextStyle(
      fontSize: 12,
      color: primaryAccent,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.33,
    ),
    unselectedLabelTextStyle: const TextStyle(
      fontSize: 12,
      color: Color(0xFFB8B8B8),
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.33,
    ),
    selectedIconTheme: const IconThemeData(color: primaryAccent, size: 24),
    unselectedIconTheme: const IconThemeData(
      color: Color(0xFFB8B8B8),
      size: 24,
    ),
  ),
  // Enhanced Chip Theme
  chipTheme: ChipThemeData(
    backgroundColor: darkSurfaceVariant.withValues(alpha: 0.4),
    selectedColor: primaryAccent.withValues(alpha: 0.15),
    secondarySelectedColor: primaryAccent.withValues(alpha: 0.15),
    labelStyle: const TextStyle(
      fontSize: 14,
      color: Color(0xFFB8B8B8),
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    secondaryLabelStyle: const TextStyle(
      fontSize: 14,
      color: primaryAccent,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    side: BorderSide.none,
    brightness: Brightness.dark,
    elevation: 0,
    pressElevation: 1,
  ),
  // Enhanced Dialog Theme
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF161618), // darkSurface
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titleTextStyle: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Color(0xFFE8E8E8),
      letterSpacing: 0,
      height: 1.27,
    ),
    contentTextStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFFB8B8B8),
      letterSpacing: 0.25,
      height: 1.43,
    ),
  ),
  // Enhanced Divider Theme
  dividerTheme: DividerThemeData(
    color: darkSurfaceVariant.withValues(alpha: 0.3),
    thickness: 0.5,
    space: 24,
    indent: 0,
    endIndent: 0,
  ),
  // Enhanced Input Decoration Theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: darkSurfaceVariant.withValues(alpha: 0.3),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: darkSurfaceVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: darkSurfaceVariant.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryAccent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: const TextStyle(
      color: Color(0xFFB8B8B8),
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.43,
    ),
    labelStyle: const TextStyle(
      color: Color(0xFFB8B8B8),
      fontWeight: FontWeight.w500,
      fontSize: 14,
    ),
  ),
);

// Layout Constants
const double kTabletBreakpoint = 600;
const double kDesktopBreakpoint = 1000;
const double kSideNavWidth = 280;
const double kCompactSideNavWidth = 80;
const double kBottomNavBarHeight = kToolbarHeight;

// Theme alias for backwards compatibility
ThemeData get modernDarkProfessionalTheme => darkProfessionalTheme;
