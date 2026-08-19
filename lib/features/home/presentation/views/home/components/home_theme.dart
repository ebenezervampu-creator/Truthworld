import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// TRUTHWORLD HOME THEME - EXTRACTED FROM MONOLITHIC HOME.DART
// Professional dark theme with blue accents for TruthWorld app
// ==========================================================================

class HomeTheme {
  // Color Palette
  static const Color darkBackground = AppColors.bgPage;
  static const Color darkSurface = AppColors.bgInput;
  static const Color darkSurfaceVariant = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Color(0xFFE8E8E8);
  static const Color darkOnSurfaceVariant = Color(0xFFB8B8B8);
  
  // Accent Colors
  static const Color primaryAccent = Color(0xFF1976D2);
  static const Color secondaryAccent = Color(0xFF42A5F5);
  static const Color tertiaryAccent = Color(0xFF90CAF9);

  static ThemeData get darkProfessionalTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAccent,
      colorScheme: _buildColorScheme(),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkSurface,
      dividerColor: darkSurfaceVariant.withValues(alpha: 0.3),
      textTheme: _buildTypography(),
      appBarTheme: _buildAppBarTheme(),
      cardTheme: _buildCardTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      navigationBarTheme: _buildNavigationBarTheme(),
      navigationRailTheme: _buildNavigationRailTheme(),
      chipTheme: _buildChipTheme(),
      dialogTheme: _buildDialogTheme(),
      dividerTheme: _buildDividerTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
    );
  }

  static ColorScheme _buildColorScheme() {
    return ColorScheme.dark(
      primary: primaryAccent,
      onPrimary: Colors.white,
      primaryContainer: primaryAccent.withValues(alpha: 0.12),
      onPrimaryContainer: primaryAccent,
      secondary: secondaryAccent,
      onSecondary: Colors.white,
      secondaryContainer: secondaryAccent.withValues(alpha: 0.12),
      onSecondaryContainer: secondaryAccent,
      tertiary: tertiaryAccent,
      onTertiary: Colors.white,
      tertiaryContainer: tertiaryAccent.withValues(alpha: 0.12),
      onTertiaryContainer: tertiaryAccent,
      onSurface: darkOnSurface,
      surfaceContainerHighest: darkSurfaceVariant,
      onSurfaceVariant: darkOnSurfaceVariant,
      error: const Color(0xFFFF6B6B),
      onError: Colors.white,
      outline: darkSurfaceVariant,
      outlineVariant: darkOnSurfaceVariant.withValues(alpha: 0.3),
      surfaceTint: primaryAccent.withValues(alpha: 0.05),
    );
  }

  static TextTheme _buildTypography() {
    return GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.roboto(
        fontWeight: FontWeight.w300,
        color: darkOnSurface,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.roboto(
        fontWeight: FontWeight.w400,
        color: darkOnSurface,
        letterSpacing: -0.25,
      ),
      displaySmall: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurface,
      ),
      headlineLarge: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurface,
        letterSpacing: -0.25,
      ),
      headlineMedium: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurface,
      ),
      headlineSmall: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurface,
      ),
      titleLarge: GoogleFonts.roboto(
        fontWeight: FontWeight.bold,
        color: darkOnSurface,
        letterSpacing: 0.15,
      ),
      titleMedium: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurface,
        letterSpacing: 0.1,
      ),
      titleSmall: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurface,
        letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.roboto(
        fontWeight: FontWeight.w400,
        color: darkOnSurface,
        letterSpacing: 0.15,
      ),
      bodyMedium: GoogleFonts.roboto(
        fontWeight: FontWeight.w400,
        color: darkOnSurface,
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.roboto(
        fontWeight: FontWeight.w400,
        color: darkOnSurfaceVariant,
        letterSpacing: 0.4,
      ),
      labelLarge: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurfaceVariant,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: darkOnSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme() {
    return AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkOnSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: primaryAccent.withValues(alpha: 0.05),
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: darkOnSurface,
        letterSpacing: 0.15,
      ),
      iconTheme: const IconThemeData(color: darkOnSurfaceVariant, size: 24),
      actionsIconTheme: const IconThemeData(color: darkOnSurfaceVariant, size: 24),
    );
  }

  static CardThemeData _buildCardTheme() {
    return CardThemeData(
      color: darkSurface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryAccent,
        disabledForegroundColor: Colors.white54,
        disabledBackgroundColor: primaryAccent.withValues(alpha: 0.3),
        elevation: 2,
        shadowColor: primaryAccent.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryAccent,
        disabledForegroundColor: primaryAccent.withValues(alpha: 0.3),
        side: BorderSide(color: primaryAccent.withValues(alpha: 0.6), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        textStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryAccent,
        disabledForegroundColor: primaryAccent.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static NavigationBarThemeData _buildNavigationBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: darkSurface.withValues(alpha: 0.95),
      indicatorColor: primaryAccent.withValues(alpha: 0.15),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      surfaceTintColor: primaryAccent.withValues(alpha: 0.05),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 24);
        }
        return const IconThemeData(color: darkOnSurfaceVariant, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final style = GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        );
        if (states.contains(WidgetState.selected)) {
          return style.copyWith(color: primaryAccent);
        }
        return style.copyWith(color: darkOnSurfaceVariant);
      }),
    );
  }

  static NavigationRailThemeData _buildNavigationRailTheme() {
    return NavigationRailThemeData(
      backgroundColor: darkSurface,
      indicatorColor: primaryAccent.withValues(alpha: 0.15),
      elevation: 1,
      groupAlignment: -1.0,
      labelType: NavigationRailLabelType.none,
      selectedLabelTextStyle: GoogleFonts.roboto(
        fontSize: 12,
        color: primaryAccent,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      unselectedLabelTextStyle: GoogleFonts.roboto(
        fontSize: 12,
        color: darkOnSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
      unselectedIconTheme: const IconThemeData(color: darkOnSurfaceVariant, size: 24),
    );
  }

  static ChipThemeData _buildChipTheme() {
    return ChipThemeData(
      backgroundColor: darkSurfaceVariant.withValues(alpha: 0.4),
      selectedColor: primaryAccent.withValues(alpha: 0.15),
      secondarySelectedColor: primaryAccent.withValues(alpha: 0.15),
      labelStyle: GoogleFonts.roboto(
        fontSize: 13,
        color: darkOnSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      secondaryLabelStyle: GoogleFonts.roboto(
        fontSize: 13,
        color: primaryAccent,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide.none,
      brightness: Brightness.dark,
      elevation: 0,
      pressElevation: 1,
    );
  }

  static DialogThemeData _buildDialogTheme() {
    return DialogThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: darkOnSurface,
        letterSpacing: 0.15,
      ),
      contentTextStyle: GoogleFonts.roboto(
        fontSize: 16,
        color: darkOnSurfaceVariant,
        letterSpacing: 0.25,
      ),
    );
  }

  static DividerThemeData _buildDividerTheme() {
    return DividerThemeData(
      color: darkSurfaceVariant.withValues(alpha: 0.3),
      thickness: 0.5,
      space: 24,
      indent: 0,
      endIndent: 0,
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
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
      hintStyle: GoogleFonts.roboto(
        color: darkOnSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.roboto(
        color: darkOnSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

extension StringExtension on String {
  String safeSubstring(int start, int end) {
    if (isEmpty) return this;
    var actualEnd = end;
    if (actualEnd > length) actualEnd = length;
    return substring(start, actualEnd);
  }
}
