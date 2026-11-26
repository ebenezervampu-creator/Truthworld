import 'package:flutter/material.dart';

/// Refined "Flagship Terracotta" aesthetic design system for TruthWorld Dubbing Studio.
///
/// Features:
/// - Warm alabaster surfaces
/// - Architectural terracotta accents
/// - Sharp espresso typography (Inter)
/// - Crisp 12px corners and 8px button radii
/// - Optional Carbon Cinema dark-mode twin
class DubbingTerracottaTheme {
  DubbingTerracottaTheme._();

  // ── Surfaces (Warm Alabaster) ──────────────────────────────────
  static const Color bgPage = Color(0xFFF7F5F0);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSurfaceAlt = Color(0xFFFAF8F4);
  static const Color bgNav = Color(0xFFFCFBF8);

  // ── Borders ────────────────────────────────────────────────────
  static const Color borderSubtle = Color(0xFFE5DFD5);
  static const Color borderDashed = Color(0xFFD8B49E);

  // ── Typography (Sharp Espresso - Inter) ─────────────────────────
  static const String fontFamily = 'Inter';
  static const Color textPrimary = Color(0xFF1A1614);
  static const Color textSecondary = Color(0xFF574E47);
  static const Color textMuted = Color(0xFF7D7269);

  // ── Brand & Interactive Accents (Architectural Terracotta) ──────
  static const Color accent = Color(0xFFB83B0A);
  static const Color accentHover = Color(0xFF962F07);
  static const Color accentSoft = Color(0xFFF8EBE4);
  static const Color accentContrast = Color(0xFFFFFFFF);
  static const Color accentSecondary = Color(0xFFD97757);

  // ── Active Navigation Pills ────────────────────────────────────
  static const Color bgPillActive = Color(0xFFF6E7DF);
  static const Color textPillActive = Color(0xFF9A3412);

  // ── Hero Banner (Whisper-Light Editorial Cream) ────────────────
  static const Color heroFrom = Color(0xFFFDFCFA);
  static const Color heroVia = Color(0xFFFAF5EE);
  static const Color heroTo = Color(0xFFF4EADF);
  static const Color heroPillBg = Color(0xFFFFFFFF);
  static const Color heroPillText = Color(0xFF29221E);
  static const Color heroPillBorder = Color(0xFFE5DFD5);

  // ── Bottom Feature Cards ───────────────────────────────────────
  static const Color card1Bg = Color(0xFFFCFAF7);
  static const Color card1IconBg = Color(0xFFF6E7DF);
  static const Color card1Icon = Color(0xFFB83B0A);

  static const Color card2Bg = Color(0xFFF8FAF8);
  static const Color card2IconBg = Color(0xFFE2F1E7);
  static const Color card2Icon = Color(0xFF166534);

  static const Color card3Bg = Color(0xFFFCFAF5);
  static const Color card3IconBg = Color(0xFFF7EBD2);
  static const Color card3Icon = Color(0xFFA16207);

  static const Color card4Bg = Color(0xFFF8F9FA);
  static const Color card4IconBg = Color(0xFFE7E5E4);
  static const Color card4Icon = Color(0xFF44403C);

  // ── Radii & Shapes (Crisp 12px corners) ────────────────────────
  static const double radiusCard = 12.0;
  static const double radiusBtn = 8.0;

  static final BorderRadius borderRadiusCard = BorderRadius.circular(radiusCard);
  static final BorderRadius borderRadiusBtn = BorderRadius.circular(radiusBtn);

  // ── Shadows ────────────────────────────────────────────────────
  static const BoxShadow shadowCard = BoxShadow(
    color: Color(0x0D1A1614), // rgba(26, 22, 20, 0.05)
    blurRadius: 20,
    offset: Offset(0, 4),
  );

  static const BoxShadow shadowFloat = BoxShadow(
    color: Color(0x141A1614), // rgba(26, 22, 20, 0.08)
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  // ── Carbon Cinema Dark Mode Twin ───────────────────────────────
  static const Color bgPageDark = Color(0xFF0C0A09);
  static const Color bgSurfaceDark = Color(0xFF171412);
  static const Color bgSurfaceAltDark = Color(0xFF1F1B18);
  static const Color bgNavDark = Color(0xFF12100E);
  static const Color borderSubtleDark = Color(0xFF292524);
  static const Color borderDashedDark = Color(0xFFB45309);
  static const Color textPrimaryDark = Color(0xFFFAFAF9);
  static const Color textSecondaryDark = Color(0xFFD6D3D1);
  static const Color textMutedDark = Color(0xFFA8A29E);

  // ── Typography Helpers ─────────────────────────────────────────
  static const TextStyle displayHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle labelUppercase = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 1.0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );
}
