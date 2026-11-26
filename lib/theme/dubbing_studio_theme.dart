import 'package:flutter/material.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Flagship dark-room design system for TruthWorld Dubbing Studio.
///
/// Built for high-craft creator audio/video localization:
/// - Pitch-obsidian canvas (`#050507`) & architectural card surfaces (`#0E0E12`)
/// - Whisper-thin 1px hairline borders (`rgba(255,255,255,0.08)`)
/// - Crisp geometric display & UI typography (`TWTypography`) paired with
///   tabular monospace (`JetBrains Mono` / `Roboto Mono`) for timecodes,
///   durations, project counts, and character quotas.
class DubbingStudioTheme {
  DubbingStudioTheme._();

  // ── Surfaces (Pitch Obsidian) ──────────────────────────────────────────────
  static const Color canvasBg = Color(0xFF050507);
  static const Color chromeBg = Color(0xFF09090C);
  static const Color cardBg = Color(0xFF0E0E12);
  static const Color surfaceElevated = Color(0xFF16161C);
  static const Color elevatedPill = Color(0xFF1E1E26);
  static const Color inputBg = Color(0xFF0A0A0D);

  // ── Hairline Borders ───────────────────────────────────────────────────────
  static final Color borderSubtle = Colors.white.withValues(alpha: 0.08);
  static final Color borderMedium = Colors.white.withValues(alpha: 0.14);
  static final Color borderStrong = Colors.white.withValues(alpha: 0.22);

  // ── Text Hierarchy ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textTertiary = Color(0xFF71717A);

  // ── Studio Accents ─────────────────────────────────────────────────────────
  static const Color accentIndigo = Color(0xFF818CF8);
  static const Color accentIndigoBg = Color(0xFF161624);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFEF4444);
  static const Color accentSky = Color(0xFF38BDF8);

  // ── Radii ──────────────────────────────────────────────────────────────────
  static const double radiusCard = 14.0;
  static const double radiusControl = 10.0;
  static const double radiusPill = 8.0;

  // ── Typography ─────────────────────────────────────────────────────────────
  static const String monoFamily = 'JetBrains Mono';
  static const List<String> monoFallbacks = [
    'Roboto Mono',
    'SF Mono',
    'Consolas',
    'monospace',
  ];

  static const TextStyle displayHero = TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    color: textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.15,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: TWTypography.brandFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    color: textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    color: textSecondary,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle labelCaps = TextStyle(
    fontFamily: TWTypography.uiFamily,
    fontFamilyFallback: TWTypography.fallbackFamilies,
    color: textTertiary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  static const TextStyle monoMeta = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallbacks,
    color: textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle monoBadge = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallbacks,
    color: textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
