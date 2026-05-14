import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

export 'app_colors.dart';
export 'responsive_helpers.dart';
export 'compatibility_layer.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.brand,
    scaffoldBackgroundColor: AppColors.bgPage,
    cardColor: AppColors.bgSurface,
    dividerColor: AppColors.bgDivider,
    
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brand,
      secondary: AppColors.brand,
      surface: AppColors.bgSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
      surfaceContainerHighest: AppColors.bgSurfaceHover,
    ),

    textTheme: TextTheme(
      displayLarge: GoogleFonts.roboto(color: AppColors.textPrimary),
      displayMedium: GoogleFonts.roboto(color: AppColors.textPrimary),
      displaySmall: GoogleFonts.roboto(color: AppColors.textPrimary),
      headlineLarge: GoogleFonts.roboto(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.roboto(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineSmall: GoogleFonts.roboto(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.roboto(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      titleMedium: GoogleFonts.roboto(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.roboto(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.roboto(color: AppColors.textPrimary),
      bodyMedium: GoogleFonts.roboto(color: AppColors.textPrimary),
      bodySmall: GoogleFonts.roboto(color: AppColors.textSecondary),
      labelLarge: GoogleFonts.roboto(color: AppColors.textPrimary),
      labelMedium: GoogleFonts.roboto(color: AppColors.textSecondary),
      labelSmall: GoogleFonts.roboto(color: AppColors.textTertiary),
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
