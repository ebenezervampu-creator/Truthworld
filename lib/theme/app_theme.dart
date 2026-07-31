import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/device_state.dart';
import 'package:truthworld/theme/tw_breakpoints.dart';
import 'package:truthworld/theme/tw_colors.dart';
import 'package:truthworld/theme/tw_gradients.dart';
import 'package:truthworld/theme/tw_layout_tokens.dart';
import 'package:truthworld/theme/tw_motion.dart';
import 'package:truthworld/theme/tw_radius.dart';
import 'package:truthworld/theme/tw_shadows.dart';
import 'package:truthworld/theme/tw_spacing.dart';
import 'package:truthworld/theme/tw_typography.dart';

export 'app_colors.dart';
export 'compatibility_layer.dart';
export 'responsive_helpers.dart';
export 'tw_colors.dart';
export 'tw_gradients.dart';
export 'tw_layout_tokens.dart';
export 'tw_motion.dart';
export 'tw_radius.dart';
export 'tw_shadows.dart';
export 'tw_spacing.dart';
export 'tw_typography.dart';

ThemeData buildAppTheme({DeviceState? device}) {
  return ThemeData(
    useMaterial3: true,

    brightness: Brightness.dark,
    primaryColor: AppColors.brand,
    scaffoldBackgroundColor: AppColors.bgPage,
    cardColor: AppColors.bgSurface,
    dividerColor: AppColors.bgDivider,

    extensions: [
      const TWColors(
        brand: AppColors.brand,
        brandContainer: AppColors.brandContainer,
        brandVariant: AppColors.brandVariant,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        textTertiary: AppColors.textTertiary,
        textDisabled: AppColors.textDisabled,
        background: AppColors.bgPage,
        surface: AppColors.bgSurface,
        surfaceContainer: AppColors.bgSurfaceHover,
        surfaceContainerHigh: AppColors.bgSurfaceHigh,
        surfaceContainerHighest: AppColors.bgElevated,
        surfaceInput: AppColors.bgInput,
        appBarSurface: AppColors.appBarSurface,
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
      TWGradients.defaults(),
      if (device != null)
        TWLayoutTokens.fromDevice(device)
      else
        TWLayoutTokens.fromDevice(
          const DeviceState(
            width: 375,
            height: 812,
            type: DeviceType.mobile,
            fontScale: 1,
          ),
        ),
    ],

    colorScheme: const ColorScheme.dark(
      primary: AppColors.brand,
      secondary: AppColors.brand,
      surface: AppColors.bgSurface,
      error: AppColors.error,
      onPrimary: Colors.black,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
      surfaceContainer: AppColors.bgSurfaceHover,
      surfaceContainerHigh: AppColors.bgSurfaceHigh,
      surfaceContainerHighest: AppColors.bgElevated,
      outline: AppColors.bgDivider,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary),
      displayMedium: TextStyle(color: AppColors.textPrimary),
      displaySmall: TextStyle(color: AppColors.textPrimary),
      headlineLarge: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      labelLarge: TextStyle(color: AppColors.textPrimary),
      labelMedium: TextStyle(color: AppColors.textSecondary),
      labelSmall: TextStyle(color: AppColors.textTertiary),
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
      selectedItemColor: Colors.white,
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
        borderSide: const BorderSide(color: AppColors.searchBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.brand),
      ),
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.black,
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
      secondaryLabelStyle: const TextStyle(color: Colors.black),
      brightness: Brightness.dark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
