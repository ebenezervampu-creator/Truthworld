import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'tw_colors.dart';
import 'tw_typography.dart';
import 'tw_spacing.dart';
import 'tw_radius.dart';
import 'tw_motion.dart';
import 'tw_shadows.dart';

export 'app_colors.dart';
export 'responsive_helpers.dart';
export 'compatibility_layer.dart';
export 'tw_colors.dart';
export 'tw_typography.dart';
export 'tw_spacing.dart';
export 'tw_radius.dart';
export 'tw_motion.dart';
export 'tw_shadows.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    primaryColor: AppColors.brand,
    scaffoldBackgroundColor: AppColors.bgPage,
    cardColor: AppColors.bgSurface,
    dividerColor: AppColors.bgDivider,
    
    extensions: [
      const TWColors(
        brand: AppColors.brand,
        brandMuted: AppColors.brandMuted,
        brandContainer: AppColors.brandContainer,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        textTertiary: AppColors.textTertiary,
        textDisabled: AppColors.textDisabled,
        background: AppColors.bgPage,
        surface: AppColors.bgSurface,
        surfaceElevated: AppColors.bgElevated,
        surfaceContainer: AppColors.bgSurfaceHover,
        divider: AppColors.bgDivider,
        success: AppColors.success,
        warning: AppColors.warning,
        error: AppColors.error,
        info: AppColors.info,
        successContainer: AppColors.successContainer,
        warningContainer: AppColors.warningContainer,
        errorContainer: AppColors.errorContainer,
        infoContainer: AppColors.infoContainer,
        selectedOverlay: AppColors.selectedOverlay,
        hoverOverlay: AppColors.hoverOverlay,
        pressedOverlay: AppColors.pressedOverlay,
        focusRing: AppColors.focusRing,
      ),
      TWTypography.defaults(AppColors.textPrimary),
      TWSpacing.defaults(),
      TWRadius.defaults(),
      TWMotion.defaults(),
      TWShadows.defaults(),
    ],
    
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brand,
      secondary: AppColors.brand,
      surface: AppColors.bgSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
      surfaceContainer: AppColors.bgSurfaceHover,
      surfaceContainerHigh: AppColors.bgSurfaceHigh,
      surfaceContainerHighest: AppColors.bgElevated,
      outline: AppColors.bgDivider,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary),
      displayMedium: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary),
      displaySmall: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary),
      headlineLarge: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary),
      bodySmall: TextStyle(fontFamily: 'Roboto', color: AppColors.textSecondary),
      labelLarge: TextStyle(fontFamily: 'Roboto', color: AppColors.textPrimary),
      labelMedium: TextStyle(fontFamily: 'Roboto', color: AppColors.textSecondary),
      labelSmall: TextStyle(fontFamily: 'Roboto', color: AppColors.textTertiary),
    ),

    iconTheme: const IconThemeData(color: AppColors.iconDefault),
    primaryIconTheme: const IconThemeData(color: AppColors.iconActive),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgPage,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgPage,
      selectedItemColor: AppColors.brand,
      unselectedItemColor: AppColors.iconDefault,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.searchBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.brand, width: 1),
      ),
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgSurface,
      disabledColor: AppColors.bgSurface,
      selectedColor: AppColors.brand,
      secondarySelectedColor: AppColors.brand,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: const TextStyle(color: AppColors.textPrimary),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      brightness: Brightness.dark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
